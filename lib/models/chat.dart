class Chat {
  final String chatId;
  final String userId;
  final String userName;
  final String lastMessage;
  final String lastMessageTime;

  Chat({
    required this.chatId,
    required this.userId,
    required this.userName,
    this.lastMessage = '',
    this.lastMessageTime = '',
  });

  factory Chat.fromAppointment(Map<String, dynamic> appointmentJson) {
    return Chat(
      chatId: appointmentJson['_id']?.toString() ?? '',
      userId:
          appointmentJson['user'] is Map
              ? appointmentJson['user']['_id'] ?? ''
              : appointmentJson['user'] ?? '',
      userName:
          appointmentJson['user'] is Map
              ? appointmentJson['user']['name'] ?? 'Unknown'
              : 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'userId': userId,
      'userName': userName,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
    };
  }
}
