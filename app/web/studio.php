<?php
/**
 * Link previews for artist pages.
 *
 * .htaccess sends /<handle> and /book/<handle> here. WhatsApp, Telegram and
 * Facebook read the page's preview tags without running the app, so this
 * script writes the artist's name, line and cover photo into them, then
 * serves the normal app page. Studio data comes from Firestore's public
 * REST API (only live studios are readable) and is cached for 5 minutes.
 */
define('ASTUDIO', 1);
require __DIR__ . '/api/config.php';

const RESERVED = [
    'about', 'account', 'admin', 'api', 'app', 'artist', 'artists', 'backstage', 'blog', 'book',
    'booking', 'bookings', 'brush', 'cache', 'careers', 'chat', 'contact', 'delete-account', 'desk',
    'explore', 'faq', 'help', 'home', 'icons', 'inbox', 'legal', 'login', 'logout', 'media',
    'message', 'messages', 'notifications', 'privacy', 'search', 'settings', 'shop', 'signin', 'signup',
    'studio', 'studios', 'support', 'terms', 'vanity', 'welcome', 'www', 'astudio', 'a-studio', 'hepius',
];

const SPECIALTIES = [
    'makeup' => 'Makeup', 'nails' => 'Nails', 'hair' => 'Hair', 'braids' => 'Braids',
    'lashes' => 'Lashes', 'brows' => 'Brows', 'henna' => 'Henna', 'skin' => 'Skincare',
];
const SUB_CITIES = [
    'bole' => 'Bole', 'kirkos' => 'Kirkos', 'yeka' => 'Yeka', 'arada' => 'Arada', 'lideta' => 'Lideta',
    'nifas-silk' => 'Nifas Silk-Lafto', 'kolfe' => 'Kolfe Keranio', 'gullele' => 'Gullele',
    'addis-ketema' => 'Addis Ketema', 'akaky' => 'Akaky Kaliti', 'lemi-kura' => 'Lemi Kura',
];

$html = @file_get_contents(__DIR__ . '/index.html');
if ($html === false) {
    http_response_code(500);
    echo 'index.html is missing.';
    exit;
}
header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-cache, must-revalidate');

$handle = strtolower(trim(isset($_GET['handle']) ? (string) $_GET['handle'] : ''));
$isBooking = isset($_GET['book']) && $_GET['book'] === '1';
if ($handle === '' || in_array($handle, RESERVED, true) ||
        !preg_match('/^[a-z0-9][a-z0-9._-]{1,28}[a-z0-9]$/', $handle)) {
    echo $html;
    exit;
}

function fs_value($v) {
    if (!is_array($v)) return null;
    if (isset($v['stringValue'])) return $v['stringValue'];
    if (isset($v['integerValue'])) return (int) $v['integerValue'];
    if (isset($v['doubleValue'])) return (float) $v['doubleValue'];
    if (isset($v['booleanValue'])) return (bool) $v['booleanValue'];
    if (isset($v['arrayValue'])) {
        $out = [];
        foreach (isset($v['arrayValue']['values']) ? $v['arrayValue']['values'] : [] as $x) $out[] = fs_value($x);
        return $out;
    }
    return null;
}

function fs_get($path) {
    list($code, $data) = http_json('GET',
        'https://firestore.googleapis.com/v1/projects/' . FIREBASE_PROJECT .
        '/databases/(default)/documents/' . $path . '?key=' . urlencode(FIREBASE_API_KEY));
    if ($code !== 200 || !is_array($data) || !isset($data['fields'])) return null;
    $out = [];
    foreach ($data['fields'] as $k => $v) $out[$k] = fs_value($v);
    return $out;
}

function load_studio($handle) {
    $cacheDir = sys_get_temp_dir() . '/astudio_preview';
    $cacheFile = $cacheDir . '/' . md5($handle) . '.json';
    if (is_file($cacheFile) && filemtime($cacheFile) > time() - 300) {
        $cached = json_decode((string) @file_get_contents($cacheFile), true);
        if (is_array($cached)) return $cached ?: null;
    }
    $studio = null;
    $h = fs_get('handles/' . rawurlencode($handle));
    if ($h && !empty($h['uid']) && is_string($h['uid'])) {
        $s = fs_get('studios/' . rawurlencode($h['uid']));
        if ($s && isset($s['status']) && $s['status'] === 'live') $studio = $s;
    }
    if (!is_dir($cacheDir)) @mkdir($cacheDir, 0700, true);
    @file_put_contents($cacheFile, json_encode($studio ?: []));
    return $studio;
}

function esc($s) {
    return htmlspecialchars((string) $s, ENT_QUOTES | ENT_HTML5, 'UTF-8');
}

function set_meta($html, $attr, $key, $value) {
    $pattern = '/<meta\s+' . $attr . '="' . preg_quote($key, '/') . '"\s+content="[^"]*"\s*\/?>/i';
    $tag = '<meta ' . $attr . '="' . $key . '" content="' . esc($value) . '">';
    return preg_replace($pattern, $tag, $html, 1);
}

$s = load_studio($handle);
if ($s) {
    $name = isset($s['name']) && $s['name'] !== '' ? $s['name'] : $handle;
    $specs = [];
    foreach (is_array($s['specialties'] ?? null) ? $s['specialties'] : [] as $id) {
        if (isset(SPECIALTIES[$id])) $specs[] = SPECIALTIES[$id];
    }
    $areas = [];
    foreach (is_array($s['subCities'] ?? null) ? $s['subCities'] : [] as $id) {
        if (isset(SUB_CITIES[$id])) $areas[] = SUB_CITIES[$id];
    }
    $line = isset($s['tagline']) && $s['tagline'] !== '' ? $s['tagline'] :
        trim(implode(' · ', $specs) . ($areas ? ' in ' . implode(', ', array_slice($areas, 0, 3)) : ''));
    $desc = ($line !== '' ? $line . '. ' : '') . ($isBooking ? 'Pick a time and book on A Studio.' : 'See her work and book on A Studio.');
    $image = SITE_ORIGIN . '/og-default.jpg';
    if (!empty($s['coverUrl']) && ($s['coverType'] ?? 'image') === 'image') {
        $image = $s['coverUrl'];
    } elseif (!empty($s['avatarUrl'])) {
        $image = $s['avatarUrl'];
    }
    $url = SITE_ORIGIN . '/' . ($isBooking ? 'book/' : '') . rawurlencode($handle);
    $title = ($isBooking ? 'Book ' : '') . $name . ' · A Studio';

    $html = preg_replace('/<title>.*?<\/title>/s', '<title>' . esc($title) . '</title>', $html, 1);
    $html = set_meta($html, 'name', 'description', $desc);
    $html = set_meta($html, 'property', 'og:title', $title);
    $html = set_meta($html, 'property', 'og:description', $desc);
    $html = set_meta($html, 'property', 'og:image', $image);
    $html = set_meta($html, 'property', 'og:url', $url);
    $html = set_meta($html, 'property', 'og:type', 'profile');
    $html = preg_replace('/<link rel="canonical" href="[^"]*">/', '<link rel="canonical" href="' . esc($url) . '">', $html, 1);
}
echo $html;
