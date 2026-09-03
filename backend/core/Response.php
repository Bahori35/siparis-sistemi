<?php
// backend/core/Response.php

declare(strict_types=1);

class Response {
    public static function json(mixed $data, int $statusCode = 200): void {
        http_response_code($statusCode);
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }

    public static function success(mixed $data = null, string $message = 'İşlem başarılı', int $statusCode = 200): void {
        self::json([
            'success' => true,
            'message' => $message,
            'data'    => $data
        ], $statusCode);
    }

    public static function error(string $message = 'Bir hata oluştu', int $statusCode = 400, mixed $errors = null): void {
        self::json([
            'success' => false,
            'message' => $message,
            'errors'  => $errors
        ], $statusCode);
    }

    public static function unauthorized(string $message = 'Yetkisiz erişim. Lütfen giriş yapın.'): void {
        self::error($message, 401);
    }

    public static function forbidden(string $message = 'Bu işlem için yetkiniz bulunmamaktadır.'): void {
        self::error($message, 403);
    }

    public static function notFound(string $message = 'Kayıt bulunamadı.'): void {
        self::error($message, 404);
    }
}
