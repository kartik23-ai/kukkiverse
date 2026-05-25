import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'firebase_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// Rotty Connect — Cross-device playback sync engine
/// Uses Firestore for real-time state sync between phone ↔ PC
///
/// Data structure in Firestore:
/// /rotty_connect/{userId}/
///   devices/{deviceId}: { name, type, online, lastSeen }
///   playback: { songId, title, artist, image, positionMs, durationMs, isPlaying, updatedAt }
///   commands/{commandId}: { action, from, timestamp }
/// ═══════════════════════════════════════════════════════════════

enum DeviceType { mobile, desktop }
enum ConnectCommand { play, pause, next, prev, seekTo, volume }

DateTime _parseDateTime(dynamic val) {
  if (val == null) return DateTime.now();
  if (val is Timestamp) return val.toDate();
  if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
  return DateTime.now();
}

class ConnectedDevice {
  final String id;
  final String name;
  final DeviceType type;
  final bool online;
  final DateTime lastSeen;

  ConnectedDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.online,
    required this.lastSeen,
  });

  factory ConnectedDevice.fromMap(String id, Map<String, dynamic> map) {
    return ConnectedDevice(
      id: id,
      name: map['name'] ?? 'Unknown',
      type: map['type'] == 'desktop' ? DeviceType.desktop : DeviceType.mobile,
      online: map['online'] ?? false,
      lastSeen: _parseDateTime(map['lastSeen']),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type == DeviceType.desktop ? 'desktop' : 'mobile',
    'online': online,
    'lastSeen': FirebaseService.instance.useRestFallback ? DateTime.now().toIso8601String() : FieldValue.serverTimestamp(),
  };
}

class RemotePlaybackState {
  final String? songId;
  final String? title;
  final String? artist;
  final String? image;
  final int positionMs;
  final int durationMs;
  final bool isPlaying;
  final DateTime updatedAt;

  RemotePlaybackState({
    this.songId,
    this.title,
    this.artist,
    this.image,
    this.positionMs = 0,
    this.durationMs = 0,
    this.isPlaying = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory RemotePlaybackState.fromMap(Map<String, dynamic> map) {
    return RemotePlaybackState(
      songId: map['songId'],
      title: map['title'],
      artist: map['artist'],
      image: map['image'],
      positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      isPlaying: map['isPlaying'] ?? false,
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'songId': songId,
    'title': title,
    'artist': artist,
    'image': image,
    'positionMs': positionMs,
    'durationMs': durationMs,
    'isPlaying': isPlaying,
    'updatedAt': FirebaseService.instance.useRestFallback ? DateTime.now().toIso8601String() : FieldValue.serverTimestamp(),
  };
}


class RottyConnectService {
  RottyConnectService._();
  static final instance = RottyConnectService._();

  late String _userId;
  late String _deviceId;
  late DeviceType _deviceType;
  late String _deviceName;

  FirebaseFirestore get _db {
    if (FirebaseService.instance.useRestFallback) {
      throw UnsupportedError('Firestore is not supported natively when REST fallback is enabled.');
    }
    return FirebaseFirestore.instance;
  }
  DocumentReference get _userDoc => _db.collection('rotty_connect').doc(_userId);
  CollectionReference get _devicesCol => _userDoc.collection('devices');
  DocumentReference get _playbackDoc => _userDoc.collection('state').doc('playback');
  CollectionReference get _commandsCol => _userDoc.collection('commands');

  StreamSubscription? _commandSub;
  Timer? _heartbeatTimer;
  Timer? _playbackSyncTimer;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize with user ID (from FirebaseAuth or storage)
  Future<void> init(String userId) async {
    _userId = userId;
    // Use SharedPreferences for device ID persistence
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('rotty_device_id') ??
        const Uuid().v4();
    await prefs.setString('rotty_device_id', _deviceId);

    // Detect platform
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _deviceType = DeviceType.desktop;
      _deviceName = Platform.localHostname;
    } else {
      _deviceType = DeviceType.mobile;
      _deviceName = 'Phone';
    }

    final devData = ConnectedDevice(
      id: _deviceId,
      name: _deviceName,
      type: _deviceType,
      online: true,
      lastSeen: DateTime.now(),
    ).toMap();

    // Register this device
    if (FirebaseService.instance.useRestFallback) {
      await FirestoreRestClient.setDoc('rotty_connect/$_userId/devices/$_deviceId', devData);
    } else {
      await _devicesCol.doc(_deviceId).set(devData);
    }

    // Heartbeat every 30 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final updateData = {
        'online': true,
        'lastSeen': FirebaseService.instance.useRestFallback ? DateTime.now().toIso8601String() : FieldValue.serverTimestamp(),
      };
      if (FirebaseService.instance.useRestFallback) {
        await FirestoreRestClient.setDoc('rotty_connect/$_userId/devices/$_deviceId', updateData, merge: true);
      } else {
        await _devicesCol.doc(_deviceId).update(updateData);
      }
    });

    _initialized = true;
    debugPrint('[RottyConnect] Initialized: $_deviceName ($_deviceId)');
  }

  /// Get real-time stream of connected devices
  Stream<List<ConnectedDevice>> watchDevices() {
    if (FirebaseService.instance.useRestFallback) {
      return Stream.periodic(const Duration(seconds: 3)).asyncMap((_) async {
        final docs = await FirestoreRestClient.listDocs('rotty_connect/$_userId/devices');
        return docs.map((d) {
          final id = d['id'] as String;
          return ConnectedDevice.fromMap(id, d);
        }).toList();
      }).asBroadcastStream();
    }
    return _devicesCol.snapshots().map((snap) =>
        snap.docs.map((d) => ConnectedDevice.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
  }

  /// Get real-time stream of remote playback state
  Stream<RemotePlaybackState?> watchPlayback() {
    if (FirebaseService.instance.useRestFallback) {
      return Stream.periodic(const Duration(seconds: 3)).asyncMap((_) async {
        final doc = await FirestoreRestClient.getDoc('rotty_connect/$_userId/state/playback');
        if (doc == null || doc.isEmpty) return null;
        return RemotePlaybackState.fromMap(doc);
      }).asBroadcastStream();
    }
    return _playbackDoc.snapshots().map((snap) {
      if (!snap.exists) return null;
      return RemotePlaybackState.fromMap(snap.data() as Map<String, dynamic>);
    });
  }

  /// Update this device's playback state (called by the active player)
  Future<void> updatePlayback({
    required String songId,
    required String title,
    required String artist,
    required String image,
    required int positionMs,
    required int durationMs,
    required bool isPlaying,
  }) async {
    final data = {
      'songId': songId,
      'title': title,
      'artist': artist,
      'image': image,
      'positionMs': positionMs,
      'durationMs': durationMs,
      'isPlaying': isPlaying,
      'activeDevice': _deviceId,
      'updatedAt': FirebaseService.instance.useRestFallback ? DateTime.now().toIso8601String() : FieldValue.serverTimestamp(),
    };
    if (FirebaseService.instance.useRestFallback) {
      await FirestoreRestClient.setDoc('rotty_connect/$_userId/state/playback', data);
    } else {
      await _playbackDoc.set(data);
    }
  }

  /// Send a command to the remote device (e.g., phone → PC "next")
  Future<void> sendCommand(ConnectCommand cmd, {int? value}) async {
    final data = {
      'action': cmd.name,
      'from': _deviceId,
      'value': value,
      'timestamp': FirebaseService.instance.useRestFallback ? DateTime.now().toIso8601String() : FieldValue.serverTimestamp(),
    };
    if (FirebaseService.instance.useRestFallback) {
      await FirestoreRestClient.addDoc('rotty_connect/$_userId/commands', data);
    } else {
      await _commandsCol.add(data);
    }
  }

  /// Listen for incoming commands (the active player calls this)
  void listenForCommands(void Function(ConnectCommand cmd, int? value) onCommand) {
    _commandSub?.cancel();
    if (FirebaseService.instance.useRestFallback) {
      _commandSub = Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
        return await FirestoreRestClient.listDocs('rotty_connect/$_userId/commands');
      }).listen((docs) {
        if (docs.isEmpty) return;
        for (final doc in docs) {
          final from = doc['from'] as String?;
          if (from == _deviceId) continue;
          
          final action = doc['action'] as String?;
          final value = (doc['value'] as num?)?.toInt();
          if (action != null) {
            final cmd = ConnectCommand.values.firstWhere(
              (c) => c.name == action,
              orElse: () => ConnectCommand.play,
            );
            onCommand(cmd, value);
          }
          final id = doc['id'] as String;
          FirestoreRestClient.deleteDoc('rotty_connect/$_userId/commands/$id');
        }
      });
      return;
    }

    _commandSub = _commandsCol
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      for (final doc in snap.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          if (data['from'] == _deviceId) continue;
          final action = data['action'] as String?;
          final value = (data['value'] as num?)?.toInt();
          if (action != null) {
            final cmd = ConnectCommand.values.firstWhere(
              (c) => c.name == action,
              orElse: () => ConnectCommand.play,
            );
            onCommand(cmd, value);
          }
          doc.doc.reference.delete();
        }
      }
    });
  }

  /// Set this device as the active playback device
  Future<void> setActiveDevice() async {
    final data = {'activeDevice': _deviceId};
    if (FirebaseService.instance.useRestFallback) {
      await FirestoreRestClient.setDoc('rotty_connect/$_userId', data, merge: true);
    } else {
      await _userDoc.set(data, SetOptions(merge: true));
    }
  }

  /// Check if this device is the active player
  Future<bool> isActiveDevice() async {
    if (FirebaseService.instance.useRestFallback) {
      final doc = await FirestoreRestClient.getDoc('rotty_connect/$_userId');
      return doc?['activeDevice'] == _deviceId;
    }
    final snap = await _userDoc.get();
    final data = snap.data() as Map<String, dynamic>?;
    return data?['activeDevice'] == _deviceId;
  }

  /// Cleanup on app close
  Future<void> dispose() async {
    _commandSub?.cancel();
    _heartbeatTimer?.cancel();
    _playbackSyncTimer?.cancel();
    final updateData = {
      'online': false,
      'lastSeen': FirebaseService.instance.useRestFallback ? DateTime.now().toIso8601String() : FieldValue.serverTimestamp(),
    };
    if (FirebaseService.instance.useRestFallback) {
      await FirestoreRestClient.setDoc('rotty_connect/$_userId/devices/$_deviceId', updateData, merge: true);
    } else {
      await _devicesCol.doc(_deviceId).update(updateData);
    }
  }
}
