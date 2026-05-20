import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import '../models/song_model.dart';
import 'storage_service.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool _ready = false;
  bool get isReady => _ready;

  FirebaseFirestore? get db => _ready ? FirebaseFirestore.instance : null;
  User? get currentUser => _ready ? FirebaseAuth.instance.currentUser : null;

  Future<bool> init() async {
    if (_ready) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      _ready = true;
      debugPrint('Firebase: ready (project rotty-music)');
      return true;
    } catch (e, st) {
      debugPrint('Firebase init failed: $e\n$st');
      return false;
    }
  }

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'local';

  Future<UserCredential> signInWithEmail(String email, String password) async {
    _ensureReady();
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _ensureUserProfile(email: email.trim());
    await syncUserData();
    return cred;
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? phone,
    String? displayName,
  }) async {
    _ensureReady();
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (displayName != null && displayName.trim().isNotEmpty) {
      await cred.user?.updateDisplayName(displayName.trim());
    }
    await _ensureUserProfile(
      email: email.trim(),
      phone: phone?.trim(),
      displayName: displayName ?? email.split('@').first,
    );
    await syncUserData();
    return cred;
  }

  Future<UserCredential> signInAsGuest() async {
    _ensureReady();
    final cred = await FirebaseAuth.instance.signInAnonymously();
    await _ensureUserProfile(displayName: 'Guest');
    return cred;
  }

  Future<void> signOut() async {
    if (!_ready) return;
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _ensureUserProfile({String? email, String? phone, String? displayName}) async {
    if (!_ready) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final firestore = db!;
    final userRef = firestore.collection('users').doc(uid);
    await userRef.set({
      if (email != null) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (displayName != null) 'displayName': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await userRef.collection('meta').doc('profile').set({
      'email': email,
      'phone': phone,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

  }

  Future<void> syncUserData() async {
    if (!_ready || FirebaseAuth.instance.currentUser == null) return;
    final firestore = db!;
    final storage = StorageService();
    final data = {
      'updatedAt': FieldValue.serverTimestamp(),
      'streak': storage.listeningStreak.days,
      'groqConfigured': storage.groqApiKey.isNotEmpty,
      'favoriteIds': storage.getFavorites().map((s) => s.id).toList(),
      'favoriteSongs': storage.getFavorites().map((s) => s.toJson()).toList(),
      'dislikedIds': storage.dislikedSongIds.toList(),
      'recentIds': storage.getRecentSongs().take(30).map((s) => s.id).toList(),
    };
    await firestore.collection('users').doc(_uid).set(data, SetOptions(merge: true));
  }

  Future<void> pullUserData() async {
    if (!_ready) return;
    final snap = await db!.collection('users').doc(_uid).get();
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null) return;
    final storage = StorageService();
    final dislikes = data['dislikedIds'];
    if (dislikes is List) {
      await storage.setDislikedSongIds(dislikes.whereType<String>().toSet());
    }
    final favSongs = data['favoriteSongs'];
    if (favSongs is List) {
      for (final item in favSongs) {
        if (item is Map) {
          final song = SongModel.fromHive(Map<String, dynamic>.from(item));
          if (!storage.isFavorite(song.id)) {
            await storage.toggleFavorite(song);
          }
        }
      }
    }
  }

  Future<String> createPartyRoom() async {
    _ensureReady();
    final code = 'ROTTY-${10000 + Random().nextInt(89999)}';
    await db!.collection('party_rooms').doc(code).set({
      'hostId': _uid,
      'queue': <Map<String, dynamic>>[],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<void> joinPartyRoom(String code) async {
    _ensureReady();
    final snap = await db!.collection('party_rooms').doc(code).get();
    if (!snap.exists) throw StateError('Party room not found');
  }

  Stream<List<SongModel>> watchPartyQueue(String code) {
    if (!_ready) return const Stream.empty();
    return db!.collection('party_rooms').doc(code).snapshots().map((snap) {
      final q = snap.data()?['queue'];
      if (q is! List) return <SongModel>[];
      return q
          .whereType<Map>()
          .map((e) => SongModel.fromHive(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  Future<void> pushPartyQueue(String code, List<SongModel> songs) async {
    if (!_ready) return;
    await db!.collection('party_rooms').doc(code).set({
      'queue': songs.map((s) => s.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> logPlay(SongModel song) async {
    if (!_ready) return;
    await db!.collection('users').doc(_uid).collection('plays').add({
      'songId': song.id,
      'title': song.title,
      'artist': song.artist,
      'at': FieldValue.serverTimestamp(),
    });
  }

  /// Remote kill switch — check Firestore 'app_config/status' doc.
  /// Returns {enabled: bool, message: String?}
  /// If 'enabled' is false, the app should block usage.
  /// To kill: set app_config/status → {enabled: false, message: "Updating..."}
  /// To restore: set app_config/status → {enabled: true}
  Future<Map<String, dynamic>> checkKillSwitch() async {
    if (!_ready) return {'enabled': true}; // Offline = allow
    try {
      final snap = await db!.collection('app_config').doc('status').get();
      if (!snap.exists) return {'enabled': true}; // No doc = allow
      final data = snap.data() ?? {};
      return {
        'enabled': data['enabled'] ?? true,
        'message': data['message'] as String? ?? 'App is under maintenance. Please try again later.',
        'minVersion': data['minVersion'] as String?,
      };
    } catch (e) {
      debugPrint('Kill switch check failed: $e');
      return {'enabled': true}; // Network error = allow (offline-first)
    }
  }

  void _ensureReady() {
    if (!_ready) throw StateError('Firebase not initialized');
  }
}
