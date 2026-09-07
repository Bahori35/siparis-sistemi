<?php
// backend/api/superadmin/announcements.php

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
    // Tüm duyuruları listele
    $stmt = $db->query("SELECT id, title, content, target_role, is_active, created_at, updated_at 
                        FROM announcements 
                        ORDER BY id DESC");
    $announcements = $stmt->fetchAll();
    Response::success($announcements, 'Duyurular listelendi.');
}

if ($method === 'POST') {
    // Yeni Duyuru Ekle
    $body = Request::getJsonBody();
    $title = trim($body['title'] ?? '');
    $content = trim($body['content'] ?? '');
    $targetRole = trim($body['target_role'] ?? 'SHOP_OWNER');
    $isActive = isset($body['is_active']) ? (int)$body['is_active'] : 1;

    if (empty($title) || empty($content)) {
        Response::error('Duyuru başlığı ve içeriği zorunludur.', 422);
    }

    if (!in_array($targetRole, ['ALL', 'SHOP_OWNER', 'CUSTOMER'])) {
        $targetRole = 'SHOP_OWNER';
    }

    $stmt = $db->prepare("INSERT INTO announcements (title, content, target_role, is_active) 
                          VALUES (:title, :content, :target_role, :is_active)");
    $stmt->execute([
        ':title'       => $title,
        ':content'     => $content,
        ':target_role' => $targetRole,
        ':is_active'   => $isActive
    ]);

    $id = (int)$db->lastInsertId();
    Response::success([
        'id'          => $id,
        'title'       => $title,
        'content'     => $content,
        'target_role' => $targetRole,
        'is_active'   => $isActive
    ], 'Duyuru başarıyla yayınlandı.', 201);
}

if ($method === 'PUT') {
    // Duyuru Güncelle
    $body = Request::getJsonBody();
    $id = (int)($body['id'] ?? 0);
    $title = trim($body['title'] ?? '');
    $content = trim($body['content'] ?? '');
    $targetRole = trim($body['target_role'] ?? 'SHOP_OWNER');
    $isActive = isset($body['is_active']) ? (int)$body['is_active'] : 1;

    if ($id <= 0 || empty($title) || empty($content)) {
        Response::error('Duyuru ID, başlığı ve içeriği zorunludur.', 422);
    }

    $stmt = $db->prepare("UPDATE announcements 
                          SET title = :title,
                              content = :content,
                              target_role = :target_role,
                              is_active = :is_active
                          WHERE id = :id");
    $stmt->execute([
        ':title'       => $title,
        ':content'     => $content,
        ':target_role' => $targetRole,
        ':is_active'   => $isActive,
        ':id'          => $id
    ]);

    Response::success(null, 'Duyuru başarıyla güncellendi.');
}

if ($method === 'DELETE') {
    // Duyuru Sil
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) {
        $body = Request::getJsonBody();
        $id = (int)($body['id'] ?? 0);
    }

    if ($id <= 0) {
        Response::error('Geçerli bir Duyuru ID belirtilmedi.', 422);
    }

    $stmt = $db->prepare("DELETE FROM announcements WHERE id = :id");
    $stmt->execute([':id' => $id]);

    Response::success(null, 'Duyuru silindi.');
}

Response::error('Desteklenmeyen istek yöntemi.', 405);
