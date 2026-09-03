import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../constants.dart';
import '../login_screen.dart';

class CustomerMenuScreen extends StatefulWidget {
  const CustomerMenuScreen({super.key});

  @override
  State<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends State<CustomerMenuScreen> {
  int _currentTab = 0; // 0: Menü, 1: Sepet & Sipariş, 2: Siparişlerim
  Map<String, dynamic>? _shopInfo;
  List<dynamic> _menu = [];
  List<dynamic> _myOrders = [];
  bool _isLoading = false;

  // Sepet: { productId: { 'product': item, 'quantity': count } }
  final Map<int, Map<String, dynamic>> _cart = {};
  final TextEditingController _orderNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMenu();
    _loadMyOrders();
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.customerMenu),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json'
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        _shopInfo = data['shop'];
        _menu = data['menu'] ?? [];
      }
    } catch (e) {
      debugPrint('Menü yükleme hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMyOrders() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.customerOrders),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json'
        },
      );
      if (res.statusCode == 200) {
        setState(() {
          _myOrders = jsonDecode(res.body)['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Sipariş yükleme hatası: $e');
    }
  }

  void _addToCart(dynamic product) {
    final id = product['id'] as int;
    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id]!['quantity'] += 1;
      } else {
        _cart[id] = {'product': product, 'quantity': 1};
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product['name']} sepete eklendi.'), duration: const Duration(seconds: 1)),
    );
  }

  void _removeFromCart(int productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        if (_cart[productId]!['quantity'] > 1) {
          _cart[productId]!['quantity'] -= 1;
        } else {
          _cart.remove(productId);
        }
      }
    });
  }

  double get _cartTotal {
    double total = 0;
    _cart.forEach((_, item) {
      total += (item['product']['price'] as num) * item['quantity'];
    });
    return total;
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final itemsPayload = _cart.entries.map((e) => {
      'product_id': e.key,
      'quantity': e.value['quantity'],
    }).toList();

    try {
      final res = await http.post(
        Uri.parse(ApiConfig.customerOrders),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'items': itemsPayload,
          'notes': _orderNotesController.text.trim(),
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 201 && data['success'] == true) {
        setState(() {
          _cart.clear();
          _orderNotesController.clear();
          _currentTab = 2; // Siparişler sekmesine geç
        });
        _loadMyOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Siparişiniz dükkana iletildi! Afiyet olsun.'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Sipariş verilemedi.'), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
      );
    }
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
            Text(_shopInfo?['name'] ?? auth.shopName ?? 'Menü', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('${auth.user?['full_name']} (Müşteri)', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadMenu();
              _loadMyOrders();
            },
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
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Menü'),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _cart.isNotEmpty,
              label: Text('${_cart.values.fold(0, (sum, i) => sum + (i['quantity'] as int))}'),
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Sepetim',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Siparişlerim'),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    if (_currentTab == 0) return _buildMenuTab();
    if (_currentTab == 1) return _buildCartTab();
    return _buildOrdersTab();
  }

  Widget _buildMenuTab() {
    if (_menu.isEmpty) {
      return const Center(child: Text('Dükkanın menüsünde henüz ürün bulunmuyor.', style: TextStyle(color: AppColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _menu.length,
      itemBuilder: (ctx, i) {
        final category = _menu[i];
        final products = category['products'] as List<dynamic>? ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                category['category_name'],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            ...products.map((p) => Card(
              color: AppColors.cardBg,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: p['description'] != null ? Text(p['description'], style: const TextStyle(color: AppColors.textMuted)) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('₺${p['price']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success)),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 30),
                      onPressed: () => _addToCart(p),
                    ),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildCartTab() {
    if (_cart.isEmpty) {
      return const Center(
        child: Text('Sepetiniz boş. Menüden dilediğiniz ürünleri ekleyin!', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._cart.values.map((item) {
            final p = item['product'];
            final qty = item['quantity'];
            return Card(
              color: AppColors.cardBg,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('₺${p['price']} x $qty = ₺${(p['price'] * qty).toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textMuted)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.remove, color: AppColors.danger), onPressed: () => _removeFromCart(p['id'])),
                    Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.add, color: AppColors.success), onPressed: () => _addToCart(p)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          TextField(
            controller: _orderNotesController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Sipariş Notu (Örn: Çay açık olsun, Kat 3 Muhasebe)',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Toplam Tutar:', style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
                Text('₺${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _submitOrder,
              child: const Text('Siparişi Tamamla & Gönder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_myOrders.isEmpty) {
      return const Center(child: Text('Henüz verilmiş bir siparişiniz bulunmuyor.', style: TextStyle(color: AppColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myOrders.length,
      itemBuilder: (ctx, i) {
        final ord = _myOrders[i];
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sipariş #${ord['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    _buildStatusChip(ord['status']),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Tarih: ${ord['created_at']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const Divider(color: Colors.white12, height: 16),
                ...items.map((it) => Text('• ${it['quantity']}x ${it['product_name']} (₺${it['unit_price']})', style: const TextStyle(color: Colors.white70))),
                const SizedBox(height: 8),
                Text('Toplam Tutar: ₺${ord['total_price']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success)),
              ],
            ),
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
