import 'package:flutter/material.dart';
import 'package:frontend/model/conversation.dart';
import 'package:frontend/services/chat_api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config.dart';

class AppController extends ChangeNotifier {
  final ChatApiService api = ChatApiService();
  static const _uuid = Uuid();

  List<Conversation> conversations = [];
  bool loadingConversations = true;
  String? conversationsError;

  String activeThreadId = _uuid.v4();
  String model = AppConfig.defaultModel;
  ThemeMode themeMode = ThemeMode.system;
  bool sidebarCollapsed = false;

  Future<void> init() async {
    await _loadPrefs();
    await refreshConversations(showLoading: true);
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModel = prefs.getString('model');
      if (savedModel != null && AppConfig.models.contains(savedModel)) {
        model = savedModel;
      }
      switch (prefs.getString('theme')) {
        case 'light':
          themeMode = ThemeMode.light;
        case 'dark':
          themeMode = ThemeMode.dark;
        default:
          themeMode = ThemeMode.system;
      }
      sidebarCollapsed = prefs.getBool('sidebar_collapsed') ?? false;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _saveString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  Future<void> refreshConversations({bool showLoading = false}) async {
    if (showLoading) {
      loadingConversations = true;
      notifyListeners();
    }
    try {
      conversations = await api.getConversations();
      conversationsError = null;
    } catch (e) {
      conversationsError = e.toString().replaceFirst('Exception: ', '');
    }
    loadingConversations = false;
    notifyListeners();
  }

  void selectThread(String threadId) {
    if (threadId == activeThreadId) return;
    activeThreadId = threadId;
    notifyListeners();
  }

  void startNewChat() {
    activeThreadId = _uuid.v4();
    notifyListeners();
  }

  void setModel(String value) {
    model = value;
    _saveString('model', value);
    notifyListeners();
  }

  void toggleTheme(Brightness current) {
    themeMode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    _saveString('theme', themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  void toggleSidebar() {
    sidebarCollapsed = !sidebarCollapsed;
    _saveBool('sidebar_collapsed', sidebarCollapsed);
    notifyListeners();
  }

  Future<void> renameConversation(String threadId, String title) async {
    await api.renameConversation(threadId, title);
    await refreshConversations();
  }

  Future<void> deleteConversation(String threadId) async {
    await api.deleteConversation(threadId);
    conversations = conversations.where((c) => c.threadId != threadId).toList();
    if (activeThreadId == threadId) activeThreadId = _uuid.v4();
    notifyListeners();
  }
}