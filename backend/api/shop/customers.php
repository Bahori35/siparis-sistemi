<?php
// backend/api/shop/customers.php

declare(strict_types=1);

require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../core/Database.php';
require_once __DIR__ . '/../../core/JWT.php';
require_once __DIR__ . '/../../core/Request.php';
require_once __DIR__ . '/../../core/Response.php';
require_once __DIR__ . '/../../core/AuthMiddleware.php';

handleCors();

// Sadece Dükkan Sahibi erişebilir
$auth = AuthMiddleware::authenticate(['SHOP_OWNER']);
$shopId = AuthMiddleware::requireShopId($auth);
$db = Database::getConnection();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Dükkana ait müşterileri listele
    $stmt = $db->prepare("SELECT id, shop_id, username, full_name, phone, is_active, created_at 
                          FROM users 
                          WHERE shop_id = :shop_id AND role = 'CUSTOMER' 
                          ORDER BY id DESC");
    $stmt->execute([':shop_id' => $shopId]);
    $customers = $stmt->fetchAll();

    Response::success($customers, 'Müşteriler listelendi.');
}

if ($method === 'POST') {
    // Yeni müşteri oluştur ve dükkana bağla
    $body = Request::getJsonBody();
    $username = trim($body['username'] ?? '');
    $password = trim($body['password'] ?? '');
    $fullName = trim($body['full_name'] ?? '');
    $phone = trim($body['phone'] ?? '');

    if (empty($username) || empty($password) || empty($fullName)) {
        Response::error('Kullanıcı adı, şifre ve ad soyad alanları zorunludur.', 422);
    }

    if (strlen($password) < 4) {
        Response::error('Şifre en az 4 karakter olmalıdır.', 422);
    }

    // Kullanıcı adı benzersizlik kontrolü
    $checkStmt = $db->prepare("SELECT id FROM users WHERE username = :username LIMIT 1");
    $checkStmt->execute([':username' => $username]);
    if ($checkStmt->fetch()) {
        Response::error('Bu kullanıcı adı zaten kullanılmaktadır. Farklı bir kullanıcı adı seçin.', 409);
    }

    $passwordHash = password_hash($password, PASSWORD_DEFAULT);

    $insertStmt = $db->prepare("INSERT INTO users (shop_id, username, password_hash, role, full_name, phone, is_active)
                                VALUES (:shop_id, :username, :password_hash, 'CUSTOMER', :full_name, :phone, 1)");
    
    $insertStmt->execute([
        ':shop_id'       => $shopId,
        ':username'      => $username,
        ':password_hash' => $passwordHash,
        ':full_name'     => $fullName,
        ':phone'         => $phone ?: null
    ]);

    $newId = (int)$db->lastInsertId();

    Response::success([
        'id'        => $newId,
        'shop_id'   => $shopId,
        'username'  => $username,
        'full_name' => $fullName,
        'phone'     => $phone,
        'role'      => 'CUSTOMER'
    ], 'Müşteri hesabı başarıyla oluşturuldu.', 201);
}

Response::error('Desteklenmeyen istek yöntemi.', 405);
