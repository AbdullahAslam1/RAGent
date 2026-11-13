class Conversation {
  final String threadId;
  final String title;
  final DateTime updatedAt;

  Conversation({
    required this.threadId,
    required this.title,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // The backend sends UTC timestamps without a "Z" suffix, so Dart would
    // treat them as local time and show the wrong hour. Add the Z, then convert.
    final raw = json['updated_at'] as String;
    final parsed = DateTime.parse(raw.endsWith('Z') ? raw : '${raw}Z');

    return Conversation(
      threadId: json['thread_id'] as String,
      title: json['title'] as String,
      updatedAt: parsed.toLocal(),
    );
  }
}