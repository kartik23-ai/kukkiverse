import 'package:http/http.dart' as http;
import 'package:rotty_music/services/api_service.dart';

void main() async {
  print('Starting download test...');
  final api = ApiService();
  
  print('Searching for song...');
  final songs = await api.searchSongs('Hawayein', limit: 1);
  if (songs.isEmpty) {
    print('No songs found!');
    return;
  }
  
  final song = songs.first;
  print('Found song: ${song.title} - ${song.artist}');
  print('Song URL: ${song.url}');
  
  if (song.url.isEmpty) {
    print('Song URL is empty. Attempting to fetch details...');
    final details = await api.getSongDetails(song.id);
    if (details != null) {
      print('Details URL: ${details.url}');
    } else {
      print('Failed to get song details.');
      return;
    }
  }

  final url = song.url;
  print('Attempting download from: $url');
  
  final client = http.Client();
  final request = http.Request('GET', Uri.parse(url));
  request.headers.addAll({
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
    'Referer': 'https://www.jiosaavn.com/',
  });

  try {
    print('Sending request...');
    final response = await client.send(request).timeout(Duration(seconds: 15));
    print('Response status code: ${response.statusCode}');
    print('Response content length: ${response.contentLength}');
    print('Response headers: ${response.headers}');
    
    if (response.statusCode != 200) {
      print('Download failed with status: ${response.statusCode}');
      return;
    }
    
    print('Reading response body stream...');
    int bytesReceived = 0;
    await response.stream.listen((chunk) {
      bytesReceived += chunk.length;
      print('Received chunk: ${chunk.length} bytes (Total: $bytesReceived)');
    }, onError: (e) {
      print('Error in stream: $e');
    }, onDone: () {
      print('Stream completed successfully! Received $bytesReceived bytes total.');
    }).asFuture();
  } catch (e, stack) {
    print('Exception occurred during download: $e');
    print(stack);
  } finally {
    client.close();
  }
}
