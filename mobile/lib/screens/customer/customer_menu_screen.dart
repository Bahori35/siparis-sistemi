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
  int _currentTab = 0; // 0: Menü, 1: Sepetim, 2: Siparişlerim
  int? _selectedCategoryId; // Sol menüden seçilen kategori filtresi (null = Tümü)
  
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
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      // SOL AÇILIR MENÜ (DRAWER)
      drawer: Drawer(
        backgroundColor: AppColors.cardBg,
        child: Column(
          children: [
            // Drawer Başlığı
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                child: const Icon(Icons.restaurant, color: Colors.white, size: 36),
              ),
              accountName: Text(
                _shopInfo?['name'] ?? 'İşletme Menüsü',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              accountEmail: Text(
                'Müşteri: ${auth.user?['full_name'] ?? ''}',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ),

            // Kategori Listesi
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Tüm Menü Butonu
                  ListTile(
                    leading: const Icon(Icons.apps, color: Colors.white70),
                    title: const Text('Tüm Menü', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    selected: _selectedCategoryId == null && _currentTab == 0,
                    selectedTileColor: AppColors.primary.withOpacity(0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = null;
                        _currentTab = 0;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(color: Colors.white12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('KATEGORİLER', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ),
                  // Dinamik Kategoriler
                  ..._menu.map((cat) {
                    final catId = cat['category_id'] as int;
                    final isSelected = _selectedCategoryId == catId && _currentTab == 0;
                    return ListTile(
                      leading: const Icon(Icons.local_cafe_outlined, color: AppColors.primary),
                      title: Text(cat['category_name'], style: const TextStyle(color: Colors.white)),
                      trailing: Chip(
                        label: Text('${(cat['products'] as List).length}'),
                        backgroundColor: AppColors.background,
                        labelStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        padding: EdgeInsets.zero,
                      ),
                      selected: isSelected,
                      selectedTileColor: AppColors.primary.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = catId;
                          _currentTab = 0;
                        });
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            ),

            // Alt Kısım: Sepet ve Çıkış
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.shopping_cart_outlined, color: AppColors.success),
              title: const Text('Sepetim', style: TextStyle(color: Colors.white)),
              trailing: _cart.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(12)),
                      child: Text('${_cart.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  : null,
              onTap: () {
                setState(() => _currentTab = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: AppColors.warning),
              title: const Text('Sipariş Geçmişim', style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => _currentTab = 2);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
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

    // Seçili kategori filtresi varsa sadece onu göster, yoksa tümünü
    final filteredCategories = _selectedCategoryId == null
        ? _menu
        : _menu.where((c) => c['category_id'] == _selectedCategoryId).toList();

    return Column(
      children: [
        // Kategori Seçim Barı (Üstte Hızlı Filtre Butonları)
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Tümü'),
                  selected: _selectedCategoryId == null,
                  selectedColor: AppColors.primary,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategoryId = null);
                  },
                ),
              ),
              ..._menu.map((cat) {
                final catId = cat['category_id'] as int;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat['category_name']),
                    selected: _selectedCategoryId == catId,
                    selectedColor: AppColors.primary,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategoryId = selected ? catId : null;
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        // Ürün Listesi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredCategories.length,
            itemBuilder: (ctx, i) {
              final category = filteredCategories[i];
              final products = category['products'] as List<dynamic>? ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          category['category_name'],
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        Text(
                          '${products.length} ürün',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        )
                      ],
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
          ),
        ),
      ],
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
