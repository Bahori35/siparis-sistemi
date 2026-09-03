<?php
// backend/api/customer/menu.php

declare(strict_types=1);

require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../core/Database.php';
require_once __DIR__ . '/../../core/JWT.php';
require_once __DIR__ . '/../../core/Request.php';
require_once __DIR__ . '/../../core/Response.php';
require_once __DIR__ . '/../../core/AuthMiddleware.php';

handleCors();

// Sadece Müşteri erişebilir (Tenant İzolasyonu)
$auth = AuthMiddleware::authenticate(['CUSTOMER']);
$shopId = AuthMiddleware::requireShopId($auth);
$db = Database::getConnection();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Sadece GET istekleri kabul edilir.', 405);
}

// 1. Dükkan bilgilerini al
$shopStmt = $db->prepare("SELECT id, name, phone, address, is_active FROM shops WHERE id = :id LIMIT 1");
$shopStmt->execute([':id' => $shopId]);
$shop = $shopStmt->fetch();

if (!$shop || (int)$shop['is_active'] !== 1) {
    Response::error('Bağlı olduğunuz dükkan şu anda hizmet verememektedir.', 403);
}

// 2. Dükkana ait aktif kategorileri çek
$catStmt = $db->prepare("SELECT id, name, sort_order 
                         FROM categories 
                         WHERE shop_id = :shop_id AND is_active = 1 
                         ORDER BY sort_order ASC, id ASC");
$catStmt->execute([':shop_id' => $shopId]);
$categories = $catStmt->fetchAll();

// 3. Dükkana ait sadece aktif ve mevcut ürünleri çek
$prodStmt = $db->prepare("SELECT id, category_id, name, description, price, image_url, is_available 
                          FROM products 
                          WHERE shop_id = :shop_id AND is_available = 1 
                          ORDER BY id DESC");
$prodStmt->execute([':shop_id' => $shopId]);
$products = $prodStmt->fetchAll();

// Ürünleri kategorilerine göre grupla
$groupedMenu = [];
$productsByCategory = [];
foreach ($products as $p) {
    $catId = (int)$p['category_id'];
    $productsByCategory[$catId][] = [
        'id'          => (int)$p['id'],
        'name'        => $p['name'],
        'description' => $p['description'],
        'price'       => (float)$p['price'],
        'image_url'   => $p['image_url'] ?? null,
        'is_available'=> (bool)$p['is_available']
    ];
}

foreach ($categories as $cat) {
    $catId = (int)$cat['id'];
    $catProducts = $productsByCategory[$catId] ?? [];
    if (!empty($catProducts)) {
        $groupedMenu[] = [
            'category_id'   => $catId,
            'category_name' => $cat['name'],
            'products'      => $catProducts
        ];
    }
}

Response::success([
    'shop' => [
        'id'      => (int)$shop['id'],
        'name'    => $shop['name'],
        'phone'   => $shop['phone'],
        'address' => $shop['address']
    ],
    'menu' => $groupedMenu
], 'Menü başarıyla getirildi.');
