import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants.dart';
import '../login_screen.dart';

class ShopDashboardScreen extends StatefulWidget {
  const ShopDashboardScreen({super.key});

  @override
  State<ShopDashboardScreen> createState() => _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends State<ShopDashboardScreen> {
  int _currentTab = 0; // 0: Siparişler, 1: Ürünler & Kategoriler, 2: Müşteriler
  List<dynamic> _orders = [];
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  List<dynamic> _customers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final headers = {
      'Authorization': 'Bearer ${auth.token}',
      'Content-Type': 'application/json'
    };

    try {
      final ordRes = await http.get(Uri.parse(ApiConfig.shopOrders), headers: headers);
      final prodRes = await http.get(Uri.parse(ApiConfig.shopProducts), headers: headers);
      final catRes = await http.get(Uri.parse(ApiConfig.shopCategories), headers: headers);
      final custRes = await http.get(Uri.parse(ApiConfig.shopCustomers), headers: headers);

      if (ordRes.statusCode == 200) _orders = jsonDecode(ordRes.body)['data'] ?? [];
      if (prodRes.statusCode == 200) _products = jsonDecode(prodRes.body)['data'] ?? [];
      if (catRes.statusCode == 200) _categories = jsonDecode(catRes.body)['data'] ?? [];
      if (custRes.statusCode == 200) _customers = jsonDecode(custRes.body)['data'] ?? [];
    } catch (e) {
      debugPrint('Veri çekme hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final res = await http.put(
        Uri.parse(ApiConfig.shopOrders),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'order_id': orderId, 'status': newStatus}),
      );
      if (res.statusCode == 200) {
        _loadAllData();
      }
    } catch (e) {
      debugPrint('Durum güncelleme hatası: $e');
    }
  }

  void _openAddCustomerDialog() {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Yeni Müşteri Tanımla', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Müşteri Ad Soyad (Ofis/Masa No)', labelStyle: TextStyle(color: AppColors.textMuted)),
              ),
              TextField(
                controller: phoneCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Telefon Numarası', labelStyle: TextStyle(color: AppColors.textMuted)),
              ),
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Giriş Kullanıcı Adı', labelStyle: TextStyle(color: AppColors.textMuted)),
              ),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Giriş Şifresi', labelStyle: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final auth = Provider.of<AuthService>(context, listen: false);
              final res = await http.post(
                Uri.parse(ApiConfig.shopCustomers),
                headers: {
                  'Authorization': 'Bearer ${auth.token}',
                  'Content-Type': 'application/json'
                },
                body: jsonEncode({
                  'full_name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'username': userCtrl.text.trim(),
                  'password': passCtrl.text.trim(),
                }),
              );
              Navigator.pop(ctx);
              _loadAllData();
            },
            child: const Text('Müşteriyi Kaydet'),
          ),
        ],
      ),
    );
  }

  void _openAddProductDialog() {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce en az 1 kategori ekleyin!')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    int selectedCatId = _categories.first['id'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text('Yeni Ürün Ekle', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedCatId,
                  dropdownColor: AppColors.cardBg,
                  style: const TextStyle(color: Colors.white),
                  items: _categories.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                    value: c['id'] as int,
                    child: Text(c['name']),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedCatId = val!),
                  decoration: const InputDecoration(labelText: 'Kategori', labelStyle: TextStyle(color: AppColors.textMuted)),
                ),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Ürün Adı', labelStyle: TextStyle(color: AppColors.textMuted)),
                ),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Fiyat (TL)', labelStyle: TextStyle(color: AppColors.textMuted)),
                ),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Açıklama (Opsiyonel)', labelStyle: TextStyle(color: AppColors.textMuted)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final auth = Provider.of<AuthService>(context, listen: false);
                await http.post(
                  Uri.parse(ApiConfig.shopProducts),
                  headers: {
                    'Authorization': 'Bearer ${auth.token}',
                    'Content-Type': 'application/json'
                  },
                  body: jsonEncode({
                    'category_id': selectedCatId,
                    'name': nameCtrl.text.trim(),
                    'price': double.tryParse(priceCtrl.text) ?? 0.0,
                    'description': descCtrl.text.trim(),
                  }),
                );
                Navigator.pop(ctx);
                _loadAllData();
              },
              child: const Text('Ürünü Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(auth.shopName ?? 'Dükkan Paneli', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('${auth.user?['full_name']} (Dükkan Sahibi)', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.danger),
            onPressed: () async {
              await auth.logout();
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildCurrentTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        backgroundColor: AppColors.cardBg,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        onTap: (index) => setState(() => _currentTab = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Siparişler'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Menü & Ürünler'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Müşteriler'),
        ],
      ),
      floatingActionButton: _currentTab == 1
          ? FloatingActionButton.extended(
              onPressed: _openAddProductDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Ürün Ekle', style: TextStyle(color: Colors.white)),
            )
          : _currentTab == 2
              ? FloatingActionButton.extended(
                  onPressed: _openAddCustomerDialog,
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: const Text('Müşteri Ekle', style: TextStyle(color: Colors.white)),
                )
              : null,
    );
  }

  Widget _buildCurrentTab() {
    if (_currentTab == 0) return _buildOrdersTab();
    if (_currentTab == 1) return _buildProductsTab();
    return _buildCustomersTab();
  }

  Widget _buildOrdersTab() {
    if (_orders.isEmpty) {
      return const Center(child: Text('Henüz gelen bir sipariş yok.', style: TextStyle(color: AppColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (ctx, i) {
        final ord = _orders[i];
        final items = ord['items'] as List<dynamic>? ?? [];
        return Card(
          color: AppColors.cardBg,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.between,
                  children: [
                    Text('Sipariş #${ord['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    _buildStatusChip(ord['status']),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Müşteri: ${ord['customer_name']} (${ord['customer_phone'] ?? '-'})', style: const TextStyle(color: AppColors.textMuted)),
                if (ord['notes'] != null && ord['notes'].toString().isNotEmpty)
                  Text('Not: "${ord['notes']}"', style: const TextStyle(color: AppColors.warning, fontStyle: FontStyle.italic)),
                const Divider(color: Colors.white12, height: 20),
                ...items.map((it) => Text('• ${it['quantity']}x ${it['product_name']} (₺${it['unit_price']})', style: const TextStyle(color: Colors.white70))),
                const SizedBox(height: 8),
                Text('Toplam: ₺${ord['total_price']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    if (ord['status'] == 'PENDING')
                      ElevatedButton(onPressed: () => _updateOrderStatus(ord['id'], 'ACCEPTED'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), child: const Text('Onayla')),
                    if (ord['status'] == 'ACCEPTED')
                      ElevatedButton(onPressed: () => _updateOrderStatus(ord['id'], 'PREPARING'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning), child: const Text('Hazırlanıyor')),
                    if (ord['status'] == 'PREPARING')
                      ElevatedButton(onPressed: () => _updateOrderStatus(ord['id'], 'DELIVERED'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success), child: const Text('Teslim Edildi')),
                    if (ord['status'] != 'DELIVERED' && ord['status'] != 'CANCELLED')
                      TextButton(onPressed: () => _updateOrderStatus(ord['id'], 'CANCELLED'), child: const Text('İptal Et', style: TextStyle(color: AppColors.danger))),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsTab() {
    if (_products.isEmpty) {
      return const Center(child: Text('Henüz ürün bulunmuyor. Ürün Ekle butonuyla ekleyebilirsiniz.', style: TextStyle(color: AppColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (ctx, i) {
        final p = _products[i];
        return Card(
          color: AppColors.cardBg,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('${p['category_name'] ?? '-'} • ₺${p['price']}', style: const TextStyle(color: AppColors.textMuted)),
            trailing: Chip(
              backgroundColor: p['is_available'] == 1 ? AppColors.success.withOpacity(0.2) : AppColors.danger.withOpacity(0.2),
              label: Text(p['is_available'] == 1 ? 'Mevcut' : 'Tükendi', style: TextStyle(color: p['is_available'] == 1 ? AppColors.success : AppColors.danger)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomersTab() {
    if (_customers.isEmpty) {
      return const Center(child: Text('Kayıtlı müşteri yok. Müşteri Ekle ile dükkanınıza özel müşteri hesabı oluşturun.', style: TextStyle(color: AppColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _customers.length,
      itemBuilder: (ctx, i) {
        final c = _customers[i];
        return Card(
          color: AppColors.cardBg,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white)),
            title: Text(c['full_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('Kullanıcı Adı: @${c['username']} • Tel: ${c['phone'] ?? '-'}', style: const TextStyle(color: AppColors.textMuted)),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'PENDING': color = AppColors.warning; label = 'Bekliyor'; break;
      case 'ACCEPTED': color = AppColors.primary; label = 'Onaylandı'; break;
      case 'PREPARING': color = Colors.orange; label = 'Hazırlanıyor'; break;
      case 'DELIVERED': color = AppColors.success; label = 'Teslim Edildi'; break;
      case 'CANCELLED': color = AppColors.danger; label = 'İptal'; break;
      default: color = AppColors.textMuted; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
