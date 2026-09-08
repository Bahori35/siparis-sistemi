import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/app_localizations.dart';
import '../../constants.dart';
import '../login_screen.dart';

class ShopDashboardScreen extends StatefulWidget {
  const ShopDashboardScreen({super.key});

  @override
  State<ShopDashboardScreen> createState() => _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends State<ShopDashboardScreen> {
  int _currentTab = 0; // 0: Siparişler, 1: Ürünler, 2: Seçenekler, 3: Kategoriler, 4: Müşteriler, 5: Duyurular
  List<dynamic> _orders = [];
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  List<dynamic> _customers = [];
  List<dynamic> _announcements = [];
  Map<String, dynamic>? _shopSettings;
  bool _isLoading = false;
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData(showSpinner: true);
    // Her 2 saniyede bir yeni siparişleri ve duyuruları arkaplanda sessizce güncelle (Anlık / Realtime)
    _liveTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchLiveDataSilently();
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveDataSilently() async {
    if (!mounted) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) return;

    final headers = {
      'Authorization': 'Bearer ${auth.token}',
      'Content-Type': 'application/json'
    };

    try {
      // 1. Siparişler
      final ordRes = await http.get(Uri.parse(ApiConfig.shopOrders), headers: headers);
      if (ordRes.statusCode == 200 && mounted) {
        final newOrders = jsonDecode(ordRes.body)['data'] ?? [];
        if (jsonEncode(_orders) != jsonEncode(newOrders)) {
          setState(() {
            _orders = newOrders;
          });
        }
      }

      // 2. Duyurular
      final annRes = await http.get(Uri.parse(ApiConfig.shopAnnouncements), headers: headers);
      if (annRes.statusCode == 200 && mounted) {
        final newAnnouncements = jsonDecode(annRes.body)['data'] ?? [];
        if (jsonEncode(_announcements) != jsonEncode(newAnnouncements)) {
          setState(() {
            _announcements = newAnnouncements;
          });
        }
      }

      // 3. Dükkan Ayarları
      final settRes = await http.get(Uri.parse(ApiConfig.shopSettings), headers: headers);
      if (settRes.statusCode == 200 && mounted) {
        final newSett = jsonDecode(settRes.body)['data'] ?? {};
        if (jsonEncode(_shopSettings) != jsonEncode(newSett)) {
          setState(() {
            _shopSettings = newSett;
          });
        }
      }
    } catch (e) {
      // Sessiz polling hatası
    }
  }

  Future<void> _loadAllData({bool showSpinner = false}) async {
    if (showSpinner) {
      setState(() => _isLoading = true);
    }
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
      final annRes = await http.get(Uri.parse(ApiConfig.shopAnnouncements), headers: headers);
      final settRes = await http.get(Uri.parse(ApiConfig.shopSettings), headers: headers);

      if (mounted) {
        setState(() {
          if (ordRes.statusCode == 200) _orders = jsonDecode(ordRes.body)['data'] ?? [];
          if (prodRes.statusCode == 200) _products = jsonDecode(prodRes.body)['data'] ?? [];
          if (catRes.statusCode == 200) _categories = jsonDecode(catRes.body)['data'] ?? [];
          if (custRes.statusCode == 200) _customers = jsonDecode(custRes.body)['data'] ?? [];
          if (annRes.statusCode == 200) _announcements = jsonDecode(annRes.body)['data'] ?? [];
          if (settRes.statusCode == 200) _shopSettings = jsonDecode(settRes.body)['data'] ?? {};
        });
      }
    } catch (e) {
      debugPrint('Veri çekme hatası: $e');
    } finally {
      if (mounted && showSpinner) setState(() => _isLoading = false);
    }
  }

  // Dükkanı Aç / Kapat Toggle (Kapatırken Not Girişi ile)
  Future<void> _toggleShopOpenStatus() async {
    final currentStatus = _shopSettings?['is_open'] == 1 || _shopSettings?['is_open'] == true;
    final nextStatus = !currentStatus;

    String? closedNote;

    // Eğer dükkan kapatılıyorsa, dükkan sahibine müşterilerin göreceği bir not / açıklama sor
    if (!nextStatus) {
      final noteCtrl = TextEditingController(text: _shopSettings?['closed_note'] ?? '');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.storefront_outlined, color: AppColors.danger),
              const SizedBox(width: 8),
              Text('close_shop_dialog_title'.tr, style: const TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'close_shop_dialog_desc'.tr,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'close_shop_reason_label'.tr,
                  hintText: 'close_shop_reason_hint'.tr,
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel_btn'.tr, style: const TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('close_shop_confirm_btn'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      closedNote = noteCtrl.text.trim();
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final payload = <String, dynamic>{
        'is_open': nextStatus ? 1 : 0,
      };
      if (!nextStatus) {
        payload['closed_note'] = (closedNote != null && closedNote.isNotEmpty) ? closedNote : 'Dükkan şu anda geçici olarak siparişe kapalıdır.';
      }

      final res = await http.put(
        Uri.parse(ApiConfig.shopSettings),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        setState(() {
          _shopSettings = data;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nextStatus ? 'shop_opened_snack'.tr : 'shop_closed_snack'.tr),
            backgroundColor: nextStatus ? AppColors.success : AppColors.danger,
          ),
        );
      }
    } catch (e) {
      debugPrint('Dükkan durumu güncelleme hatası: $e');
    }
  }

  // Mesai Saatleri Ayarlama Penceresi
  void _openWorkHoursDialog() {
    String openTime = _shopSettings?['opening_time'] ?? '08:00';
    String closeTime = _shopSettings?['closing_time'] ?? '22:00';
    bool autoHours = (_shopSettings?['auto_hours_enabled'] == 1 || _shopSettings?['auto_hours_enabled'] == true);

    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0);
    }

    String formatTime(TimeOfDay tod) {
      final h = tod.hour.toString().padLeft(2, '0');
      final m = tod.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    TimeOfDay selectedOpen = parseTime(openTime);
    TimeOfDay selectedClose = parseTime(closeTime);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.access_time_filled, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('work_hours_dialog_title'.tr, style: const TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                title: Text('apply_work_hours'.tr, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text('apply_work_hours_desc'.tr, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                value: autoHours,
                onChanged: (val) {
                  setDialogState(() => autoHours = val);
                },
              ),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${'opening_time'.tr}:', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.wb_sunny_outlined, size: 16, color: AppColors.primary),
                    label: Text(formatTime(selectedOpen), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedOpen,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedOpen = picked);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${'closing_time'.tr}:', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.nights_stay_outlined, size: 16, color: AppColors.primary),
                    label: Text(formatTime(selectedClose), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedClose,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedClose = picked);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final auth = Provider.of<AuthService>(context, listen: false);
                final finalOpen = formatTime(selectedOpen);
                final finalClose = formatTime(selectedClose);

                final res = await http.put(
                  Uri.parse(ApiConfig.shopSettings),
                  headers: {
                    'Authorization': 'Bearer ${auth.token}',
                    'Content-Type': 'application/json'
                  },
                  body: jsonEncode({
                    'opening_time': finalOpen,
                    'closing_time': finalClose,
                    'auto_hours_enabled': autoHours ? 1 : 0,
                  }),
                );

                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body)['data'];
                  setState(() {
                    _shopSettings = data;
                  });
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('work_hours_saved_success'.tr), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
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
        title: Text(isEditing ? 'edit_category'.tr : 'add_category'.tr, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'category_name_hint'.tr,
                labelStyle: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sortCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'category_order_label'.tr,
                labelStyle: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel_btn'.tr)),
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
              isEditing ? 'update_btn'.tr : 'save_btn'.tr,
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
        title: Text('delete_category_title'.tr, style: const TextStyle(color: Colors.white)),
        content: Text(
          '"$categoryName" ${'delete_category_confirm'.tr}',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('cancel_btn'.tr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('yes_delete'.tr),
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
        SnackBar(content: Text('add_first_product_warn'.tr)),
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
              children: [
                const Icon(Icons.tune, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text('manage_options'.tr, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
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
                    Text('select_product_option_step'.tr, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
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
                    Text('${'existing_option_groups'.tr} (${currentGroups.length}):', style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    if (currentGroups.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'no_options_yet'.tr,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                          Text(
                            'option_title_step'.tr,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'option_title_subhint'.tr,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: groupTitleCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'option_title_field'.tr,
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
                          Text(
                            'option_items_step'.tr,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'option_items_subhint'.tr,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: itemCtrl,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'option_item_field'.tr,
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
                                      SnackBar(content: Text('enter_option_title_warn'.tr), backgroundColor: AppColors.warning),
                                    );
                                    return;
                                  }
                                  if (item.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('enter_option_item_warn'.tr), backgroundColor: AppColors.warning),
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
                                label: Text('add_item_btn'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                child: Text('close_btn'.tr, style: const TextStyle(color: AppColors.textMuted)),
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
                    SnackBar(content: Text('options_saved_success'.tr), backgroundColor: AppColors.success),
                  );
                },
                icon: const Icon(Icons.save, color: Colors.white, size: 18),
                label: Text('save_and_apply_btn'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        SnackBar(content: Text('add_first_category_warn'.tr)),
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
                  SnackBar(content: Text('photo_uploaded_success'.tr), backgroundColor: AppColors.success),
                );
              } else {
                setDialogState(() => isUploadingImage = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(data['message'] ?? 'photo_upload_failed'.tr), backgroundColor: AppColors.danger),
                );
              }
            } catch (e) {
              setDialogState(() => isUploadingImage = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${'photo_pick_error'.tr}: $e'), backgroundColor: AppColors.danger),
              );
            }
          }

          return AlertDialog(
            backgroundColor: AppColors.cardBg,
            title: Text(isEditing ? 'edit_product'.tr : 'add_product'.tr, style: const TextStyle(color: Colors.white)),
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
                    decoration: InputDecoration(labelText: 'category_select'.tr, labelStyle: const TextStyle(color: AppColors.textMuted)),
                  ),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'product_name_req'.tr, labelStyle: const TextStyle(color: AppColors.textMuted)),
                  ),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'product_price_req'.tr, labelStyle: const TextStyle(color: AppColors.textMuted)),
                  ),
                  const SizedBox(height: 12),
                  // Galeri Yükleme Butonu & Link Kutusu
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: imgCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'product_img'.tr,
                            hintText: 'https://...',
                            hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                            labelStyle: const TextStyle(color: AppColors.textMuted),
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
                        label: Text(isUploadingImage ? '...' : 'gallery_btn'.tr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                    decoration: InputDecoration(labelText: 'product_desc_opt'.tr, labelStyle: const TextStyle(color: AppColors.textMuted)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel_btn'.tr)),
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
                  isEditing ? 'update_btn'.tr : 'add_product_btn'.tr,
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
        title: Text('delete_product_title'.tr, style: const TextStyle(color: Colors.white)),
        content: Text('"$productName" ${'delete_product_confirm'.tr}', style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('cancel_btn'.tr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('yes_delete'.tr),
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
            SnackBar(content: Text('"$productName" ${'product_deleted_success'.tr}'), backgroundColor: AppColors.success),
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

  // Siparişin Ödeme Durumunu Değiştir (Ödendi / Ödenmedi)
  Future<void> _toggleOrderPaymentStatus(int orderId, bool currentIsPaid) async {
    final nextPaid = !currentIsPaid;
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final res = await http.put(
        Uri.parse(ApiConfig.shopOrders),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'order_id': orderId, 'is_paid': nextPaid ? 1 : 0}),
      );
      if (res.statusCode == 200) {
        _loadAllData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nextPaid ? 'order_marked_paid'.tr : 'order_marked_unpaid'.tr),
            backgroundColor: nextPaid ? AppColors.success : AppColors.warning,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Ödeme durumu güncelleme hatası: $e');
    }
  }

  // Bir müşterinin tüm açık hesap borçlarını tek tıkla "Ödendi" yapma
  Future<void> _markCustomerAllPaid(int customerId, String customerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text('settle_all_account_title'.tr, style: const TextStyle(color: Colors.white)),
        content: Text(
          '"$customerName" ${'settle_all_account_confirm'.tr}',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('cancel_btn'.tr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('settle_all_account_confirm_btn'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final auth = Provider.of<AuthService>(context, listen: false);
      try {
        final res = await http.put(
          Uri.parse(ApiConfig.shopOrders),
          headers: {
            'Authorization': 'Bearer ${auth.token}',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({'bulk_customer_id': customerId, 'is_paid': 1}),
        );
        if (res.statusCode == 200) {
          _loadAllData();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$customerName" ${'customer_all_settled_success'.tr}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        debugPrint('Toplu ödeme hatası: $e');
      }
    }
  }

  // Müşterinin Ayrıntılı Sipariş & Hesap Geçmişi Penceresi (Günlük / Haftalık / Aylık & Ödendi / Ödenmedi)
  void _openCustomerOrderHistoryDialog(Map<String, dynamic> customer) {
    int selectedPeriod = 0; // 0: Tümü, 1: Bugün (Günlük), 2: Son 7 Gün (Haftalık), 3: Son 30 Gün (Aylık)
    int selectedPayFilter = 0; // 0: Tümü, 1: Ödenmemişler (Açık Hesap), 2: Ödenenler (Kapatılanlar)

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final customerId = customer['id'];
          final now = DateTime.now();

          // Müşteriye ait siparişleri filtrele
          final customerOrders = _orders.where((o) => o['customer_id'] == customerId).toList();

          final filteredOrders = customerOrders.where((ord) {
            final isPaid = (ord['is_paid'] == 1 || ord['is_paid'] == true);
            final isCancelled = (ord['status'] == 'CANCELLED');

            if (selectedPayFilter == 1) {
              if (isPaid || isCancelled) return false;
            } else if (selectedPayFilter == 2) {
              if (!isPaid || isCancelled) return false;
            } else if (selectedPayFilter == 3) {
              if (!isCancelled) return false;
            }

            if (selectedPeriod > 0) {
              DateTime? orderDate = DateTime.tryParse(ord['created_at'] ?? '');
              if (orderDate != null) {
                if (selectedPeriod == 1) {
                  // Günlük
                  if (orderDate.year != now.year || orderDate.month != now.month || orderDate.day != now.day) {
                    return false;
                  }
                } else if (selectedPeriod == 2) {
                  // Haftalık
                  if (now.difference(orderDate).inDays > 7) {
                    return false;
                  }
                } else if (selectedPeriod == 3) {
                  // Aylık
                  if (now.difference(orderDate).inDays > 30) {
                    return false;
                  }
                }
              }
            }
            return true;
          }).toList();

          // Toplam Borç (Ödenmemişler) ve Toplam Ödenen Tutar Hesapla
          // İptal edilen siparişler borca veya ödenen tutara dahil edilmez!
          double unpaidTotal = 0;
          double paidTotal = 0;
          for (var o in customerOrders) {
            if (o['status'] == 'CANCELLED') continue;
            final amt = double.tryParse(o['total_price']?.toString() ?? '0') ?? 0;
            final isPaid = (o['is_paid'] == 1 || o['is_paid'] == true);
            if (isPaid) {
              paidTotal += amt;
            } else {
              unpaidTotal += amt;
            }
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık & Kapatma Butonu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer['full_name'] ?? 'customer_orders_history'.tr,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            '${'user_label'.tr}: @${customer['username']} • ${'phone_short'.tr}: ${customer['phone'] ?? '-'}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    )
                  ],
                ),
                const SizedBox(height: 12),

                // Hesap Özeti Kartı (Ödenmemiş Borç & Ödenen Tutar)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${'unpaid_balance'.tr}:', style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('₺${unpaidTotal.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.warning, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(height: 35, width: 1, color: Colors.white12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${'total_paid'.tr}:', style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('₺${paidTotal.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (unpaidTotal > 0)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _markCustomerAllPaid(customerId, customer['full_name']);
                          },
                          child: Text('close_account_btn'.tr, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 1. ZAMAN FİLTRESİ (Tümü / Günlük / Haftalık / Aylık)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text('${'period'.tr}: ', style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: Text('period_all'.tr),
                        selected: selectedPeriod == 0,
                        selectedColor: AppColors.primary,
                        onSelected: (v) => setModalState(() => selectedPeriod = 0),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('period_daily'.tr),
                        selected: selectedPeriod == 1,
                        selectedColor: AppColors.primary,
                        onSelected: (v) => setModalState(() => selectedPeriod = 1),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('period_weekly'.tr),
                        selected: selectedPeriod == 2,
                        selectedColor: AppColors.primary,
                        onSelected: (v) => setModalState(() => selectedPeriod = 2),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('period_monthly'.tr),
                        selected: selectedPeriod == 3,
                        selectedColor: AppColors.primary,
                        onSelected: (v) => setModalState(() => selectedPeriod = 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // 2. ÖDEME DURUMU FİLTRESİ (Tümü / Ödenmemişler / Ödenenler)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text('${'payment_status'.tr}: ', style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: Text('pay_all'.tr),
                        selected: selectedPayFilter == 0,
                        selectedColor: AppColors.accent,
                        onSelected: (v) => setModalState(() => selectedPayFilter = 0),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('pay_unpaid'.tr),
                        selected: selectedPayFilter == 1,
                        selectedColor: AppColors.warning,
                        onSelected: (v) => setModalState(() => selectedPayFilter = 1),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('pay_paid'.tr),
                        selected: selectedPayFilter == 2,
                        selectedColor: AppColors.success,
                        onSelected: (v) => setModalState(() => selectedPayFilter = 2),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('pay_cancelled'.tr),
                        selected: selectedPayFilter == 3,
                        selectedColor: AppColors.danger,
                        onSelected: (v) => setModalState(() => selectedPayFilter = 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.white12),

                // SİPARİŞ LİSTESİ
                Expanded(
                  child: filteredOrders.isEmpty
                      ? Center(
                          child: Text('no_filtered_records'.tr, style: const TextStyle(color: AppColors.textMuted)),
                        )
                      : ListView.builder(
                          itemCount: filteredOrders.length,
                          itemBuilder: (ctx, idx) {
                            final ord = filteredOrders[idx];
                            final items = ord['items'] as List<dynamic>? ?? [];
                            final isPaid = (ord['is_paid'] == 1 || ord['is_paid'] == true);

                            return Card(
                              color: AppColors.background.withOpacity(0.9),
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isPaid ? AppColors.success.withOpacity(0.3) : AppColors.warning.withOpacity(0.4),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${'order_number'.tr} #${ord['id']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                                        // Ödeme Durumu Rozeti & Toggle Butonu
                                        InkWell(
                                          onTap: () async {
                                            await _toggleOrderPaymentStatus(ord['id'], isPaid);
                                            setModalState(() {});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isPaid ? AppColors.success.withOpacity(0.15) : AppColors.warning.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: isPaid ? AppColors.success : AppColors.warning),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(isPaid ? Icons.check_circle : Icons.hourglass_top, color: isPaid ? AppColors.success : AppColors.warning, size: 14),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isPaid ? 'status_paid'.tr : 'status_unpaid'.tr,
                                                  style: TextStyle(color: isPaid ? AppColors.success : AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${'date'.tr}: ${ord['created_at']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    if (ord['notes'] != null && ord['notes'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text('${'order_note_label'.tr}: "${ord['notes']}"', style: const TextStyle(color: AppColors.warning, fontSize: 12, fontStyle: FontStyle.italic)),
                                    ],
                                    const Divider(color: Colors.white10, height: 12),
                                    ...items.map((it) => Padding(
                                          padding: const EdgeInsets.only(bottom: 2),
                                          child: Text(
                                            '• ${it['quantity']}x ${it['product_name']} (₺${it['unit_price']}) ${it['selected_options'] != null ? "[${it['selected_options']}]" : ""}',
                                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          ),
                                        )),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${'total_amount'.tr}: ₺${ord['total_price']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success)),
                                        _buildStatusChip(ord['status']),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openAddCustomerDialog({Map<String, dynamic>? editCustomer}) {
    final isEditing = editCustomer != null;
    final userCtrl = TextEditingController(text: editCustomer?['username'] ?? '');
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: editCustomer?['full_name'] ?? '');
    final phoneCtrl = TextEditingController(text: editCustomer?['phone'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text(isEditing ? 'edit_customer'.tr : 'add_customer'.tr, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: 'customer_name_req'.tr, labelStyle: const TextStyle(color: AppColors.textMuted)),
              ),
              TextField(
                controller: phoneCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: 'customer_phone'.tr, labelStyle: const TextStyle(color: AppColors.textMuted)),
              ),
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: 'customer_username_req'.tr, labelStyle: const TextStyle(color: AppColors.textMuted)),
              ),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: isEditing ? 'customer_password_edit_hint'.tr : 'customer_password_req'.tr,
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel_btn'.tr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final auth = Provider.of<AuthService>(context, listen: false);
              final headers = {
                'Authorization': 'Bearer ${auth.token}',
                'Content-Type': 'application/json'
              };

              http.Response res;
              if (isEditing) {
                res = await http.put(
                  Uri.parse(ApiConfig.shopCustomers),
                  headers: headers,
                  body: jsonEncode({
                    'id': editCustomer['id'],
                    'full_name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'username': userCtrl.text.trim(),
                    'password': passCtrl.text.trim(),
                  }),
                );
              } else {
                res = await http.post(
                  Uri.parse(ApiConfig.shopCustomers),
                  headers: headers,
                  body: jsonEncode({
                    'full_name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'username': userCtrl.text.trim(),
                    'password': passCtrl.text.trim(),
                  }),
                );
              }

              final data = jsonDecode(res.body);
              if (res.statusCode == 200 || res.statusCode == 201) {
                if (!context.mounted) return;
                Navigator.pop(ctx);
                _loadAllData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEditing ? 'customer_updated_success'.tr : 'customer_created_success'.tr),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(data['message'] ?? 'operation_failed'.tr), backgroundColor: AppColors.danger),
                );
              }
            },
            child: Text(
              isEditing ? 'update_btn'.tr : 'customer_save_btn'.tr,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteCustomer(int customerId, String customerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text('delete_customer_title'.tr, style: const TextStyle(color: Colors.white)),
        content: Text('"$customerName" ${'delete_customer_confirm'.tr}', style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('cancel_btn'.tr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final auth = Provider.of<AuthService>(context, listen: false);
      try {
        final res = await http.delete(
          Uri.parse('${ApiConfig.shopCustomers}?id=$customerId'),
          headers: {
            'Authorization': 'Bearer ${auth.token}',
            'Content-Type': 'application/json'
          },
        );

        final data = jsonDecode(res.body);
        if (res.statusCode == 200 && data['success'] == true) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$customerName" ${'customer_deleted_success'.tr}'), backgroundColor: AppColors.success),
          );
          _loadAllData();
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'customer_delete_failed'.tr), backgroundColor: AppColors.danger),
          );
        }
      } catch (e) {
        debugPrint('Müşteri silme hatası: $e');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
        );
      }
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
            Text(auth.shopName ?? 'shop_panel'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('${auth.user?['full_name']} (${'shop_owner_label'.tr})', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          // Dükkan Açık / Kapalı Toggle Butonu
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Tooltip(
              message: (_shopSettings?['is_open'] == 1 || _shopSettings?['is_open'] == true)
                  ? 'shop_open_tip'.tr
                  : 'shop_closed_tip'.tr,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_shopSettings?['is_open'] == 1 || _shopSettings?['is_open'] == true)
                      ? AppColors.success.withOpacity(0.2)
                      : AppColors.danger.withOpacity(0.2),
                  foregroundColor: (_shopSettings?['is_open'] == 1 || _shopSettings?['is_open'] == true)
                      ? AppColors.success
                      : AppColors.danger,
                  side: BorderSide(
                    color: (_shopSettings?['is_open'] == 1 || _shopSettings?['is_open'] == true)
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                icon: Icon(
                  (_shopSettings?['is_open'] == 1 || _shopSettings?['is_open'] == true)
                      ? Icons.storefront
                      : Icons.storefront_outlined,
                  size: 16,
                ),
                label: Text(
                  (_shopSettings?['is_open'] == 1 || _shopSettings?['is_open'] == true) ? 'shop_open'.tr : 'shop_closed'.tr,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: _toggleShopOpenStatus,
              ),
            ),
          ),
          // Mesai Saatleri Ayar Butonu
          IconButton(
            icon: const Icon(Icons.access_time, color: AppColors.accent),
            tooltip: 'work_hours'.tr,
            onPressed: _openWorkHoursDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'refresh'.tr,
            onPressed: _loadAllData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.danger),
            tooltip: 'logout'.tr,
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
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.receipt_long), label: 'tab_orders'.tr),
          BottomNavigationBarItem(icon: const Icon(Icons.fastfood), label: 'tab_products'.tr),
          BottomNavigationBarItem(icon: const Icon(Icons.tune), label: 'tab_options'.tr),
          BottomNavigationBarItem(icon: const Icon(Icons.category), label: 'tab_categories'.tr),
          BottomNavigationBarItem(icon: const Icon(Icons.people), label: 'tab_customers'.tr),
          BottomNavigationBarItem(icon: const Icon(Icons.campaign), label: 'tab_announcements'.tr),
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
        label: Text('add_product'.tr, style: const TextStyle(color: Colors.white)),
      );
    }
    if (_currentTab == 2) {
      return FloatingActionButton.extended(
        onPressed: () => _openAddOptionToProductDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('add_option'.tr, style: const TextStyle(color: Colors.white)),
      );
    }
    if (_currentTab == 3) {
      return FloatingActionButton.extended(
        onPressed: () => _openAddCategoryDialog(),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('add_category'.tr, style: const TextStyle(color: Colors.white)),
      );
    }
    if (_currentTab == 4) {
      return FloatingActionButton.extended(
        onPressed: _openAddCustomerDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text('add_customer'.tr, style: const TextStyle(color: Colors.white)),
      );
    }
    return null;
  }

  Widget _buildCurrentTab() {
    if (_currentTab == 0) return _buildOrdersTab();
    if (_currentTab == 1) return _buildProductsTab();
    if (_currentTab == 2) return _buildOptionsTab();
    if (_currentTab == 3) return _buildCategoriesTab();
    if (_currentTab == 4) return _buildCustomersTab();
    return _buildAnnouncementsTab();
  }

  Widget _buildOrdersTab() {
    if (_orders.isEmpty) {
      return Center(child: Text('no_orders'.tr, style: const TextStyle(color: AppColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (ctx, i) {
        final ord = _orders[i];
        final items = ord['items'] as List<dynamic>? ?? [];
        final isPaid = (ord['is_paid'] == 1 || ord['is_paid'] == true);

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
                    Text('${'order_number'.tr} #${ord['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    Row(
                      children: [
                        // Ödeme Durumu Rozeti & Hızlı Toggle
                        InkWell(
                          onTap: () => _toggleOrderPaymentStatus(ord['id'], isPaid),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? AppColors.success.withOpacity(0.15)
                                  : AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isPaid ? AppColors.success : AppColors.warning,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPaid ? Icons.check_circle : Icons.hourglass_top,
                                  color: isPaid ? AppColors.success : AppColors.warning,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isPaid ? 'status_paid'.tr : 'status_unpaid'.tr,
                                  style: TextStyle(
                                    color: isPaid ? AppColors.success : AppColors.warning,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildStatusChip(ord['status']),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${'customer_panel'.tr}: ${ord['customer_name']} (${ord['customer_phone'] ?? '-'})', style: const TextStyle(color: AppColors.textMuted)),
                if (ord['notes'] != null && ord['notes'].toString().isNotEmpty)
                  Text('${'order_note_label'.tr}: "${ord['notes']}"', style: const TextStyle(color: AppColors.warning, fontStyle: FontStyle.italic)),
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
                              '${'options_label'.tr}: ${it['selected_options']}',
                              style: const TextStyle(color: AppColors.accent, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Text('${'total_amount'.tr}: ₺${ord['total_price']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    if (ord['status'] == 'PENDING')
                      ElevatedButton(onPressed: () => _updateOrderStatus(ord['id'], 'ACCEPTED'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), child: Text('status_approved'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    if (ord['status'] == 'ACCEPTED')
                      ElevatedButton(onPressed: () => _updateOrderStatus(ord['id'], 'PREPARING'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning), child: Text('status_preparing'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    if (ord['status'] == 'PREPARING')
                      ElevatedButton(onPressed: () => _updateOrderStatus(ord['id'], 'DELIVERED'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success), child: Text('status_delivered'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    if (ord['status'] != 'DELIVERED' && ord['status'] != 'CANCELLED')
                      TextButton(onPressed: () => _updateOrderStatus(ord['id'], 'CANCELLED'), child: Text('status_cancel'.tr, style: const TextStyle(color: AppColors.danger))),
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
      return Center(child: Text('no_products'.tr, style: const TextStyle(color: AppColors.textMuted)));
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
      return Center(
        child: Text('no_products_for_options'.tr, style: const TextStyle(color: AppColors.textMuted)),
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
                      label: Text('add_edit_option'.tr, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (groups.isEmpty) ...[
                  Text(
                    'no_options_defined'.tr,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
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
      return Center(child: Text('no_categories_add_hint'.tr, style: const TextStyle(color: AppColors.textMuted)));
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
            subtitle: Text('${'category_sort_order'.tr}: ${cat['sort_order'] ?? 0}', style: const TextStyle(color: AppColors.textMuted)),
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
      return Center(child: Text('no_customers_add_hint'.tr, style: const TextStyle(color: AppColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _customers.length,
      itemBuilder: (ctx, i) {
        final c = _customers[i];
        final customerId = c['id'];

        // Bu müşterinin bekleyen ödenmemiş toplam borcunu hesapla (İptal edilenler hariç)
        double unpaidTotal = 0;
        int orderCount = 0;
        for (var o in _orders) {
          if (o['customer_id'] == customerId) {
            orderCount++;
            if (o['status'] != 'CANCELLED' && o['is_paid'] != 1 && o['is_paid'] != true) {
              unpaidTotal += double.tryParse(o['total_price']?.toString() ?? '0') ?? 0;
            }
          }
        }

        return Card(
          color: AppColors.cardBg,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: unpaidTotal > 0 ? AppColors.warning.withOpacity(0.4) : Colors.white10,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: unpaidTotal > 0 ? AppColors.warning.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
                      child: Icon(Icons.person, color: unpaidTotal > 0 ? AppColors.warning : AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['full_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text('${'user_label'.tr}: @${c['username']} • ${'phone_short'.tr}: ${c['phone'] ?? '-'}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                      tooltip: 'update_btn'.tr,
                      onPressed: () => _openAddCustomerDialog(editCustomer: c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.danger, size: 20),
                      tooltip: 'delete_btn'.tr,
                      onPressed: () => _deleteCustomer(c['id'], c['full_name']),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      unpaidTotal > 0 ? '${'unpaid_balance'.tr}: ₺${unpaidTotal.toStringAsFixed(2)}' : '${'unpaid_balance'.tr}: ₺0.00 (${'no_debt'.tr})',
                      style: TextStyle(
                        color: unpaidTotal > 0 ? AppColors.warning : AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text('$orderCount ${'total_orders_count'.tr}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    icon: const Icon(Icons.receipt_long, size: 16, color: Colors.white),
                    label: Text('customer_orders_history'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => _openCustomerOrderHistoryDialog(c),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementsTab() {
    if (_announcements.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 64, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('Henüz yayınlanmış bir duyuru bulunmuyor.', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _announcements.length,
      itemBuilder: (ctx, i) {
        final ann = _announcements[i];
        final dateStr = ann['created_at'] != null ? ann['created_at'].toString().split(' ').first : '';

        return Card(
          color: AppColors.cardBg,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.campaign, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ann['title'] ?? 'Duyuru',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (dateStr.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 12),
                Text(
                  ann['content'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
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
      case 'PENDING': color = AppColors.warning; label = 'status_pending'.tr; break;
      case 'ACCEPTED': color = AppColors.primary; label = 'status_accepted'.tr; break;
      case 'PREPARING': color = Colors.orange; label = 'status_preparing'.tr; break;
      case 'DELIVERED': color = AppColors.success; label = 'status_delivered'.tr; break;
      case 'CANCELLED': color = AppColors.danger; label = 'status_cancelled'.tr; break;
      default: color = AppColors.textMuted; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
