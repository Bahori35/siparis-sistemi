import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../constants.dart';
import '../login_screen.dart';

class ShopDashboardScreen extends StatefulWidget {
  const ShopDashboardScreen({super.key});

  @override
  State<ShopDashboardScreen> createState() => _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends State<ShopDashboardScreen> {
  int _currentTab = 0; // 0: Siparişler, 1: Ürünler, 2: Kategoriler, 3: Müşteriler
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

  // ==========================================
  // KATEGORİ YÖNETİMİ (EKLE, DÜZENLE, SİL)
  // ==========================================
  void _openAddCategoryDialog({Map<String, dynamic>? editCategory}) {
    final nameCtrl = TextEditingController(text: editCategory?['name'] ?? '');
    final sortCtrl = TextEditingController(text: editCategory?['sort_order']?.toString() ?? '0');
    final isEditing = editCategory != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text(isEditing ? 'Kategori Düzenle' : 'Yeni Kategori Ekle', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Kategori Adı (Örn: Çorbalar, Tatlılar)',
                labelStyle: TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sortCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Sıralama Sırası (0, 1, 2...)',
                labelStyle: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final auth = Provider.of<AuthService>(context, listen: false);
              final headers = {
                'Authorization': 'Bearer ${auth.token}',
                'Content-Type': 'application/json'
              };

              if (isEditing) {
                // Güncelleme
                await http.put(
                  Uri.parse(ApiConfig.shopCategories),
                  headers: headers,
                  body: jsonEncode({
                    'id': editCategory['id'],
                    'name': name,
                    'sort_order': int.tryParse(sortCtrl.text) ?? 0,
                  }),
                );
              } else {
                // Yeni Ekleme
                await http.post(
                  Uri.parse(ApiConfig.shopCategories),
                  headers: headers,
                  body: jsonEncode({
                    'name': name,
                    'sort_order': int.tryParse(sortCtrl.text) ?? 0,
                  }),
                );
              }

              if (!context.mounted) return;
              Navigator.pop(ctx);
              _loadAllData();
            },
            child: Text(
              isEditing ? 'Güncelle' : 'Kaydet',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(int categoryId, String categoryName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Kategoriyi Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '"$categoryName" kategorisini ve bu kategoriye bağlı tüm ürünleri silmek istediğinize emin misiniz?',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final auth = Provider.of<AuthService>(context, listen: false);
      try {
        await http.delete(
          Uri.parse('${ApiConfig.shopCategories}?id=$categoryId'),
          headers: {
            'Authorization': 'Bearer ${auth.token}',
            'Content-Type': 'application/json'
          },
        );
        _loadAllData();
      } catch (e) {
        debugPrint('Kategori silme hatası: $e');
      }
    }
  }

  // =========================================================================
  // SEÇENEK YÖNETİMİ (ÖZEL PENCERE: Ürün Seç -> Başlık Yaz -> + Butonuyla Madde Ekle)
  // =========================================================================
  void _openAddOptionToProductDialog({Map<String, dynamic>? preselectedProduct}) {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce menüye en az 1 ürün ekleyin!')),
      );
      return;
    }

    int selectedProductId = preselectedProduct != null ? preselectedProduct['id'] : _products.first['id'];
    
    // Seçili ürünün mevcut seçenek listesini parse et
    List<Map<String, dynamic>> currentGroups = [];
    void parseExistingGroups(int prodId) {
      currentGroups.clear();
      final p = _products.firstWhere((item) => item['id'] == prodId, orElse: () => null);
      if (p != null && p['options_json'] != null) {
        try {
          final decoded = jsonDecode(p['options_json']);
          if (decoded is List) {
            for (var g in decoded) {
              currentGroups.add({
                'title': g['title'] ?? 'Seçenek',
                'items': List<String>.from((g['items'] as List?)?.map((e) => e.toString()) ?? []),
              });
            }
          }
        } catch (_) {}
      }
    }

    parseExistingGroups(selectedProductId);

    final groupTitleCtrl = TextEditingController();
    final itemCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: AppColors.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.tune, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text('Ürün Seçenekleri Yönetimi', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Ürün Seçimi
                    const Text('1. Seçenek Eklenecek Ürün:', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: selectedProductId,
                      dropdownColor: AppColors.cardBg,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.background.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _products.map<DropdownMenuItem<int>>((p) => DropdownMenuItem(
                        value: p['id'] as int,
                        child: Text('${p['name']} (₺${p['price']})', overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedProductId = val;
                            parseExistingGroups(selectedProductId);
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),

                    // 2. Mevcut Seçenek Grupları Listesi
                    Text('Mevcut Seçenek Grupları (${currentGroups.length}):', style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    if (currentGroups.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Bu ürüne henüz seçenek eklenmemiş. Aşağıdan yeni seçenek grubu ve seçenek maddeleri ekleyebilirsiniz.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ),

                    ...currentGroups.asMap().entries.map((entry) {
                      final gIdx = entry.key;
                      final g = entry.value;
                      final items = g['items'] as List<String>;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  g['title'],
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                                  onPressed: () {
                                    setModalState(() {
                                      currentGroups.removeAt(gIdx);
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: items.asMap().entries.map((itemEntry) {
                                final iIdx = itemEntry.key;
                                final itemTxt = itemEntry.value;
                                return Chip(
                                  backgroundColor: AppColors.cardBg,
                                  label: Text(itemTxt, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.danger),
                                  onDeleted: () {
                                    setModalState(() {
                                      items.removeAt(iIdx);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12),

                    // 3. Yeni Seçenek Grubu & Madde Ekleme Formu
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '2. Yeni Seçenek Başlığı Belirleyin:',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Örn: "Şeker Durumu", "Sos Tercihi", "Ekmek Seçimi"',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: groupTitleCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Seçenek Başlığı (Örn: Şeker)',
                              labelStyle: const TextStyle(color: AppColors.accent, fontSize: 12),
                              hintText: 'Şeker, Sos vb.',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                              filled: true,
                              fillColor: AppColors.cardBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Seçenek Maddelerini + ile Ekleyin:',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Örn: "Sade" yazıp + ya basın, "Orta" yazıp + ya basın...',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: itemCtrl,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'Seçenek (Örn: Sade / Orta / Şekerli)',
                                    labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                    filled: true,
                                    fillColor: AppColors.cardBg,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  onSubmitted: (_) {
                                    final title = groupTitleCtrl.text.trim();
                                    final item = itemCtrl.text.trim();
                                    if (title.isNotEmpty && item.isNotEmpty) {
                                      setModalState(() {
                                        var existing = currentGroups.firstWhere((g) => g['title'].toString().toLowerCase() == title.toLowerCase(), orElse: () => {});
                                        if (existing.isNotEmpty) {
                                          (existing['items'] as List<String>).add(item);
                                        } else {
                                          currentGroups.add({
                                            'title': title,
                                            'items': <String>[item],
                                          });
                                        }
                                        itemCtrl.clear();
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  final title = groupTitleCtrl.text.trim();
                                  final item = itemCtrl.text.trim();
                                  if (title.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Lütfen önce Seçenek Başlığı girin (Örn: Şeker)!'), backgroundColor: AppColors.warning),
                                    );
                                    return;
                                  }
                                  if (item.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Lütfen eklenecek seçeneği yazın (Örn: Sade)!'), backgroundColor: AppColors.warning),
                                    );
                                    return;
                                  }
                                  setModalState(() {
                                    var existing = currentGroups.firstWhere(
                                      (g) => g['title'].toString().toLowerCase() == title.toLowerCase(),
                                      orElse: () => {},
                                    );
                                    if (existing.isNotEmpty) {
                                      (existing['items'] as List<String>).add(item);
                                    } else {
                                      currentGroups.add({
                                        'title': title,
                                        'items': <String>[item],
                                      });
                                    }
                                    itemCtrl.clear();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                                label: const Text('Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final auth = Provider.of<AuthService>(context, listen: false);
                  final selectedProd = _products.firstWhere((p) => p['id'] == selectedProductId);

                  // Ürünü yeni options_json ile güncelle
                  await http.put(
                    Uri.parse(ApiConfig.shopProducts),
                    headers: {
                      'Authorization': 'Bearer ${auth.token}',
                      'Content-Type': 'application/json'
                    },
                    body: jsonEncode({
                      'id': selectedProductId,
                      'category_id': selectedProd['category_id'],
                      'name': selectedProd['name'],
                      'price': selectedProd['price'],
                      'image_url': selectedProd['image_url'],
                      'description': selectedProd['description'],
                      'is_available': selectedProd['is_available'] ?? 1,
                      'options_json': currentGroups.isNotEmpty ? currentGroups : null,
                    }),
                  );

                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  _loadAllData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Seçenekler ürüne başarıyla kaydedildi!'), backgroundColor: AppColors.success),
                  );
                },
                icon: const Icon(Icons.save, color: Colors.white, size: 18),
                label: const Text('Kaydet ve Uygula', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // ÜRÜN YÖNETİMİ (EKLE, DÜZENLE, SİL)
  // ==========================================
  void _openAddProductDialog({Map<String, dynamic>? editProduct}) {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce en az 1 kategori ekleyin!')),
      );
      return;
    }

    final isEditing = editProduct != null;
    final nameCtrl = TextEditingController(text: editProduct?['name'] ?? '');
    final descCtrl = TextEditingController(text: editProduct?['description'] ?? '');
    final priceCtrl = TextEditingController(text: editProduct?['price']?.toString() ?? '');
    final imgCtrl = TextEditingController(text: editProduct?['image_url'] ?? '');

    int selectedCatId = editProduct != null ? editProduct['category_id'] : _categories.first['id'];
    bool isUploadingImage = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickAndUploadImage() async {
            try {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 1024,
                maxHeight: 1024,
                imageQuality: 85,
              );

              if (pickedFile == null) return;

              setDialogState(() => isUploadingImage = true);

              final auth = Provider.of<AuthService>(context, listen: false);
              final bytes = await pickedFile.readAsBytes();
              final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

              final res = await http.post(
                Uri.parse(ApiConfig.shopUpload),
                headers: {
                  'Authorization': 'Bearer ${auth.token}',
                  'Content-Type': 'application/json'
                },
                body: jsonEncode({'image_base64': base64Image}),
              );

              final data = jsonDecode(res.body);
              if (res.statusCode == 200 && data['success'] == true) {
                final uploadedUrl = data['data']['image_url'];
                setDialogState(() {
                  imgCtrl.text = uploadedUrl;
                  isUploadingImage = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fotoğraf başarıyla yüklendi!'), backgroundColor: AppColors.success),
                );
              } else {
                setDialogState(() => isUploadingImage = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(data['message'] ?? 'Fotoğraf yüklenemedi.'), backgroundColor: AppColors.danger),
                );
              }
            } catch (e) {
              setDialogState(() => isUploadingImage = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fotoğraf seçme hatası: $e'), backgroundColor: AppColors.danger),
              );
            }
          }

          return AlertDialog(
            backgroundColor: AppColors.cardBg,
            title: Text(isEditing ? 'Ürün Düzenle' : 'Yeni Ürün Ekle', style: const TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    decoration: const InputDecoration(labelText: 'Ürün Adı *', labelStyle: TextStyle(color: AppColors.textMuted)),
                  ),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Fiyat (TL) *', labelStyle: TextStyle(color: AppColors.textMuted)),
                  ),
                  const SizedBox(height: 12),
                  // Galeri Yükleme Butonu & Link Kutusu
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: imgCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Görsel Linki / URL',
                            hintText: 'https://...',
                            hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
                            labelStyle: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isUploadingImage ? null : pickAndUploadImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: isUploadingImage
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.photo_library, size: 18),
                        label: Text(isUploadingImage ? '...' : 'Galeri', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (imgCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imgCtrl.text,
                        height: 90,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
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
                  final headers = {
                    'Authorization': 'Bearer ${auth.token}',
                    'Content-Type': 'application/json'
                  };

                  if (isEditing) {
                    await http.put(
                      Uri.parse(ApiConfig.shopProducts),
                      headers: headers,
                      body: jsonEncode({
                        'id': editProduct['id'],
                        'category_id': selectedCatId,
                        'name': nameCtrl.text.trim(),
                        'price': double.tryParse(priceCtrl.text) ?? 0.0,
                        'image_url': imgCtrl.text.trim(),
                        'options_json': editProduct['options_json'],
                        'description': descCtrl.text.trim(),
                        'is_available': editProduct['is_available'] ?? 1,
                      }),
                    );
                  } else {
                    await http.post(
                      Uri.parse(ApiConfig.shopProducts),
                      headers: headers,
                      body: jsonEncode({
                        'category_id': selectedCatId,
                        'name': nameCtrl.text.trim(),
                        'price': double.tryParse(priceCtrl.text) ?? 0.0,
                        'image_url': imgCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                      }),
                    );
                  }

                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  _loadAllData();
                },
                child: Text(
                  isEditing ? 'Güncelle' : 'Ürünü Ekle',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteProduct(int productId, String productName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Ürünü Sil', style: TextStyle(color: Colors.white)),
        content: Text('"$productName" ürününü silmek istediğinize emin misiniz?', style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final auth = Provider.of<AuthService>(context, listen: false);
      try {
        final res = await http.delete(
          Uri.parse('${ApiConfig.shopProducts}?id=$productId'),
          headers: {
            'Authorization': 'Bearer ${auth.token}',
            'Content-Type': 'application/json'
          },
        );

        final data = jsonDecode(res.body);
        if (res.statusCode == 200 && data['success'] == true) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$productName" başarıyla silindi.'), backgroundColor: AppColors.success),
          );
          _loadAllData();
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Ürün silinemedi.'), backgroundColor: AppColors.danger),
          );
        }
      } catch (e) {
        debugPrint('Ürün silme hatası: $e');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
        );
      }
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
              await http.post(
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
              if (!context.mounted) return;
              Navigator.pop(ctx);
              _loadAllData();
            },
            child: const Text('Müşteriyi Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentTab = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Siparişler'),
          BottomNavigationBarItem(icon: Icon(Icons.fastfood), label: 'Ürünler'),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Seçenekler'),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Kategoriler'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Müşteriler'),
        ],
      ),
      floatingActionButton: _getFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Widget? _getFab() {
    if (_currentTab == 1) {
      return FloatingActionButton.extended(
        onPressed: () => _openAddProductDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ürün Ekle', style: TextStyle(color: Colors.white)),
      );
    }
    if (_currentTab == 2) {
      return FloatingActionButton.extended(
        onPressed: () => _openAddOptionToProductDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Seçenek Ekle', style: TextStyle(color: Colors.white)),
      );
    }
    if (_currentTab == 3) {
      return FloatingActionButton.extended(
        onPressed: () => _openAddCategoryDialog(),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Kategori Ekle', style: TextStyle(color: Colors.white)),
      );
    }
    if (_currentTab == 4) {
      return FloatingActionButton.extended(
        onPressed: _openAddCustomerDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Müşteri Ekle', style: TextStyle(color: Colors.white)),
      );
    }
    return null;
  }

  Widget _buildCurrentTab() {
    if (_currentTab == 0) return _buildOrdersTab();
    if (_currentTab == 1) return _buildProductsTab();
    if (_currentTab == 2) return _buildOptionsTab();
    if (_currentTab == 3) return _buildCategoriesTab();
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                ...items.map((it) {
                  final hasOpts = it['selected_options'] != null && it['selected_options'].toString().trim().isNotEmpty;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ${it['quantity']}x ${it['product_name']} (₺${it['unit_price']})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        if (hasOpts) ...[
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              'Seçenekler: ${it['selected_options']}',
                              style: const TextStyle(color: AppColors.accent, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Text('Toplam: ₺${ord['total_price']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    if (ord['status'] == 'PENDING')
                      ElevatedButton(onPressed: () => _updateOrderStatus(ord['id'], 'ACCEPTED'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), child: const Text('Onayla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    if (ord['status'] == 'ACCEPTED')
                      ElevatedButton(onPressed: () => _updateOrderStatus(ord['id'], 'PREPARING'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning), child: const Text('Hazırlanıyor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    if (ord['status'] == 'PREPARING')
                      ElevatedButton(onPressed: () => _updateOrderStatus(ord['id'], 'DELIVERED'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success), child: const Text('Teslim Edildi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
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
            leading: p['image_url'] != null && p['image_url'].toString().trim().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      p['image_url'],
                      width: 65,
                      height: 65,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.fastfood, color: AppColors.primary, size: 28),
                      ),
                    ),
                  )
                : Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fastfood, color: AppColors.primary, size: 28),
                  ),
            title: Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('${p['category_name'] ?? '-'} • ₺${p['price']}', style: const TextStyle(color: AppColors.textMuted)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                  onPressed: () => _openAddProductDialog(editProduct: p),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.danger, size: 20),
                  onPressed: () => _deleteProduct(p['id'], p['name']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionsTab() {
    if (_products.isEmpty) {
      return const Center(
        child: Text('Henüz ürün bulunmuyor. Önce Ürünler sekmesinden ürün ekleyin.', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (ctx, i) {
        final p = _products[i];
        List<dynamic> groups = [];
        if (p['options_json'] != null) {
          try {
            final decoded = jsonDecode(p['options_json']);
            if (decoded is List) groups = decoded;
          } catch (_) {}
        }

        return Card(
          color: AppColors.cardBg,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        p['name'],
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openAddOptionToProductDialog(preselectedProduct: p),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text('Seçenek Ekle / Düzenle', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (groups.isEmpty) ...[
                  const Text(
                    'Tanımlı seçenek bulunmuyor (Şeker, Sos vb. eklemek için butona dokunun).',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ] else ...[
                  ...groups.map((g) {
                    final title = g['title'] ?? 'Seçenek';
                    final items = (g['items'] as List?)?.map((e) => e.toString()).toList() ?? [];

                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$title:',
                              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: items.map((it) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.background.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(it, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              )).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab() {
    if (_categories.isEmpty) {
      return const Center(child: Text('Henüz kategori bulunmuyor. Kategori Ekle butonuyla ekleyebilirsiniz.', style: TextStyle(color: AppColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _categories.length,
      itemBuilder: (ctx, i) {
        final cat = _categories[i];
        return Card(
          color: AppColors.cardBg,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.accent,
              child: Icon(Icons.category, color: Colors.white, size: 20),
            ),
            title: Text(cat['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('Sıra: ${cat['sort_order'] ?? 0}', style: const TextStyle(color: AppColors.textMuted)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                  onPressed: () => _openAddCategoryDialog(editCategory: cat),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.danger, size: 20),
                  onPressed: () => _deleteCategory(cat['id'], cat['name']),
                ),
              ],
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
