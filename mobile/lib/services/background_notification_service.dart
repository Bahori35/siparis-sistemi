import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../constants.dart';

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'order_service_channel',
    'Sipariş Dinleme Servisi',
    description: 'Arka planda gelen sipariş ve duyuruları dinler',
    importance: Importance.low,
  );

  const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
    'order_alerts_channel',
    'Sipariş ve Duyuru Bildirimleri',
    description: 'Yeni sipariş ve duyuru alarmları',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(alertChannel);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  await _localNotifications.initialize(
    const InitializationSettings(android: initializationSettingsAndroid),
  );

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBackgroundServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'order_service_channel',
      initialNotificationTitle: 'Sipariş Sistemi Aktif',
      initialNotificationContent: 'Arka planda siparişler dinleniyor...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onBackgroundServiceStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  final AudioPlayer bgAudioPlayer = AudioPlayer();
  final Set<int> knownOrderIds = {};
  final Set<int> knownAnnouncementIds = {};
  bool isFirstRun = true;

  Future<void> playAlertSoundAndVibrate() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 800);
      } else {
        HapticFeedback.heavyImpact();
      }
      await bgAudioPlayer.stop();
      await bgAudioPlayer.play(AssetSource('bildirim.mp3'));

      await Future.delayed(const Duration(milliseconds: 1400));
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 800);
      } else {
        HapticFeedback.heavyImpact();
      }

      await bgAudioPlayer.stop();
      await bgAudioPlayer.play(AssetSource('bildirim.mp3'));
    } catch (e) {
      debugPrint('Background audio error: $e');
    }
  }

  Future<void> showAlertNotification({required int id, required String title, required String body}) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'order_alerts_channel',
      'Sipariş ve Duyuru Bildirimleri',
      channelDescription: 'Yeni sipariş ve duyuru alarmları',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
      fullScreenIntent: true,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  // Her 3 saniyede bir dükkan sipariş ve duyurularını kontrol et
  Timer.periodic(const Duration(seconds: 3), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userJson = prefs.getString('auth_user');

    if (token == null || userJson == null) return;
    final user = jsonDecode(userJson);
    if (user['role'] != 'SHOP_OWNER') return;

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    try {
      // 1. Yeni Sipariş Kontrolü
      final ordRes = await http.get(Uri.parse(ApiConfig.shopOrders), headers: headers);
      if (ordRes.statusCode == 200) {
        final List orders = jsonDecode(ordRes.body)['data'] ?? [];
        if (isFirstRun) {
          for (final ord in orders) {
            final id = int.tryParse(ord['id']?.toString() ?? '');
            if (id != null) knownOrderIds.add(id);
          }
        } else {
          for (final ord in orders) {
            final id = int.tryParse(ord['id']?.toString() ?? '');
            if (id != null && !knownOrderIds.contains(id)) {
              knownOrderIds.add(id);
              if (ord['status'] == 'PENDING' || ord['status'] == null) {
                // Bildirim ve Ses Tetikle
                final custName = ord['customer_name'] ?? 'Müşteri';
                final total = ord['total_price'] ?? '0';
                showAlertNotification(
                  id: id,
                  title: '🔔 Yeni Sipariş Geldi!',
                  body: '$custName tarafından ₺$total tutarında yeni sipariş verildi.',
                );
                playAlertSoundAndVibrate();
              }
            }
          }
        }
      }

      // 2. Yeni Duyuru Kontrolü
      final annRes = await http.get(Uri.parse(ApiConfig.shopAnnouncements), headers: headers);
      if (annRes.statusCode == 200) {
        final List announcements = jsonDecode(annRes.body)['data'] ?? [];
        if (isFirstRun) {
          for (final a in announcements) {
            final id = int.tryParse(a['id']?.toString() ?? '');
            if (id != null) knownAnnouncementIds.add(id);
          }
          isFirstRun = false;
        } else {
          for (final a in announcements) {
            final id = int.tryParse(a['id']?.toString() ?? '');
            if (id != null && !knownAnnouncementIds.contains(id)) {
              knownAnnouncementIds.add(id);
              final title = a['title'] ?? 'Yeni Duyuru';
              final content = a['content'] ?? '';
              showAlertNotification(
                id: 9000 + id,
                title: '📢 $title',
                body: content,
              );
              playAlertSoundAndVibrate();
            }
          }
        }
      }
    } catch (e) {
      // Sessiz hata
    }
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}
