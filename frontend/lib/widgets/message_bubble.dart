import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:frontend/model/chat_message.dart';
import 'package:frontend/widgets/fade_side_in.dart';
import 'typing_dots.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming; // true only for the reply currently being generated
  final bool animate; // play the entrance animation (new messages only)

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content;
    switch (message.role) {
      case 'user':
        content = _user(context);
      case 'system':
        content = _system(context);
      default:
        content = _assistant(context);
    }
    return animate ? FadeSlideIn(child: content) : content;
  }

  Widget _user(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(left: 48, top: 10, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: SelectableText(
          message.content,
          style: TextStyle(color: scheme.onPrimaryContainer, height: 1.45),
        ),
      ),
    );
  }

  Widget _system(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.content,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assistant(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final waiting = message.content.isEmpty && isStreaming;

    Widget body;
    if (waiting) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: TypingDots(),
      );
    } else if (message.isError) {
      body = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                message.content,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      );
    } else {
      final sheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
        code: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: scheme.surfaceContainerHighest,
        ),
        codeblockPadding: const EdgeInsets.all(14),
        codeblockDecoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: scheme.primary, width: 3)),
        ),
      );
      body = MarkdownBody(
        data: message.content,
        selectable: true,
        styleSheet: sheet,
      );
    }

    final showActions =
        !isStreaming && !message.isError && message.content.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.auto_awesome, size: 15, color: scheme.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                body,
                if (showActions)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton(
                      tooltip: 'Copy',
                      iconSize: 17,
                      visualDensity: VisualDensity.compact,
                      color: scheme.onSurfaceVariant,
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: message.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}