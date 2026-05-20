import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class UpiAppInfo {
  const UpiAppInfo({required this.packageName, required this.name, this.icon});
  final String packageName;
  final String name;
  final Uint8List? icon;

  factory UpiAppInfo.fromMap(Map<dynamic, dynamic> m) {
    Uint8List? icon;
    final raw = m['icon'];
    if (raw is Uint8List) {
      icon = raw;
    } else if (raw is List) {
      icon = Uint8List.fromList(raw.cast<int>());
    }
    return UpiAppInfo(
      packageName: m['package']?.toString() ?? '',
      name: m['name']?.toString() ?? 'UPI App',
      icon: icon,
    );
  }
}

class UpiPaymentResult {
  const UpiPaymentResult({required this.success, this.rawResponse, this.status});
  final bool success;
  final String? rawResponse;
  final String? status;
}

/// UPI premium — ₹99/month. PRO unlocks only when UPI returns success.
class PremiumPaymentService {
  PremiumPaymentService._();
  static final PremiumPaymentService instance = PremiumPaymentService._();

  static const _channel = MethodChannel('com.rottymusic.rotty_music/upi');

  static const String upiId = '8532999011@ybl';
  static const String merchantName = 'ROTTY MUSIC';
  static const double monthlyPrice = 99;

  String upiPayUri(String transactionRefId) {
    return 'upi://pay?pa=${Uri.encodeComponent(upiId)}'
        '&pn=${Uri.encodeComponent(merchantName)}'
        '&am=${monthlyPrice.toStringAsFixed(2)}'
        '&cu=INR'
        '&tn=${Uri.encodeComponent('ROTTY Premium — 1 month')}'
        '&tr=${Uri.encodeComponent(transactionRefId)}'
        '&mode=04';
  }

  String newTransactionRef() => 'ROTTY-${DateTime.now().millisecondsSinceEpoch}';

  Future<List<UpiAppInfo>> getInstalledUpiApps() async {
    try {
      final list = await _channel.invokeMethod<List<dynamic>>('getUpiApps');
      if (list == null) return [];
      return list.map((e) => UpiAppInfo.fromMap(Map<dynamic, dynamic>.from(e as Map))).where((a) => a.packageName.isNotEmpty).toList();
    } catch (e) {
      debugPrint('getUpiApps failed: $e');
      return [];
    }
  }

  Future<UpiPaymentResult> payWithApp({
    required UpiAppInfo app,
    required String transactionRefId,
  }) async {
    try {
      final uri = upiPayUri(transactionRefId);
      final response = await _channel.invokeMethod<String>('startPayment', {
        'package': app.packageName,
        'uri': uri,
      });
      if (response == null || response.isEmpty) {
        return const UpiPaymentResult(success: false, status: 'empty');
      }
      final lower = response.toLowerCase();
      final success = lower.contains('success') && !lower.contains('fail');
      String? status;
      if (lower.contains('success')) {
        status = 'success';
      } else if (lower.contains('fail')) {
        status = 'failure';
      } else if (lower.contains('submit')) {
        status = 'submitted';
      }
      return UpiPaymentResult(success: success, rawResponse: response, status: status);
    } on PlatformException catch (e) {
      if (e.code == 'cancelled') {
        return const UpiPaymentResult(success: false, status: 'cancelled');
      }
      return UpiPaymentResult(success: false, status: e.code);
    } catch (e) {
      return UpiPaymentResult(success: false, status: e.toString());
    }
  }
}
