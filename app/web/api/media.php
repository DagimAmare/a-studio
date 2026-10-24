<?php
/**
 * A Studio media management: POST /api/media.php
 *
 *   action=delete         url=<public media url>     owner or admin
 *   action=purge                                     owner: every file they uploaded
 *   action=private_get    path=<uid>/<file>          owner or admin, streams the file
 *   action=private_delete path=<uid>/<file>          owner or admin
 */
define('ASTUDIO', 1);
require __DIR__ . '/config.php';

require_same_origin();
$user = require_user();
$uid = $user['uid'];
$action = isset($_POST['action']) ? (string) $_POST['action'] : '';

function remove_tree($dir) {
    if (!is_dir($dir)) return 0;
    $n = 0;
    foreach (scandir($dir) as $f) {
        if ($f === '.' || $f === '..') continue;
        $p = $dir . '/' . $f;
        if (is_dir($p)) {
            $n += remove_tree($p);
        } elseif (@unlink($p)) {
            $n++;
        }
    }
    @rmdir($dir);
    return $n;
}

/** Verification files older than 30 days are removed whatever happened. */
function sweep_private($root) {
    if (!is_dir($root)) return;
    $limit = time() - 30 * 86400;
    foreach (glob($root . '/*/*_*.*') ?: [] as $f) {
        if (is_file($f) && filemtime($f) < $limit) @unlink($f);
    }
}

switch ($action) {
    case 'delete': {
        $url = isset($_POST['url']) ? (string) $_POST['url'] : '';
        $prefix = media_url_base() . '/';
        if (strpos($url, $prefix) !== 0) fail(400, 'Not an A Studio media file.');
        $rel = substr($url, strlen($prefix));
        if (!preg_match('/^([A-Za-z0-9_-]{6,128})\/([a-f0-9]{32}(_t)?\.(jpg|png|webp|gif|mp4|webm|mov))$/', $rel, $m)) {
            fail(400, 'Bad media path.');
        }
        if ($m[1] !== $uid && !is_admin($user)) fail(403, 'Not your file.');
        $path = media_root() . '/' . $m[1] . '/' . $m[2];
        $removed = is_file($path) && @unlink($path);
        // The grid thumbnail goes with its original.
        if (empty($m[3])) {
            $thumb = media_root() . '/' . $m[1] . '/' . substr($m[2], 0, strrpos($m[2], '.')) . '_t.jpg';
            if (is_file($thumb)) @unlink($thumb);
        }
        send_json(200, ['deleted' => $removed]);
    }
    case 'purge': {
        $n = remove_tree(media_root() . '/' . $uid);
        $root = private_root();
        $n += remove_tree($root . '/' . $uid);
        send_json(200, ['deleted' => $n]);
    }
    case 'private_get': {
        $path = isset($_POST['path']) ? (string) $_POST['path'] : '';
        if (!valid_private_path($path)) fail(400, 'Bad path.');
        $owner = substr($path, 0, strpos($path, '/'));
        $admin = is_admin($user);
        if ($owner !== $uid && !$admin) fail(403, 'Not allowed.');
        $root = private_root();
        if ($admin) sweep_private($root);
        $file = $root . '/' . $path;
        if (!is_file($file)) fail(404, 'That file is gone (files are removed after the decision).');
        $finfo = new finfo(FILEINFO_MIME_TYPE);
        $mime = $finfo->file($file) ?: 'application/octet-stream';
        http_response_code(200);
        header('Content-Type: ' . $mime);
        header('Content-Length: ' . filesize($file));
        header('Cache-Control: no-store, private');
        header('X-Content-Type-Options: nosniff');
        readfile($file);
        exit;
    }
    case 'private_delete': {
        $path = isset($_POST['path']) ? (string) $_POST['path'] : '';
        if (!valid_private_path($path)) fail(400, 'Bad path.');
        $owner = substr($path, 0, strpos($path, '/'));
        if ($owner !== $uid && !is_admin($user)) fail(403, 'Not allowed.');
        $file = private_root() . '/' . $path;
        $removed = is_file($file) && @unlink($file);
        send_json(200, ['deleted' => $removed]);
    }
    default:
        fail(400, 'Unknown action.');
}
