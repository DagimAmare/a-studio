<?php
/**
 * A Studio endpoints: shared settings and helpers. Not a page.
 * Included by upload.php, media.php and ../studio.php.
 *
 * Nothing here is secret: the Firebase web API key and project id are
 * already public in the web app. They only scope Google's checks to the
 * A Studio project.
 */
if (!defined('ASTUDIO')) {
    http_response_code(404);
    exit;
}

const FIREBASE_API_KEY = 'AIzaSyD19QkSbcaBvb3RkkVYQLl30nAQJTVPMjc';
const FIREBASE_PROJECT = 'astudio-207';
const SITE_ORIGIN = 'https://astudio.hepius.co';

const IMAGE_MAX_BYTES = 8 * 1024 * 1024;    // keep in sync with media_types.dart
const VIDEO_MAX_BYTES = 64 * 1024 * 1024;   // keep in sync with media_types.dart
const THUMB_SIDE = 640;

// Real bytes decide the type, never the name or what the browser says.
const ALLOWED_TYPES = [
    'image/jpeg'      => ['jpg',  'image'],
    'image/png'       => ['png',  'image'],
    'image/webp'      => ['webp', 'image'],
    'image/gif'       => ['gif',  'image'],
    'video/mp4'       => ['mp4',  'video'],
    'video/webm'      => ['webm', 'video'],
    'video/quicktime' => ['mov',  'video'],
];

function send_json($code, $data) {
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function fail($code, $msg) {
    send_json($code, ['error' => $msg]);
}

/** Only the A Studio site may call these endpoints from a browser. */
function require_same_origin() {
    $origin = isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : '';
    if ($origin !== '' && $origin !== SITE_ORIGIN) {
        fail(403, 'Origin not allowed.');
    }
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        fail(405, 'POST only.');
    }
}

function http_json($method, $url, $body = null, $headers = []) {
    if (!function_exists('curl_init')) {
        return [0, null];
    }
    $ch = curl_init($url);
    $opts = [
        CURLOPT_CUSTOMREQUEST  => $method,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT        => 10,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_HTTPHEADER     => array_merge(['Accept: application/json'], $headers),
    ];
    if ($body !== null) {
        $opts[CURLOPT_POSTFIELDS] = json_encode($body);
        $opts[CURLOPT_HTTPHEADER][] = 'Content-Type: application/json';
    }
    curl_setopt_array($ch, $opts);
    $resp = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($resp === false) {
        return [0, null];
    }
    return [$code, json_decode($resp, true)];
}

/**
 * Confirms a Firebase ID token with Google and returns the account's uid,
 * or fails the request. Google does the signature and expiry checks.
 */
function require_user() {
    $idToken = isset($_POST['idToken']) ? (string) $_POST['idToken'] : '';
    if ($idToken === '') {
        fail(401, 'Please sign in first.');
    }
    if (!function_exists('curl_init')) {
        fail(500, 'The server cannot check sign-ins (cURL is missing).');
    }
    list($code, $data) = http_json('POST',
        'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' . urlencode(FIREBASE_API_KEY),
        ['idToken' => $idToken]);
    if ($code !== 200 || !is_array($data) || empty($data['users'][0]['localId'])) {
        fail(401, 'Your session has expired. Sign in again and retry.');
    }
    $uid = (string) $data['users'][0]['localId'];
    if (!preg_match('/^[A-Za-z0-9_-]{6,128}$/', $uid)) {
        fail(401, 'Unexpected account id.');
    }
    return ['uid' => $uid, 'idToken' => $idToken];
}

/**
 * True when admins/{uid} exists. Asked of Firestore with the person's own
 * token, so the database rules decide (only an admin can read it).
 */
function is_admin($user) {
    list($code,) = http_json('GET',
        'https://firestore.googleapis.com/v1/projects/' . FIREBASE_PROJECT .
        '/databases/(default)/documents/admins/' . rawurlencode($user['uid']),
        null, ['Authorization: Bearer ' . $user['idToken']]);
    return $code === 200;
}

/** Public media lives in <document root>/media/<uid>/. */
function media_root() {
    return dirname(__DIR__) . '/media';
}

function media_url_base() {
    return SITE_ORIGIN . '/media';
}

/**
 * Private files (verification) live OUTSIDE the website, in the hosting
 * account's home folder, so no URL can ever reach them.
 */
function private_root() {
    $home = getenv('HOME');
    if (!$home && function_exists('posix_getpwuid') && function_exists('posix_geteuid')) {
        $pw = @posix_getpwuid(posix_geteuid());
        if (is_array($pw) && !empty($pw['dir'])) {
            $home = $pw['dir'];
        }
    }
    if (!$home) {
        $parts = explode('/', __DIR__);
        if (count($parts) > 2 && $parts[1] === 'home') {
            $home = '/home/' . $parts[2];
        }
    }
    if (!$home) {
        fail(500, 'Private storage is not available on this server.');
    }
    return rtrim($home, '/') . '/astudio_private';
}

function ensure_dir($dir, $private = false) {
    if (!is_dir($dir) && !@mkdir($dir, $private ? 0700 : 0755, true) && !is_dir($dir)) {
        fail(500, 'Server storage is not available.');
    }
}

/** Guards the public media folder: nothing in it may ever run as code. */
function guard_media_dir($root) {
    $guard = $root . '/.htaccess';
    if (file_exists($guard)) {
        return;
    }
    @file_put_contents($guard,
        "# A Studio uploads only. Never execute anything in here.\n" .
        "Options -ExecCGI -Indexes\n" .
        "RemoveHandler .php .phtml .php3 .php4 .php5 .php7 .php8 .phar .pl .py .cgi .sh\n" .
        "RemoveType .php .phtml .phar\n" .
        "<IfModule mod_php.c>\n  php_flag engine off\n</IfModule>\n" .
        "<FilesMatch \"\\.(php|phtml|phar|php[0-9]|pl|py|cgi|sh|html?|js|svg)$\">\n  Require all denied\n</FilesMatch>\n" .
        "<IfModule mod_headers.c>\n" .
        "  Header set Cache-Control \"public, max-age=31536000, immutable\"\n" .
        "  Header set X-Content-Type-Options \"nosniff\"\n" .
        "</IfModule>\n");
}

function guard_private_dir($root) {
    $guard = $root . '/.htaccess';
    if (!file_exists($guard)) {
        @file_put_contents($guard, "Require all denied\n");
    }
}

function random_name($ext) {
    try {
        return bin2hex(random_bytes(16)) . '.' . $ext;
    } catch (Exception $e) {
        return str_replace('.', '', uniqid('f', true)) . '.' . $ext;
    }
}

/** "<uid>/<kind>_<hex>.<ext>" and nothing else. */
function valid_private_path($path) {
    return is_string($path) &&
        preg_match('/^[A-Za-z0-9_-]{6,128}\/(id|work)_[a-f0-9]{32}\.(jpg|png|webp|gif|mp4|webm|mov)$/', $path) === 1;
}
