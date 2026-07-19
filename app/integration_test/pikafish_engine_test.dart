// Step 4.1 acceptance (mirrors 0.6 for Rapfi): drive Pikafish through Dart
// FFI on a real device/simulator and get back a legal-looking move for the
// Xiangqi starting position, with the bundled NNUE network wired up.
import 'package:chess_practice/engine/pikafish_assets.dart';
import 'package:chess_practice/engine/pikafish_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Pikafish answers the Xiangqi opening position through FFI',
      (tester) async {
    final evalFile = await const PikafishAssets().ensureNetworkFile();

    final uciLog = await PikafishEngine.instance.start(evalFile: evalFile);
    expect(uciLog, isNotNull, reason: 'uci handshake should not time out');
    expect(uciLog!.any((l) => l.startsWith('uciok')), isTrue);

    PikafishEngine.instance.newGame();
    PikafishEngine.instance.setPosition();
    final (bestMove, _, log) = await PikafishEngine.instance.goMoveTime(2000);

    expect(bestMove, isNotNull, reason: '引擎应该在开局给出一步棋，而不是超时: $log');
    // UCI Xiangqi move notation: file a-i + rank 0-9, twice (from-square,
    // to-square), e.g. "h2e2".
    expect(RegExp(r'^[a-i][0-9][a-i][0-9]$').hasMatch(bestMove!), isTrue,
        reason: '走法格式应为 UCI 坐标（如 h2e2），实际: $bestMove');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
