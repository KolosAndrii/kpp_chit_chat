import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_lab_kpp/features/chat/widgets/message_bubbles/message_model.dart';

class Chat {
  final String id;
  final List<String> participantIds; 
  final Message? lastMessage;
  final int unreadCount;
  
  final bool isGroup;
  final String? groupName;
  final String? groupImage;

  String? _cachedChatName; 
  String? _cachedChatImage;

  final String adminId;
  final DateTime? createdAt;

  Chat({
    required this.id,
    required this.participantIds,
    this.lastMessage,
    this.unreadCount = 0,
    this.isGroup = false,
    this.groupName,
    this.groupImage,
    String? chatName, 
    String? chatImage,
    required this.adminId,
    this.createdAt, 
  }) {
    _cachedChatName = chatName;
    _cachedChatImage = chatImage;
  }

  factory Chat.fromFirestore(DocumentSnapshot doc, String myUid) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // --- 1. ПАРСИМО LAST MESSAGE (Безпечно) ---
    Message? lastMsg;
    final lastMsgData = data['lastMessage'];

    if (lastMsgData != null) {
      if (lastMsgData is Map<String, dynamic>) {
        // --- ВАРІАНТ 1: Новий формат (Map) ---
        
        MessageType msgType = MessageType.text;
        if (lastMsgData['type'] == 'image') msgType = MessageType.image;
        if (lastMsgData['type'] == 'video') msgType = MessageType.video;

        lastMsg = Message(
          id: 'preview', 
          text: lastMsgData['text'] ?? '', 
          senderId: lastMsgData['senderId'] ?? '', 
          timestamp: (lastMsgData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          type: msgType,
          fileUrl: lastMsgData['fileUrl'], 
          
          // 🔥 ДОДАНО: читаємо readBy з даних останнього повідомлення
          readBy: List<String>.from(lastMsgData['readBy'] ?? []), 
        );
      } else if (lastMsgData is String) {
        // --- ВАРІАНТ 2: Старий формат (String) ---
        
        lastMsg = Message(
          id: 'preview', 
          text: lastMsgData, 
          senderId: '', 
          timestamp: DateTime.now(), 
          type: MessageType.text,
          
          // 🔥 ДОДАНО: пустий список для сумісності
          readBy: [], 
        );
      }
    }
    // -------------------------------------------

    final unreadMap = data['unreadCount'] as Map<String, dynamic>? ?? {};
    final myUnread = unreadMap[myUid] ?? 0;

    final bool isGroupChat = data['isGroup'] ?? false;
    final String? gName = data['groupName'];
    final String? gImage = data['groupImage'];

    return Chat(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      lastMessage: lastMsg,
      unreadCount: myUnread is int ? myUnread : 0,
      isGroup: isGroupChat,
      groupName: gName,
      groupImage: gImage,
      chatName: isGroupChat ? (gName ?? 'Group Chat') : null,
      chatImage: isGroupChat ? gImage : null,
      adminId: data['adminId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
  
  String get displayName {
    if (isGroup) {
      return groupName ?? 'Group Chat';
    }
    return _cachedChatName ?? 'Unknown User'; 
  }

  set chatName(String? name) {
    _cachedChatName = name;
  }

  String? get displayImage {
    if (isGroup) {
      return groupImage;
    }
    return _cachedChatImage;
  }
  
  set chatImage(String? image) {
    _cachedChatImage = image;
  }

  // Твій виправлений геттер для сортування
  DateTime get lastActivityTime => lastMessage?.timestamp ?? createdAt ?? DateTime.now();

  String get lastMessageText {
    if (lastMessage == null) return 'No messages';

    if (lastMessage!.type == MessageType.image) {
      return '📷 Photo';
    }
    if (lastMessage!.type == MessageType.video) {
      return '🎥 Video';
    }
    
    return lastMessage!.text.isNotEmpty ? lastMessage!.text : 'File';
  }

  /// Перевіряє, чи є цей чат непрочитаним для конкретного юзера
  bool isUnreadForUser(String userId) {
    // Якщо повідомлень немає - чат прочитаний
    if (lastMessage == null) return false;

    // Якщо це "текстова заглушка" старого формату (де readBy пустий) - вважаємо прочитаним
    if (lastMessage!.readBy.isEmpty && lastMessage!.senderId.isEmpty) return false;

    // Головна перевірка: чи є мій ID у списку тих, хто прочитав
    return !lastMessage!.readBy.contains(userId);
  }
}



















// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:chat_lab_kpp/features/chat/widgets/message_bubbles/message_model.dart';

// class Chat {
//   final String id;
//   final List<String> participantIds; 
//   final Message? lastMessage;
//   final int unreadCount;
  
//   final bool isGroup;
//   final String? groupName;
//   final String? groupImage;

//   String? _cachedChatName; 
//   String? _cachedChatImage;

//   final String adminId;//
//   final DateTime? createdAt;//

//   Chat({
//     required this.id,
//     required this.participantIds,
//     this.lastMessage,
//     this.unreadCount = 0,
//     this.isGroup = false,
//     this.groupName,
//     this.groupImage,
//     String? chatName, 
//     String? chatImage,
//     required this.adminId,//
//     this.createdAt, //
//   }) {
//     _cachedChatName = chatName;
//     _cachedChatImage = chatImage;
//   }

//   factory Chat.fromFirestore(DocumentSnapshot doc, String myUid) {
//     Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
//     // --- 1. ПАРСИМО LAST MESSAGE (Безпечно) ---
//     Message? lastMsg;
//     final lastMsgData = data['lastMessage'];

//     if (lastMsgData != null) {
//       if (lastMsgData is Map<String, dynamic>) {
//         // Якщо це новий формат (об'єкт з типом і файлом)
        
//         // Визначаємо тип
//         MessageType msgType = MessageType.text;
//         if (lastMsgData['type'] == 'image') msgType = MessageType.image;
//         if (lastMsgData['type'] == 'video') msgType = MessageType.video;

//         lastMsg = Message(
//           id: 'preview', 
//           text: lastMsgData['text'] ?? '', 
//           senderId: lastMsgData['senderId'] ?? '', 
//           timestamp: (lastMsgData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
//           // Важливо: передаємо тип і посилання
//           type: msgType,
//           fileUrl: lastMsgData['fileUrl'], 
//         );
//       } else if (lastMsgData is String) {
//         // Якщо це старий формат (просто рядок тексту) - для сумісності
//         lastMsg = Message(
//           id: 'preview',
//           text: lastMsgData,
//           senderId: '',
//           timestamp: DateTime.now(),
//           type: MessageType.text,
//         );
//       }
//     }
//     // -------------------------------------------

//     // 2. Лічильник
//     final unreadMap = data['unreadCount'] as Map<String, dynamic>? ?? {};
//     final myUnread = unreadMap[myUid] ?? 0;

//     // 3. Групові поля
//     final bool isGroupChat = data['isGroup'] ?? false;
//     final String? gName = data['groupName'];
//     final String? gImage = data['groupImage'];

//     return Chat(
//       id: doc.id,
//       participantIds: List<String>.from(data['participantIds'] ?? []),
//       lastMessage: lastMsg,
//       unreadCount: myUnread is int ? myUnread : 0,
//       isGroup: isGroupChat,
//       groupName: gName,
//       groupImage: gImage,
//       // Кешуємо дефолтні значення для груп
//       chatName: isGroupChat ? (gName ?? 'Group Chat') : null,
//       chatImage: isGroupChat ? gImage : null,
//       adminId: data['adminId'] ?? '',//
//       createdAt: (data['createdAt'] as Timestamp?)?.toDate(),//
//     );
//   }
  
//   String get displayName {
//     if (isGroup) {
//       return groupName ?? 'Group Chat';
//     }
//     return _cachedChatName ?? 'Unknown User'; 
//   }

//   set chatName(String? name) {
//     _cachedChatName = name;
//   }

//   String? get displayImage {
//     if (isGroup) {
//       return groupImage;
//     }
//     return _cachedChatImage;
//   }
  
//   set chatImage(String? image) {
//     _cachedChatImage = image;
//   }

//   DateTime get lastActivityTime => lastMessage?.timestamp ?? createdAt ?? DateTime(2000);

//   // --- ГЕТТЕР ТЕКСТУ ПОВІДОМЛЕННЯ (Для списку чатів) ---
//   String get lastMessageText {
//     if (lastMessage == null) return 'No messages';

//     // Якщо це картинка
//     if (lastMessage!.type == MessageType.image) {
//       return '📷 Photo';
//     }
//     // Якщо це відео
//     if (lastMessage!.type == MessageType.video) {
//       return '🎥 Video';
//     }
    
//     // Якщо текст
//     return lastMessage!.text.isNotEmpty ? lastMessage!.text : 'File';
//   }
// }























// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:chat_lab_kpp/features/chat/widgets/message_bubbles/message_model.dart';

// class Chat {
//   final String id;
//   final List<String> participantIds; 
//   final Message? lastMessage;
//   final int unreadCount;
  
//   // --- НОВІ ПОЛЯ ДЛЯ ГРУП (з БД) ---
//   final bool isGroup;
//   final String? groupName;
//   final String? groupImage;

//   // --- UI ПОЛЯ (Заповнюються локально) ---
//   // Для приватних чатів сюди запишемо ім'я друга.
//   // Для груп - сюди автоматично підставиться groupName.
//   String? _cachedChatName; 
//   String? _cachedChatImage;

//   Chat({
//     required this.id,
//     required this.participantIds,
//     this.lastMessage,
//     this.unreadCount = 0,
//     this.isGroup = false,
//     this.groupName,
//     this.groupImage,
//     String? chatName,   // Опціонально для ручного встановлення
//     String? chatImage,
//   }) {
//     _cachedChatName = chatName;
//     _cachedChatImage = chatImage;
//   }

//   factory Chat.fromFirestore(DocumentSnapshot doc, String myUid) {
//     Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
//     // 1. Парсимо повідомлення
//     Message? lastMsg;
//     if (data['lastMessage'] != null) {
//       final map = data['lastMessage'] as Map<String, dynamic>;
//       lastMsg = Message(
//         id: 'preview', 
//         text: map['text'] ?? '', 
//         senderId: map['senderId'] ?? '', 
//         timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
//       );
//     }

//     // 2. Лічильник
//     final unreadMap = data['unreadCount'] as Map<String, dynamic>? ?? {};
//     final myUnread = unreadMap[myUid] ?? 0;

//     // 3. Групові поля
//     final bool isGroupChat = data['isGroup'] ?? false;
//     final String? gName = data['groupName'];
//     final String? gImage = data['groupImage'];

//     return Chat(
//       id: doc.id,
//       participantIds: List<String>.from(data['participantIds'] ?? []),
//       lastMessage: lastMsg,
//       unreadCount: myUnread is int ? myUnread : 0,
//       isGroup: isGroupChat,
//       groupName: gName,
//       groupImage: gImage,
//       // Якщо це група - одразу кешуємо її назву як основну
//       chatName: isGroupChat ? (gName ?? 'Group Chat') : null,
//       chatImage: isGroupChat ? gImage : null,
//     );
//   }
  
//   // --- РОЗУМНІ ГЕТТЕРИ ДЛЯ UI ---

//   // Якщо це група -> повертаємо назву групи.
//   // Якщо приватний -> повертаємо те, що знайшли (ім'я друга) або заглушку.
//   String get displayName {
//     if (isGroup) {
//       return groupName ?? 'New Group';
//     }
//     return _cachedChatName ?? 'Unknown User'; 
//   }

//   // Сеттер, щоб ми могли оновити ім'я друга, коли завантажимо його з Users
//   set chatName(String? name) {
//     _cachedChatName = name;
//   }

//   String? get displayImage {
//     if (isGroup) {
//       return groupImage;
//     }
//     return _cachedChatImage;
//   }
  
//   set chatImage(String? image) {
//     _cachedChatImage = image;
//   }

//   DateTime get lastActivityTime => lastMessage?.timestamp ?? DateTime(2000);
//   String get lastMessageText => lastMessage?.text ?? 'Немає повідомлень';
// }



















// // import 'package:chat_lab_kpp/features/chat/widgets/message_bubbles/message_model.dart'; // перевірте шлях
// // import 'chat_member_model.dart';

// // class Chat {
// //   final int id;
// //   final String name;
// //   final List<Message> messages;
  
// //   // Нові поля
// //   final String description;
// //   final List<ChatMember> members;
// //   final List<String> mediaFiles; // Список назв файлів або URL

// //   Chat({
// //     required this.id,
// //     required this.name,
// //     required this.messages,
// //     // Додаємо дефолтні значення або вимагаємо їх
// //     //нове
// //     this.description = '',
// //     this.members = const [],
// //     this.mediaFiles = const [],
// //   });

 

// //   // Останнє повідомлення текстом (для прев'ю)
// //   String get lastMessageText => messages.isNotEmpty ? messages.last.text : 'Немає повідомлень';
  
// //   // Час останньої активності (для сортування)
// //   // Якщо повідомлень немає, ставимо старий час, щоб чат був внизу
// //   DateTime get lastActivityTime => messages.isNotEmpty ? messages.last.timestamp : DateTime(2000);
// // }











































