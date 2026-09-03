<?php
// backend/api/shop/orders.php

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
    // Dükkana gelen siparişleri kalemleriyle birlikte çek
    $status = $_GET['status'] ?? null;
    
    $query = "SELECT o.id, o.shop_id, o.customer_id, o.total_price, o.status, o.notes, o.created_at,
                     u.full_name as customer_name, u.phone as customer_phone
              FROM orders o
              LEFT JOIN users u ON o.customer_id = u.id
              WHERE o.shop_id = :shop_id";
    $params = [':shop_id' => $shopId];

    if (!empty($status)) {
        $query .= " AND o.status = :status";
        $params[':status'] = $status;
    }

    $query .= " ORDER BY o.id DESC";

    $stmt = $db->prepare($query);
    $stmt->execute($params);
    $orders = $stmt->fetchAll();

    // Sipariş kalemlerini ekle
    foreach ($orders as &$order) {
        $itemStmt = $db->prepare("SELECT oi.id, oi.product_id, oi.quantity, oi.unit_price, p.name as product_name
                                  FROM order_items oi
                                  LEFT JOIN products p ON oi.product_id = p.id
                                  WHERE oi.order_id = :order_id");
        $itemStmt->execute([':order_id' => $order['id']]);
        $order['items'] = $itemStmt->fetchAll();
    }

    Response::success($orders, 'Siparişler listelendi.');
}

if ($method === 'PUT') {
    // Sipariş durumu güncelle (PENDING, ACCEPTED, PREPARING, DELIVERED, CANCELLED)
    $body = Request::getJsonBody();
    $orderId = (int)($body['order_id'] ?? 0);
    $newStatus = trim($body['status'] ?? '');

    $validStatuses = ['PENDING', 'ACCEPTED', 'PREPARING', 'DELIVERED', 'CANCELLED'];
    if ($orderId <= 0 || !in_array($newStatus, $validStatuses, true)) {
        Response::error('Geçerli bir Sipariş ID ve durum belirtilmelidir.', 422);
    }

    // Tenant doğrulaması
    $check = $db->prepare("SELECT id FROM orders WHERE id = :id AND shop_id = :shop_id");
    $check->execute([':id' => $orderId, ':shop_id' => $shopId]);
    if (!$check->fetch()) {
        Response::notFound('Sipariş bulunamadı veya bu dükkana ait değil.');
    }

    $stmt = $db->prepare("UPDATE orders SET status = :status WHERE id = :id AND shop_id = :shop_id");
    $stmt->execute([':status' => $newStatus, ':id' => $orderId, ':shop_id' => $shopId]);

    Response::success(['order_id' => $orderId, 'status' => $newStatus], 'Sipariş durumu güncellendi.');
}

Response::error('Desteklenmeyen istek yöntemi.', 405);
