import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:frontend/model/chat_message.dart';
import 'package:frontend/model/conversation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class ChatApiService {
  final String baseUrl = AppConfig.baseUrl;

  /// Streams reply tokens. Cancelling the subscription closes the connection.
  Stream<String> streamChat({
    required String message,
    required String threadId,
    required String model,
  }) async* {
    final request = http.Request("POST", Uri.parse("$baseUrl/chat/stream"));
    request.headers["Content-Type"] = "application/json";
    request.body = jsonEncode({
      "message": message,
      "thread_id": threadId,
      "model": model,
    });

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception("Server returned ${response.statusCode}: $body");
      }

      String buffer = "";
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        while (buffer.contains("\n\n")) {
          final index = buffer.indexOf("\n\n");
          final rawEvent = buffer.substring(0, index);
          buffer = buffer.substring(index + 2);

          if (!rawEvent.startsWith("data: ")) continue;

          final data =
              jsonDecode(rawEvent.substring(6)) as Map<String, dynamic>;

          if (data.containsKey("token")) {
            yield data["token"] as String;
          } else if (data.containsKey("error")) {
            throw Exception(data["error"]);
          } else if (data.containsKey("done")) {
            return;
          }
        }
      }
    } finally {
      client.close();
    }
  }

  Future<List<ChatMessage>> getHistory(String threadId) async {
    final response = await http.get(Uri.parse("$baseUrl/history/$threadId"));
    if (response.statusCode != 200) {
      throw Exception("Failed to load history (${response.statusCode})");
    }
    final data = jsonDecode(response.body);
    final list = data is Map ? data["messages"] : null;
    if (list is! List) {
      throw Exception("Unexpected response from /history: ${response.body}");
    }
    return list
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<Conversation>> getConversations() async {
    final response = await http.get(Uri.parse("$baseUrl/conversations"));
    if (response.statusCode != 200) {
      throw Exception("Failed to load chats (${response.statusCode})");
    }
    final data = jsonDecode(response.body);
    final list = data is Map ? data["conversations"] : null;
    if (list is! List) {
      throw Exception(
          "Unexpected response from /conversations: ${response.body}");
    }
    return list
        .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<void> renameConversation(String threadId, String title) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/conversations/$threadId"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"title": title}),
    );
    if (response.statusCode != 200) {
      throw Exception("Rename failed (${response.statusCode})");
    }
  }

  Future<void> deleteConversation(String threadId) async {
    final response =
        await http.delete(Uri.parse("$baseUrl/conversations/$threadId"));
    if (response.statusCode != 200) {
      throw Exception("Delete failed (${response.statusCode})");
    }
  }

  Future<String> uploadDocument({
    required String threadId,
    required String filename,
    required Uint8List bytes,
  }) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/upload"));
    request.fields["thread_id"] = threadId;
    request.files.add(
      http.MultipartFile.fromBytes("file", bytes, filename: filename),
    );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {}

    if (streamed.statusCode != 200) {
      throw Exception(data["message"] ?? "Upload failed (${streamed.statusCode})");
    }
    return (data["message"] ?? "Uploaded") as String;
  }
}