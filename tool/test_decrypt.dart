import 'package:rotty_music/models/song_model.dart';

void main() {
  const enc = 'ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDyryhkSYK5IH2E7FCO52VR6yhNbcEbes5iCcja4+W8xhE0SwtCJToN4Bw7tS9a8Gtq';
  final song = SongModel.fromSaavnWeb({
    'id': 'test',
    'song': 'Test',
    'primary_artists': 'Artist',
    'album': 'Alb',
    'image': '',
    'duration': '200',
    'encrypted_media_url': enc,
    'media_preview_url': 'https://preview.saavncdn.com/871/kZs0TCfjYI5zhsqMesydF9I9qSvwi0WcROt_96_p.mp4',
    '320kbps': 'true',
  });
  print('url: ${song.url}');
  print('hasPlayable: ${song.hasPlayableUrl}');
}
