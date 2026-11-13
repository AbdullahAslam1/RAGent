import 'package:flutter/material.dart';
import '../state/app_controller.dart';

/// The slim icon strip shown when the sidebar is collapsed.
class SidebarRail extends StatelessWidget {
  final AppController controller;
  final VoidCallback onExpand;

  const SidebarRail({
    super.key,
    required this.controller,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            IconButton(
              tooltip: 'Open sidebar (Ctrl+B)',
              onPressed: onExpand,
              color: scheme.onSurfaceVariant,
              icon: const Icon(Icons.menu),
            ),
            const SizedBox(height: 6),
            IconButton.filledTonal(
              tooltip: 'New chat',
              onPressed: controller.startNewChat,
              icon: const Icon(Icons.add),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Toggle theme',
              onPressed: () => controller.toggleTheme(theme.brightness),
              color: scheme.onSurfaceVariant,
              icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}