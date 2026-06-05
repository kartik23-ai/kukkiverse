import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/rotty_glass.dart';
import '../../services/firebase_service.dart';


const String projectId = 'rotty-music';
const String apiKey = 'AIzaSyDkD9uaVanSvrsAg_Myg7mYKW0GSjB0t7w';
const String baseUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = false;
  bool _isDbOnline = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Progress metrics for mass broadcasting
  double _broadcastProgress = 0.0;
  int _broadcastSent = 0;
  int _broadcastTotal = 0;
  bool _isBroadcasting = false;

  // Pending Payments tab
  int _currentTab = 0;
  List<Map<String, dynamic>> _pendingPayments = [];
  bool _loadingPayments = false;

  @override
  void initState() {
    super.initState();
    _fetchUsersData();
    _fetchPendingPayments();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Helper: Decode Firestore values
  dynamic _decodeValue(Map<String, dynamic> firestoreValue) {
    if (firestoreValue.containsKey('nullValue')) return null;
    if (firestoreValue.containsKey('stringValue')) return firestoreValue['stringValue'];
    if (firestoreValue.containsKey('booleanValue')) return firestoreValue['booleanValue'];
    if (firestoreValue.containsKey('doubleValue')) return firestoreValue['doubleValue'];
    if (firestoreValue.containsKey('integerValue')) return int.tryParse(firestoreValue['integerValue']?.toString() ?? '');
    if (firestoreValue.containsKey('arrayValue')) {
      final list = firestoreValue['arrayValue']['values'] as List?;
      if (list == null) return [];
      return list.map((item) => _decodeValue(Map<String, dynamic>.from(item))).toList();
    }
    if (firestoreValue.containsKey('mapValue')) {
      final fields = firestoreValue['mapValue']['fields'] as Map?;
      if (fields == null) return {};
      final result = <String, dynamic>{};
      fields.forEach((k, v) {
        result[k.toString()] = _decodeValue(Map<String, dynamic>.from(v));
      });
      return result;
    }
    return null;
  }

  // Helper: Encode values to Firestore format
  Map<String, dynamic> _encodeValue(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is num) return {'doubleValue': value.toDouble()};
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map((item) => _encodeValue(item)).toList(),
        }
      };
    }
    if (value is Map) {
      final fields = <String, Map<String, dynamic>>{};
      value.forEach((k, v) {
        fields[k.toString()] = _encodeValue(v);
      });
      return {
        'mapValue': {
          'fields': fields,
        }
      };
    }
    return {'stringValue': value.toString()};
  }

  Future<void> _fetchUsersData() async {
    setState(() {
      _isLoading = true;
    });

    final fetched = <Map<String, dynamic>>[];
    bool isOnline = false;
    String? nextPageToken;

    try {
      do {
        String url = '$baseUrl/users?key=$apiKey&pageSize=100';
        if (nextPageToken != null) {
          url += '&pageToken=$nextPageToken';
        }
        
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          isOnline = true;
          final body = json.decode(res.body);
          final documents = body['documents'] as List?;
          if (documents != null) {
            for (final doc in documents) {
              final docName = doc['name'] as String;
              final uid = docName.split('/').last;
              final fields = doc['fields'] as Map<String, dynamic>?;

              if (fields != null) {
                final decoded = <String, dynamic>{'uid': uid};
                fields.forEach((k, v) {
                  decoded[k] = _decodeValue(Map<String, dynamic>.from(v));
                });
                fetched.add(decoded);
              }
            }
          }
          nextPageToken = body['nextPageToken'] as String?;
        } else {
          nextPageToken = null;
          throw Exception('HTTP status ${res.statusCode}');
        }
      } while (nextPageToken != null);
    } catch (e) {
      isOnline = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Database connection failed: $e', style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _allUsers = fetched;
        _isDbOnline = isOnline;
        _isLoading = false;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredUsers = List.from(_allUsers);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredUsers = _allUsers.where((u) {
        final email = (u['email'] ?? '').toString().toLowerCase();
        final displayName = (u['displayName'] ?? '').toString().toLowerCase();
        final username = (u['username'] ?? displayName.isNotEmpty ? displayName : email.split('@').first).toString().toLowerCase();
        final uid = (u['uid'] ?? '').toString().toLowerCase();
        return email.contains(query) || username.contains(query) || uid.contains(query);
      }).toList();
    }
  }

  Future<void> _toggleSupporterStatus(String uid, bool currentStatus) async {
    final newStatus = !currentStatus;
    // Optimistic UI update
    setState(() {
      for (var u in _allUsers) {
        if (u['uid'] == uid) {
          u['is_supporter'] = newStatus;
        }
      }
      _applyFilter();
    });

    try {
      final fields = {'is_supporter': _encodeValue(newStatus)};
      final body = json.encode({'fields': fields});
      final res = await http.patch(
        Uri.parse('$baseUrl/users/$uid?updateMask.fieldPaths=is_supporter&key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        throw Exception('Status code ${res.statusCode}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.greenAccent,
            content: Text(
              newStatus
                  ? 'Supporter VIP badge successfully granted!'
                  : 'Supporter status revoked.',
              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    } catch (e) {
      // Revert UI status on exception
      setState(() {
        for (var u in _allUsers) {
          if (u['uid'] == uid) {
            u['is_supporter'] = currentStatus;
          }
        }
        _applyFilter();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to update: $e', style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
      }
    }
  }

  Future<void> _fetchPendingPayments() async {
    if (!mounted) return;
    setState(() {
      _loadingPayments = true;
    });

    final fetched = <Map<String, dynamic>>[];

    try {
      final res = await http.get(Uri.parse('$baseUrl/payments_pending?key=$apiKey')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final documents = body['documents'] as List?;
        if (documents != null) {
          for (final doc in documents) {
            final docName = doc['name'] as String;
            final utr = docName.split('/').last;
            final fields = doc['fields'] as Map<String, dynamic>?;

            if (fields != null) {
              final decoded = <String, dynamic>{'utr': utr};
              fields.forEach((k, v) {
                decoded[k] = _decodeValue(Map<String, dynamic>.from(v));
              });
              fetched.add(decoded);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching pending payments: $e');
    }

    if (mounted) {
      setState(() {
        _pendingPayments = fetched;
        _loadingPayments = false;
      });
    }
  }

  Future<void> _handlePaymentApproval(String utr, String uid, bool approve) async {
    setState(() {
      _loadingPayments = true;
    });

    try {
      final newStatus = approve ? 'approved' : 'rejected';
      final paymentFields = {
        'status': _encodeValue(newStatus),
      };
      
      final payRes = await http.patch(
        Uri.parse('$baseUrl/payments_pending/$utr?updateMask.fieldPaths=status&key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fields': paymentFields}),
      ).timeout(const Duration(seconds: 8));

      if (payRes.statusCode == 200) {
        if (approve) {
          final userFields = {'is_supporter': _encodeValue(true)};
          await http.patch(
            Uri.parse('$baseUrl/users/$uid?updateMask.fieldPaths=is_supporter&key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'fields': userFields}),
          ).timeout(const Duration(seconds: 8));

          await _pushNotificationToFirestore(
            uid,
            'Supporter Badge Unlocked! 💖',
            'Aapka UPI Payment verify ho gaya hai! Profile badge successfully activate kar diya gaya hai. Thank you for supporting Rotty Music!',
            route: '/support',
          );
        } else {
          await _pushNotificationToFirestore(
            uid,
            'Payment Verification Failed ⚠️',
            'UTR ID $utr verify nahi ho paya. Please double check standard UPI details in Support screen or try again.',
            route: '/support',
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: approve ? Colors.greenAccent : Colors.redAccent,
              content: Text(
                approve ? 'Payment approved & Supporter badge activated!' : 'Payment rejected.',
                style: GoogleFonts.inter(color: approve ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      } else {
        throw Exception('HTTP status ${payRes.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to process payment claim: $e', style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
      }
    }

    await _fetchPendingPayments();
    await _fetchUsersData();
  }

  Widget _buildPaymentsList() {
    final pending = _pendingPayments.where((p) => p['status'] == 'pending').toList();
    final approved = _pendingPayments.where((p) => p['status'] == 'approved').toList();
    final rejected = _pendingPayments.where((p) => p['status'] == 'rejected').toList();

    final showList = [...pending, ...approved, ...rejected];

    if (showList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_rounded, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(
              'No payment claims submitted yet',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: showList.length,
      itemBuilder: (context, idx) {
        final p = showList[idx];
        final utr = p['utr'] ?? 'No UTR';
        final email = p['email'] ?? 'No Email';
        final uid = p['uid'] ?? '';
        final status = p['status'] ?? 'pending';
        final submittedAt = p['submittedAt'] ?? '';

        final isPending = status == 'pending';
        final isApproved = status == 'approved';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: isPending 
                  ? Colors.pinkAccent.withValues(alpha: 0.15) 
                  : Colors.white.withValues(alpha: 0.05)
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPending
                          ? Colors.pinkAccent.withValues(alpha: 0.15)
                          : isApproved
                              ? Colors.greenAccent.withValues(alpha: 0.15)
                              : Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isPending
                            ? Colors.pinkAccent
                            : isApproved
                                ? Colors.greenAccent
                                : Colors.redAccent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    submittedAt.isNotEmpty 
                        ? submittedAt.toString().substring(0, 10) 
                        : '',
                    style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'UTR ID: $utr',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Email: $email',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
              ),
              Text(
                'UID: $uid',
                style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 11),
              ),
              if (isPending) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 14),
                      label: Text('Reject', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _handlePaymentApproval(utr, uid, false),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 14),
                      label: Text('Approve', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _handlePaymentApproval(utr, uid, true),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<bool> _pushNotificationToFirestore(String uid, String title, String bodyText, {String? route}) async {
    try {
      final now = DateTime.now().toIso8601String();
      final docId = 'notif_${DateTime.now().millisecondsSinceEpoch}';

      final fields = {
        'id': _encodeValue(docId),
        'title': _encodeValue(title),
        'body': _encodeValue(bodyText),
        'createdAt': _encodeValue(now),
      };

      if (route != null && route.trim().isNotEmpty) {
        fields['route'] = _encodeValue(route.trim());
      }

      final body = json.encode({'fields': fields});
      final res = await http.post(
        Uri.parse('$baseUrl/users/$uid/notifications?documentId=$docId&key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 6));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _showNotificationDialog({String? targetUid, String? targetEmail}) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final routeCtrl = TextEditingController();
    final isMassBroadcast = targetUid == null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141426),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        title: Row(
          children: [
            Icon(
              isMassBroadcast ? Icons.campaign_rounded : Icons.notification_important_rounded,
              color: isMassBroadcast ? AppColors.accent : Colors.cyanAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isMassBroadcast ? 'Mass Broadcast Alert' : 'Send targeted Alert',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMassBroadcast
                    ? 'Broadcast this alert instantly to all ${_allUsers.length} registered users.'
                    : 'Send customized notification to $targetEmail',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: _dialogInputDecoration('Alert Title', Icons.title_rounded),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: _dialogInputDecoration('Alert Body Message', Icons.message_rounded),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: routeCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: _dialogInputDecoration('Route Redirect (Optional, e.g. /premium)', Icons.alt_route_rounded),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isMassBroadcast ? AppColors.accent : Colors.cyanAccent,
              foregroundColor: isMassBroadcast ? Colors.white : Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final title = titleCtrl.text.trim();
              final body = bodyCtrl.text.trim();
              final route = routeCtrl.text.trim();

              if (title.isEmpty || body.isEmpty) return;

              Navigator.pop(ctx);

              if (isMassBroadcast) {
                _startMassBroadcast(title, body, route);
              } else {
                _sendDirectNotification(targetUid, title, body, route);
              }
            },
            child: Text(
              isMassBroadcast ? 'Broadcast' : 'Send',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dialogInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.white30, size: 18),
      hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    );
  }

  Future<void> _sendDirectNotification(String uid, String title, String body, String route) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await _pushNotificationToFirestore(uid, title, body, route: route);

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.cyanAccent,
          content: Text('Alert successfully dispatched!', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Failed to dispatch alert.', style: GoogleFonts.inter(color: Colors.white)),
        ),
      );
    }
  }

  Future<void> _startMassBroadcast(String title, String body, String route) async {
    if (_allUsers.isEmpty) return;

    setState(() {
      _isBroadcasting = true;
      _broadcastSent = 0;
      _broadcastTotal = _allUsers.length;
      _broadcastProgress = 0.0;
    });

    int successes = 0;

    for (var i = 0; i < _allUsers.length; i++) {
      if (!_isBroadcasting) break; // Allow cancel
      final u = _allUsers[i];
      final uid = u['uid'];

      final success = await _pushNotificationToFirestore(uid, title, body, route: route);
      if (success) {
        successes++;
      }

      if (mounted) {
        setState(() {
          _broadcastSent = i + 1;
          _broadcastProgress = _broadcastSent / _broadcastTotal;
        });
      }
      // Small pause to prevent rate limiting
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted) {
      setState(() {
        _isBroadcasting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 4),
          content: Text(
            'Broadcast completed! Dispatched to $successes / $_broadcastTotal users successfully.',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Guard check: Only allow Kartik!
    final isAdmin = FirebaseService.instance.isAdmin;
    if (!isAdmin) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Access Denied. You do not have permissions to view this screen.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
      );
    }

    final totalSupporters = _allUsers.where((u) => u['is_supporter'] == true).length;
    final pendingCount = _pendingPayments.where((p) => p['status'] == 'pending').length;

    return AppScaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Control Panel',
                              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Rotty Music Live Database Tools',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
                        onPressed: _isLoading ? null : () {
                          _fetchUsersData();
                          _fetchPendingPayments();
                        },
                      ),
                    ],
                  ),
                ),

                // Stats Dashboard Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: RottyGlass(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          accentColor: Colors.cyanAccent,
                          glowIntensity: 0.08,
                          child: Column(
                            children: [
                              FittedBox(
                                child: Text(
                                  _isLoading ? '...' : '${_allUsers.length}',
                                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Total Users',
                                style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RottyGlass(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          accentColor: Colors.pinkAccent,
                          glowIntensity: 0.08,
                          child: Column(
                            children: [
                              FittedBox(
                                child: Text(
                                  _isLoading ? '...' : '$totalSupporters',
                                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.pinkAccent),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'VIP Supporters',
                                style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RottyGlass(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          accentColor: _isDbOnline ? Colors.greenAccent : Colors.redAccent,
                          glowIntensity: 0.08,
                          child: Column(
                            children: [
                              Icon(
                                _isDbOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                color: _isDbOnline ? Colors.greenAccent : Colors.redAccent,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isDbOnline ? 'DB Online' : 'Offline',
                                style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tabs Switcher
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _currentTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _currentTab == 0
                                  ? Colors.cyanAccent.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _currentTab == 0
                                    ? Colors.cyanAccent.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Users',
                                style: GoogleFonts.inter(
                                  color: _currentTab == 0 ? Colors.cyanAccent : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _currentTab = 1);
                            _fetchPendingPayments();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _currentTab == 1
                                  ? Colors.pinkAccent.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _currentTab == 1
                                    ? Colors.pinkAccent.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Pending Payments',
                                    style: GoogleFonts.inter(
                                      color: _currentTab == 1 ? Colors.pinkAccent : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (pendingCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Colors.pinkAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$pendingCount',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Control Toolbar (Search & Broadcast Button) - Only show on Users tab
                if (_currentTab == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search user by Name, Email or UID...',
                              hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
                              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30, size: 18),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() {
                                          _searchQuery = '';
                                          _applyFilter();
                                        });
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.04),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
                              ),
                            ),
                            onChanged: (v) {
                              setState(() {
                                _searchQuery = v;
                                _applyFilter();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(46, 46),
                          ),
                          icon: const Icon(Icons.campaign_rounded, color: Colors.white),
                          tooltip: 'Mass Broadcast to all users',
                          onPressed: _allUsers.isEmpty ? null : () => _showNotificationDialog(),
                        ),
                      ],
                    ),
                  ),

                if (_currentTab == 0) const SizedBox(height: 16),

                // Main Content Area
                Expanded(
                  child: _currentTab == 0
                      ? (_isLoading ? _buildShimmerSkeleton() : _buildUserList())
                      : (_loadingPayments ? _buildShimmerSkeleton() : _buildPaymentsList()),
                ),
              ],
            ),
          ),

          // Realtime Broadcast HUD overlay
          if (_isBroadcasting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: RottyGlass(
                    padding: const EdgeInsets.all(24),
                    accentColor: AppColors.accent,
                    glowIntensity: 0.25,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.campaign_rounded, color: AppColors.accent, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Broadcasting System Alert...',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Dispatched: $_broadcastSent / $_broadcastTotal users',
                          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 20),
                        LinearProgressIndicator(
                          value: _broadcastProgress,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            setState(() {
                              _isBroadcasting = false;
                            });
                          },
                          child: Text('Cancel / Stop Queue', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No users matching filters' : 'No registered users found',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, idx) {
        final u = _filteredUsers[idx];
        final email = u['email'] ?? 'No Email';
        final username = u['username'] ?? u['displayName'] ?? (email != 'No Email' ? email.split('@').first : 'User');
        final uid = u['uid'] ?? '';
        final isSupporter = u['is_supporter'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ExpansionTile(
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            shape: const Border(),
            leading: CircleAvatar(
              backgroundColor: isSupporter ? Colors.pinkAccent.withValues(alpha: 0.2) : Colors.cyanAccent.withValues(alpha: 0.1),
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: GoogleFonts.outfit(
                  color: isSupporter ? Colors.pinkAccent : Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              username,
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              email,
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: InkWell(
              onTap: () => _toggleSupporterStatus(uid, isSupporter),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSupporter ? Colors.pinkAccent.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSupporter ? Colors.pinkAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSupporter ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isSupporter ? Colors.pinkAccent : Colors.white30,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSupporter ? 'SUPPORTER' : 'FREE',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: isSupporter ? Colors.pinkAccent : Colors.white54,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: Colors.white.withValues(alpha: 0.06)),
                    Row(
                      children: [
                        Text(
                          'UID: $uid',
                          style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 10, letterSpacing: 0.5),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: uid));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User UID copied to clipboard!'), duration: Duration(seconds: 1)),
                            );
                          },
                          child: const Icon(Icons.copy_rounded, color: Colors.white30, size: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        // Dispatch targeted message action
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.notification_add_rounded, color: Colors.cyanAccent, size: 14),
                          label: Text(
                            'Send Alert Toast',
                            style: GoogleFonts.inter(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _showNotificationDialog(targetUid: uid, targetEmail: email),
                        ),
                        // VIP badge quick control button
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isSupporter ? Colors.redAccent.withValues(alpha: 0.2) : Colors.pinkAccent,
                            foregroundColor: isSupporter ? Colors.redAccent : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: Icon(isSupporter ? Icons.no_accounts_rounded : Icons.workspace_premium_rounded, size: 14),
                          label: Text(
                            isSupporter ? 'Revoke VIP' : 'Upgrade VIP',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _toggleSupporterStatus(uid, isSupporter),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.04),
      highlightColor: Colors.white.withValues(alpha: 0.08),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
