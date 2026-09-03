import 'package:flutter/material.dart';

class ApiConfig {
  // Canlı/Lokal sunucu IP adresinizi buraya yazın (Örn: http://192.168.1.100 veya http://10.0.2.2/backend/api)
  static const String baseUrl = 'http://10.0.2.2/backend/api'; 

  // Endpointler
  static const String login = '$baseUrl/auth/login.php';
  
  // Dükkan Sahibi
  static const String shopCustomers = '$baseUrl/shop/customers.php';
  static const String shopCategories = '$baseUrl/shop/categories.php';
  static const String shopProducts = '$baseUrl/shop/products.php';
  static const String shopOrders = '$baseUrl/shop/orders.php';
  
  // Müşteri
  static const String customerMenu = '$baseUrl/customer/menu.php';
  static const String customerOrders = '$baseUrl/customer/orders.php';
}

class AppColors {
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color accent = Color(0xFFA855F7);
  static const Color background = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFF1E293B);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
}
