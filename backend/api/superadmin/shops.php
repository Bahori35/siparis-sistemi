<?php
// backend/api/superadmin/shops.php

declare(strict_types=1);

require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../core/Database.php';
require_once __DIR__ . '/../../core/JWT.php';
require_once __DIR__ . '/../../core/Request.php';
require_once __DIR__ . '/../../core/Response.php';
require_once __DIR__ . '/../../core/AuthMiddleware.php';

handleCors();

// Sadece Web Süper Admin erişebilir
AuthMiddleware::authenticate(['SUPER_ADMIN']);
$db = Database::getConnection();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Dükkanları, sahiplerini ve istatistiklerini listele
    $stmt = $db->query("SELECT s.id, s.name, s.phone, s.address, s.is_active, s.created_at,
                               u.id as owner_id, u.username as owner_username, u.full_name as owner_name,
                               (SELECT COUNT(*) FROM products WHERE shop_id = s.id) as product_count,
                               (SELECT COUNT(*) FROM users WHERE shop_id = s.id AND role = 'CUSTOMER') as customer_count,
                               (SELECT COUNT(*) FROM orders WHERE shop_id = s.id) as order_count
                        FROM shops s
                        LEFT JOIN users u ON u.shop_id = s.id AND u.role = 'SHOP_OWNER'
                        ORDER BY s.id DESC");
    $shops = $stmt->fetchAll();
    Response::success($shops, 'Dükkanlar listelendi.');
}

if ($method === 'POST') {
    // Yeni Dükkan ve Dükkan Sahibi Hesabı Oluştur
    $body = Request::getJsonBody();
    $shopName = trim($body['shop_name'] ?? '');
    $shopPhone = trim($body['shop_phone'] ?? '');
    $shopAddress = trim($body['shop_address'] ?? '');
    
    $ownerUsername = trim($body['owner_username'] ?? '');
    $ownerPassword = trim($body['owner_password'] ?? '');
    $ownerFullName = trim($body['owner_fullname'] ?? '');

    if (empty($shopName) || empty($ownerUsername) || empty($ownerPassword) || empty($ownerFullName)) {
        Response::error('Dükkan adı, dükkan sahibi adı, kullanıcı adı ve şifre zorunludur.', 422);
    }

    // Kullanıcı adı kontrolü
    $uCheck = $db->prepare("SELECT id FROM users WHERE username = :username LIMIT 1");
    $uCheck->execute([':username' => $ownerUsername]);
    if ($uCheck->fetch()) {
        Response::error('Bu dükkan sahibi kullanıcı adı zaten kullanımda.', 409);
    }

    try {
        $db->beginTransaction();

        // 1. Dükkanı oluştur
        $sStmt = $db->prepare("INSERT INTO shops (name, phone, address, is_active) 
                               VALUES (:name, :phone, :address, 1)");
        $sStmt->execute([
            ':name'    => $shopName,
            ':phone'   => $shopPhone ?: null,
            ':address' => $shopAddress ?: null
        ]);
        $shopId = (int)$db->lastInsertId();

        // 2. Dükkan Sahibini oluştur (SHOP_OWNER)
        $passwordHash = password_hash($ownerPassword, PASSWORD_DEFAULT);
        $uStmt = $db->prepare("INSERT INTO users (shop_id, username, password_hash, role, full_name, phone, is_active)
                               VALUES (:shop_id, :username, :password_hash, 'SHOP_OWNER', :full_name, :phone, 1)");
        $uStmt->execute([
            ':shop_id'       => $shopId,
            ':username'      => $ownerUsername,
            ':password_hash' => $passwordHash,
            ':full_name'     => $ownerFullName,
            ':phone'         => $shopPhone ?: null
        ]);
        $ownerId = (int)$db->lastInsertId();

        $db->commit();

        Response::success([
            'shop_id'        => $shopId,
            'shop_name'      => $shopName,
            'owner_id'       => $ownerId,
            'owner_username' => $ownerUsername
        ], 'Yeni dükkan ve dükkan sahibi başarıyla tanımlandı.', 201);

    } catch (Exception $e) {
        if ($db->inTransaction()) {
            $db->rollBack();
        }
        Response::error('Dükkan oluşturulurken hata: ' . $e->getMessage(), 500);
    }
}

if ($method === 'PUT') {
    // Dükkan Aktiflik / Bilgi Güncelleme
    $body = Request::getJsonBody();
    $shopId = (int)($body['id'] ?? 0);
    $name = trim($body['name'] ?? '');
    $phone = trim($body['phone'] ?? '');
    $address = trim($body['address'] ?? '');
    $isActive = isset($body['is_active']) ? (int)$body['is_active'] : null;

    if ($shopId <= 0) {
        Response::error('Geçerli bir Dükkan ID girilmelidir.', 422);
    }

    $stmt = $db->prepare("UPDATE shops 
                          SET name = COALESCE(NULLIF(:name, ''), name),
                              phone = COALESCE(NULLIF(:phone, ''), phone),
                              address = COALESCE(NULLIF(:address, ''), address),
                              is_active = COALESCE(:is_active, is_active)
                          WHERE id = :id");
    $stmt->execute([
        ':name'      => $name,
        ':phone'     => $phone,
        ':address'   => $address,
        ':is_active' => $isActive,
        ':id'        => $shopId
    ]);

    Response::success(null, 'Dükkan bilgileri güncellendi.');
}

if ($method === 'DELETE') {
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) {
        Response::error('Geçerli bir Dükkan ID belirtilmedi.', 422);
    }

    $stmt = $db->prepare("DELETE FROM shops WHERE id = :id");
    $stmt->execute([':id' => $id]);

    if ($stmt->rowCount() === 0) {
        Response::notFound('Dükkan bulunamadı veya silinemedi.');
    }

    Response::success(null, 'Dükkan ve bağlı tüm verileri başarıyla silindi.');
}

Response::error('Desteklenmeyen istek yöntemi.', 405);
