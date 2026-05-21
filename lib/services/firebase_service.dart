import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../firebase_options.dart';
import '../models/song_model.dart';
import 'storage_service.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool _ready = false;
  bool get isReady => _ready;

  bool _useRestFallback = false;
  bool get useRestFallback => _useRestFallback;

  String get userId => _uid;

  FirebaseFirestore? get db {
    if (_useRestFallback) return null;
    return _ready ? FirebaseFirestore.instance : null;
  }

  User? get currentUser {
    if (_useRestFallback) return null;
    return _ready ? FirebaseAuth.instance.currentUser : null;
  }

  Future<bool> init() async {
    if (_ready) return true;
    if (Platform.isWindows) {
      _useRestFallback = true;
      _ready = true;
      debugPrint('Firebase: REST Fallback ready on Windows (project rotty-music)');
      return true;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      _ready = true;
      debugPrint('Firebase: ready (project rotty-music)');
      return true;
    } catch (e, st) {
      debugPrint('Firebase init failed: $e\n$st');
      _useRestFallback = true;
      _ready = true;
      debugPrint('Firebase: REST Fallback enabled after native failure');
      return true;
    }
  }

  String get _uid {
    final custom = StorageService().customSyncId;
    if (custom.isNotEmpty) return custom;
    if (_useRestFallback) {
      return StorageService().installationId;
    }
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? StorageService().installationId;
    } catch (_) {
      return StorageService().installationId;
    }
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    if (_useRestFallback) {
      throw UnsupportedError('Auth is not supported on desktop REST fallback.');
    }
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
    if (_useRestFallback) {
      throw UnsupportedError('Auth is not supported on desktop REST fallback.');
    }
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
    if (_useRestFallback) {
      throw UnsupportedError('Auth is not supported on desktop REST fallback.');
    }
    _ensureReady();
    final cred = await FirebaseAuth.instance.signInAnonymously();
    await _ensureUserProfile(displayName: 'Guest');
    return cred;
  }

  Future<void> signOut() async {
    if (!_ready || _useRestFallback) return;
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _ensureUserProfile({String? email, String? phone, String? displayName}) async {
    if (!_ready) return;
    if (_useRestFallback) {
      await FirestoreRestClient.setDoc('users/$_uid', {
        if (email != null) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (displayName != null) 'displayName': displayName,
        'updatedAt': DateTime.now().toIso8601String(),
        'lastSeenAt': DateTime.now().toIso8601String(),
      }, merge: true);
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
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
    } catch (e) {
      debugPrint('Firestore native _ensureUserProfile error: $e. Falling back to REST.');
      _useRestFallback = true;
      await FirestoreRestClient.setDoc('users/$_uid', {
        if (email != null) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (displayName != null) 'displayName': displayName,
        'updatedAt': DateTime.now().toIso8601String(),
        'lastSeenAt': DateTime.now().toIso8601String(),
      }, merge: true);
    }
  }

  Future<void> syncUserData() async {
    if (!_ready) return;
    final storage = StorageService();
    final data = {
      'updatedAt': _useRestFallback ? DateTime.now().toIso8601String() : FieldValue.serverTimestamp(),
      'streak': storage.listeningStreak.days,
      'groqConfigured': storage.groqApiKey.isNotEmpty,
      'favoriteIds': storage.getFavorites().map((s) => s.id).toList(),
      'favoriteSongs': storage.getFavorites().map((s) => s.toJson()).toList(),
      'dislikedIds': storage.dislikedSongIds.toList(),
      'recentIds': storage.getRecentSongs().take(30).map((s) => s.id).toList(),
    };
    if (_useRestFallback) {
      await FirestoreRestClient.setDoc('users/$_uid', data, merge: true);
    } else {
      if (FirebaseAuth.instance.currentUser == null) return;
      try {
        await db!.collection('users').doc(_uid).set(data, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore native syncUserData error: $e. Falling back to REST.');
        _useRestFallback = true;
        data['updatedAt'] = DateTime.now().toIso8601String();
        await FirestoreRestClient.setDoc('users/$_uid', data, merge: true);
      }
    }
  }

  Future<void> pullUserData() async {
    if (!_ready) return;
    Map<String, dynamic>? data;
    if (_useRestFallback) {
      data = await FirestoreRestClient.getDoc('users/$_uid');
    } else {
      try {
        final snap = await db!.collection('users').doc(_uid).get();
        if (snap.exists) {
          data = snap.data();
        }
      } catch (e) {
        debugPrint('Firestore native pullUserData error: $e. Falling back to REST.');
        _useRestFallback = true;
        data = await FirestoreRestClient.getDoc('users/$_uid');
      }
    }
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
    final data = {
      'hostId': _uid,
      'queue': <Map<String, dynamic>>[],
      'nowPlaying': null,
      'isPlaying': false,
      'updatedAt': _useRestFallback ? DateTime.now().toIso8601String() : FieldValue.serverTimestamp(),
    };
    if (_useRestFallback) {
      await FirestoreRestClient.setDoc('party_rooms/$code', data);
    } else {
      try {
        await db!.collection('party_rooms').doc(code).set(data);
      } catch (e) {
        debugPrint('Firestore native createPartyRoom error: $e. Falling back to REST.');
        _useRestFallback = true;
        data['updatedAt'] = DateTime.now().toIso8601String();
        await FirestoreRestClient.setDoc('party_rooms/$code', data);
      }
    }
    return code;
  }

  Future<void> joinPartyRoom(String code) async {
    _ensureReady();
    if (_useRestFallback) {
      final doc = await FirestoreRestClient.getDoc('party_rooms/$code');
      if (doc == null) throw StateError('Party room not found');
    } else {
      try {
        final snap = await db!.collection('party_rooms').doc(code).get();
        if (!snap.exists) throw StateError('Party room not found');
      } catch (e) {
        debugPrint('Firestore native joinPartyRoom error: $e. Falling back to REST.');
        _useRestFallback = true;
        final doc = await FirestoreRestClient.getDoc('party_rooms/$code');
        if (doc == null) throw StateError('Party room not found');
      }
    }
  }

  Stream<List<SongModel>> watchPartyQueue(String code) async* {
    if (!_ready) return;
    if (_useRestFallback) {
      yield* _watchPartyQueueRest(code);
      return;
    }
    try {
      yield* db!.collection('party_rooms').doc(code).snapshots().map((snap) {
        final q = snap.data()?['queue'];
        if (q is! List) return <SongModel>[];
        return q
            .whereType<Map>()
            .map((e) => SongModel.fromHive(Map<String, dynamic>.from(e)))
            .toList();
      });
    } catch (e) {
      debugPrint('Firestore native watchPartyQueue stream error: $e. Falling back to REST.');
      _useRestFallback = true;
      yield* _watchPartyQueueRest(code);
    }
  }

  Stream<List<SongModel>> _watchPartyQueueRest(String code) {
    return Stream.periodic(const Duration(seconds: 3)).asyncMap((_) async {
      final doc = await FirestoreRestClient.getDoc('party_rooms/$code');
      if (doc == null) return <SongModel>[];
      final q = doc['queue'];
      if (q is! List) return <SongModel>[];
      return q
          .whereType<Map>()
          .map((e) => SongModel.fromHive(Map<String, dynamic>.from(e)))
          .toList();
    }).asBroadcastStream();
  }

  Stream<FirebasePartyRoom> watchPartyRoom(String code) async* {
    if (!_ready) return;
    if (_useRestFallback) {
      yield* _watchPartyRoomRest(code);
      return;
    }
    try {
      yield* db!.collection('party_rooms').doc(code).snapshots().map((snap) {
        final data = snap.data() ?? {};
        final q = data['queue'];
        final queue = q is List
            ? q
                .whereType<Map>()
                .map((e) => SongModel.fromHive(Map<String, dynamic>.from(e)))
                .toList()
            : <SongModel>[];
        final np = data['nowPlaying'];
        final nowPlaying = np is Map
            ? SongModel.fromHive(Map<String, dynamic>.from(np))
            : null;
        final isPlaying = data['isPlaying'] as bool? ?? false;
        return FirebasePartyRoom(queue: queue, nowPlaying: nowPlaying, isPlaying: isPlaying);
      });
    } catch (e) {
      debugPrint('Firestore native watchPartyRoom stream error: $e. Falling back to REST.');
      _useRestFallback = true;
      yield* _watchPartyRoomRest(code);
    }
  }

  Stream<FirebasePartyRoom> _watchPartyRoomRest(String code) {
    return Stream.periodic(const Duration(seconds: 3)).asyncMap((_) async {
      final data = await FirestoreRestClient.getDoc('party_rooms/$code') ?? {};
      final q = data['queue'];
      final queue = q is List
          ? q
              .whereType<Map>()
              .map((e) => SongModel.fromHive(Map<String, dynamic>.from(e)))
              .toList()
          : <SongModel>[];
      final np = data['nowPlaying'];
      final nowPlaying = np is Map
          ? SongModel.fromHive(Map<String, dynamic>.from(np))
          : null;
      final isPlaying = data['isPlaying'] as bool? ?? false;
      return FirebasePartyRoom(queue: queue, nowPlaying: nowPlaying, isPlaying: isPlaying);
    }).asBroadcastStream();
  }

  Future<void> pushPartyQueue(String code, List<SongModel> songs) async {
    if (!_ready) return;
    final data = {
      'queue': songs.map((s) => s.toJson()).toList(),
      'updatedAt': _useRestFallback ? DateTime.now().toIso8601String() : FieldValue.serverTimestamp(),
    };
    if (_useRestFallback) {
      await FirestoreRestClient.setDoc('party_rooms/$code', data, merge: true);
    } else {
      try {
        await db!.collection('party_rooms').doc(code).set(data, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore native pushPartyQueue error: $e. Falling back to REST.');
        _useRestFallback = true;
        data['updatedAt'] = DateTime.now().toIso8601String();
        await FirestoreRestClient.setDoc('party_rooms/$code', data, merge: true);
      }
    }
  }

  Future<void> updatePartyPlayback(String code, SongModel? song, bool isPlaying) async {
    if (!_ready) return;
    final data = {
      'nowPlaying': song?.toJson(),
      'isPlaying': isPlaying,
      'updatedAt': _useRestFallback ? DateTime.now().toIso8601String() : FieldValue.serverTimestamp(),
    };
    if (_useRestFallback) {
      await FirestoreRestClient.setDoc('party_rooms/$code', data, merge: true);
    } else {
      try {
        await db!.collection('party_rooms').doc(code).set(data, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore native updatePartyPlayback error: $e. Falling back to REST.');
        _useRestFallback = true;
        data['updatedAt'] = DateTime.now().toIso8601String();
        await FirestoreRestClient.setDoc('party_rooms/$code', data, merge: true);
      }
    }
  }

  Future<void> logPlay(SongModel song) async {
    if (!_ready) return;
    if (_useRestFallback) {
      await FirestoreRestClient.addDoc('users/$_uid/plays', {
        'songId': song.id,
        'title': song.title,
        'artist': song.artist,
        'at': DateTime.now().toIso8601String(),
      });
      return;
    }
    try {
      await db!.collection('users').doc(_uid).collection('plays').add({
        'songId': song.id,
        'title': song.title,
        'artist': song.artist,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore native logPlay error: $e. Falling back to REST.');
      _useRestFallback = true;
      await FirestoreRestClient.addDoc('users/$_uid/plays', {
        'songId': song.id,
        'title': song.title,
        'artist': song.artist,
        'at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<Map<String, dynamic>> checkKillSwitch() async {
    if (!_ready) return {'enabled': true};
    try {
      if (_useRestFallback) {
        final data = await FirestoreRestClient.getDoc('app_config/status');
        if (data == null) return {'enabled': true};
        return {
          'enabled': data['enabled'] ?? true,
          'message': data['message'] as String? ?? 'App is under maintenance. Please try again later.',
          'minVersion': data['minVersion'] as String?,
        };
      }
      final snap = await db!.collection('app_config').doc('status').get();
      if (!snap.exists) return {'enabled': true};
      final data = snap.data() ?? {};
      return {
        'enabled': data['enabled'] ?? true,
        'message': data['message'] as String? ?? 'App is under maintenance. Please try again later.',
        'minVersion': data['minVersion'] as String?,
      };
    } catch (e) {
      debugPrint('Kill switch check failed: $e');
      return {'enabled': true};
    }
  }

  void _ensureReady() {
    if (!_ready) throw StateError('Firebase not initialized');
  }
}

class FirebasePartyRoom {
  final List<SongModel> queue;
  final SongModel? nowPlaying;
  final bool isPlaying;

  FirebasePartyRoom({
    required this.queue,
    this.nowPlaying,
    this.isPlaying = false,
  });
}

class FirestoreRestClient {
  static const String projectId = 'rotty-music';
  static const String apiKey = 'AIzaSyDkD9uaVanSvrsAg_Myg7mYKW0GSjB0t7w';
  static const String baseUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  static Map<String, dynamic> encode(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is num) return {'doubleValue': value.toDouble()};
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map((item) => encode(item)).toList(),
        }
      };
    }
    if (value is Map) {
      final fields = <String, Map<String, dynamic>>{};
      value.forEach((k, v) {
        fields[k.toString()] = encode(v);
      });
      return {
        'mapValue': {
          'fields': fields,
        }
      };
    }
    return {'stringValue': value.toString()};
  }

  static dynamic decode(Map<String, dynamic> firestoreValue) {
    if (firestoreValue.containsKey('nullValue')) return null;
    if (firestoreValue.containsKey('stringValue')) return firestoreValue['stringValue'];
    if (firestoreValue.containsKey('booleanValue')) return firestoreValue['booleanValue'];
    if (firestoreValue.containsKey('doubleValue')) return firestoreValue['doubleValue'];
    if (firestoreValue.containsKey('integerValue')) return int.tryParse(firestoreValue['integerValue']?.toString() ?? '');
    if (firestoreValue.containsKey('arrayValue')) {
      final list = firestoreValue['arrayValue']['values'] as List?;
      if (list == null) return [];
      return list.map((item) => decode(Map<String, dynamic>.from(item))).toList();
    }
    if (firestoreValue.containsKey('mapValue')) {
      final fields = firestoreValue['mapValue']['fields'] as Map?;
      if (fields == null) return {};
      final result = <String, dynamic>{};
      fields.forEach((k, v) {
        result[k.toString()] = decode(Map<String, dynamic>.from(v));
      });
      return result;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getDoc(String path) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$path?key=$apiKey')).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final fields = body['fields'] as Map<String, dynamic>?;
        if (fields == null) return {};
        final result = <String, dynamic>{};
        fields.forEach((k, v) {
          result[k] = decode(Map<String, dynamic>.from(v));
        });
        return result;
      }
      return null;
    } catch (e) {
      debugPrint('REST getDoc error for $path: $e');
      return null;
    }
  }

  static Future<void> setDoc(String path, Map<String, dynamic> data, {bool merge = false}) async {
    try {
      final fields = <String, dynamic>{};
      data.forEach((k, v) {
        fields[k] = encode(v);
      });
      final body = json.encode({'fields': fields});
      
      String url = '$baseUrl/$path?key=$apiKey';
      if (merge) {
        for (final key in data.keys) {
          url += '&updateMask.fieldPaths=$key';
        }
      }
      await http.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('REST setDoc error for $path: $e');
    }
  }

  static Future<void> deleteDoc(String path) async {
    try {
      await http.delete(Uri.parse('$baseUrl/$path?key=$apiKey')).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('REST deleteDoc error for $path: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> listDocs(String collectionPath) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$collectionPath?key=$apiKey')).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final documents = body['documents'] as List?;
        if (documents == null) return [];
        final list = <Map<String, dynamic>>[];
        for (final doc in documents) {
          final fields = doc['fields'] as Map<String, dynamic>?;
          if (fields == null) continue;
          final docName = doc['name'] as String;
          final id = docName.split('/').last;
          final map = <String, dynamic>{'id': id};
          fields.forEach((k, v) {
            map[k] = decode(Map<String, dynamic>.from(v));
          });
          list.add(map);
        }
        return list;
      }
      return [];
    } catch (e) {
      debugPrint('REST listDocs error for $collectionPath: $e');
      return [];
    }
  }

  static Future<void> addDoc(String collectionPath, Map<String, dynamic> data) async {
    try {
      final fields = <String, dynamic>{};
      data.forEach((k, v) {
        fields[k] = encode(v);
      });
      final body = json.encode({'fields': fields});
      await http.post(
        Uri.parse('$baseUrl/$collectionPath?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('REST addDoc error for $collectionPath: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> queryCollection({
    required String collectionId,
    String? orderByField,
    bool descending = false,
    int? limit,
  }) async {
    try {
      final structuredQuery = <String, dynamic>{
        'from': [{'collectionId': collectionId}],
      };
      if (orderByField != null) {
        structuredQuery['orderBy'] = [{
          'field': {'fieldPath': orderByField},
          'direction': descending ? 'DESCENDING' : 'ASCENDING',
        }];
      }
      if (limit != null) {
        structuredQuery['limit'] = limit;
      }
      final queryBody = {
        'structuredQuery': structuredQuery,
      };
      final response = await http.post(
        Uri.parse('https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:runQuery?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(queryBody),
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List?;
        if (list == null) return [];
        final results = <Map<String, dynamic>>[];
        for (final item in list) {
          final doc = item['document'] as Map<String, dynamic>?;
          if (doc == null) continue;
          final fields = doc['fields'] as Map<String, dynamic>?;
          if (fields == null) continue;
          final docName = doc['name'] as String;
          final id = docName.split('/').last;
          final map = <String, dynamic>{'id': id};
          fields.forEach((k, v) {
            map[k] = decode(Map<String, dynamic>.from(v));
          });
          results.add(map);
        }
        return results;
      }
      return [];
    } catch (e) {
      debugPrint('REST queryCollection error: $e');
      return [];
    }
  }
}

