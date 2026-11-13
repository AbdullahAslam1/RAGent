import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/platform.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isStreaming;
  final bool isUploading;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttach;

  const ChatInput({
    super.key,
    required this.controller,
    required this.isStreaming,
    required this.isUploading,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _focused
              ? scheme.primary.withAlpha(150)
              : scheme.outlineVariant,
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(_focused ? 24 : 10),
            blurRadius: _focused ? 18 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: IconButton(
              tooltip: 'Attach a PDF or TXT file',
              color: scheme.onSurfaceVariant,
              onPressed: (widget.isStreaming || widget.isUploading)
                  ? null
                  : widget.onAttach,
              icon: widget.isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file),
            ),
          ),
          Expanded(
            // Enter sends, Shift+Enter inserts a new line
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): () {
                  if (!widget.isStreaming) widget.onSend();
                },
              },
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: !isTouchPlatform,
                minLines: 1,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Message RAGent…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: widget.isStreaming
                  ? IconButton.filled(
                      key: const ValueKey('stop'),
                      tooltip: 'Stop generating',
                      onPressed: widget.onStop,
                      icon: const Icon(Icons.stop_rounded),
                    )
                  : ValueListenableBuilder<TextEditingValue>(
                      key: const ValueKey('send'),
                      valueListenable: widget.controller,
                      builder: (context, value, _) => IconButton.filled(
                        tooltip: 'Send',
                        onPressed:
                            value.text.trim().isEmpty ? null : widget.onSend,
                        icon: const Icon(Icons.arrow_upward),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}