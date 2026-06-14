import 'package:flutter/material.dart';

/// The app's home screen.
///
/// In v1 this reads the local Open mHealth cache and renders the in-app
/// dashboard (DESIGN.md §9, read/display path A). For now it is a placeholder.
class DashboardPage extends StatelessWidget {
  /// Creates the dashboard page.
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cairn')),
      body: const Center(child: Text('Cairn')),
    );
  }
}
