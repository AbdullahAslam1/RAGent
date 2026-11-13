import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/app_controller.dart';
import '../widgets/conversation_sidebar.dart';
import '../widgets/sidebar_rail.dart';
import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppController controller;
  const HomeScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            // A new key per thread gives each chat fresh state; the switcher
            // cross-fades between them.
            final chat = AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, if (current != null) current],
              ),
              child: ChatScreen(
                key: ValueKey(controller.activeThreadId),
                controller: controller,
                threadId: controller.activeThreadId,
                drawer: wide
                    ? null
                    : Drawer(
                        child: ConversationSidebar(
                          controller: controller,
                          onSelected: () => Navigator.of(context).pop(),
                        ),
                      ),
              ),
            );

            if (!wide) return chat;

            return CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyB, control: true):
                    controller.toggleSidebar,
                const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
                    controller.toggleSidebar,
              },
              child: Scaffold(
                body: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SidebarShell(controller: controller),
                    Expanded(child: chat),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Animates between the full sidebar and the slim rail.
class _SidebarShell extends StatelessWidget {
  final AppController controller;
  const _SidebarShell({required this.controller});

  static const double expandedWidth = 288;
  static const double railWidth = 68;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final collapsed = controller.sidebarCollapsed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      width: collapsed ? railWidth : expandedWidth,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // Full sidebar: laid out at its full width and clipped while it
            // shrinks, so nothing reflows mid-animation.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: expandedWidth,
              child: ExcludeFocus(
                excluding: collapsed,
                child: IgnorePointer(
                  ignoring: collapsed,
                  child: AnimatedOpacity(
                    opacity: collapsed ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: ConversationSidebar(
                      controller: controller,
                      onCollapse: controller.toggleSidebar,
                    ),
                  ),
                ),
              ),
            ),
            // Icon rail
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: railWidth,
              child: IgnorePointer(
                ignoring: !collapsed,
                child: AnimatedOpacity(
                  opacity: collapsed ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: SidebarRail(
                    controller: controller,
                    onExpand: controller.toggleSidebar,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}