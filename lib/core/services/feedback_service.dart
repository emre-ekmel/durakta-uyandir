import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedbackService {
  static const String _githubRepoUrl = 'https://github.com/emre-ekmel/durakta-uyandir';

  static const Duration _rateLimitDuration = Duration(minutes: 1);

  /// Cihaza özel anonim bir ID döndürür (Rate limiting için)
  static Future<String> _getUserId() async {
    try {
      final auth = FirebaseAuth.instance;
      User? user = auth.currentUser;
      if (user == null) {
        final userCreds = await auth.signInAnonymously();
        user = userCreds.user;
      }
      return user!.uid;
    } catch (e) {
      debugPrint('[FeedbackService] Error signing in anonymously: $e');
      throw const FormatException('AUTH_FAILED');
    }
  }

  /// Rate limit kontrolü yapar
  static Future<bool> _canSendFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSentTimestamp = prefs.getInt('feedback_last_sent_time');

    if (lastSentTimestamp != null) {
      final lastSent = DateTime.fromMillisecondsSinceEpoch(lastSentTimestamp);
      if (DateTime.now().difference(lastSent) < _rateLimitDuration) {
        return false;
      }
    }
    return true;
  }

  /// Feedback gönderim zamanını kaydeder
  static Future<void> _markFeedbackSent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('feedback_last_sent_time', DateTime.now().millisecondsSinceEpoch);
  }

  /// Kategori bazlı dairesel tampon slotunu hesaplar (1-3 arası)
  static Future<int> _getNextSlotForCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'feedback_slot_$category';
    int currentSlot = prefs.getInt(key) ?? 1;
    int nextSlot = currentSlot + 1;
    if (nextSlot > 3) nextSlot = 1;
    await prefs.setInt(key, nextSlot);
    return currentSlot;
  }

  static Future<String> _collectDeviceInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = DeviceInfoPlugin();

      String deviceDetails = '';

      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        deviceDetails =
            'Cihaz: ${android.brand} ${android.model}\n'
            'Android: ${android.version.release} (SDK ${android.version.sdkInt})\n'
            'Uygulama: ${packageInfo.version}+${packageInfo.buildNumber}';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        deviceDetails =
            'Cihaz: ${ios.utsname.machine}\n'
            'iOS: ${ios.systemVersion}\n'
            'Uygulama: ${packageInfo.version}+${packageInfo.buildNumber}';
      }

      return deviceDetails;
    } catch (e) {
      debugPrint('[FeedbackService] Error collecting device info: $e');
      return 'Cihaz bilgileri alınamadı.';
    }
  }

  static Future<bool> openGitHubIssue({
    required String category,
    required String description,
  }) async {
    try {
      final deviceInfo = await _collectDeviceInfo();

      final String label = switch (category) {
        'bug' => 'bug',
        'suggestion' => 'enhancement',
        _ => 'feedback',
      };

      final uri = Uri.parse('$_githubRepoUrl/issues/new').replace(
        queryParameters: {
          'title': '[$category] ',
          'body': '$description\n\n---\n**Cihaz Bilgileri:**\n```\n$deviceInfo\n```',
          'labels': label,
        },
      );

      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[FeedbackService] Error opening GitHub issue: $e');
      return false;
    }
  }

  /// Geri bildirimi Firebase'e (Firestore ve Storage) doğrudan gönderir.
  static Future<bool> sendFeedback({
    required String category,
    required String description,
    List<String>? imagesBase64,
  }) async {
    if (!await _canSendFeedback()) {
      debugPrint('[FeedbackService] Rate limit exceeded.');
      throw const FormatException('RATE_LIMIT');
    }

    try {
      final deviceInfo = await _collectDeviceInfo();
      final userId = await _getUserId();
      final slot = await _getNextSlotForCategory(category);
      
      final docId = '${category}_${userId}_$slot';
      final docRef = FirebaseFirestore.instance.collection('feedbacks').doc(docId);

      // Firebase Storage Blaze planı zorunlu kıldığı için resimleri iyice küçültüp 
      // Firestore'a doğrudan base64 dizisi olarak kaydediyoruz.
      // Firestore'un 1 MB döküman limiti var. Bu yüzden base64 verisi çok küçük olmalı.
      
      await docRef.set({
        'userId': userId,
        'category': category,
        'description': description,
        'deviceInfo': deviceInfo,
        'images': imagesBase64 ?? [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[FeedbackService] Feedback sent successfully via Firebase.');
      await _markFeedbackSent();
      return true;
    } on FormatException catch (_) {
      rethrow;
    } catch (e) {
      debugPrint('[FeedbackService] Error sending feedback: $e');
      return false;
    }
  }

  static bool get isWebhookAvailable => true;
}
