<?php
// backend/config/config.php

declare(strict_types=1);

// Hata Raporlama Ayarları (Production'da 0 yapılmalıdır)
error_reporting(E_ALL);
ini_set('display_errors', '1');

// Zaman Dilimi
date_default_timezone_set('Europe/Istanbul');

// Güvenlik & JWT Ayarları
define('JWT_SECRET_KEY', 'SuperSecretJwtKeyChangeThisInProduction_2026!@#$%^&*');
define('JWT_ALGORITHM', 'HS256');
define('JWT_EXPIRY_SECONDS', 60 * 60 * 24 * 30); // 30 Günlük Token Geçerliliği

// CORS Ayarları
function handleCors(): void {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
    header('Content-Type: application/json; charset=UTF-8');

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit;
    }
}
