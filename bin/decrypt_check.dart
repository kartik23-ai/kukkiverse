import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

void main() {
  const enc =
      'ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDyryhkSYK5IH2E7FCO52VR6yhNbcEbes5iCcja4+W8xhE0SwtCJToN4Bw7tS9a8Gtq';
  try {
    final key = Uint8List.fromList(utf8.encode('38346591'));
    final cipher = BlockCipher('DES/ECB/PKCS7')..init(false, KeyParameter(key));
    final out = cipher.process(Uint8List.fromList(base64.decode(enc)));
    print(utf8.decode(out));
  } catch (e, st) {
    print('ERR: $e\n$st');
  }
}
