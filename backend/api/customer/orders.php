<?php
// backend/api/customer/orders.php

declare(strict_types=1);

require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../core/Database.php';
require_once __DIR__ . '/../../core/JWT.php';
require_once __DIR__ . '/../../core/Request.php';
require_once __DIR__ . '/../../core/Response.php';
require_once __DIR__ . '/../../core/AuthMiddleware.php';

handleCors();

$auth = AuthMiddleware::authenticate(['CUSTOMER']);
$shopId = AuthMiddleware::requireShopId($auth);
$customerId = (int)$auth['user_id'];
$db = Database::getConnection();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Müşterinin kendi sipariş geçmişini getir
    $stmt = $db->prepare("SELECT o.id, o.shop_id, o.total_price, o.status, o.notes, o.created_at,
                                 s.name as shop_name
                          FROM orders o
                          LEFT JOIN shops s ON o.shop_id = s.id
                          WHERE o.customer_id = :customer_id AND o.shop_id = :shop_id
                          ORDER BY o.id DESC");
    $stmt->execute([
        ':customer_id' => $customerId,
        ':shop_id'     => $shopId
    ]);
    $orders = $stmt->fetchAll();

    foreach ($orders as &$order) {
        $itemStmt = $db->prepare("SELECT oi.id, oi.product_id, oi.quantity, oi.unit_price, oi.selected_options, p.name as product_name
                                  FROM order_items oi
                                  LEFT JOIN products p ON oi.product_id = p.id
                                  WHERE oi.order_id = :order_id");
        $itemStmt->execute([':order_id' => $order['id']]);
        $order['items'] = $itemStmt->fetchAll();
    }

    Response::success($orders, 'Siparişleriniz listelendi.');
}

if ($method === 'POST') {
    // Yeni Sipariş Oluştur
    $body = Request::getJsonBody();
    $items = $body['items'] ?? []; // [{ product_id: 1, quantity: 2, selected_options: "..." }, ...]
    $notes = trim($body['notes'] ?? '');

    if (!is_array($items) || empty($items)) {
        Response::error('Sipariş verebilmek için en az bir ürün seçmelisiniz.', 422);
    }

    try {
        $db->beginTransaction();

        $totalPrice = 0.0;
        $orderItemsToInsert = [];

        // Dükkan açık mı ve mesai saatleri içinde mi kontrol et
        $sCheck = $db->prepare("SELECT is_active, is_open, opening_time, closing_time, auto_hours_enabled FROM shops WHERE id = :id LIMIT 1");
        $sCheck->execute([':id' => $shopId]);
        $shopInfo = $sCheck->fetch();

        if (!$shopInfo || (int)$shopInfo['is_active'] !== 1) {
            $db->rollBack();
            Response::error('Dükkan şu anda aktif değildir.', 400);
        }

        $isOpenManual = (int)$shopInfo['is_open'] === 1;
        $autoHours = (int)$shopInfo['auto_hours_enabled'] === 1;
        $openTime = $shopInfo['opening_time'] ?: '08:00';
        $closeTime = $shopInfo['closing_time'] ?: '22:00';
        $currentTime = date('H:i');
        $isWithinHours = true;

        if ($autoHours) {
            if ($openTime <= $closeTime) {
                $isWithinHours = ($currentTime >= $openTime && $currentTime <= $closeTime);
            } else {
                $isWithinHours = ($currentTime >= $openTime || $currentTime <= $closeTime);
            }
        }

        if (!$isOpenManual) {
            $db->rollBack();
            Response::error('Dükkan şu anda sipariş alımına kapalıdır.', 400);
        }

        if (!$isWithinHours) {
            $db->rollBack();
            Response::error("Dükkan mesai saatleri dışındadır. Sipariş kabul edilmiyor. (Mesai: {$openTime} - {$closeTime})", 400);
        }

        // Ürünleri doğrula ve güncel dükkan fiyatlarını hesapla (Güvenlik: Fiyat frontend'den alınmaz!)
        foreach ($items as $item) {
            $productId = (int)($item['product_id'] ?? 0);
            $quantity = (int)($item['quantity'] ?? 0);
            $selectedOptions = isset($item['selected_options']) ? (is_string($item['selected_options']) ? trim($item['selected_options']) : json_encode($item['selected_options'], JSON_UNESCAPED_UNICODE)) : null;

            if ($productId <= 0 || $quantity <= 0) {
                $db->rollBack();
                Response::error('Geçersiz ürün veya miktar.', 422);
            }

            // Sadece müşterinin dükkanına ait ve aktif olan ürünü doğrula
            $pStmt = $db->prepare("SELECT id, name, price, is_available 
                                   FROM products 
                                   WHERE id = :id AND shop_id = :shop_id 
                                   LIMIT 1 FOR UPDATE");
            $pStmt->execute([':id' => $productId, ':shop_id' => $shopId]);
            $product = $pStmt->fetch();

            if (!$product) {
                $db->rollBack();
                Response::error("Ürün bulunamadı veya bu dükkana ait değil (ID: {$productId}).", 404);
            }

            if ((int)$product['is_available'] !== 1) {
                $db->rollBack();
                Response::error("'{$product['name']}' şu anda tükendi ve sipariş edilemez.", 400);
            }

            $unitPrice = (float)$product['price'];
            $subTotal = $unitPrice * $quantity;
            $totalPrice += $subTotal;

            $orderItemsToInsert[] = [
                'product_id'       => $productId,
                'quantity'         => $quantity,
                'unit_price'       => $unitPrice,
                'selected_options' => $selectedOptions,
                'name'             => $product['name']
            ];
        }

        // Ana sipariş kaydını oluştur
        $orderStmt = $db->prepare("INSERT INTO orders (shop_id, customer_id, total_price, status, notes)
                                   VALUES (:shop_id, :customer_id, :total_price, 'PENDING', :notes)");
        $orderStmt->execute([
            ':shop_id'     => $shopId,
            ':customer_id' => $customerId,
            ':total_price' => $totalPrice,
            ':notes'       => $notes ?: null
        ]);

        $orderId = (int)$db->lastInsertId();

        // Kalemleri ekle
        $itemInsertStmt = $db->prepare("INSERT INTO order_items (order_id, product_id, quantity, unit_price, selected_options)
                                        VALUES (:order_id, :product_id, :quantity, :unit_price, :selected_options)");
        foreach ($orderItemsToInsert as $oItem) {
            $itemInsertStmt->execute([
                ':order_id'         => $orderId,
                ':product_id'       => $oItem['product_id'],
                ':quantity'         => $oItem['quantity'],
                ':unit_price'       => $oItem['unit_price'],
                ':selected_options' => $oItem['selected_options']
            ]);
        }

        $db->commit();

        Response::success([
            'order_id'    => $orderId,
            'total_price' => $totalPrice,
            'status'      => 'PENDING',
            'items_count' => count($orderItemsToInsert)
        ], 'Siparişiniz başarıyla alındı! Dükkan onayına sunuldu.', 201);

    } catch (Exception $e) {
        if ($db->inTransaction()) {
            $db->rollBack();
        }
        Response::error('Sipariş oluşturulurken bir hata oluştu: ' . $e->getMessage(), 500);
    }
}

Response::error('Desteklenmeyen istek yöntemi.', 405);
