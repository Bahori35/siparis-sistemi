import 'package:flutter/material.dart';

class ApiConfig {
  // XAMPP / Backend API IP Adresi
  static const String baseUrl = 'http://46.197.188.20/backend/api'; 

  // Endpointler
  static const String login = '$baseUrl/auth/login.php';
  
  // Dükkan Sahibi
  static const String shopCustomers = '$baseUrl/shop/customers.php';
  static const String shopCategories = '$baseUrl/shop/categories.php';
  static const String shopProducts = '$baseUrl/shop/products.php';
  static const String shopOrders = '$baseUrl/shop/orders.php';
  static const String shopUpload = '$baseUrl/shop/upload.php';
  
  // Müşteri
  static const String customerMenu = '$baseUrl/customer/menu.php';
  static const String customerOrders = '$baseUrl/customer/orders.php';
  
  // Dükkan Ayarları (Aç/Kapat & Mesai Saatleri)
  static const String shopSettings = '$baseUrl/shop/settings.php';
  
  // Duyurular
  static const String shopAnnouncements = '$baseUrl/shop/announcements.php';
}

class AppColors {
  // Canlı Turuncu Renk Teması (Warm Orange / Amber)
  static const Color primary = Color(0xFFFF7A00);      // Ana Turuncu (Butonlar, Vurgular)
  static const Color primaryDark = Color(0xFFE05600);  // Koyu Turuncu (Hover / Tıklama)
  static const Color accent = Color(0xFFFF9D42);       // Açık Turuncu Vurgu
  static const Color background = Color(0xFF121212);   // Koyu Siyah / Arka Plan
  static const Color cardBg = Color(0xFF1E1E1E);       // Koyu Kart ve Kutu Arka Planı
  static const Color textMain = Color(0xFFFFFFFF);     // Beyaz Başlık ve Yazılar
  static const Color textMuted = Color(0xFFA0A0A0);    // Yumuşak Gri Yardımcı Yazılar
  static const Color success = Color(0xFF10B981);      // Yeşil (Onay)
  static const Color warning = Color(0xFFF59E0B);      // Sarı / Turuncu
  static const Color danger = Color(0xFFEF4444);       // Kırmızı (Silme/İptal)
}
