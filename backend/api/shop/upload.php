<?php
// backend/api/shop/upload.php

declare(strict_types=1);

require_once __DIR__ . '/../../config/config.php';
require_once __DIR__ . '/../../core/JWT.php';
require_once __DIR__ . '/../../core/Request.php';
require_once __DIR__ . '/../../core/Response.php';
require_once __DIR__ . '/../../core/AuthMiddleware.php';

handleCors();

// Sadece Dükkan Sahibi resim yükleyebilir
$auth = AuthMiddleware::authenticate(['SHOP_OWNER']);
$shopId = AuthMiddleware::requireShopId($auth);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Sadece POST istekleri kabul edilir.', 405);
}

// 1. Multipart dosya kontrolü
if (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
    $fileTmpPath = $_FILES['image']['tmp_name'];
    $fileName = $_FILES['image']['name'];
    $fileSize = $_FILES['image']['size'];
    $fileType = $_FILES['image']['type'];

    // İzin verilen formatlar
    $allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
    $fileExtension = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));

    if (!in_array($fileExtension, $allowedExtensions, true)) {
        Response::error('Geçersiz dosya formatı. Yalnızca JPG, PNG ve WEBP formatları desteklenir.', 422);
    }

    if ($fileSize > 5 * 1024 * 1024) { // 5MB limit
        Response::error('Görsel boyutu en fazla 5MB olabilir.', 422);
    }

    // Hedef Dizin
    $uploadDir = __DIR__ . '/../../public/uploads/products/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0777, true);
    }

    $newFileName = 'prod_' . $shopId . '_' . time() . '_' . bin2hex(random_bytes(4)) . '.' . $fileExtension;
    $destPath = $uploadDir . $newFileName;

    if (move_uploaded_file($fileTmpPath, $destPath)) {
        // Canlı/Lokal URL oluştur
        $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? "https" : "http";
        $host = $_SERVER['HTTP_HOST'] ?? '46.197.188.20';
        $fileUrl = "{$protocol}://{$host}/backend/public/uploads/products/{$newFileName}";

        Response::success([
            'image_url' => $fileUrl,
            'file_name' => $newFileName
        ], 'Görsel başarıyla yüklendi.');
    } else {
        Response::error('Dosya kaydedilemedi.', 500);
    }
}

// 2. Base64 formatında JSON yükleme desteği (Alternatif)
$body = Request::getJsonBody();
if (!empty($body['image_base64'])) {
    $base64Data = $body['image_base64'];
    $extension = 'jpg';

    if (preg_match('/^data:image\/(\w+);base64,/', $base64Data, $type)) {
        $base64Data = substr($base64Data, strpos($base64Data, ',') + 1);
        $extension = strtolower($type[1]);
        if ($extension === 'jpeg') $extension = 'jpg';
    }

    $decodedData = base64_decode($base64Data);
    if (!$decodedData) {
        Response::error('Geçersiz Base64 görsel verisi.', 422);
    }

    $uploadDir = __DIR__ . '/../../public/uploads/products/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0777, true);
    }

    $newFileName = 'prod_' . $shopId . '_' . time() . '_' . bin2hex(random_bytes(4)) . '.' . $extension;
    $destPath = $uploadDir . $newFileName;

    if (file_put_contents($destPath, $decodedData)) {
        $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? "https" : "http";
        $host = $_SERVER['HTTP_HOST'] ?? '46.197.188.20';
        $fileUrl = "{$protocol}://{$host}/backend/public/uploads/products/{$newFileName}";

        Response::success([
            'image_url' => $fileUrl,
            'file_name' => $newFileName
        ], 'Görsel başarıyla yüklendi.');
    } else {
        Response::error('Dosya yazılamadı.', 500);
    }
}

Response::error('Yüklenecek bir görsel bulunamadı.', 400);
