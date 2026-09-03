-- ==========================================================
-- BAŞLANGIÇ TEST VE ÖRNEK VERİLERİ (seed.sql)
-- Şifrelerin tümü düz metin olarak '123456'dır (password_hash)
-- Hash: $2y$10$wN7N70j0cugKxsqgXpP8zef/2VjGZ1vPqm2FmgJ8B.w75r8b8O.eG
-- ==========================================================

-- 1. Süper Admin Kullanıcısı (shop_id = NULL)
INSERT INTO users (shop_id, username, password_hash, role, full_name, phone, is_active)
VALUES (
    NULL,
    'admin',
    '$2y$10$wN7N70j0cugKxsqgXpP8zef/2VjGZ1vPqm2FmgJ8B.w75r8b8O.eG', -- 123456
    'SUPER_ADMIN',
    'Sistem Yöneticisi',
    '05550000000',
    1
);

-- 2. Örnek Dükkan 1: "İbrahim Abi Çay & Tost Evi"
INSERT INTO shops (id, name, phone, address, is_active)
VALUES (1, 'İbrahim Abi Çay & Tost Evi', '05321112233', 'Çarşı Meydanı No:12', 1);

-- 3. Dükkan Sahibi (Shop Owner)
INSERT INTO users (shop_id, username, password_hash, role, full_name, phone, is_active)
VALUES (
    1,
    'ibrahim',
    '$2y$10$wN7N70j0cugKxsqgXpP8zef/2VjGZ1vPqm2FmgJ8B.w75r8b8O.eG', -- 123456
    'SHOP_OWNER',
    'İbrahim Usta',
    '05321112233',
    1
);

-- 4. Örnek Müşteri (Customer - Dükkan 1'e bağlı)
INSERT INTO users (shop_id, username, password_hash, role, full_name, phone, is_active)
VALUES (
    1,
    'ahmet',
    '$2y$10$wN7N70j0cugKxsqgXpP8zef/2VjGZ1vPqm2FmgJ8B.w75r8b8O.eG', -- 123456
    'CUSTOMER',
    'Ahmet Yılmaz (Ofis Kat 3)',
    '05443332211',
    1
);

-- 5. Dükkan 1 Kategorileri
INSERT INTO categories (id, shop_id, name, sort_order, is_active) VALUES
(1, 1, 'Sıcak İçecekler', 1, 1),
(2, 1, 'Tostlar & Sandviçler', 2, 1),
(3, 1, 'Soğuk İçecekler', 3, 1);

-- 6. Dükkan 1 Ürünleri
INSERT INTO products (shop_id, category_id, name, description, price, is_available) VALUES
(1, 1, 'Tavşan Kanı Çay', 'Özel harman demlik çay', 15.00, 1),
(1, 1, 'Oralet (Portakal / Kivi)', 'Sıcak fincan oralet', 20.00, 1),
(1, 1, 'Türk Kahvesi', 'Közde pişirilmiş sade/orta/şekerli', 40.00, 1),
(1, 2, 'Kaşarlı Tost', 'Bol tereyağlı ve kaşarlı tost', 65.00, 1),
(1, 2, 'Karışık Tost (Sucuk + Kaşar)', 'Kasap sucuk ve taze kaşarlı özel tost', 85.00, 1),
(1, 3, 'Kutu Kola 330ml', 'Soğuk kutu', 35.00, 1),
(1, 3, 'Şişe Ayran 300ml', 'Köy yoğurdundan yayık ayran', 25.00, 1);
