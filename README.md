# Multi-Tenant Sipariş Sistemi

Bu proje; Web Süper Admin Paneli, Saf PHP REST API (JWT & Tenant İzolasyonlu), MariaDB veritabanı şeması ve iOS/Android için tek kod tabanlı Flutter mobil uygulamasını içerir.

---

## 🚀 1. Veritabanı Kurulumu (MariaDB / MySQL)

1. MariaDB / MySQL sunucunuzda `siparis_sistemi` adında bir veritabanı oluşturun:
   ```sql
   CREATE DATABASE siparis_sistemi CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
2. Şemayı ve örnek başlangıç verilerini içeri aktarın:
   - `backend/database/schema.sql` (Tüm tablolar, Foreign Key ve Index yapılandırmaları)
   - `backend/database/seed.sql` (Süper admin, dükkan sahibi ve müşteri test hesapları)

> **Varsayılan Test Hesapları (Şifrelerin tümü `123456`):**
> - **Süper Admin:** Kullanıcı adı: `admin` | Şifre: `123456`
> - **Dükkan Sahibi:** Kullanıcı adı: `ibrahim` | Şifre: `123456`
> - **Müşteri:** Kullanıcı adı: `ahmet` | Şifre: `123456`

---

## 🌐 2. Web Süper Admin Paneli & Backend

1. `backend/config/database.php` dosyasındaki veritabanı kullanıcı adı ve şifrenizi kontrol edin.
2. XAMPP, Laragon veya PHP Dahili Sunucusunu başlatın:
   ```bash
   php -S 127.0.0.1:8000
   ```
3. Tarayıcınızdan Web Süper Admin Paneline erişin:
   - **URL:** `http://127.0.0.1:8000/backend/public/admin/index.html` (veya XAMPP `htdocs` altındaysa `http://localhost/.../backend/public/admin/index.html`)
   - Yeni dükkanlar ekleyebilir, dondurabilir, dükkan sahipleri tanımlayabilir ve genel istatistikleri görebilirsiniz.

---

## 📱 3. Mobil Uygulama (Flutter - iOS & Android)

Mobil uygulama hem **Dükkan Sahibi** hem de **Müşteri** için ortak tek bir giriş ekranı sunar. Kullanıcı adı ve şifreye göre dönen role (`SHOP_OWNER` veya `CUSTOMER`) uygun arayüz otomatik açılır.

1. `mobile/lib/constants.dart` içindeki `baseUrl` adresini kendi API sunucu IP'nize göre ayarlayın (Örn: `http://192.168.1.50/backend/api` veya emülatör için `http://10.0.2.2/backend/api`).
2. Bağımlılıkları yükleyin ve çalıştırın:
   ```bash
   cd mobile
   flutter pub get
   flutter run
   ```

### 🔑 Sistem Özellikleri & Güvenlik
- **Saf PHP & Bağımsız JWT:** Harici paket gerektirmeden çalışan HMAC-SHA256 token motoru.
- **Tenant İzolasyonu:** Müşteriler yalnızca kendilerini ekleyen dükkanın menüsünü görebilir ve sipariş verebilir. Başka dükkanların ürünlerine erişim PHP API ve veritabanı seviyesinde engellenmiştir.
- **Dükkan Sahibi Paneli:** Müşteri hesabı oluşturma, ürün/kategori yönetimi ve anlık sipariş durumu takibi (Onayla, Hazırlanıyor, Teslim Edildi).
- **Müşteri Paneli:** Kategori bazlı menü, sepet yönetimi, sipariş notu ekleme ve geçmiş sipariş durumu takibi.
