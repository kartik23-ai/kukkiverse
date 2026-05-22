import 'package:flutter_test/flutter_test.dart';
import 'package:rotty_music/services/api_service.dart';
import 'package:http/http.dart' as http;

void main() {
  test('Test Song Search and URL Resolution and Download', () async {
    final api = ApiService();
    final songs = await api.searchSongs('Hawayein', limit: 1);
    expect(songs.isNotEmpty, true);
    final song = songs.first;
    var url = song.url;
    if (url.isEmpty) {
      final details = await api.getSongDetails(song.id);
      url = details!.url;
    }
    expect(url.isNotEmpty, true);
    final client = http.Client();
    final response = await client.send(http.Request('GET', Uri.parse(url)));
    expect(response.statusCode, 200);
    int bytesReceived = 0;
    await response.stream.forEach((chunk) {
      bytesReceived += chunk.length;
    });
    expect(bytesReceived > 0, true);
    client.close();
  }, skip: 'Requires live internet connection and can be slow');
}
