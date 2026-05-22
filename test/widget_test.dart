import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rotty_music/models/song_model.dart';
import 'package:rotty_music/widgets/desktop_song_row.dart';
import 'package:rotty_music/providers/providers.dart';
import 'package:rotty_music/services/storage_service.dart';

void main() {
  testWidgets('DesktopSongRow widget rendering test', (WidgetTester tester) async {
    final song = SongModel(
      id: 'test_song_123',
      title: 'Test Title',
      artist: 'Test Artist',
      album: 'Test Album',
      image: '',
      duration: const Duration(seconds: 180),
      url: 'https://example.com/test.mp3',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadNotifierProvider.overrideWith((ref) => DownloadNotifierMock()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DesktopSongRow(
              song: song,
              playlist: [song],
            ),
          ),
        ),
      ),
    );

    // Verify song title and artist are rendered.
    expect(find.text('Test Title'), findsOneWidget);
    expect(find.text('Test Artist'), findsOneWidget);
  });
}

class DownloadNotifierMock extends StateNotifier<Map<String, DownloadState>> implements DownloadNotifier {
  DownloadNotifierMock() : super({});

  @override
  StorageService get _storage => throw UnimplementedError();

  @override
  Map<String, DownloadState> get currentStates => state;

  @override
  void _init() {}

  @override
  void updateProgress(String id, double progress) {}

  @override
  void setDownloaded(String id) {}

  @override
  void setFailed(String id) {}

  @override
  void setRemoved(String id) {}
}
