<?php
// backend/api/shop/settings.php

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
    // Dükkan ayarlarını, mesai saatlerini ve açık/kapalı durumunu getir
    $stmt = $db->prepare("SELECT id, name, phone, address, is_active, is_open, opening_time, closing_time, auto_hours_enabled 
                          FROM shops 
                          WHERE id = :id LIMIT 1");
    $stmt->execute([':id' => $shopId]);
    $shop = $stmt->fetch();

    if (!$shop) {
        Response::notFound('Dükkan bulunamadı.');
    }

    Response::success($shop, 'Dükkan ayarları getirildi.');
}

if ($method === 'PUT') {
    // Dükkan aç/kapat veya mesai saatlerini güncelle
    $body = Request::getJsonBody();

    $fields = [];
    $params = [':id' => $shopId];

    if (isset($body['is_open'])) {
        $fields[] = 'is_open = :is_open';
        $params[':is_open'] = (int)$body['is_open'];
    }

    if (isset($body['opening_time'])) {
        $fields[] = 'opening_time = :opening_time';
        $params[':opening_time'] = trim($body['opening_time']);
    }

    if (isset($body['closing_time'])) {
        $fields[] = 'closing_time = :closing_time';
        $params[':closing_time'] = trim($body['closing_time']);
    }

    if (isset($body['auto_hours_enabled'])) {
        $fields[] = 'auto_hours_enabled = :auto_hours_enabled';
        $params[':auto_hours_enabled'] = (int)$body['auto_hours_enabled'];
    }

    if (empty($fields)) {
        Response::error('Güncellenecek bir ayar belirtilmedi.', 422);
    }

    $sql = "UPDATE shops SET " . implode(', ', $fields) . " WHERE id = :id";
    $stmt = $db->prepare($sql);
    $stmt->execute($params);

    // Güncel durumu dön
    $stmtGet = $db->prepare("SELECT id, name, is_open, opening_time, closing_time, auto_hours_enabled FROM shops WHERE id = :id");
    $stmtGet->execute([':id' => $shopId]);
    $updated = $stmtGet->fetch();

    Response::success($updated, 'Dükkan ayarları başarıyla güncellendi.');
}

Response::error('Desteklenmeyen istek yöntemi.', 405);
