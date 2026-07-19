// Step 0.6/0.7 spike UI: one button that drives the in-process Rapfi engine
// through FFI and shows the engine's moves. Not the real game UI.
import 'package:flutter/material.dart';

import 'engine/rapfi_ffi.dart';

void main() {
  runApp(const SpikeApp());
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '引擎联通验证',
      theme: ThemeData(colorSchemeSeed: Colors.brown, useMaterial3: true),
      home: const SpikePage(),
    );
  }
}

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});

  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  final List<String> _lines = [];
  bool _busy = false;
  bool _gameRunning = false;
  int _humanX = 8, _humanY = 8;

  void _log(String s) => setState(() => _lines.add(s));

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      if (!_gameRunning) {
        final ok = await RapfiEngine.instance.startGame(thinkMs: 2000);
        _log(ok ? '引擎初始化 OK（棋盘 15×15）' : '引擎初始化失败');
        if (!ok) return;
        _gameRunning = true;
        final (move, log) = await RapfiEngine.instance.engineOpens();
        for (final l in log.where((l) => l.startsWith('MESSAGE'))) {
          _log('  $l');
        }
        _log('引擎开局: $move');
      } else {
        _log('我方落子: $_humanX,$_humanY');
        final (move, log) = await RapfiEngine.instance.reply(_humanX, _humanY);
        for (final l in log.where((l) => l.startsWith('MESSAGE'))) {
          _log('  $l');
        }
        _log('引擎应对: $move');
        _humanX += 1; // 下次点击换个点，避免重复落子
      }
    } catch (e) {
      _log('异常: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapfi 引擎联通验证')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _busy ? null : _run,
              child: Text(_busy
                  ? '引擎思考中…'
                  : _gameRunning
                      ? '走一步（我方 $_humanX,$_humanY）'
                      : '开始对局（引擎先手）'),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _lines.length,
              itemBuilder: (_, i) => Text(
                _lines[i],
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
