import 'package:flutter/material.dart';

void main() {
  runApp(const _LegacyEntrypointNoticeApp());
}

class _LegacyEntrypointNoticeApp extends StatelessWidget {
  const _LegacyEntrypointNoticeApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('White Povar (Legacy Entrypoint)')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'This root Flutter app is legacy.\n'
              'Use /frontend/lib/main.dart as the primary application entrypoint.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
