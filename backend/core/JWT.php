<?php
// backend/core/JWT.php

declare(strict_types=1);

class JWT {
    public static function encode(array $payload, string $secret = JWT_SECRET_KEY, int $expirySeconds = JWT_EXPIRY_SECONDS): string {
        $header = [
            'typ' => 'JWT',
            'alg' => 'HS256'
        ];

        $now = time();
        $payload['iat'] = $now;
        $payload['exp'] = $now + $expirySeconds;

        $base64Header = self::base64UrlEncode(json_encode($header));
        $base64Payload = self::base64UrlEncode(json_encode($payload));

        $signature = hash_hmac('sha256', "{$base64Header}.{$base64Payload}", $secret, true);
        $base64Signature = self::base64UrlEncode($signature);

        return "{$base64Header}.{$base64Payload}.{$base64Signature}";
    }

    public static function decode(string $token, string $secret = JWT_SECRET_KEY): ?array {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            return null;
        }

        [$base64Header, $base64Payload, $base64Signature] = $parts;

        $expectedSignature = hash_hmac('sha256', "{$base64Header}.{$base64Payload}", $secret, true);
        $expectedBase64Signature = self::base64UrlEncode($expectedSignature);

        if (!hash_equals($expectedBase64Signature, $base64Signature)) {
            return null;
        }

        $payloadJson = self::base64UrlDecode($base64Payload);
        if (!$payloadJson) {
            return null;
        }

        $payload = json_decode($payloadJson, true);
        if (!is_array($payload)) {
            return null;
        }

        // Zaman aşımı (Expiration) kontrolü
        if (isset($payload['exp']) && $payload['exp'] < time()) {
            return null;
        }

        return $payload;
    }

    private static function base64UrlEncode(string $data): string {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    private static function base64UrlDecode(string $data): string|false {
        $remainder = strlen($data) % 4;
        if ($remainder) {
            $data .= str_repeat('=', 4 - $remainder);
        }
        return base64_decode(strtr($data, '-_', '+/'));
    }
}
