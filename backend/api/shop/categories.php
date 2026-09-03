<?php
// backend/api/shop/categories.php

declare(strict_types=1);

require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../core/Database.php';
require_once __DIR__ . '/../../core/JWT.php';
require_once __DIR__ . '/../../core/Request.php';
require_once __DIR__ . '/../../core/Response.php';
require_once __DIR__ . '/../../core/AuthMiddleware.php';

handleCors();

$auth = AuthMiddleware::authenticate(['SHOP_OWNER']);
$shopId = AuthMiddleware::requireShopId($auth);
$db = Database::getConnection();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $stmt = $db->prepare("SELECT id, shop_id, name, sort_order, is_active, created_at 
                          FROM categories 
                          WHERE shop_id = :shop_id 
                          ORDER BY sort_order ASC, id ASC");
    $stmt->execute([':shop_id' => $shopId]);
    $categories = $stmt->fetchAll();

    Response::success($categories, 'Kategoriler listelendi.');
}

if ($method === 'POST') {
    $body = Request::getJsonBody();
    $name = trim($body['name'] ?? '');
    $sortOrder = (int)($body['sort_order'] ?? 0);

    if (empty($name)) {
        Response::error('Kategori adı zorunludur.', 422);
    }

    $stmt = $db->prepare("INSERT INTO categories (shop_id, name, sort_order, is_active) 
                          VALUES (:shop_id, :name, :sort_order, 1)");
    $stmt->execute([
        ':shop_id'    => $shopId,
        ':name'       => $name,
        ':sort_order' => $sortOrder
    ]);

    $id = (int)$db->lastInsertId();
    Response::success(['id' => $id, 'shop_id' => $shopId, 'name' => $name, 'sort_order' => $sortOrder], 'Kategori eklendi.', 201);
}

if ($method === 'PUT') {
    $body = Request::getJsonBody();
    $id = (int)($body['id'] ?? 0);
    $name = trim($body['name'] ?? '');
    $sortOrder = isset($body['sort_order']) ? (int)$body['sort_order'] : null;
    $isActive = isset($body['is_active']) ? (int)$body['is_active'] : null;

    if ($id <= 0 || empty($name)) {
        Response::error('Kategori ID ve adı zorunludur.', 422);
    }

    // Tenant kontrolü
    $check = $db->prepare("SELECT id FROM categories WHERE id = :id AND shop_id = :shop_id");
    $check->execute([':id' => $id, ':shop_id' => $shopId]);
    if (!$check->fetch()) {
        Response::notFound('Kategori bulunamadı veya bu dükkana ait değil.');
    }

    $stmt = $db->prepare("UPDATE categories 
                          SET name = :name, 
                              sort_order = COALESCE(:sort_order, sort_order),
                              is_active = COALESCE(:is_active, is_active)
                          WHERE id = :id AND shop_id = :shop_id");
    $stmt->execute([
        ':name'       => $name,
        ':sort_order' => $sortOrder,
        ':is_active'  => $isActive,
        ':id'         => $id,
        ':shop_id'    => $shopId
    ]);

    Response::success(null, 'Kategori güncellendi.');
}

if ($method === 'DELETE') {
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) {
        Response::error('Geçerli bir Kategori ID belirtilmedi.', 422);
    }

    $stmt = $db->prepare("DELETE FROM categories WHERE id = :id AND shop_id = :shop_id");
    $stmt->execute([':id' => $id, ':shop_id' => $shopId]);

    if ($stmt->rowCount() === 0) {
        Response::notFound('Kategori bulunamadı veya silinemedi.');
    }

    Response::success(null, 'Kategori ve bağlı ürünler başarıyla silindi.');
}

Response::error('Desteklenmeyen istek yöntemi.', 405);
