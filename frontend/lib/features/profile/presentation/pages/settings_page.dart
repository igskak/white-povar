import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Settings are coming soon'),
              subtitle: Text(
                'This entry point is added in V2 so critical account actions are not hidden in menus.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
