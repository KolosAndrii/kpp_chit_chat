import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


enum MessageType { text, image, video, file } 

class Message {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final bool? isRead;

  // 2. Нові поля (опціональні, щоб не ламати старі повідомлення)
  final MessageType type;
  final String? fileUrl;

  final List<String> readBy;////

  // Геттер: перевіряє, чи це моє повідомлення
  bool get isSentByMe {
    return FirebaseAuth.instance.currentUser?.uid == senderId;
  }

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text, // За замовчуванням текст
    this.fileUrl,
    required this.readBy,////
  });

  // Створення з документа Firebase
  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Визначаємо тип повідомлення
   MessageType msgType = MessageType.text;

    if (data['type'] == 'image') {
      msgType = MessageType.image;
    } else if (data['type'] == 'video') {
      msgType = MessageType.video;
    } else if (data['type'] == 'file') { // <-- Додали перевірку
      msgType = MessageType.file;
    }

    return Message(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      type: msgType, // Тепер сюди потрапить правильний Enum
      fileUrl: data['fileUrl'],
      readBy: List<String>.from(data['readBy'] ?? []),////
    );
  }

 

  // Підготовка даних для відправки в базу
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      // ЗАЛИШАЄМО ТВОЄ ПОЛЕ timestamp
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'type': type.name, // 'text' або 'image'
      'fileUrl': fileUrl,
    };
  }
  
  String get timeString {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}













// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';



// class Message {
//   final String id;
//   final String text;
//   final String senderId;
//   final DateTime timestamp;
//   final bool isRead;

//   // Геттер: перевіряє, чи це моє повідомлення
//   bool get isSentByMe {
//     return FirebaseAuth.instance.currentUser?.uid == senderId;
//   }

//   Message({
//     required this.id,
//     required this.text,
//     required this.senderId,
//     required this.timestamp,
//     this.isRead = false,
//   });

//   // Створення з документа Firebase
//   factory Message.fromFirestore(DocumentSnapshot doc) {
//     Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
//     return Message(
//       id: doc.id,
//       text: data['text'] ?? '',
//       senderId: data['senderId'] ?? '',
//       // Конвертуємо Timestamp у DateTime
//       timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
//       isRead: data['isRead'] ?? false,
//     );
//   }

//   // Підготовка даних для відправки в базу
//   Map<String, dynamic> toMap() {
//     return {
//       'text': text,
//       'senderId': senderId,
//       'timestamp': Timestamp.fromDate(timestamp),
//       'isRead': isRead,
//       'type': 'text',
//     };
//   }
  
//   String get timeString {
//     return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
//   }
// }
















// class Message {
//   final String text;
//   final DateTime timestamp; // Зберігаємо точний час для сортування
//   final bool isSentByMe;

//   Message({
//     required this.text,
//     required this.timestamp, // Приймаємо DateTime
//     required this.isSentByMe,
//   });

//   // Геттер, який перетворює час у стрінг для UI (наприклад, "14:05")
//   String get timeString {
//     return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
//   }
// }