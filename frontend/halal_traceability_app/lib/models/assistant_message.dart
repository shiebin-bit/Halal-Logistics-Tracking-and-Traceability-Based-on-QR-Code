class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final String role;
  final String content;
  final DateTime createdAt;

  factory AssistantMessage.user(String content) {
    return AssistantMessage(
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
  }

  factory AssistantMessage.assistant(String content) {
    return AssistantMessage(
      role: 'assistant',
      content: content,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toRequestJson() {
    return {
      'role': role,
      'content': content,
    };
  }
}
