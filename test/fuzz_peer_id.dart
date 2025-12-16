// ignore_for_file: avoid_print
import 'package:p2plib/p2plib.dart';

void main() {
  print('Testing PeerId lengths...');
  for (var i = 0; i < 100; i++) {
    try {
      final bytes = Uint8List(i);
      final id = PeerId(value: bytes);
      print(
        'Length $i: PASS - Created PeerId: ${id.toString().substring(0, 10)}...',
      );
    } catch (e) {
      // print('Length $i: FAIL - $e');
    }
  }
}
