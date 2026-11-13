class ChatMessage {
  final String role;
  final String content;
  final bool isError;

  const ChatMessage({
    required this.role,
    required this.content,
    this.isError = false,
  });

  ChatMessage copyWith({String? content, bool? isError}) => ChatMessage(
        role: role,
        content: content ?? this.content,
        isError: isError ?? this.isError,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
      );
}