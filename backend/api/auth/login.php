<?php
// backend/api/auth/login.php

declare(strict_types=1);

require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../core/Database.php';
require_once __DIR__ . '/../../core/JWT.php';
require_once __DIR__ . '/../../core/Request.php';
require_once __DIR__ . '/../../core/Response.php';

handleCors();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Sadece POST istekleri kabul edilir.', 405);
}

$body = Request::getJsonBody();
$username = trim($body['username'] ?? '');
$password = trim($body['password'] ?? '');

if (empty($username) || empty($password)) {
    Response::error('Kullanıcı adı ve şifre zorunludur.', 422);
}

$db = Database::getConnection();

// Kullanıcıyı ve bağlı olduğu dükkan durumunu sorgula
$sql = "SELECT u.id, u.shop_id, u.username, u.password_hash, u.role, u.full_name, u.is_active as user_active,
               s.name as shop_name, s.is_active as shop_active
        FROM users u
        LEFT JOIN shops s ON u.shop_id = s.id
        WHERE u.username = :username
        LIMIT 1";

$stmt = $db->prepare($sql);
$stmt->execute([':username' => $username]);
$user = $stmt->fetch();

if (!$user) {
    Response::error('Kullanıcı adı veya şifre hatalı.', 401);
}

// Şifre kontrolü
if (!password_verify($password, $user['password_hash'])) {
    Response::error('Kullanıcı adı veya şifre hatalı.', 401);
}

// Kullanıcı aktiflik kontrolü
if ((int)$user['user_active'] !== 1) {
    Response::error('Hesabınız dondurulmuş veya pasife alınmıştır.', 403);
}

// Dükkan aktiflik kontrolü (SUPER_ADMIN hariç)
if ($user['role'] !== 'SUPER_ADMIN') {
    if (empty($user['shop_id']) || (int)$user['shop_active'] !== 1) {
        Response::error('Bağlı olduğunuz dükkan/işletme aktif değildir.', 403);
    }
}

// JWT Token Üretimi
$payload = [
    'user_id'   => (int)$user['id'],
    'shop_id'   => $user['shop_id'] ? (int)$user['shop_id'] : null,
    'username'  => $user['username'],
    'role'      => $user['role'],
    'full_name' => $user['full_name']
];

$token = JWT::encode($payload);

Response::success([
    'token' => $token,
    'user'  => [
        'id'        => (int)$user['id'],
        'shop_id'   => $user['shop_id'] ? (int)$user['shop_id'] : null,
        'shop_name' => $user['shop_name'] ?? 'Sistem Yönetimi',
        'username'  => $user['username'],
        'role'      => $user['role'],
        'full_name' => $user['full_name']
    ]
], 'Giriş başarılı.');
