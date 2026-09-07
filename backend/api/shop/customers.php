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

if ($method === 'PUT') {
    // Müşteri bilgilerini güncelle
    $body = Request::getJsonBody();
    $id = (int)($body['id'] ?? 0);
    $username = trim($body['username'] ?? '');
    $password = trim($body['password'] ?? '');
    $fullName = trim($body['full_name'] ?? '');
    $phone = trim($body['phone'] ?? '');

    if ($id <= 0 || empty($username) || empty($fullName)) {
        Response::error('Müşteri ID, kullanıcı adı ve ad soyad alanları zorunludur.', 422);
    }

    // Müşterinin bu dükkana ait olduğunu doğrula
    $checkStmt = $db->prepare("SELECT id FROM users WHERE id = :id AND shop_id = :shop_id AND role = 'CUSTOMER' LIMIT 1");
    $checkStmt->execute([':id' => $id, ':shop_id' => $shopId]);
    if (!$checkStmt->fetch()) {
        Response::notFound('Müşteri bulunamadı veya bu dükkana ait değil.');
    }

    // Kullanıcı adı başka bir kullanıcı tarafından kullanılıyor mu?
    $dupStmt = $db->prepare("SELECT id FROM users WHERE username = :username AND id != :id LIMIT 1");
    $dupStmt->execute([':username' => $username, ':id' => $id]);
    if ($dupStmt->fetch()) {
        Response::error('Bu kullanıcı adı başka bir hesap tarafından kullanılmaktadır.', 409);
    }

    if (!empty($password)) {
        if (strlen($password) < 4) {
            Response::error('Şifre en az 4 karakter olmalıdır.', 422);
        }
        $passwordHash = password_hash($password, PASSWORD_DEFAULT);
        $updateStmt = $db->prepare("UPDATE users 
                                    SET username = :username,
                                        password_hash = :password_hash,
                                        full_name = :full_name,
                                        phone = :phone
                                    WHERE id = :id AND shop_id = :shop_id AND role = 'CUSTOMER'");
        $updateStmt->execute([
            ':username'      => $username,
            ':password_hash' => $passwordHash,
            ':full_name'     => $fullName,
            ':phone'         => $phone ?: null,
            ':id'            => $id,
            ':shop_id'       => $shopId
        ]);
    } else {
        // Şifre boş bırakılmışsa eski şifreyi koru
        $updateStmt = $db->prepare("UPDATE users 
                                    SET username = :username,
                                        full_name = :full_name,
                                        phone = :phone
                                    WHERE id = :id AND shop_id = :shop_id AND role = 'CUSTOMER'");
        $updateStmt->execute([
            ':username'  => $username,
            ':full_name' => $fullName,
            ':phone'     => $phone ?: null,
            ':id'        => $id,
            ':shop_id'   => $shopId
        ]);
    }

    Response::success(null, 'Müşteri bilgileri başarıyla güncellendi.');
}

if ($method === 'DELETE') {
    // Müşteriyi sil
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) {
        $body = Request::getJsonBody();
        $id = (int)($body['id'] ?? 0);
    }

    if ($id <= 0) {
        Response::error('Geçerli bir Müşteri ID belirtilmedi.', 422);
    }

    // Müşterinin bu dükkana ait olduğunu doğrula
    $checkStmt = $db->prepare("SELECT id FROM users WHERE id = :id AND shop_id = :shop_id AND role = 'CUSTOMER' LIMIT 1");
    $checkStmt->execute([':id' => $id, ':shop_id' => $shopId]);
    if (!$checkStmt->fetch()) {
        Response::notFound('Müşteri bulunamadı veya bu dükkana ait değil.');
    }

    try {
        $db->beginTransaction();

        $delStmt = $db->prepare("DELETE FROM users WHERE id = :id AND shop_id = :shop_id AND role = 'CUSTOMER'");
        $delStmt->execute([':id' => $id, ':shop_id' => $shopId]);

        $db->commit();

        Response::success(null, 'Müşteri başarıyla silindi.');
    } catch (PDOException $e) {
        if ($db->inTransaction()) {
            $db->rollBack();
        }
        Response::error('Müşteri silinirken bir hata oluştu: ' . $e->getMessage(), 500);
    }
}

Response::error('Desteklenmeyen istek yöntemi.', 405);
