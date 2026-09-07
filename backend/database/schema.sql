-- ==========================================================
-- SİPARİŞ SİSTEMİ - MARIADB VERİTABANI ŞEMASI (schema.sql)
-- Karakter Seti: utf8mb4 / Collation: utf8mb4_unicode_ci
-- Motor: InnoDB (Foreign Key & Transaction Desteği)
-- ==========================================================

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS shops;
SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------
-- 1. SHOPS TABLOSU (İşletmeler / Dükkanlar)
-- ----------------------------------------------------------
CREATE TABLE shops (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL COMMENT 'Dükkan / İşletme Adı',
    phone VARCHAR(20) NULL COMMENT 'İletişim Numarası',
    address TEXT NULL COMMENT 'Dükkan Adresi',
    is_active TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: Aktif, 0: Dondurulmuş/Pasif',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_shops_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------
-- 2. USERS TABLOSU (Kullanıcılar: Süper Admin, Dükkan Sahibi, Müşteri)
-- ----------------------------------------------------------
CREATE TABLE users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id INT UNSIGNED NULL COMMENT 'Süper Admin için NULL, Dükkan Sahibi ve Müşteri için zorunlu',
    username VARCHAR(80) NOT NULL UNIQUE COMMENT 'Giriş Kullanıcı Adı',
    password_hash VARCHAR(255) NOT NULL COMMENT 'Bcrypt / Argon2 Hash',
    role ENUM('SUPER_ADMIN', 'SHOP_OWNER', 'CUSTOMER') NOT NULL DEFAULT 'CUSTOMER' COMMENT 'Kullanıcı Rolü',
    full_name VARCHAR(120) NOT NULL COMMENT 'Ad Soyad / Unvan',
    phone VARCHAR(20) NULL COMMENT 'Müşteri/Kullanıcı Telefonu',
    is_active TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: Aktif, 0: Engelli/Pasif',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_users_shop_id 
        FOREIGN KEY (shop_id) REFERENCES shops(id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
        
    INDEX idx_users_shop_role (shop_id, role),
    INDEX idx_users_username (username),
    INDEX idx_users_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------
-- 3. CATEGORIES TABLOSU (Dükkan Ürün Kategorileri)
-- ----------------------------------------------------------
CREATE TABLE categories (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id INT UNSIGNED NOT NULL COMMENT 'Kategorinin ait olduğu dükkan',
    name VARCHAR(100) NOT NULL COMMENT 'Kategori Adı (Çaylar, Tostlar, vb.)',
    sort_order INT NOT NULL DEFAULT 0 COMMENT 'Menüdeki sıralama sırası',
    is_active TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: Göster, 0: Gizle',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_categories_shop_id 
        FOREIGN KEY (shop_id) REFERENCES shops(id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
        
    INDEX idx_categories_shop_sort (shop_id, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------
-- 4. PRODUCTS TABLOSU (Ürünler)
-- ----------------------------------------------------------
CREATE TABLE products (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id INT UNSIGNED NOT NULL COMMENT 'Ürünün ait olduğu dükkan',
    category_id INT UNSIGNED NOT NULL COMMENT 'Ürünün kategorisi',
    name VARCHAR(150) NOT NULL COMMENT 'Ürün Adı',
    description TEXT NULL COMMENT 'Ürün Açıklaması / İçindekiler',
    price DECIMAL(10, 2) NOT NULL DEFAULT 0.00 COMMENT 'Birim Fiyatı (TL)',
    image_url VARCHAR(255) NULL COMMENT 'Ürün Görsel URL veya Yolu',
    options_json TEXT NULL COMMENT 'Ürün Seçenek Grupları JSON (Şeker, Sos, Boyut vb.)',
    is_available TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: Menüde Var/Sipariş Edilebilir, 0: Tükendi/Yok',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_products_shop_id 
        FOREIGN KEY (shop_id) REFERENCES shops(id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
        
    CONSTRAINT fk_products_category_id 
        FOREIGN KEY (category_id) REFERENCES categories(id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
        
    INDEX idx_products_shop_category (shop_id, category_id, is_available),
    INDEX idx_products_shop_available (shop_id, is_available)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------
-- 5. ORDERS TABLOSU (Siparişler)
-- ----------------------------------------------------------
CREATE TABLE orders (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    shop_id INT UNSIGNED NOT NULL COMMENT 'Siparişin verildiği dükkan',
    customer_id INT UNSIGNED NOT NULL COMMENT 'Siparişi veren müşteri (users tablosu)',
    total_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00 COMMENT 'Toplam Tutar',
    status ENUM('PENDING', 'ACCEPTED', 'PREPARING', 'DELIVERED', 'CANCELLED') NOT NULL DEFAULT 'PENDING' COMMENT 'Sipariş Durumu',
    notes TEXT NULL COMMENT 'Müşteri Sipariş Notu',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_orders_shop_id 
        FOREIGN KEY (shop_id) REFERENCES shops(id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
        
    CONSTRAINT fk_orders_customer_id 
        FOREIGN KEY (customer_id) REFERENCES users(id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
        
    INDEX idx_orders_shop_status_date (shop_id, status, created_at),
    INDEX idx_orders_customer (customer_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------
-- 6. ORDER_ITEMS TABLOSU (Sipariş Kalemleri)
-- ----------------------------------------------------------
CREATE TABLE order_items (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id INT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NULL COMMENT 'Ürün silinirse NULL olur, geçmiş sipariş kaydı korunur',
    quantity INT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Adet',
    unit_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00 COMMENT 'Sipariş anındaki ürün birim fiyatı',
    selected_options TEXT NULL COMMENT 'Her adet için seçilen opsiyonlar (JSON / Metin)',
    
    CONSTRAINT fk_order_items_order_id 
        FOREIGN KEY (order_id) REFERENCES orders(id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
        
    CONSTRAINT fk_order_items_product_id 
        FOREIGN KEY (product_id) REFERENCES products(id) 
        ON DELETE SET NULL ON UPDATE CASCADE,
        
    INDEX idx_order_items_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------
-- 7. ANNOUNCEMENTS TABLOSU (Sistem Duyuruları)
-- ----------------------------------------------------------
CREATE TABLE announcements (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL COMMENT 'Duyuru Başlığı',
    content TEXT NOT NULL COMMENT 'Duyuru Detayı / Metni',
    target_role ENUM('ALL', 'SHOP_OWNER', 'CUSTOMER') NOT NULL DEFAULT 'SHOP_OWNER' COMMENT 'Hedef Kitle',
    is_active TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1: Yayında, 0: Pasif',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_announcements_active (is_active, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
