<?php
/**
 * A Studio upload endpoint: POST /api/upload.php (same origin as the app).
 *
 * Fields: file (multipart), idToken (Firebase sign-in), optional private=1
 * with kind=id|work for verification files.
 *
 * Public uploads are stored at /media/<uid>/<random>.<ext> and return
 *   {"url": "...", "thumbUrl": "..."}   (thumbUrl for photos when GD is on)
 * Private uploads go outside the website and return {"path": "<uid>/..."}.
 */
define('ASTUDIO', 1);
require __DIR__ . '/config.php';

require_same_origin();
$user = require_user();
$uid = $user['uid'];

if (!isset($_FILES['file']) || !is_array($_FILES['file'])) {
    fail(400, 'No file received.');
}
$file = $_FILES['file'];
if ($file['error'] === UPLOAD_ERR_INI_SIZE || $file['error'] === UPLOAD_ERR_FORM_SIZE) {
    fail(413, 'That file is too large for the server.');
}
if ($file['error'] !== UPLOAD_ERR_OK || !is_uploaded_file($file['tmp_name'])) {
    fail(400, 'The upload did not finish. Try again.');
}

$finfo = new finfo(FILEINFO_MIME_TYPE);
$mime = $finfo->file($file['tmp_name']);
if (!isset(ALLOWED_TYPES[$mime])) {
    fail(415, 'Only photos (JPG, PNG, WebP, GIF) and videos (MP4, WebM, MOV) can be uploaded.');
}
list($ext, $kind) = ALLOWED_TYPES[$mime];
$cap = $kind === 'video' ? VIDEO_MAX_BYTES : IMAGE_MAX_BYTES;
if ($file['size'] <= 0 || $file['size'] > $cap) {
    fail(413, $kind === 'video' ? 'Videos must be 64 MB or smaller.' : 'Photos must be 8 MB or smaller.');
}

// ---------------------------------------------------------------- private
if (isset($_POST['private']) && $_POST['private'] === '1') {
    $pkind = isset($_POST['kind']) ? (string) $_POST['kind'] : '';
    if ($pkind !== 'id' && $pkind !== 'work') {
        fail(400, 'Unknown private file kind.');
    }
    $root = private_root();
    ensure_dir($root, true);
    guard_private_dir($root);
    $dir = $root . '/' . $uid;
    ensure_dir($dir, true);
    $name = $pkind . '_' . random_name($ext);
    if (!move_uploaded_file($file['tmp_name'], $dir . '/' . $name)) {
        fail(500, 'Could not save the file.');
    }
    @chmod($dir . '/' . $name, 0600);
    send_json(200, ['path' => $uid . '/' . $name]);
}

// ---------------------------------------------------------------- public
$root = media_root();
ensure_dir($root);
guard_media_dir($root);
$dir = $root . '/' . $uid;
ensure_dir($dir);

$name = random_name($ext);
$dest = $dir . '/' . $name;
if (!move_uploaded_file($file['tmp_name'], $dest)) {
    fail(500, 'Could not save the file.');
}
@chmod($dest, 0644);

$base = media_url_base() . '/' . $uid . '/';
$out = ['url' => $base . $name, 'thumbUrl' => ''];

// A small copy for grids, when the server has GD. Never fatal.
if ($kind === 'image' && $mime !== 'image/gif' && function_exists('imagecreatetruecolor')) {
    try {
        $src = null;
        if ($mime === 'image/jpeg' && function_exists('imagecreatefromjpeg')) $src = @imagecreatefromjpeg($dest);
        if ($mime === 'image/png' && function_exists('imagecreatefrompng')) $src = @imagecreatefrompng($dest);
        if ($mime === 'image/webp' && function_exists('imagecreatefromwebp')) $src = @imagecreatefromwebp($dest);
        if ($src) {
            $w = imagesx($src);
            $h = imagesy($src);
            $long = max($w, $h);
            if ($long > THUMB_SIDE) {
                $scale = THUMB_SIDE / $long;
                $tw = max(1, (int) round($w * $scale));
                $th = max(1, (int) round($h * $scale));
                $dst = imagecreatetruecolor($tw, $th);
                $white = imagecolorallocate($dst, 255, 255, 255);
                imagefill($dst, 0, 0, $white);
                imagecopyresampled($dst, $src, 0, 0, 0, 0, $tw, $th, $w, $h);
                $tname = substr($name, 0, strrpos($name, '.')) . '_t.jpg';
                if (@imagejpeg($dst, $dir . '/' . $tname, 80)) {
                    @chmod($dir . '/' . $tname, 0644);
                    $out['thumbUrl'] = $base . $tname;
                }
                imagedestroy($dst);
            }
            imagedestroy($src);
        }
    } catch (Throwable $e) {
        // Thumbnails are a nicety; the original is already saved.
    }
}

send_json(200, $out);
