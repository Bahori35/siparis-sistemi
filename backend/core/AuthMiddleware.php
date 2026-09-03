<?php
// backend/core/AuthMiddleware.php

declare(strict_types=1);

require_once __DIR__ . '/JWT.php';
require_once __DIR__ . '/Request.php';
require_once __DIR__ . '/Response.php';

class AuthMiddleware {
    /**
     * Token'ı doğrular ve payload'ı döner.
     * İsteğe bağlı olarak rol kontrolü yapar (örn: ['SUPER_ADMIN'] veya ['SHOP_OWNER']).
     */
    public static function authenticate(array $allowedRoles = []): array {
        $token = Request::getBearerToken();
        if (!$token) {
            Response::unauthorized('Erişim reddedildi: Yetkilendirme token\'ı bulunamadı.');
        }

        $payload = JWT::decode($token);
        if (!$payload || !isset($payload['user_id'], $payload['role'])) {
            Response::unauthorized('Geçersiz veya süresi dolmuş oturum.');
        }

        // Rol Denetimi
        if (!empty($allowedRoles) && !in_array($payload['role'], $allowedRoles, true)) {
            Response::forbidden('Bu işlem için gerekli yetkiye sahip değilsiniz.');
        }

        return $payload;
    }

    /**
     * Dükkan sahibi veya müşterinin zorunlu shop_id'sini güvenli şekilde döndürür.
     */
    public static function requireShopId(array $authData): int {
        if (!isset($authData['shop_id']) || empty($authData['shop_id'])) {
            Response::forbidden('Bu işlem için dükkan ilişkisi zorunludur.');
        }
        return (int)$authData['shop_id'];
    }
}
