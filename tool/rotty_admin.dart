import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String projectId = 'rotty-music';
const String apiKey = 'AIzaSyDkD9uaVanSvrsAg_Myg7mYKW0GSjB0t7w';
const String baseUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

void main() async {
  print('\n======================================================');
  print('          ROTTY MUSIC - ADMIN CONTROL PANEL          ');
  print('======================================================');
  
  while (true) {
    print('\nSelect an administrative task:');
    print('1. List All Users & Supporter Status');
    print('2. Grant/Revoke Supporter Badge (Unlock VIP Status)');
    print('3. Send targeted notification to a single User');
    print('4. Broadcast MASS Notification to ALL Users');
    print('5. Exit Panel');
    stdout.write('\nEnter your choice (1-5): ');
    
    final choice = stdin.readLineSync()?.trim();
    
    if (choice == '1') {
      await listAllUsers();
    } else if (choice == '2') {
      await updateSupporterStatus();
    } else if (choice == '3') {
      await sendSingleNotification();
    } else if (choice == '4') {
      await broadcastMassNotification();
    } else if (choice == '5') {
      print('\nExiting Admin Panel. Have a great launch! 🚀\n');
      break;
    } else {
      print('\nInvalid choice. Please select between 1 and 5.');
    }
  }
}

/// Dynamic encoder for Firestore REST API format
Map<String, dynamic> encodeValue(dynamic value) {
  if (value == null) return {'nullValue': null};
  if (value is String) return {'stringValue': value};
  if (value is bool) return {'booleanValue': value};
  if (value is num) return {'doubleValue': value.toDouble()};
  if (value is List) {
    return {
      'arrayValue': {
        'values': value.map((item) => encodeValue(item)).toList(),
      }
    };
  }
  if (value is Map) {
    final fields = <String, Map<String, dynamic>>{};
    value.forEach((k, v) {
      fields[k.toString()] = encodeValue(v);
    });
    return {
      'mapValue': {
        'fields': fields,
      }
    };
  }
  return {'stringValue': value.toString()};
}

/// Dynamic decoder for Firestore REST API format
dynamic decodeValue(Map<String, dynamic> firestoreValue) {
  if (firestoreValue.containsKey('nullValue')) return null;
  if (firestoreValue.containsKey('stringValue')) return firestoreValue['stringValue'];
  if (firestoreValue.containsKey('booleanValue')) return firestoreValue['booleanValue'];
  if (firestoreValue.containsKey('doubleValue')) return firestoreValue['doubleValue'];
  if (firestoreValue.containsKey('integerValue')) return int.tryParse(firestoreValue['integerValue']?.toString() ?? '');
  if (firestoreValue.containsKey('arrayValue')) {
    final list = firestoreValue['arrayValue']['values'] as List?;
    if (list == null) return [];
    return list.map((item) => decodeValue(Map<String, dynamic>.from(item))).toList();
  }
  if (firestoreValue.containsKey('mapValue')) {
    final fields = firestoreValue['mapValue']['fields'] as Map?;
    if (fields == null) return {};
    final result = <String, dynamic>{};
    fields.forEach((k, v) {
      result[k.toString()] = decodeValue(Map<String, dynamic>.from(v));
    });
    return result;
  }
  return null;
}

/// Retrieves all users from Firestore
Future<List<Map<String, dynamic>>> fetchUsers() async {
  final users = <String, Map<String, dynamic>>{};
  try {
    final res = await http.get(Uri.parse('$baseUrl/users?key=$apiKey')).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
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
              decoded[k] = decodeValue(Map<String, dynamic>.from(v));
            });
            users[uid] = decoded;
          }
        }
      }
    }
  } catch (e) {
    print('Error fetching users: $e');
  }
  return users.values.toList();
}

/// Command 1: List all users
Future<void> listAllUsers() async {
  print('\nFetching user accounts from live database...');
  final users = await fetchUsers();
  if (users.isEmpty) {
    print('\nNo registered users found in Firestore.');
    return;
  }
  
  print('\n---------------- ROTTY MUSIC USERS LIST ----------------');
  for (var i = 0; i < users.length; i++) {
    final u = users[i];
    final supporterStatus = (u['is_supporter'] == true) ? '★ SUPPORTER (VIP)' : 'FREE USER';
    final email = u['email'] ?? 'No Email';
    final name = u['username'] ?? 'User';
    print('[${i + 1}] Email: $email | Name: $name | UID: ${u['uid']} | Status: $supporterStatus');
  }
  print('--------------------------------------------------------');
}

/// Command 2: Unlock/Lock VIP Supporter status
Future<void> updateSupporterStatus() async {
  final users = await fetchUsers();
  if (users.isEmpty) {
    print('\nNo users found to upgrade.');
    return;
  }
  
  stdout.write('\nEnter target user\'s email or UID: ');
  final input = stdin.readLineSync()?.trim();
  if (input == null || input.isEmpty) return;
  
  Map<String, dynamic>? targetUser;
  for (final u in users) {
    if (u['uid'] == input || u['email']?.toString().toLowerCase() == input.toLowerCase()) {
      targetUser = u;
      break;
    }
  }
  
  if (targetUser == null) {
    print('\nUser with ID or Email "$input" not found in Firestore.');
    return;
  }
  
  final currentStatus = targetUser['is_supporter'] == true;
  print('\nSelected User: ${targetUser['username']} (${targetUser['email']})');
  print('Current Status: ${currentStatus ? 'SUPPORTER (VIP)' : 'FREE USER'}');
  
  stdout.write('Do you want to unlock Supporter status for this user? (yes/no): ');
  final confirm = stdin.readLineSync()?.trim().toLowerCase();
  
  if (confirm == 'yes' || confirm == 'y') {
    final uid = targetUser['uid'];
    final success = await setSupporterField(uid, true);
    if (success) {
      print('\n🎉 Success! Supporter VIP badge has been successfully unlocked for ${targetUser['email']}!');
    }
  } else if (confirm == 'no' || confirm == 'n') {
    final uid = targetUser['uid'];
    final success = await setSupporterField(uid, false);
    if (success) {
      print('\nSupporter status revoked. User is now back to free tier.');
    }
  }
}

Future<bool> setSupporterField(String uid, bool isSupporter) async {
  try {
    final fields = {'is_supporter': encodeValue(isSupporter)};
    final body = json.encode({'fields': fields});
    final res = await http.patch(
      Uri.parse('$baseUrl/users/$uid?updateMask.fieldPaths=is_supporter&key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 8));
    
    return res.statusCode == 200;
  } catch (e) {
    print('Failed to write supporter field: $e');
    return false;
  }
}

/// Command 3: Send single targeted notification
Future<void> sendSingleNotification() async {
  final users = await fetchUsers();
  if (users.isEmpty) {
    print('\nNo users found in database.');
    return;
  }
  
  stdout.write('\nEnter target user\'s email or UID: ');
  final input = stdin.readLineSync()?.trim();
  if (input == null || input.isEmpty) return;
  
  Map<String, dynamic>? targetUser;
  for (final u in users) {
    if (u['uid'] == input || u['email']?.toString().toLowerCase() == input.toLowerCase()) {
      targetUser = u;
      break;
    }
  }
  
  if (targetUser == null) {
    print('\nUser with ID or Email "$input" not found in Firestore.');
    return;
  }
  
  print('\nSending notification to: ${targetUser['username']} (${targetUser['email']})');
  await triggerNotificationForm(targetUser['uid']);
}

/// Form builder for sending notifications
Future<void> triggerNotificationForm(String uid) async {
  stdout.write('Enter Notification Title: ');
  final title = stdin.readLineSync()?.trim();
  if (title == null || title.isEmpty) return;
  
  stdout.write('Enter Notification Body Message: ');
  final message = stdin.readLineSync()?.trim();
  if (message == null || message.isEmpty) return;
  
  stdout.write('Enter Redirection Route (Optional, e.g. /settings, press enter to skip): ');
  final route = stdin.readLineSync()?.trim();
  
  final success = await pushNotificationToFirestore(uid, title, message, route: route);
  if (success) {
    print('\n🔔 Notification successfully dispatched! User will see the glassmorphic toast instantly.');
  } else {
    print('\nFailed to dispatch notification. Please check database permissions or internet.');
  }
}

/// Writes notification document to Firestore
Future<bool> pushNotificationToFirestore(String uid, String title, String bodyText, {String? route}) async {
  try {
    final now = DateTime.now().toIso8601String();
    final docId = 'notif_${DateTime.now().millisecondsSinceEpoch}';
    
    final fields = {
      'id': encodeValue(docId),
      'title': encodeValue(title),
      'body': encodeValue(bodyText),
      'createdAt': encodeValue(now),
    };
    
    if (route != null && route.isNotEmpty) {
      fields['route'] = encodeValue(route);
    }
    
    final body = json.encode({'fields': fields});
    
    final res = await http.post(
      Uri.parse('$baseUrl/users/$uid/notifications?documentId=$docId&key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 8));
    
    return res.statusCode == 200;
  } catch (e) {
    print('Exception sending notification: $e');
    return false;
  }
}

/// Command 4: MASS Broadcast Notifications
Future<void> broadcastMassNotification() async {
  print('\nFetching all target users from live database...');
  final users = await fetchUsers();
  if (users.isEmpty) {
    print('\nNo registered users found to broadcast to.');
    return;
  }
  
  print('\n⚠️ WARNING: You are about to broadcast a MASS Notification to ALL ${users.length} registered users!');
  stdout.write('Enter Notification Title: ');
  final title = stdin.readLineSync()?.trim();
  if (title == null || title.isEmpty) return;
  
  stdout.write('Enter Notification Body Message: ');
  final message = stdin.readLineSync()?.trim();
  if (message == null || message.isEmpty) return;
  
  stdout.write('Enter Redirection Route (Optional, press enter to skip): ');
  final route = stdin.readLineSync()?.trim();
  
  stdout.write('\nAre you sure you want to broadcast this message to ALL ${users.length} users? (yes/no): ');
  final confirm = stdin.readLineSync()?.trim().toLowerCase();
  
  if (confirm == 'yes' || confirm == 'y') {
    print('\nBroadcasting messages in queue...');
    var successCount = 0;
    
    for (final u in users) {
      final uid = u['uid'];
      final email = u['email'] ?? 'No Email';
      stdout.write('Sending to $email... ');
      
      final success = await pushNotificationToFirestore(uid, title, message, route: route);
      if (success) {
        print('✅ Sent');
        successCount++;
      } else {
        print('❌ Failed');
      }
    }
    
    print('\n================ BROADCAST COMPLETION SUMMARY ================');
    print('Successfully dispatched notifications to: $successCount / ${users.length} users.');
    print('==============================================================\n');
  } else {
    print('\nMass broadcast cancelled by administrator.');
  }
}
