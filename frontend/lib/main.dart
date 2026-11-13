import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';

void main() => runApp(const RAGentApp());

class RAGentApp extends StatefulWidget {
  const RAGentApp({super.key});

  @override
  State<RAGentApp> createState() => _RAGentAppState();
}

class _RAGentAppState extends State<RAGentApp> {
  final AppController _controller = AppController();

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => MaterialApp(
        title: 'RAGent',
        debugShowCheckedModeBanner: false,
        themeMode: _controller.themeMode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Light and dark cross-fade instead of snapping
        themeAnimationDuration: const Duration(milliseconds: 300),
        themeAnimationCurve: Curves.easeInOut,
        home: HomeScreen(controller: _controller),
      ),
    );
  }
}