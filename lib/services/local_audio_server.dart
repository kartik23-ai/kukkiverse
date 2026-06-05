import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LocalAudioServer {
  static final LocalAudioServer _instance = LocalAudioServer._internal();
  factory LocalAudioServer() => _instance;
  LocalAudioServer._internal();

  HttpServer? _server;
  int? get port => _server?.port;

  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      debugPrint('ROTTY LOCAL SERVER: Started on http://127.0.0.1:$port');
      
      _server!.listen((HttpRequest request) async {
        try {
          final path = request.uri.path;
          if (path.startsWith('/downloads/')) {
            final fileName = Uri.decodeComponent(path.substring('/downloads/'.length));
            final docDir = await getApplicationDocumentsDirectory();
            final file = File('${docDir.path}/downloads/$fileName');
            
            if (await file.exists()) {
              final fileLength = await file.length();
              request.response.headers.add('Accept-Ranges', 'bytes');

              final extension = fileName.split('.').last.toLowerCase();
              final contentType = switch (extension) {
                'mp3' => ContentType('audio', 'mpeg'),
                'm4a' || 'mp4' => ContentType('audio', 'mp4'),
                _ => ContentType('audio', 'mpeg'),
              };
              request.response.headers.contentType = contentType;

              final rangeHeader = request.headers.value('range');
              if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
                final parts = rangeHeader.substring(6).split('-');
                final start = int.parse(parts[0]);
                final end = parts.length > 1 && parts[1].isNotEmpty
                    ? int.parse(parts[1])
                    : fileLength - 1;

                if (start >= 0 && end < fileLength && start <= end) {
                  request.response.statusCode = HttpStatus.partialContent;
                  request.response.headers.add(
                    'Content-Range',
                    'bytes $start-$end/$fileLength',
                  );
                  request.response.headers.contentLength = end - start + 1;
                  
                  final stream = file.openRead(start, end + 1);
                  await request.response.addStream(stream);
                  return;
                }
              }

              request.response.headers.contentLength = fileLength;
              await request.response.addStream(file.openRead());
            } else {
              request.response.statusCode = HttpStatus.notFound;
              request.response.write('File not found');
            }
          } else if (path.startsWith('/proxy')) {
            final targetUrl = request.uri.queryParameters['url'];
            if (targetUrl == null || targetUrl.isEmpty) {
              request.response.statusCode = HttpStatus.badRequest;
              request.response.write('URL is required');
              return;
            }

            final client = HttpClient();
            client.connectionTimeout = const Duration(seconds: 10);
            
            try {
              final uri = Uri.parse(targetUrl);
              final targetRequest = await client.getUrl(uri);
              
              // Forward headers from ExoPlayer/just_audio
              request.headers.forEach((name, values) {
                if (name.toLowerCase() != 'host' && name.toLowerCase() != 'user-agent') {
                  for (final val in values) {
                    targetRequest.headers.add(name, val);
                  }
                }
              });

              // Set browser-like headers for YouTube streams
              final isYt = targetUrl.contains('googlevideo.com') || targetUrl.contains('youtube.com') || targetUrl.contains('youtu.be');
              if (isYt) {
                targetRequest.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
                targetRequest.headers.set('Referer', 'https://www.youtube.com/');
              } else {
                final ua = request.headers.value('user-agent');
                if (ua != null) {
                  targetRequest.headers.set('User-Agent', ua);
                }
              }

              final targetResponse = await targetRequest.close();
              
              // Set headers back to ExoPlayer
              request.response.statusCode = targetResponse.statusCode;
              targetResponse.headers.forEach((name, values) {
                final lowerName = name.toLowerCase();
                if (['content-type', 'content-length', 'accept-ranges', 'content-range'].contains(lowerName)) {
                  for (final val in values) {
                    request.response.headers.add(name, val);
                  }
                }
              });

              await request.response.addStream(targetResponse);
            } catch (e) {
              debugPrint('ROTTY LOCAL SERVER: Proxy streaming error/interruption: $e');
            } finally {
              client.close(force: true);
            }
          } else {
            request.response.statusCode = HttpStatus.notFound;
            request.response.write('Not found');
          }
        } catch (e) {
          debugPrint('ROTTY LOCAL SERVER: Request error: $e');
          request.response.statusCode = HttpStatus.internalServerError;
        } finally {
          await request.response.close();
        }
      });
    } catch (e) {
      debugPrint('ROTTY LOCAL SERVER: Failed to start: $e');
    }
  }

  void stop() {
    _server?.close(force: true);
    _server = null;
  }
}
