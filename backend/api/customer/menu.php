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
$shopStmt = $db->prepare("SELECT id, name, phone, address, is_active, is_open, opening_time, closing_time, auto_hours_enabled, closed_note 
                          FROM shops 
                          WHERE id = :id LIMIT 1");
$shopStmt->execute([':id' => $shopId]);
$shop = $shopStmt->fetch();

if (!$shop || (int)$shop['is_active'] !== 1) {
    Response::error('Bağlı olduğunuz dükkan şu anda hizmet verememektedir.', 403);
}

// Dükkan açık mı, mesai saatinde mi hesapla
$isOpenManual = (int)$shop['is_open'] === 1;
$autoHours = (int)$shop['auto_hours_enabled'] === 1;
$openTime = $shop['opening_time'] ?: '08:00';
$closeTime = $shop['closing_time'] ?: '22:00';
$closedNote = trim((string)($shop['closed_note'] ?? ''));

$currentTime = date('H:i');
$isWithinHours = true;

if ($autoHours) {
    if ($openTime <= $closeTime) {
        // Örn: 08:00 - 22:00
        $isWithinHours = ($currentTime >= $openTime && $currentTime <= $closeTime);
    } else {
        // Geceyi aşan mesai: Örn: 18:00 - 02:00
        $isWithinHours = ($currentTime >= $openTime || $currentTime <= $closeTime);
    }
}

$isAcceptingOrders = $isOpenManual && $isWithinHours;
$closedReason = '';
if (!$isOpenManual) {
    $closedReason = $closedNote !== '' ? $closedNote : 'Dükkan şu anda geçici olarak siparişe kapalıdır.';
} elseif (!$isWithinHours) {
    $closedReason = "Dükkan mesai saatleri dışındadır. (Mesai: {$openTime} - {$closeTime})";
}

// 2. Dükkana ait aktif kategorileri çek
$catStmt = $db->prepare("SELECT id, name, sort_order 
                         FROM categories 
                         WHERE shop_id = :shop_id AND is_active = 1 
                         ORDER BY sort_order ASC, id ASC");
$catStmt->execute([':shop_id' => $shopId]);
$categories = $catStmt->fetchAll();

// 3. Dükkana ait sadece aktif ve mevcut ürünleri çek
$prodStmt = $db->prepare("SELECT id, category_id, name, description, price, image_url, options_json, is_available 
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
    $options = null;
    if (!empty($p['options_json'])) {
        $options = json_decode($p['options_json'], true);
    }
    $productsByCategory[$catId][] = [
        'id'          => (int)$p['id'],
        'name'        => $p['name'],
        'description' => $p['description'],
        'price'       => (float)$p['price'],
        'image_url'   => $p['image_url'] ?? null,
        'options'     => $options,
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
        'id'                  => (int)$shop['id'],
        'name'                => $shop['name'],
        'phone'               => $shop['phone'],
        'address'             => $shop['address'],
        'is_open'             => (bool)$isOpenManual,
        'is_accepting_orders' => (bool)$isAcceptingOrders,
        'closed_reason'       => $closedReason,
        'opening_time'        => $openTime,
        'closing_time'        => $closeTime,
        'auto_hours_enabled'  => (bool)$autoHours
    ],
    'menu' => $groupedMenu
], 'Menü başarıyla getirildi.');
