import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/model/chat_message.dart';
import 'package:frontend/widgets/fade_side_in.dart';
import '../config.dart';
import '../state/app_controller.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final AppController controller;
  final String threadId;
  final Widget? drawer; // provided on small screens only

  const ChatScreen({
    super.key,
    required this.controller,
    required this.threadId,
    this.drawer,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  StreamSubscription<String>? _sub;

  bool _loadingHistory = true;
  String? _historyError;
  bool _streaming = false;
  bool _uploading = false;
  bool _showJumpButton = false;

  // Messages before this index came from history and appear without animation.
  int _animateFrom = 0;

  AppController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadHistory();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------- helpers ----------

  String _friendlyError(Object e) {
    final text = e.toString().replaceFirst('Exception: ', '');
    if (text.contains('Failed to fetch') ||
        text.contains('Connection refused') ||
        text.contains('SocketException') ||
        text.contains('ClientException')) {
      return 'Cannot reach the server. Check that the backend is running '
          'and the URL in config.dart is correct.';
    }
    return text;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _title() {
    for (final conv in _c.conversations) {
      if (conv.threadId == widget.threadId) return conv.title;
    }
    return 'New chat';
  }

  // ---------- scrolling ----------

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final away = _scroll.position.maxScrollExtent - _scroll.position.pixels > 240;
    if (away != _showJumpButton) setState(() => _showJumpButton = away);
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && _showJumpButton) return; // don't yank the view while reading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  // ---------- actions ----------

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final history = await _c.api.getHistory(widget.threadId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
        _animateFrom = _messages.length;
        _loadingHistory = false;
      });
      _scrollToBottom(force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = _friendlyError(e);
        _loadingHistory = false;
      });
    }
  }

  void _send([String? preset]) {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _streaming || _loadingHistory) return;

    _input.clear();

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _messages.add(const ChatMessage(role: 'assistant', content: ''));
      _streaming = true;
    });
    _scrollToBottom(force: true);

    final index = _messages.length - 1;

    _sub = _c.api
        .streamChat(
          message: text,
          threadId: widget.threadId,
          model: _c.model,
        )
        .listen(
      (token) {
        if (!mounted) return;
        setState(() {
          _messages[index] =
              _messages[index].copyWith(content: _messages[index].content + token);
        });
        _scrollToBottom();
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _messages[index] = ChatMessage(
            role: 'assistant',
            content: _friendlyError(e),
            isError: true,
          );
          _streaming = false;
        });
        _c.refreshConversations();
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _streaming = false);
        _c.refreshConversations();
      },
      cancelOnError: true,
    );
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    setState(() {
      _streaming = false;
      if (_messages.isNotEmpty &&
          _messages.last.role == 'assistant' &&
          _messages.last.content.isEmpty) {
        _messages.removeLast();
      }
    });
    _c.refreshConversations();
  }

  Future<void> _attach() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;

    if (bytes == null) {
      _snack('Could not read that file.');
      return;
    }
    if (bytes.length > AppConfig.maxUploadBytes) {
      _snack('File is too large (max 10 MB).');
      return;
    }

    setState(() => _uploading = true);
    try {
      await _c.api.uploadDocument(
        threadId: widget.threadId,
        filename: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          role: 'system',
          content: 'Uploaded document: ${file.name}',
        ));
      });
      _scrollToBottom(force: true);
      _c.refreshConversations();
    } catch (e) {
      _snack('Upload failed: ${_friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ---------- UI pieces ----------

  Widget _modelMenu() {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        return PopupMenuButton<String>(
          tooltip: 'Choose model',
          initialValue: _c.model,
          onSelected: _c.setModel,
          position: PopupMenuPosition.under,
          itemBuilder: (_) => AppConfig.models
              .map((m) => PopupMenuItem(value: m, child: Text(m)))
              .toList(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_c.model, style: Theme.of(context).textTheme.labelLarge),
                Icon(Icons.expand_more,
                    size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _suggestionCard(
      int i, IconData icon, String label, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;

    // Later cards take slightly longer, which gives a staggered entrance.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 380 + i * 90),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child),
      ),
      child: SizedBox(
        width: 250,
        child: Material(
          color: scheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: FadeSlideIn(
            duration: const Duration(milliseconds: 450),
            offsetY: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.auto_awesome, color: scheme.onPrimary),
                ),
                const SizedBox(height: 20),
                Text('How can I help you today?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'Search the web, do math, save things for later, '
                  'or chat with your documents.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _suggestionCard(0, Icons.public, 'Latest AI news',
                        () => _send("What's the latest news in AI?")),
                    _suggestionCard(1, Icons.calculate_outlined, 'Do some math',
                        () => _send('What is 1234 multiplied by 5678?')),
                    _suggestionCard(2, Icons.bookmark_outline,
                        'Remember something',
                        () => _send('Remember that I prefer short answers.')),
                    _suggestionCard(3, Icons.description_outlined,
                        'Chat with a document', _attach),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_loadingHistory) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_historyError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 12),
              Text(_historyError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _loadHistory,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) return _emptyState();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: _messages.length,
          itemBuilder: (context, i) {
            final m = _messages[i];
            final isLastAssistant =
                i == _messages.length - 1 && m.role == 'assistant';
            return MessageBubble(
              message: m,
              isStreaming: _streaming && isLastAssistant,
              animate: i >= _animateFrom,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            final title = _title();
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, if (current != null) current],
              ),
              child: Text(
                title,
                key: ValueKey(title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            );
          },
        ),
        actions: [
          _modelMenu(),
          if (widget.drawer != null)
            IconButton(
              tooltip: 'New chat',
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: _c.startNewChat,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildMessages(),
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_showJumpButton,
                    child: AnimatedSlide(
                      offset: _showJumpButton ? Offset.zero : const Offset(0, 0.6),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: _showJumpButton ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Center(
                          child: FloatingActionButton.small(
                            heroTag: null,
                            elevation: 2,
                            onPressed: _jumpToBottom,
                            child: const Icon(Icons.arrow_downward),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChatInput(
                        controller: _input,
                        isStreaming: _streaming,
                        isUploading: _uploading,
                        onSend: _send,
                        onStop: _stop,
                        onAttach: _attach,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'RAGent can make mistakes. Verify important information.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}