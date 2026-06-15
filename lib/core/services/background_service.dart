import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:audio_session/audio_session.dart' hide AndroidAudioFocus, AVAudioSessionCategory;
import 'package:audioplayers/audioplayers.dart';
import 'package:durakta_uyandir/core/utils/location_utils.dart';
import 'package:durakta_uyandir/domain/entities/destination_alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

bool _isSoundEnabled = true;
bool _isVibrationEnabled = true;
bool _isNotificationEnabled = true;

bool _isHeadphoneOnlyModeEnabled = false;

final AudioPlayer _audioPlayer = AudioPlayer();
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final payload = notificationResponse.payload;

    FlutterBackgroundService().invoke('stop_alarm_from_notification', {'id': payload});
  } catch (e) {
    debugPrint('notificationTapBackground Error: $e');
  }
}

final Map<String, DateTime> _lastTriggerTimes = {};

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    debugPrint("[BG Service] onStart() CALLED");

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: "Durakta Uyandır",
        content: "Servis Başlatıldı...",
      );
    }

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.actionId == 'stop_alarm_action') {
          await flutterLocalNotificationsPlugin.cancel(0);
          _audioPlayer.stop();
          Vibration.cancel();

          final payload = response.payload;
          if (payload != null) {
            final prefs = await SharedPreferences.getInstance();
            final stoppedAlarms = prefs.getStringList('stopped_alarms') ?? [];
            if (!stoppedAlarms.contains(payload)) {
              stoppedAlarms.add(payload);
              await prefs.setStringList('stopped_alarms', stoppedAlarms);
            }

            final SendPort? send = IsolateNameServer.lookupPortByName('bg_service_port');
            send?.send('stop_alarm:$payload');
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    List<Map<String, dynamic>> monitoredAlarms = [];

    service.on('stop_alarm_from_notification').listen((event) async {
      try {
        await flutterLocalNotificationsPlugin.cancel(0);
      } catch (e) {
        debugPrint("[BG Service] Notification cancel error: $e");
      }

      try {
        await _audioPlayer.stop();
      } catch (e) {
        debugPrint("[BG Service] AudioPlayer stop error: $e");
      }

      try {
        Vibration.cancel();
      } catch (e) {
        debugPrint("[BG Service] Vibration cancel error: $e");
      }

      final id = event?['id'];
      if (id != null) {
        for (var alarm in monitoredAlarms) {
          if (alarm['id'] == id) {
            alarm['isActive'] = false;
            debugPrint("[BG Service] Alarm $id disabled in memory.");

            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.reload();
              final stoppedAlarms = prefs.getStringList('stopped_alarms') ?? [];
              if (!stoppedAlarms.contains(id)) {
                stoppedAlarms.add(id);
                await prefs.setStringList('stopped_alarms', stoppedAlarms);
              }
            } catch (e) {
              debugPrint("[BG Service] BG SharedPreferences Error: $e");
            }

            try {
              if (service is AndroidServiceInstance) {
                service.invoke('disableAlarmInDb', {'id': id});
              }
            } catch (e) {
              debugPrint("[BG Service] disableAlarmInDb invoke error: $e");
            }
            break;
          }
        }
      } else {
        for (var alarm in monitoredAlarms) {
          alarm['isActive'] = false;
          try {
            if (service is AndroidServiceInstance) {
              service.invoke('disableAlarmInDb', {'id': alarm['id']});
            }
          } catch (e) {
            debugPrint("[BG Service] disableAlarmInDb invoke error: $e");
          }
        }
      }
    });

    StreamSubscription<Position>? streamSubscription;

    void startLocationStream() {
      streamSubscription?.cancel();
      debugPrint("[BG Service] Starting location stream.");

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      streamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position? position) {
          if (position != null) {
            if (kDebugMode) {
              debugPrint("[BG Service] Position: ${position.latitude}, ${position.longitude}");
            }

            if (service is AndroidServiceInstance) {
              String status = "Konum takibi aktif.";

              if (monitoredAlarms.isNotEmpty) {
                double minDistance = double.infinity;
                String nearestName = "";

                for (var alarm in monitoredAlarms) {
                  if (alarm['isActive'] == true) {
                    final dist = LocationUtils.calculateDistance(
                      position.latitude,
                      position.longitude,
                      (alarm['targetLat'] as num).toDouble(),
                      (alarm['targetLng'] as num).toDouble(),
                    );
                    if (dist < minDistance) {
                      minDistance = dist;
                      nearestName = alarm['name'];
                    }
                  }
                }
                if (minDistance != double.infinity) {
                  status = "$nearestName: ${minDistance.toStringAsFixed(0)}m";
                }
              }

              service.setForegroundNotificationInfo(title: "Durakta Uyandır", content: status);
            }

            _checkAlarms(position, monitoredAlarms, flutterLocalNotificationsPlugin);
          }
        },
        onError: (e) {
          debugPrint("[BG Service] Location Stream Error: $e");
        },
      );
    }

    service.on('stopService').listen((event) {
      debugPrint("[BG Service] Stop requested");
      service.stopSelf();
    });

    service.on('updateSettings').listen((event) {
      debugPrint("[BG Service] 'updateSettings' received: $event");
      if (event != null) {
        if (event.containsKey('sound')) _isSoundEnabled = event['sound'];
        if (event.containsKey('vibration')) _isVibrationEnabled = event['vibration'];
        if (event.containsKey('notification')) _isNotificationEnabled = event['notification'];
        if (event.containsKey('headphoneOnly')) {
          _isHeadphoneOnlyModeEnabled = event['headphoneOnly'];
        }

        debugPrint(
          "[BG Service] Settings updated: Sound=$_isSoundEnabled, Vibe=$_isVibrationEnabled, Note=$_isNotificationEnabled, HeadphoneOnly=$_isHeadphoneOnlyModeEnabled",
        );
      }
    });

    service.on('updateAlarms').listen((event) async {
      debugPrint("[BG Service] 'updateAlarms' received: $event");
      if (event != null && event['alarms'] != null) {
        final List<dynamic> rawList = event['alarms'];
        monitoredAlarms = List<Map<String, dynamic>>.from(rawList);
        debugPrint("[BG Service] Alarms updated. Count: ${monitoredAlarms.length}");

        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          debugPrint(
            "[BG Service] Immediate position check: ${position.latitude}, ${position.longitude}",
          );
          _checkAlarms(position, monitoredAlarms, flutterLocalNotificationsPlugin);
        } on TimeoutException {
          debugPrint("[BG Service] Timeout getting immediate position, attempting last known...");
          final position = await Geolocator.getLastKnownPosition();
          if (position != null) {
            _checkAlarms(position, monitoredAlarms, flutterLocalNotificationsPlugin);
          }
        } catch (e) {
          debugPrint("[BG Service] Error getting immediate position: $e");
        }
      }
    });

    startLocationStream();
  } catch (e, stack) {
    debugPrint("[BG Service] CRITICAL ERROR IN ONSTART: $e");
    debugPrint(stack.toString());
  }
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

Future<void> _checkAlarms(
  Position position,
  List<Map<String, dynamic>> alarms,
  FlutterLocalNotificationsPlugin notificationPlugin,
) async {
  for (var alarm in alarms) {
    if (alarm['isActive'] == true) {
      final double targetLat = (alarm['targetLat'] as num).toDouble();
      final double targetLng = (alarm['targetLng'] as num).toDouble();
      final double radius = (alarm['triggerRadiusInMeters'] as num?)?.toDouble() ?? 500.0;

      final double distance = LocationUtils.calculateDistance(
        position.latitude,
        position.longitude,
        targetLat,
        targetLng,
      );

      final alarmId = alarm['id'] as String;
      final lastTime = _lastTriggerTimes[alarmId];
      final bool canTrigger = lastTime == null ||
          DateTime.now().difference(lastTime).inMinutes >= 1;

      if (distance <= radius && canTrigger) {
        debugPrint("[BG Service] !!! TRIGGERING ALARM for '${alarm['name']}' !!!");
        _lastTriggerTimes[alarmId] = DateTime.now();

        try {
          await _triggerAlarm(alarm, notificationPlugin);
        } catch (e) {
          debugPrint("[BG Service] TRIGGER FAILED: $e");
        }
      }
    }
  }
}

Future<void> _triggerAlarm(
  Map<String, dynamic> alarm,
  FlutterLocalNotificationsPlugin notificationPlugin,
) async {
  if (_isSoundEnabled) {
    bool playOnMediaChannel = false;

    if (_isHeadphoneOnlyModeEnabled) {
      debugPrint("[BG Service] Headphone Mode ON. Checking devices...");
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());

        final devices = await session.getDevices();

        bool isHeadphonesConnected = false;
        for (var device in devices) {
          if (device.type == AudioDeviceType.wiredHeadset ||
              device.type == AudioDeviceType.bluetoothA2dp ||
              device.type == AudioDeviceType.bluetoothSco) {
            isHeadphonesConnected = true;
            break;
          }
        }

        debugPrint("[BG Service] Headphones Connected: $isHeadphonesConnected");

        if (isHeadphonesConnected) {
          playOnMediaChannel = true;
          debugPrint("[BG Service] Routing to Media Channel.");
        } else {
          debugPrint("[BG Service] Routing to Alarm Channel.");
        }
      } catch (e) {
        debugPrint("[BG Service] Error checking audio devices: $e");
      }
    }

    try {
      _audioPlayer.stop();

      await _audioPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            usageType: playOnMediaChannel ? AndroidUsageType.media : AndroidUsageType.alarm,
            contentType: AndroidContentType.music,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
        ),
      );

      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
    } catch (e) {
      debugPrint("[BG Service] Error playing sound: $e");
    }
  }

  if (_isVibrationEnabled) {
    try {
      if (await Vibration.hasVibrator()) {
        if (await Vibration.hasCustomVibrationsSupport()) {
          Vibration.vibrate(pattern: [500, 1000, 500, 1000], intensities: [0, 255, 0, 255]);
        } else {
          Vibration.vibrate(pattern: [500, 1000, 500, 1000]);
        }
      }
    } catch (e) {
      debugPrint("[BG Service] Error vibrating: $e");
    }
  }

  if (_isNotificationEnabled) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'alarm_channel',
      'ALARM CHANNEL',
      channelDescription: 'Channel for alarm notifications',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      playSound: false,
      enableVibration: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'stop_alarm_action',
          'DURDUR',
          cancelNotification: true,
          showsUserInterface: false,
        ),
      ],
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await notificationPlugin.show(
      0,
      'Durağa Yaklaştınız!',
      '${alarm['name']} konumuna vardınız.',
      platformChannelSpecifics,
      payload: alarm['id'],
    );
  }

  debugPrint("[BG Service] Alarm sequence completed for ${alarm['name']}");
}

class BackgroundLocationService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();

  static Future<void> initializeService() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground',
      'MY FOREGROUND SERVICE',
      description: 'This channel is used for important notifications.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
      'alarm_channel',
      'ALARM CHANNEL',
      description: 'Channel for alarm notifications',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alarmChannel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'Durakta Uyandır',
        initialNotificationContent: 'Konum takibi başlatılıyor...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<void> startService() async {
    debugPrint("[BG Service] Requesting startService()...");

    if (!await Permission.location.isGranted) {
      debugPrint("[BG Service] Permission denied. Aborting startService.");
      return;
    }

    if (await _service.isRunning()) {
      debugPrint("[BG Service] Service already running.");
      return;
    }

    await _service.startService();

    for (int i = 0; i < 15; i++) {
      if (await _service.isRunning()) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  static Future<void> stopService() async {
    _service.invoke("stopService");
  }

  static Future<void> updateAlarms(List<DestinationAlarm> alarms) async {
    debugPrint("[BG Service Request] Updating alarms: ${alarms.length}");
    final alarmsJson = alarms
        .map(
          (e) => {
            'id': e.id,
            'name': e.name,
            'targetLat': e.targetLat,
            'targetLng': e.targetLng,
            'triggerRadiusInMeters': e.triggerRadiusInMeters,
            'isActive': e.isActive,
          },
        )
        .toList();

    _service.invoke("updateAlarms", {'alarms': alarmsJson});
  }

  static Future<void> updateSettings(Map<String, dynamic> settings) async {
    debugPrint("[BG Service Request] Updating settings: $settings");
    _service.invoke("updateSettings", settings);
  }
}
