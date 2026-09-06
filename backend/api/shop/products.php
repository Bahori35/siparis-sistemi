<?php
// backend/api/shop/products.php

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
    // Dükkana ait tüm ürünleri kategorileriyle birlikte listele
    $stmt = $db->prepare("SELECT p.id, p.shop_id, p.category_id, p.name, p.description, 
                                 p.price, p.image_url, p.options_json, p.is_available, p.created_at,
                                 c.name as category_name
                          FROM products p
                          LEFT JOIN categories c ON p.category_id = c.id
                          WHERE p.shop_id = :shop_id 
                          ORDER BY c.sort_order ASC, p.id DESC");
    $stmt->execute([':shop_id' => $shopId]);
    $products = $stmt->fetchAll();

    Response::success($products, 'Ürünler listelendi.');
}

if ($method === 'POST') {
    $body = Request::getJsonBody();
    $categoryId = (int)($body['category_id'] ?? 0);
    $name = trim($body['name'] ?? '');
    $description = trim($body['description'] ?? '');
    $price = (float)($body['price'] ?? 0);
    $imageUrl = trim($body['image_url'] ?? '');
    $optionsJson = !empty($body['options_json']) ? (is_string($body['options_json']) ? $body['options_json'] : json_encode($body['options_json'], JSON_UNESCAPED_UNICODE)) : null;
    $isAvailable = isset($body['is_available']) ? (int)$body['is_available'] : 1;

    if ($categoryId <= 0 || empty($name) || $price < 0) {
        Response::error('Geçerli bir kategori, ürün adı ve fiyat girilmelidir.', 422);
    }

    // Kategorinin bu dükkana ait olduğunu doğrula (Tenant Güvenliği)
    $catCheck = $db->prepare("SELECT id FROM categories WHERE id = :id AND shop_id = :shop_id");
    $catCheck->execute([':id' => $categoryId, ':shop_id' => $shopId]);
    if (!$catCheck->fetch()) {
        Response::error('Seçilen kategori bu dükkana ait değil.', 403);
    }

    $stmt = $db->prepare("INSERT INTO products (shop_id, category_id, name, description, price, image_url, options_json, is_available)
                          VALUES (:shop_id, :category_id, :name, :description, :price, :image_url, :options_json, :is_available)");
    $stmt->execute([
        ':shop_id'      => $shopId,
        ':category_id'  => $categoryId,
        ':name'         => $name,
        ':description'  => $description ?: null,
        ':price'        => $price,
        ':image_url'    => $imageUrl ?: null,
        ':options_json' => $optionsJson,
        ':is_available' => $isAvailable
    ]);

    $id = (int)$db->lastInsertId();
    Response::success([
        'id'          => $id,
        'shop_id'     => $shopId,
        'category_id' => $categoryId,
        'name'        => $name,
        'price'       => $price,
        'image_url'   => $imageUrl ?: null,
        'options_json'=> $optionsJson,
        'is_available'=> $isAvailable
    ], 'Ürün başarıyla eklendi.', 201);
}

if ($method === 'PUT') {
    $body = Request::getJsonBody();
    $id = (int)($body['id'] ?? 0);
    $categoryId = (int)($body['category_id'] ?? 0);
    $name = trim($body['name'] ?? '');
    $description = trim($body['description'] ?? '');
    $price = isset($body['price']) ? (float)$body['price'] : null;
    $imageUrl = isset($body['image_url']) ? trim($body['image_url']) : null;
    $optionsJson = array_key_exists('options_json', $body) 
        ? (!empty($body['options_json']) ? (is_string($body['options_json']) ? $body['options_json'] : json_encode($body['options_json'], JSON_UNESCAPED_UNICODE)) : null)
        : null;
    $isAvailable = isset($body['is_available']) ? (int)$body['is_available'] : null;

    if ($id <= 0 || empty($name) || $price === null || $price < 0) {
        Response::error('Ürün ID, adı ve fiyatı zorunludur.', 422);
    }

    // Ürün ve kategori dükkana ait mi?
    $check = $db->prepare("SELECT id FROM products WHERE id = :id AND shop_id = :shop_id");
    $check->execute([':id' => $id, ':shop_id' => $shopId]);
    if (!$check->fetch()) {
        Response::notFound('Ürün bulunamadı veya bu dükkana ait değil.');
    }

    $stmt = $db->prepare("UPDATE products 
                          SET category_id = :category_id,
                              name = :name,
                              description = :description,
                              price = :price,
                              image_url = :image_url,
                              options_json = :options_json,
                              is_available = :is_available
                          WHERE id = :id AND shop_id = :shop_id");
    $stmt->execute([
        ':category_id'  => $categoryId,
        ':name'         => $name,
        ':description'  => $description ?: null,
        ':price'        => $price,
        ':image_url'    => $imageUrl ?: null,
        ':options_json' => $optionsJson,
        ':is_available' => $isAvailable,
        ':id'           => $id,
        ':shop_id'      => $shopId
    ]);

    Response::success(null, 'Ürün başarıyla güncellendi.');
}

if ($method === 'DELETE') {
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) {
        $body = Request::getJsonBody();
        $id = (int)($body['id'] ?? 0);
    }

    if ($id <= 0) {
        Response::error('Geçerli bir Ürün ID belirtilmedi.', 422);
    }

    try {
        // Ürünün bu dükkana ait olduğunu kontrol et
        $check = $db->prepare("SELECT id FROM products WHERE id = :id AND shop_id = :shop_id");
        $check->execute([':id' => $id, ':shop_id' => $shopId]);
        if (!$check->fetch()) {
            Response::notFound('Ürün bulunamadı veya bu dükkana ait değil.');
        }

        // Ürünü sil (Eğer geçmiş siparişlerde kullanılmışsa foreign key hatası vermemesi için cascade/temizleme yap)
        $db->beginTransaction();
        
        // Ürüne bağlı geçmiş sipariş kalemlerindeki product_id referansını güncelle veya temizle
        // Foreign key kısıtlaması nedeniyle silme engellenmesin diye:
        $delItems = $db->prepare("DELETE FROM order_items WHERE product_id = :id");
        $delItems->execute([':id' => $id]);

        $stmt = $db->prepare("DELETE FROM products WHERE id = :id AND shop_id = :shop_id");
        $stmt->execute([':id' => $id, ':shop_id' => $shopId]);

        $db->commit();

        Response::success(null, 'Ürün başarıyla silindi.');
    } catch (PDOException $e) {
        if ($db->inTransaction()) {
            $db->rollBack();
        }
        Response::error('Ürün silinirken bir hata oluştu: ' . $e->getMessage(), 500);
    }
}

Response::error('Desteklenmeyen istek yöntemi.', 405);
