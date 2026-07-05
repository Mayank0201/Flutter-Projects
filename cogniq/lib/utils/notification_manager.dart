import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'activity_tracker.dart';
import 'daily_challenge_manager.dart';

class NotificationManager {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const int dailyChallengeNotificationId = 1001;
  static const int inactivity3DaysNotificationId = 2003;
  static const int inactivity7DaysNotificationId = 2007;
  static const int installTestNotificationId = 9999;

  // Helper check to ensure notification methods only run on supported mobile platforms
  static bool get _isSupportedPlatform => 
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  // Initialize the notification plugin
  static Future<void> initialize() async {
    if (!_isSupportedPlatform) return;
    tz.initializeTimeZones();

    try {
      final String? timeZoneName = await const MethodChannel('com.mayank.cogniq/install_marker')
          .invokeMethod<String>('getLocalTimezone');
      if (timeZoneName != null) {
        try {
          tz.setLocalLocation(tz.getLocation(timeZoneName));
        } catch (e) {
          debugPrint('Location $timeZoneName not found in IANA database, trying fallbacks: $e');
          if (timeZoneName.contains('Calcutta') || timeZoneName.contains('Kolkata') || timeZoneName.contains('GMT+05:30') || timeZoneName.contains('IST')) {
            tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
          } else {
            bool found = false;
            final cleanName = timeZoneName.replaceAll('GMT', '').replaceAll('UTC', '').trim();
            if (cleanName.startsWith('+') || cleanName.startsWith('-')) {
              final parts = cleanName.substring(1).split(':');
              if (parts.isNotEmpty) {
                final hours = int.tryParse(parts[0]) ?? 0;
                final minutes = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
                final totalMinutes = hours * 60 + minutes;
                if (totalMinutes == 330) {
                  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
                  found = true;
                } else if (totalMinutes == 480) {
                  tz.setLocalLocation(tz.getLocation('Asia/Singapore'));
                  found = true;
                } else if (totalMinutes == 0) {
                  tz.setLocalLocation(tz.UTC);
                  found = true;
                }
              }
            }
            if (!found) {
              for (var name in tz.timeZoneDatabase.locations.keys) {
                if (name.toLowerCase().contains(timeZoneName.toLowerCase())) {
                  tz.setLocalLocation(tz.getLocation(name));
                  found = true;
                  break;
                }
              }
            }
            if (!found) {
              tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
            }
          }
        }
      } else {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      }
    } catch (e) {
      debugPrint('Failed to set local timezone, defaulting to Asia/Kolkata: $e');
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {}
    }

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_stat_brain');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification click if needed
      },
    );

    // Create Notification Channels for Android 8.0+ explicitly
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        const AndroidNotificationChannel channel1 = AndroidNotificationChannel(
          'inactivity_channel',
          'Brain Training Reminders',
          description: 'Reminders when you haven\'t played in a few days',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        const AndroidNotificationChannel channel2 = AndroidNotificationChannel(
          'daily_challenge_channel',
          'Daily Challenge Alerts',
          description: 'Reminders for daily challenge deadlines',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        const AndroidNotificationChannel channel3 = AndroidNotificationChannel(
          'test_channel',
          'Test Alerts',
          description: 'Notifications for testing purposes',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        
        await androidPlugin.createNotificationChannel(channel1);
        await androidPlugin.createNotificationChannel(channel2);
        await androidPlugin.createNotificationChannel(channel3);
      }
    } catch (e) {
      debugPrint('Failed to create notification channels: $e');
    }
  }

  static Future<AndroidScheduleMode> _getScheduleMode() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final bool? canSchedule = await androidPlugin.canScheduleExactNotifications();
        if (canSchedule == true) {
          return AndroidScheduleMode.exactAllowWhileIdle;
        }
      }
    } catch (_) {}
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  // Request notification permissions (called on app startup/home screen)
  static Future<void> requestPermissions() async {
    if (!_isSupportedPlatform) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  // Helper to get today's date string matching daily challenge format
  static String _getTodayDateStr() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  // Schedule or update daily challenge deadline reminder
  static Future<void> updateDailyChallengeReminder() async {
    if (!_isSupportedPlatform) return;
    final prefs = await SharedPreferences.getInstance();
    
    // Check if challenge start time exists
    final startTimeStr = prefs.getString('daily_challenge_start_time') ?? '';
    if (startTimeStr.isEmpty) {
      await _plugin.cancel(dailyChallengeNotificationId);
      return;
    }

    final startTime = DateTime.tryParse(startTimeStr);
    if (startTime == null) {
      await _plugin.cancel(dailyChallengeNotificationId);
      return;
    }

    // Check if user has already completed all 3 challenges today
    final dateStr = _getTodayDateStr();
    final completedCount = await DailyChallengeManager.getCompletedCountForDate(dateStr);
    
    if (completedCount >= 3) {
      // Completed, cancel scheduled notification
      await _plugin.cancel(dailyChallengeNotificationId);
      return;
    }

    // Schedule 12 hours after start (which is 12 hours remaining in the 24h cycle)
    final reminderTime = startTime.add(const Duration(hours: 12));
    final now = DateTime.now();

    if (reminderTime.isAfter(now)) {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'daily_challenge_channel',
        'Daily Challenge Alerts',
        channelDescription: 'Reminders for daily challenge deadlines',
        importance: Importance.high,
        priority: Priority.high,
      );
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      try {
        final mode = await _getScheduleMode();
        await _plugin.zonedSchedule(
          dailyChallengeNotificationId,
          'Daily Challenge Reminder ⏳',
          'Only 12 hours left to complete today\'s Daily Challenge! Train your brain to keep your streak going!',
          tz.TZDateTime.from(reminderTime, tz.local),
          platformDetails,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('Failed to schedule daily challenge reminder: $e');
      }
    } else {
      // If the 12-hour reminder point has already passed, cancel any old ones
      await _plugin.cancel(dailyChallengeNotificationId);
    }
  }

  // Schedule inactivity reminders relative to the last activity time
  static Future<void> updateInactivityReminders() async {
    if (!_isSupportedPlatform) return;
    // Cancel existing inactivity notifications
    await _plugin.cancel(inactivity3DaysNotificationId);
    await _plugin.cancel(inactivity7DaysNotificationId);

    // Get favorite game to inject into message
    final favoriteGame = await ActivityTracker.getFavoriteGame();
    final now = DateTime.now();

    // Inactivity Alert Details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'inactivity_channel',
      'Brain Training Reminders',
      channelDescription: 'Reminders when you haven\'t played in a few days',
      importance: Importance.high,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final mode = await _getScheduleMode();

    // 2-Day Inactivity Reminder
    final reminder2Days = now.add(const Duration(days: 2));
    try {
      await _plugin.zonedSchedule(
        inactivity3DaysNotificationId,
        'Train Your Brain 🧠',
        'You haven\'t trained your brain in 2 days! Try playing $favoriteGame to keep your mind sharp!',
        tz.TZDateTime.from(reminder2Days, tz.local),
        platformDetails,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule 2-day inactivity reminder: $e');
    }

    // 7-Day Inactivity Reminder
    final reminder7Days = now.add(const Duration(days: 7));
    try {
      await _plugin.zonedSchedule(
        inactivity7DaysNotificationId,
        'Don\'t Lose Your Edge! 📈',
        'It\'s been a week! Keep your brain power growing — jump back into $favoriteGame and challenge yourself!',
        tz.TZDateTime.from(reminder7Days, tz.local),
        platformDetails,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule 7-day inactivity reminder: $e');
    }
  }

  // Schedule a test notification 1 minute after installation
  static Future<void> scheduleInstallTestNotification() async {
    if (!_isSupportedPlatform) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('test_install_notification_scheduled') ?? false) {
      return; // already scheduled
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Alerts',
      channelDescription: 'Notifications for testing purposes',
      importance: Importance.high,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final reminderTime = DateTime.now().add(const Duration(minutes: 1));
    final mode = await _getScheduleMode();
    try {
      await _plugin.zonedSchedule(
        installTestNotificationId,
        'Welcome to CogniQ! 🚀 (Test)',
        'Thanks for installing! This is a test notification scheduled 1 minute after installation.',
        tz.TZDateTime.from(reminderTime, tz.local),
        platformDetails,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      await prefs.setBool('test_install_notification_scheduled', true);
    } catch (e) {
      debugPrint('Failed to schedule install test notification: $e');
    }
  }
}
