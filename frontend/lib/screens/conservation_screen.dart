import 'package:flutter/material.dart';
import 'package:frontend/model/conversation.dart';
import 'package:frontend/services/chat_api_services.dart';
import 'package:frontend/state/app_controller.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  final AppController controller;
  const ConversationsScreen({
    super.key,
    required this.controller,
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final ChatApiService _api = ChatApiService();
  List<Conversation> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _api.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openChat(String threadId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(
      controller: widget.controller,  
      threadId: threadId)),
    );
    // Reload when coming back, since a chat may have been created or updated
    _load();
  }

  void _newChat() {
    _openChat(const Uuid().v4());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RAGent"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newChat,
        icon: const Icon(Icons.add),
        label: const Text("New Chat"),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 12),
              const Text("Could not reach the server"),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text("Retry")),
            ],
          ),
        ),
      );
    }

    if (_conversations.isEmpty) {
      return const Center(child: Text("No chats yet. Tap New Chat to start."));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final c = _conversations[index];
          return ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(DateFormat('MMM d, h:mm a').format(c.updatedAt)),
            onTap: () => _openChat(c.threadId),
          );
        },
      ),
    );
  }
}