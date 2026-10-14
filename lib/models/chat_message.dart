import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? timestamp;

  const ChatMessage({
    this.id = '',
    required this.senderId,
    required this.senderName,
    required this.text,
    this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'senderName': senderName,
    'text': text,
    'timestamp': FieldValue.serverTimestamp(),
  };

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: (map['senderId'] ?? '').toString(),
      senderName: (map['senderName'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}