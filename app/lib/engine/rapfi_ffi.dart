// Dart FFI bindings for the Rapfi C bridge (native/wrapper/rapfi_bridge.h).
//
// The engine runs on its own native thread inside the process; `recv` blocks,
// so callers must invoke it off the UI isolate (see RapfiEngine.bestMove).
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
        : DynamicLibrary.open('librapfi_core.so');
    start = lib.lookupFunction<_StartC, _StartDart>('rapfi_start');
    send = lib.lookupFunction<_SendC, _SendDart>('rapfi_send');
    recv = lib.lookupFunction<_RecvC, _RecvDart>('rapfi_recv');
  }

  late final _StartDart start;
  late final _SendDart send;
  late final _RecvDart recv;
}

/// Line-oriented Gomocup-protocol client for the in-process engine.
class RapfiEngine {
  static final RapfiEngine instance = RapfiEngine._();
  RapfiEngine._();

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
    final buf = malloc.allocate<Utf8>(1024);
    try {
      final n = _b.recv(buf, 1024, timeoutMs);
      if (n < 0) return null;
      return buf.toDartString();
    } finally {
      malloc.free(buf);
    }
  }

  /// Reads lines until a move ("x,y") or OK/ERROR shows up.
  /// MESSAGE/DEBUG lines are collected into [log].
  static String? _readReply(List<String> log, int timeoutMs) {
    for (;;) {
      final line = _recvLine(timeoutMs);
      if (line == null) return null;
      log.add(line);
      if (RegExp(r'^\d+,\d+$').hasMatch(line) ||
          line == 'OK' ||
          line.startsWith('ERROR')) {
        return line;
      }
    }
  }

  /// Starts (or restarts) a game. [maxDepth] caps the search depth (engine
  /// default is 99, effectively unlimited) — together with [thinkMs] this is
  /// how difficulty levels are implemented. Returns true when the engine
  /// answered OK.
  Future<bool> startGame({
    int boardSize = 15,
    int thinkMs = 2000,
    int maxDepth = 99,
  }) async {
    if (!_started) {
      _b.start();
      _started = true;
    }
    _send('START $boardSize');
    final (reply, _) = await _await();
    _send('INFO timeout_turn $thinkMs');
    _send('INFO max_depth $maxDepth');
    return reply == 'OK';
  }

  /// Asks the engine to open the game (engine plays first).
  Future<(String?, List<String>)> engineOpens() async {
    _send('BEGIN');
    return _await();
  }

  /// Sends the human move and returns the engine's reply move.
  Future<(String?, List<String>)> reply(int x, int y) async {
    _send('TURN $x,$y');
    return _await();
  }

  Future<(String?, List<String>)> _await() async {
    final result = await Isolate.run(() {
      final log = <String>[];
      final move = _readReply(log, 30000);
      return (move, log);
    });
    return result;
  }
}
