import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/song_model.dart';
import 'firebase_service.dart';
import 'storage_service.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  final _supabase = Supabase.instance.client;

  Future<String> createPartyRoom() async {
    final code = 'ROTTY-${10000 + Random().nextInt(89999)}';
    final uid = FirebaseService.instance.userId;
    final name = StorageService().profileName.isEmpty ? 'Guest' : StorageService().profileName;

    // 1. Create room
    await _supabase.from('party_rooms').insert({
      'code': code,
      'host_id': uid,
      'is_playing': false,
      'now_playing': null,
      'queue': [],
      'updated_at': DateTime.now().toIso8601String(),
    });

    // 2. Add host as member
    await _supabase.from('party_members').insert({
      'room_code': code,
      'uid': uid,
      'name': name,
      'joined_at': DateTime.now().toIso8601String(),
    });

    return code;
  }

  Future<void> joinPartyRoom(String code) async {
    // Check if room exists
    final response = await _supabase.from('party_rooms').select('code').eq('code', code).maybeSingle();
    if (response == null) {
      throw StateError('Party room not found');
    }

    final uid = FirebaseService.instance.userId;
    final name = StorageService().profileName.isEmpty ? 'Guest' : StorageService().profileName;

    // Delete any pre-existing membership
    await _supabase.from('party_members').delete().eq('room_code', code).eq('uid', uid);

    // Join
    await _supabase.from('party_members').insert({
      'room_code': code,
      'uid': uid,
      'name': name,
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeMemberFromPartyRoom(String code) async {
    final uid = FirebaseService.instance.userId;
    await _supabase.from('party_members').delete().eq('room_code', code).eq('uid', uid);
  }

  Future<void> kickMemberFromPartyRoom(String code, String targetUid) async {
    await _supabase.from('party_members').delete().eq('room_code', code).eq('uid', targetUid);
  }

  Future<void> pushPartyQueue(String code, List<SongModel> songs) async {
    await _supabase.from('party_rooms').update({
      'queue': songs.map((s) => s.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('code', code);
  }

  Future<void> updatePartyPlayback(String code, SongModel? song, bool isPlaying) async {
    await _supabase.from('party_rooms').update({
      'now_playing': song?.toJson(),
      'is_playing': isPlaying,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('code', code);
  }

  Stream<FirebasePartyRoom> watchPartyRoom(String code) {
    return _supabase
        .from('party_rooms')
        .stream(primaryKey: ['code'])
        .eq('code', code)
        .map((maps) {
          if (maps.isEmpty) {
            return FirebasePartyRoom(queue: []);
          }
          final data = maps.first;
          
          final q = data['queue'];
          final List<SongModel> queue = [];
          if (q is List) {
            for (final item in q) {
              try {
                if (item is Map) {
                  queue.add(SongModel.fromHive(Map<String, dynamic>.from(item)));
                } else if (item is String) {
                  final decoded = json.decode(item);
                  if (decoded is Map) {
                    queue.add(SongModel.fromHive(Map<String, dynamic>.from(decoded)));
                  }
                }
              } catch (e) {
                debugPrint('ROTTY SUPABASE SYNC ERROR: Failed to parse queue item: $e');
              }
            }
          }

          final np = data['now_playing'];
          SongModel? nowPlaying;
          if (np is Map) {
            try {
              nowPlaying = SongModel.fromHive(Map<String, dynamic>.from(np));
            } catch (_) {}
          } else if (np is String && np.isNotEmpty) {
            try {
              final decoded = json.decode(np);
              if (decoded is Map) {
                nowPlaying = SongModel.fromHive(Map<String, dynamic>.from(decoded));
              }
            } catch (_) {}
          }

          final isPlaying = data['is_playing'] as bool? ?? false;
          final hostId = data['host_id'] as String?;
          return FirebasePartyRoom(
            queue: queue,
            nowPlaying: nowPlaying,
            isPlaying: isPlaying,
            hostId: hostId,
          );
        });
  }

  Stream<List<FirebasePartyMember>> watchPartyMembers(String code) {
    return _supabase
        .from('party_members')
        .stream(primaryKey: ['id'])
        .eq('room_code', code)
        .map((maps) {
          return maps.map((data) {
            return FirebasePartyMember(
              uid: data['uid'] as String,
              name: data['name'] as String? ?? 'Guest',
            );
          }).toList();
        });
  }

  Stream<bool> watchSelfMemberStatus(String code) {
    final uid = FirebaseService.instance.userId;
    return _supabase
        .from('party_members')
        .stream(primaryKey: ['id'])
        .eq('room_code', code)
        .map((maps) {
          return maps.any((data) => data['uid'] == uid);
        });
  }
}
