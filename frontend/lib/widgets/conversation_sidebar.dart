import 'package:flutter/material.dart';
import 'package:frontend/model/conversation.dart';
import '../state/app_controller.dart';
import '../utils/platform.dart';

class ConversationSidebar extends StatefulWidget {
  final AppController controller;
  final VoidCallback? onSelected; // closes the drawer on small screens
  final VoidCallback? onCollapse; // null on small screens (no collapse there)

  const ConversationSidebar({
    super.key,
    required this.controller,
    this.onSelected,
    this.onCollapse,
  });

  @override
  State<ConversationSidebar> createState() => _ConversationSidebarState();
}

class _ConversationSidebarState extends State<ConversationSidebar> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, List<Conversation>> _group(List<Conversation> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<Conversation>>{
      'Today': [],
      'Yesterday': [],
      'Previous 7 days': [],
      'Older': [],
    };

    for (final c in items) {
      final d = DateTime(c.updatedAt.year, c.updatedAt.month, c.updatedAt.day);
      final diff = today.difference(d).inDays;
      if (diff <= 0) {
        groups['Today']!.add(c);
      } else if (diff == 1) {
        groups['Yesterday']!.add(c);
      } else if (diff < 7) {
        groups['Previous 7 days']!.add(c);
      } else {
        groups['Older']!.add(c);
      }
    }

    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  Future<void> _rename(Conversation c) async {
    final textController = TextEditingController(text: c.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 80,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, textController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final trimmed = newTitle?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == c.title) return;

    try {
      await widget.controller.renameConversation(c.threadId, trimmed);
    } catch (e) {
      _snack('Could not rename: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _delete(Conversation c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
          'This permanently deletes "${c.title}" and its uploaded documents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await widget.controller.deleteConversation(c.threadId);
    } catch (e) {
      _snack('Could not delete: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Widget _centered(Widget child) => Center(
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      );

  Widget _buildBody(AppController c, List<Conversation> filtered) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (c.loadingConversations && c.conversations.isEmpty) {
      return const Center(
        key: ValueKey('loading'),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (c.conversationsError != null && c.conversations.isEmpty) {
      return _centered(
        Column(
          key: const ValueKey('error'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              c.conversationsError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => c.refreshConversations(showLoading: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (filtered.isEmpty) {
      return _centered(
        Text(
          _query.isEmpty ? 'No chats yet' : 'No matching chats',
          key: const ValueKey('empty'),
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final rows = <Widget>[];
    _group(filtered).forEach((label, items) {
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ));
      rows.addAll(items.map((conv) => _ChatTile(
            conversation: conv,
            selected: conv.threadId == c.activeThreadId,
            onTap: () {
              widget.onSelected?.call();
              c.selectThread(conv.threadId);
            },
            onRename: () => _rename(conv),
            onDelete: () => _delete(conv),
          )));
    });

    return ListView(
      key: const ValueKey('list'),
      padding: const EdgeInsets.only(bottom: 8),
      children: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final c = widget.controller;
            final filtered = c.conversations
                .where((x) => x.title.toLowerCase().contains(_query.toLowerCase()))
                .toList();

            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.auto_awesome,
                            size: 16, color: scheme.onPrimary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'RAGent',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (widget.onCollapse != null)
                        IconButton(
                          tooltip: 'Collapse sidebar (Ctrl+B)',
                          onPressed: widget.onCollapse,
                          color: scheme.onSurfaceVariant,
                          icon: const Icon(Icons.keyboard_double_arrow_left,
                              size: 20),
                        ),
                    ],
                  ),
                ),

                // New chat
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _NavItem(
                    icon: Icons.add,
                    label: 'New chat',
                    onTap: () {
                      widget.onSelected?.call();
                      c.startNewChat();
                    },
                  ),
                ),

                // Search
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search chats',
                      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withAlpha(110),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: scheme.primary.withAlpha(140)),
                      ),
                    ),
                  ),
                ),

                // Chat list
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildBody(c, filtered),
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Toggle theme',
                        onPressed: () => c.toggleTheme(theme.brightness),
                        color: scheme.onSurfaceVariant,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) => RotationTransition(
                            turns: Tween(begin: 0.75, end: 1.0).animate(anim),
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: Icon(
                            dark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            key: ValueKey(dark),
                            size: 20,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh chats',
                        onPressed: () => c.refreshConversations(),
                        color: scheme.onSurfaceVariant,
                        icon: const Icon(Icons.refresh, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A simple row button with a soft hover background.
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.onTap});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hover
                ? scheme.surfaceContainerHighest.withAlpha(140)
                : scheme.surfaceContainerHighest.withAlpha(0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One minimal chat row: plain text, soft highlight, menu only on hover.
class _ChatTile extends StatefulWidget {
  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ChatTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showMore = _hover || widget.selected || isTouchPlatform;

    final highlight = scheme.surfaceContainerHighest;
    final Color bg = widget.selected
        ? highlight
        : _hover
            ? highlight.withAlpha(120)
            : highlight.withAlpha(0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.conversation.title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w400,
                    color: widget.selected
                        ? scheme.onSurface
                        : scheme.onSurface.withAlpha(215),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: showMore ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: IgnorePointer(
                  ignoring: !showMore,
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: PopupMenuButton<String>(
                      tooltip: 'Options',
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(Icons.more_horiz,
                          color: scheme.onSurfaceVariant),
                      onSelected: (v) =>
                          v == 'rename' ? widget.onRename() : widget.onDelete(),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Rename'),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: scheme.error),
                            const SizedBox(width: 10),
                            Text('Delete',
                                style: TextStyle(color: scheme.error)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}