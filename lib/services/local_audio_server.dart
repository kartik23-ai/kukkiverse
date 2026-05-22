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
              request.response.headers.contentType = ContentType('audio', 'mpeg');

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
