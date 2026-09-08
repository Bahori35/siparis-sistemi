import 'dart:async';
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
  
  Map<String, dynamic>? _shopInfo;
  List<dynamic> _menu = [];
  List<dynamic> _myOrders = [];
  bool _isLoading = false;
  Timer? _liveTimer;

  // Sepet: Liste halinde tutuyoruz. Her eleman: { 'product': item, 'quantity': 1, 'selected_options': 'Sade, Orta vb.' }
  final List<Map<String, dynamic>> _cartList = [];
  final TextEditingController _orderNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMenu();
    _loadMyOrders();
    // Sipariş durumlarını (Onaylandı, Hazırlanıyor, Teslim Edildi) anlık güncelle
    _liveTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMyOrdersSilently();
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMyOrdersSilently() async {
    if (!mounted) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) return;

    try {
      final res = await http.get(
        Uri.parse(ApiConfig.customerOrders),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json'
        },
      );
      if (res.statusCode == 200 && mounted) {
        final newOrders = jsonDecode(res.body)['data'] ?? [];
        if (jsonEncode(_myOrders) != jsonEncode(newOrders)) {
          setState(() {
            _myOrders = newOrders;
          });
        }
      }

      // Dükkanın açık/kapalı durumunu ve notunu da anlık sessizce güncelle
      final menuRes = await http.get(
        Uri.parse(ApiConfig.customerMenu),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json'
        },
      );
      if (menuRes.statusCode == 200 && mounted) {
        final data = jsonDecode(menuRes.body)['data'];
        final newShop = data['shop'];
        if (jsonEncode(_shopInfo) != jsonEncode(newShop)) {
          setState(() {
            _shopInfo = newShop;
          });
        }
      }
    } catch (_) {}
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

  // =========================================================================
  // SEÇENEK VE ADET BELİRLEME PENCERESİ (3 Kahve için 1., 2., 3. Ayrı Seçim)
  // =========================================================================
  void _openAddToCartDialog(dynamic product) {
    int quantity = 1;
    final optionsData = product['options'] as List<dynamic>? ?? [];

    // optionsData: [ { title: 'Şeker', items: ['Sade', 'Orta', 'Şekerli'] }, ... ]
    // Her adet indexi (0, 1, 2) için seçilen opsiyonlar: { 0: { 'İçindekiler': ['Domates', 'Kaşar'] } }
    final Map<int, Map<String, List<String>>> unitSelections = {
      0: {}
    };

    // Başlangıçta hiçbir seçenek varsayılan olarak seçili gelmesin (boş başlasın)
    for (var g in optionsData) {
      final title = g['title'] ?? 'Seçenek';
      unitSelections[0]![title] = [];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık & Kapat
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product['name'],
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                  Text('₺${product['price']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success)),
                  const SizedBox(height: 16),

                  // ADET SEÇİMİ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Adet Belirleyin:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 28),
                              onPressed: () {
                                if (quantity > 1) {
                                  setSheetState(() {
                                    unitSelections.remove(quantity - 1);
                                    quantity--;
                                  });
                                }
                              },
                            ),
                            Text('$quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: AppColors.success, size: 28),
                              onPressed: () {
                                if (quantity < 20) {
                                  setSheetState(() {
                                    final newIndex = quantity;
                                    unitSelections[newIndex] = {};
                                    for (var g in optionsData) {
                                      final title = g['title'] ?? 'Seçenek';
                                      unitSelections[newIndex]![title] = [];
                                    }
                                    quantity++;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // SEÇENEKLER (1. ÜRÜN, 2. ÜRÜN, 3. ÜRÜN AYRI AYRI)
                  if (optionsData.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Seçenekleri Belirleyin (İstediğiniz kadar seçebilirsiniz):', style: TextStyle(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    ...List.generate(quantity, (index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quantity > 1 ? '${index + 1}. ${product['name']} Seçenekleri:' : 'Seçimleriniz:',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            ...optionsData.map((g) {
                              final groupTitle = g['title'] ?? 'Seçenek';
                              final items = (g['items'] as List?)?.map((e) => e.toString()).toList() ?? [];
                              final selectedList = unitSelections[index]?[groupTitle] ?? [];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$groupTitle:', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      children: items.map((optItem) {
                                        final isSel = selectedList.contains(optItem);
                                        return FilterChip(
                                          label: Text(optItem, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : AppColors.textMuted)),
                                          selected: isSel,
                                          checkmarkColor: Colors.white,
                                          selectedColor: AppColors.primary,
                                          backgroundColor: AppColors.cardBg,
                                          onSelected: (selected) {
                                            setSheetState(() {
                                              if (unitSelections[index]![groupTitle] == null) {
                                                unitSelections[index]![groupTitle] = [];
                                              }
                                              if (selected) {
                                                if (!unitSelections[index]![groupTitle]!.contains(optItem)) {
                                                  unitSelections[index]![groupTitle]!.add(optItem);
                                                }
                                              } else {
                                                unitSelections[index]![groupTitle]!.remove(optItem);
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 20),

                  // SEPETE EKLE ONAY BUTONU
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        // Her adet için oluşturulan opsiyon metinlerini sepet listesine ekle
                        setState(() {
                          for (int i = 0; i < quantity; i++) {
                            final optsMap = unitSelections[i] ?? {};
                            final List<String> formattedOpts = [];
                            optsMap.forEach((title, items) {
                              if (items.isNotEmpty) {
                                formattedOpts.add('$title: ${items.join(", ")}');
                              }
                            });
                            final optsStr = formattedOpts.join(' | ');

                            _cartList.add({
                              'product': product,
                              'quantity': 1,
                              'selected_options': optsStr.isNotEmpty ? optsStr : null,
                            });
                          }
                        });

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$quantity adet ${product['name']} sepete eklendi.'),
                            backgroundColor: AppColors.success,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
                      label: Text(
                        'Sepete Ekle (₺${((product['price'] as num) * quantity).toStringAsFixed(2)})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartList.removeAt(index);
    });
  }

  double get _cartTotal {
    double total = 0;
    for (var item in _cartList) {
      total += (item['product']['price'] as num) * (item['quantity'] as int);
    }
    return total;
  }

  Future<void> _submitOrder() async {
    if (_cartList.isEmpty) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final itemsPayload = _cartList.map((e) => {
      'product_id': e['product']['id'],
      'quantity': e['quantity'],
      'selected_options': e['selected_options'],
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
          _cartList.clear();
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
            Text(_shopInfo?['name'] ?? auth.shopName ?? 'Hızlı ve Micro Sipariş', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
              isLabelVisible: _cartList.isNotEmpty,
              label: Text('${_cartList.length}'),
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

  // ==========================================
  // AKORDİYON / DİKEY MENÜ
  // ==========================================
  Widget _buildMenuTab() {
    final bool isAcceptingOrders = _shopInfo?['is_accepting_orders'] == true || _shopInfo?['is_accepting_orders'] == 1;
    final String closedReason = _shopInfo?['closed_reason'] ?? 'Dükkan şu anda sipariş alımına kapalıdır.';
    final String openingTime = _shopInfo?['opening_time'] ?? '08:00';
    final String closingTime = _shopInfo?['closing_time'] ?? '22:00';
    final bool autoHours = _shopInfo?['auto_hours_enabled'] == true || _shopInfo?['auto_hours_enabled'] == 1;

    if (_menu.isEmpty) {
      return const Center(child: Text('Dükkanın menüsünde henüz ürün bulunmuyor.', style: TextStyle(color: AppColors.textMuted)));
    }

    return Column(
      children: [
        // Mesai Saatleri Bilgi Kartı (Müşteriler için her zaman görünür)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAcceptingOrders ? AppColors.primary.withOpacity(0.3) : AppColors.danger.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time_filled, color: isAcceptingOrders ? AppColors.primary : AppColors.textMuted, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    autoHours ? 'Mesai Saatleri: $openingTime - $closingTime' : 'Çalışma Saatleri: $openingTime - $closingTime',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAcceptingOrders ? AppColors.success.withOpacity(0.15) : AppColors.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isAcceptingOrders ? AppColors.success : AppColors.danger, width: 0.8),
                ),
                child: Text(
                  isAcceptingOrders ? 'AÇIK' : 'KAPALI',
                  style: TextStyle(
                    color: isAcceptingOrders ? AppColors.success : AppColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Dükkan Kapalı veya Mesai Dışı Bilgilendirme Banner'ı
        if (!isAcceptingOrders)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.danger.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.do_not_disturb_on, color: AppColors.danger, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DÜKKAN SİPARİŞE KAPALI',
                        style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        closedReason,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _menu.length,
            itemBuilder: (ctx, i) {
              final category = _menu[i];
              final products = category['products'] as List<dynamic>? ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: i == 0,
                    iconColor: AppColors.primary,
                    collapsedIconColor: AppColors.textMuted,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary, size: 22),
                    ),
                    title: Text(
                      category['category_name'],
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${products.length} Çeşit Ürün',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                    children: products.map((p) {
                      final hasImage = p['image_url'] != null && p['image_url'].toString().trim().isNotEmpty;
                      final hasDesc = p['description'] != null && p['description'].toString().trim().isNotEmpty;
                      final hasOptions = p['options'] != null && (p['options'] as List).isNotEmpty;

                      return Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Ürün Adı (En Üstte)
                            Text(
                              p['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (hasDesc) ...[
                              const SizedBox(height: 4),
                              Text(
                                p['description'],
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.3),
                              ),
                            ],

                            // 2. Büyük Ürün Görseli (İsmin Altında)
                            if (hasImage) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  p['image_url'],
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // 3. Alt Kısım: Fiyat ve Sepete Ekle Butonu
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₺${p['price']}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: isAcceptingOrders
                                      ? () => _openAddToCartDialog(p)
                                      : () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(closedReason),
                                              backgroundColor: AppColors.danger,
                                            ),
                                          );
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isAcceptingOrders ? AppColors.primary : Colors.grey.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 2,
                                  ),
                                  icon: Icon(isAcceptingOrders ? (hasOptions ? Icons.tune : Icons.add_shopping_cart) : Icons.lock_outline, size: 18),
                                  label: Text(
                                    !isAcceptingOrders
                                        ? 'Kapalı'
                                        : (hasOptions ? 'Seç ve Ekle' : 'Sepete Ekle'),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartTab() {
    if (_cartList.isEmpty) {
      return const Center(
        child: Text('Sepetiniz boş. Menüden dilediğiniz ürünleri ekleyin!', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._cartList.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final p = item['product'];
            final opts = item['selected_options'];

            return Card(
              color: AppColors.cardBg,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                title: Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (opts != null && opts.toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Seçenek: $opts', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 2),
                    Text('Birim Tutar: ₺${p['price']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _removeFromCart(idx),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          TextField(
            controller: _orderNotesController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Sipariş Notu (Örn: Kat 3 Muhasebe)',
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
                Text('Toplam (${_cartList.length} Ürün):', style: const TextStyle(fontSize: 16, color: AppColors.textMuted)),
                Text('₺${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Builder(
            builder: (ctx) {
              final bool isAcceptingOrders = _shopInfo?['is_accepting_orders'] == true || _shopInfo?['is_accepting_orders'] == 1;
              final String closedReason = _shopInfo?['closed_reason'] ?? 'Dükkan şu anda sipariş alımına kapalıdır.';

              return SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAcceptingOrders ? AppColors.primary : Colors.grey.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isAcceptingOrders
                      ? _submitOrder
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(closedReason),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        },
                  child: Text(
                    isAcceptingOrders ? 'Siparişi Tamamla & Gönder' : 'Dükkan Kapalı (Sipariş Verilemez)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              );
            },
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
                    Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (ord['is_paid'] == 1 || ord['is_paid'] == true)
                                ? AppColors.success.withOpacity(0.15)
                                : AppColors.warning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (ord['is_paid'] == 1 || ord['is_paid'] == true) ? AppColors.success : AppColors.warning,
                            ),
                          ),
                          child: Text(
                            (ord['is_paid'] == 1 || ord['is_paid'] == true) ? 'ÖDENDİ' : 'ÖDENMEDİ',
                            style: TextStyle(
                              color: (ord['is_paid'] == 1 || ord['is_paid'] == true) ? AppColors.success : AppColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildStatusChip(ord['status']),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Tarih: ${ord['created_at']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const Divider(color: Colors.white12, height: 16),
                ...items.map((it) {
                  final hasOpts = it['selected_options'] != null && it['selected_options'].toString().trim().isNotEmpty;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ${it['quantity']}x ${it['product_name']} (₺${it['unit_price']})', style: const TextStyle(color: Colors.white70)),
                        if (hasOpts) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text('Seçenek: ${it['selected_options']}', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontStyle: FontStyle.italic)),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
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
