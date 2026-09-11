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
    $isPaid = isset($_GET['is_paid']) ? (int)$_GET['is_paid'] : null;
    $customerId = isset($_GET['customer_id']) ? (int)$_GET['customer_id'] : null;
    $period = $_GET['period'] ?? null; // 'daily', 'weekly', 'monthly'
    
    $query = "SELECT o.id, o.shop_id, o.customer_id, o.total_price, o.status, o.is_paid, o.paid_at, o.notes, o.cancel_reason, o.created_at,
                     u.full_name as customer_name, u.phone as customer_phone
              FROM orders o
              LEFT JOIN users u ON o.customer_id = u.id
              WHERE o.shop_id = :shop_id";
    $params = [':shop_id' => $shopId];

    if (!empty($status)) {
        $query .= " AND o.status = :status";
        $params[':status'] = $status;
    }

    if ($isPaid !== null) {
        $query .= " AND o.is_paid = :is_paid";
        $params[':is_paid'] = $isPaid;
    }

    if ($customerId !== null && $customerId > 0) {
        $query .= " AND o.customer_id = :customer_id";
        $params[':customer_id'] = $customerId;
    }

    if ($period === 'daily') {
        $query .= " AND DATE(o.created_at) = CURDATE()";
    } elseif ($period === 'weekly') {
        $query .= " AND o.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)";
    } elseif ($period === 'monthly') {
        $query .= " AND o.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)";
    }

    $query .= " ORDER BY o.id DESC";

    $stmt = $db->prepare($query);
    $stmt->execute($params);
    $orders = $stmt->fetchAll();

    // Sipariş kalemlerini ekle
    foreach ($orders as &$order) {
        $itemStmt = $db->prepare("SELECT oi.id, oi.product_id, oi.quantity, oi.unit_price, oi.selected_options, p.name as product_name
                                  FROM order_items oi
                                  LEFT JOIN products p ON oi.product_id = p.id
                                  WHERE oi.order_id = :order_id");
        $itemStmt->execute([':order_id' => $order['id']]);
        $order['items'] = $itemStmt->fetchAll();
    }

    Response::success($orders, 'Siparişler listelendi.');
}

if ($method === 'PUT') {
    // Sipariş durumu veya Ödeme durumu güncelleme
    $body = Request::getJsonBody();
    $orderId = (int)($body['order_id'] ?? 0);
    $newStatus = isset($body['status']) ? trim((string)$body['status']) : null;
    $isPaid = isset($body['is_paid']) ? (int)$body['is_paid'] : null;
    $cancelReason = isset($body['cancel_reason']) ? trim((string)$body['cancel_reason']) : null;

    // Toplu müşteri ödemesi (Örn: Bir müşterinin tüm borcunu tek seferde kapatma)
    $bulkCustomerPayment = isset($body['bulk_customer_id']) ? (int)$body['bulk_customer_id'] : null;

    if ($bulkCustomerPayment !== null && $bulkCustomerPayment > 0 && $isPaid !== null) {
        $paidAt = $isPaid === 1 ? date('Y-m-d H:i:s') : null;
        $bulkStmt = $db->prepare("UPDATE orders SET is_paid = :is_paid, paid_at = :paid_at WHERE customer_id = :cust_id AND shop_id = :shop_id");
        $bulkStmt->execute([
            ':is_paid' => $isPaid,
            ':paid_at' => $paidAt,
            ':cust_id' => $bulkCustomerPayment,
            ':shop_id' => $shopId
        ]);
        Response::success(null, 'Müşterinin tüm sipariş ödemeleri güncellendi.');
    }

    if ($orderId <= 0) {
        Response::error('Geçerli bir Sipariş ID belirtilmelidir.', 422);
    }

    // Tenant doğrulaması
    $check = $db->prepare("SELECT id, is_paid FROM orders WHERE id = :id AND shop_id = :shop_id");
    $check->execute([':id' => $orderId, ':shop_id' => $shopId]);
    $currentOrder = $check->fetch();
    if (!$currentOrder) {
        Response::notFound('Sipariş bulunamadı veya bu dükkana ait değil.');
    }

    $updates = [];
    $params = [':id' => $orderId, ':shop_id' => $shopId];

    if ($newStatus !== null && $newStatus !== '') {
        $validStatuses = ['PENDING', 'ACCEPTED', 'PREPARING', 'DELIVERED', 'CANCELLED'];
        if (!in_array($newStatus, $validStatuses, true)) {
            Response::error('Geçersiz sipariş durumu.', 422);
        }
        $updates[] = 'status = :status';
        $params[':status'] = $newStatus;

        if ($newStatus === 'CANCELLED') {
            $updates[] = 'cancel_reason = :cancel_reason';
            $params[':cancel_reason'] = ($cancelReason !== null && $cancelReason !== '') ? $cancelReason : 'İşletme tarafından iptal edildi.';
        }
    }

    if ($isPaid !== null) {
        $updates[] = 'is_paid = :is_paid';
        $params[':is_paid'] = $isPaid;

        if ($isPaid === 1) {
            $updates[] = 'paid_at = NOW()';
        } else {
            $updates[] = 'paid_at = NULL';
        }
    }

    if (empty($updates)) {
        Response::error('Güncellenecek bir durum belirtilmedi.', 422);
    }

    $sql = "UPDATE orders SET " . implode(', ', $updates) . " WHERE id = :id AND shop_id = :shop_id";
    $stmt = $db->prepare($sql);
    $stmt->execute($params);

    Response::success(['order_id' => $orderId, 'status' => $newStatus, 'is_paid' => $isPaid, 'cancel_reason' => $cancelReason], 'Sipariş başarıyla güncellendi.');
}

Response::error('Desteklenmeyen istek yöntemi.', 405);
