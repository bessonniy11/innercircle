class Message {
  final String id;
  final String content;
  final String senderId;
  final String senderUsername; // Assuming we want to display sender's username
  final String chatId; // Добавлено поле chatId
  final DateTime createdAt;

  Message({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderUsername,
    required this.chatId, // Добавлено в конструктор
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      content: json['content'] as String,
      senderId: json['sender']['id'] as String, // Assuming sender is an object with id
      senderUsername: json['sender']['username'] as String, // Assuming sender is an object with username
      chatId: json['chat']['id'] as String, // Парсинг chatId из вложенного объекта chat
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'chatId': chatId, // Добавлено в toJson
      'createdAt': createdAt.toIso8601String(),
    };
  }
} 