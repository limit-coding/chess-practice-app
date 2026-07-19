// Dart FFI bindings for the Pikafish C bridge
// (native/wrapper/pikafish_bridge.h) — a standard UCI client. Same
// threading rules as RapfiEngine (see rapfi_ffi.dart): `recv` blocks, so
// every read happens off the UI isolate.
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

typedef _StartC = Int32 Function();
typedef _StartDart = int Function();
typedef _SendC = Void Function(Pointer<Utf8>);
typedef _SendDart = void Function(Pointer<Utf8>);
typedef _RecvC = Int32 Function(Pointer<Utf8>, Int32, Int32);
typedef _RecvDart = int Function(Pointer<Utf8>, int, int);

class _Bindings {
  _Bindings() {
    final lib = Platform.isIOS || Platform.isMacOS
        ? DynamicLibrary.process()
        : DynamicLibrary.open('libpikafish_core.so');
    start = lib.lookupFunction<_StartC, _StartDart>('pikafish_start');
    send = lib.lookupFunction<_SendC, _SendDart>('pikafish_send');
    recv = lib.lookupFunction<_RecvC, _RecvDart>('pikafish_recv');
  }

  late final _StartDart start;
  late final _SendDart send;
  late final _RecvDart recv;
}

/// Line-oriented UCI client for the in-process Pikafish engine. Stays at
/// the raw protocol level (position strings, move strings) rather than
/// modeling Xiangqi positions/moves itself — that belongs to the game-state
/// layer built on top of this (see RapfiEngine/GomokuGame for the Gomoku
/// equivalent split).
class PikafishEngine {
  static final PikafishEngine instance = PikafishEngine._();
  PikafishEngine._();

  static final _Bindings _b = _Bindings();
  bool _started = false;

  void _send(String line) {
    final p = line.toNativeUtf8();
    try {
      _b.send(p);
    } finally {
      malloc.free(p);
    }
  }

  static String? _recvLine(int timeoutMs) {
    final buf = malloc.allocate<Utf8>(4096);
    try {
      final n = _b.recv(buf, 4096, timeoutMs);
      if (n < 0) return null;
      return buf.toDartString();
    } finally {
      malloc.free(buf);
    }
  }

  /// Reads lines until one starts with [until], returning every line seen
  /// (including the terminal one). `null` on timeout.
  static List<String>? _readUntil(String until, int timeoutMs) {
    final log = <String>[];
    for (;;) {
      final line = _recvLine(timeoutMs);
      if (line == null) return null;
      log.add(line);
      if (line.startsWith(until)) return log;
    }
  }

  static Future<List<String>?> _await(String until, int timeoutMs) {
    return Isolate.run(() => _readUntil(until, timeoutMs));
  }

  /// Starts the engine thread and performs the `uci` handshake. [evalFile]
  /// is the absolute path to the NNUE network (see
  /// `PikafishAssets.ensureNetworkFile`); pass it every time since the
  /// engine process may not persist it across app restarts in the same way
  /// a native install would. Returns the full `uci` response (option list
  /// etc.) for diagnostics.
  Future<List<String>?> start({required String evalFile}) async {
    if (!_started) {
      _b.start();
      _started = true;
    }
    _send('uci');
    final uciLog = await _await('uciok', 10000);
    _send('setoption name EvalFile value $evalFile');
    _send('isready');
    await _await('readyok', 30000);
    return uciLog;
  }

  /// `ucinewgame` — clears hash/history between unrelated games.
  void newGame() => _send('ucinewgame');

  /// Sets the position via `position startpos [moves ...]` or
  /// `position fen <fen> [moves ...]`.
  void setPosition({String? fen, List<String> moves = const []}) {
    final base = fen == null ? 'startpos' : 'fen $fen';
    final movesPart = moves.isEmpty ? '' : ' moves ${moves.join(' ')}';
    _send('position $base$movesPart');
  }

  /// `go movetime <ms>`, returning `(bestMove, ponderMove?, infoLines)`.
  /// `bestMove` is `null` on timeout or if the engine has no legal move.
  Future<(String?, String?, List<String>)> goMoveTime(
    int ms, {
    int timeoutMs = 60000,
  }) async {
    _send('go movetime $ms');
    final log = await _await('bestmove', timeoutMs);
    if (log == null) return (null, null, <String>[]);

    final last = log.last;
    final match = RegExp(r'^bestmove (\S+)(?: ponder (\S+))?').firstMatch(last);
    if (match == null) return (null, null, log);
    return (match.group(1), match.group(2), log);
  }
}
