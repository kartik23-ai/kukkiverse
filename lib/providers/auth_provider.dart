import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  if (!FirebaseService.instance.isReady || FirebaseService.instance.useRestFallback) {
    return Stream.value(null);
  }
  return FirebaseAuth.instance.authStateChanges();
});

final isLoggedInProvider = Provider<bool>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.maybeWhen(data: (u) => u != null, orElse: () => false);
});
