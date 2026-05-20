import 'package:flutter_test/flutter_test.dart';
import 'package:rotty_music/models/song_model.dart';

void main() {
  test('decrypt produces akamaized or saavncdn url', () {
    const enc =
        'ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDyryhkSYK5IH2E7FCO52VR6yhNbcEbes5iCcja4+W8xhE0SwtCJToN4Bw7tS9a8Gtq';
    final song = SongModel.fromSaavnWeb({
      'id': 'rjkrTnma',
      'song': 'Kesariya',
      'primary_artists': 'Arijit',
      'album': 'Brahmastra',
      'image': '',
      'duration': '268',
      'encrypted_media_url': enc,
      '320kbps': 'true',
    });
    print('URL: ${song.url}');
    expect(song.hasPlayableUrl, true);
    expect(song.url.contains('saavn'), true);
    expect(song.url, isNot(contains('preview.saavncdn.com')));
  });
}
