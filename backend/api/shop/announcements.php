<?php
// backend/api/shop/announcements.php

declare(strict_types=1);

require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../core/Database.php';
require_once __DIR__ . '/../../core/JWT.php';
require_once __DIR__ . '/../../core/Request.php';
require_once __DIR__ . '/../../core/Response.php';
require_once __DIR__ . '/../../core/AuthMiddleware.php';

handleCors();

// Dükkan Sahibi veya Müşteri
$auth = AuthMiddleware::authenticate(['SHOP_OWNER', 'CUSTOMER']);
$role = $auth['role'];
$db = Database::getConnection();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    // Dükkan sahibine ve tüm kullanıcılara yönelik aktif duyuruları getir
    $stmt = $db->prepare("SELECT id, title, content, target_role, created_at 
                          FROM announcements 
                          WHERE is_active = 1 AND (target_role = 'ALL' OR target_role = :role) 
                          ORDER BY id DESC 
                          LIMIT 50");
    $stmt->execute([':role' => $role]);
    $announcements = $stmt->fetchAll();

    Response::success($announcements, 'Duyurular listelendi.');
}

Response::error('Desteklenmeyen istek yöntemi.', 405);
