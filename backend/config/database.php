<?php
// backend/config/database.php

declare(strict_types=1);

return [
    'host'     => '127.0.0.1',
    'port'     => 3306,
    'dbname'   => 'siparis_sistemi',
    'username' => 'root',
    'password' => '',
    'charset'  => 'utf8mb4',
    'options'  => [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ]
];
