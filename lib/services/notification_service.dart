import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_service.dart';
import 'storage_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _localNotificationsInitialized = false;

  void initialize(BuildContext context, WidgetRef ref) {
    if (_initialized) return;
    _initialized = true;

    if (Platform.isAndroid || Platform.isIOS) {
      Permission.notification.request().then((status) {
        debugPrint('[Notifications] Permission requested: $status');
        _initLocalNotifications();
      });
    }

    if (!FirebaseService.instance.isReady) return;

    // Listen to Firestore notifications collection for this user in real time
    final uid = FirebaseService.instance.userId;
    
    if (FirebaseService.instance.useRestFallback) {
      // Periodic REST polling for notifications on Windows fallback
      Stream.periodic(const Duration(seconds: 10)).asyncMap((_) async {
        try {
          final list = await FirestoreRestClient.listDocs('users/$uid/notifications');
          return list;
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      }).listen((docs) {
        _handleNotificationDocs(context, docs);
      });
    } else {
      // Real-time Firestore stream on native Android
      final db = FirebaseService.instance.db;
      if (db != null) {
        db.collection('users').doc(uid).collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .listen((snap) {
            final docs = snap.docs.map((d) => d.data()).toList();
            _handleNotificationDocs(context, docs);
          });
      }
    }
  }

  void _initLocalNotifications() async {
    if (_localNotificationsInitialized) return;
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      await _localNotifications.initialize(
        settings: initializationSettings,
      );
      _localNotificationsInitialized = true;
      debugPrint('[Notifications] local notifications initialized successfully.');
    } catch (e) {
      debugPrint('[Notifications] Failed to initialize local notifications: $e');
    }
  }

  Future<void> _showSystemNotification(String title, String body, {String? route}) async {
    if (!_localNotificationsInitialized) return;
    try {
      const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
        'rotty_music_notifications',
        'Rotty Music Notifications',
        channelDescription: 'General notifications for Rotty Music App',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );
      const NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);
      await _localNotifications.show(
        id: DateTime.now().millisecond, // unique id per message
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: route,
      );
    } catch (e) {
      debugPrint('[Notifications] Failed to show system notification: $e');
    }
  }

  void _handleNotificationDocs(BuildContext context, List<Map<String, dynamic>> docs) {
    if (docs.isEmpty) return;
    final latest = docs.first;
    final id = latest['id'] ?? latest['createdAt']?.toString();
    final lastSeenId = StorageService().lastNotificationId;
    if (id == null || id == lastSeenId) return;
    StorageService().setLastNotificationId(id);

    final title = latest['title'] as String? ?? 'Rotty Music';
    final body = latest['body'] as String? ?? 'Check out the new update!';
    final route = latest['route'] as String?;

    showForegroundNotification(context, title, body, route: route);
    _showSystemNotification(title, body, route: route);
  }

  void showForegroundNotification(BuildContext context, String title, String body, {String? route}) {
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _GlassNotificationToast(
        title: title,
        body: body,
        onTap: () {
          overlayEntry.remove();
          if (route != null && route.isNotEmpty) {
            context.push(route);
          }
        },
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }
}

class _GlassNotificationToast extends StatefulWidget {
  const _GlassNotificationToast({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_GlassNotificationToast> createState() => _GlassNotificationToastState();
}

class _GlassNotificationToastState extends State<_GlassNotificationToast> with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<Offset> _offsetAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack));

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn),
    );

    _animCtrl.forward();

    // Auto dismiss after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        _animCtrl.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SlideTransition(
            position: _offsetAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFA2D48).withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFA2D48), Color(0xFF7B61FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFA2D48).withValues(alpha: 0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.body,
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                              onPressed: () {
                                _animCtrl.reverse().then((_) => widget.onDismiss());
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
