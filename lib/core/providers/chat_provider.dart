import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../features/chat/models/chat_model.dart';
import '../../features/chat/widgets/message_bubbles/message_model.dart';
import '../../features/chat/repositories/chat_repository.dart';
import '../../features/auth/models/user_model.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository = ChatRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- СТАН ---
  // Чати
  List<Chat> _chats = [];
  List<Chat> _filteredChats = [];
  StreamSubscription? _chatsSubscription;
  bool _isLoadingChats = false;

  // Повідомлення (активний чат)
  List<Message> _currentMessages = [];
  StreamSubscription? _messagesSubscription;
  bool _isLoadingMessages = false;
  String? _activeChatId;

  // Учасники
  List<UserModel> _chatMembers = [];
  bool _isLoadingMembers = false;

  // --- ГЕТТЕРИ ---
  List<Chat> get chats => _filteredChats;
  bool get isLoadingChats => _isLoadingChats;

  List<Message> get currentMessages => _currentMessages;
  bool get isLoadingMessages => _isLoadingMessages;

  List<UserModel> get chatMembers => _chatMembers;
  bool get isLoadingMembers => _isLoadingMembers;

  String? get currentUserId => _auth.currentUser?.uid;

  // ===========================================================================
  // 1. ІНІЦІАЛІЗАЦІЯ ТА СПИСОК ЧАТІВ
  // ===========================================================================


  
  void init() {
    _isLoadingChats = true;
    notifyListeners();

    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    _chatsSubscription = _repository.getChatsStream().listen((chatsData) async {
      _chats = chatsData;

      // Підтягуємо імена/аватарки для приватних чатів (Client-side Join)
      for (var chat in _chats) {
        if (!chat.isGroup) {
          final otherUserId = chat.participantIds.firstWhere(
            (id) => id != myUid,
            orElse: () => '',
          );

          if (otherUserId.isNotEmpty) {
            final user = await _repository.getUserProfile(otherUserId);
            if (user != null) {
              chat.chatName = user.username;
              chat.chatImage = user.photoUrl;
            }
          }
        }
      }

      // Сортуємо: нові зверху
      _chats.sort((a, b) => b.lastActivityTime.compareTo(a.lastActivityTime));
      

      _filteredChats = _chats;
      
      _isLoadingChats = false;
      notifyListeners();
    }, onError: (error) {
      debugPrint("Error loading chats: $error");
      _isLoadingChats = false;
      notifyListeners();
    });
  }

  void searchChats(String query) {
    if (query.isEmpty) {
      _filteredChats = _chats;
    } else {
      _filteredChats = _chats
          .where((chat) => chat.displayName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  Chat? getChatById(String id) {
    try {
      return _chats.firstWhere((chat) => chat.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> createNewChat(String name, List<String> userIds) async {
    await _repository.createGroupChat(name, userIds);
  }

  Future<String?> startChatWithUser(String userId) async {
    try {
      return await _repository.createPrivateChat(userId);
    } catch (e) {
      debugPrint("Error creating chat: $e");
      return null;
    }
  }

  Future<void> leaveChat(String chatId) async {
    try {
      await _repository.leaveChat(chatId);
      
      // Якщо ми вийшли з чату, який зараз відкритий - треба закрити його в UI
      if (_activeChatId == chatId) {
        _activeChatId = null;
        _currentMessages = [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error leaving chat: $e");
    }
  }

  // ===========================================================================
  // 2. ПОВІДОМЛЕННЯ (Вхід/Вихід з чату, CRUD)
  // ===========================================================================

  void enterChat(String chatId) {
    if (_activeChatId == chatId) return;

    _activeChatId = chatId;
    _isLoadingMessages = true;
    _currentMessages = [];
    notifyListeners();

    _repository.markChatAsRead(chatId);

    _messagesSubscription?.cancel();
    _messagesSubscription = _repository.getMessagesStream(chatId).listen(
      (messages) {
        _currentMessages = messages;
        _isLoadingMessages = false;
        notifyListeners();
      },
      onError: (error) {
        debugPrint("Error listening to messages: $error");
        _isLoadingMessages = false;
        notifyListeners();
      },
    );
  }

  void leaveChatPage() { /// не знаю для чого воно
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _currentMessages = [];
    _activeChatId = null;
  }

  void sendMessage(String chatId, String text) {
    if (text.trim().isEmpty) return;
    
    final chat = getChatById(chatId);
    final participants = chat?.participantIds ?? [];

    _repository.sendMessage(chatId, text, participants);
  }

  // void sendMessage(String chatId, String text) {
  //   if (text.trim().isEmpty) return;
  //   _repository.sendMessage(chatId, text);
  // }

  

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    try {
      await _repository.editMessage(chatId, messageId, newText);
    } catch (e) {
      debugPrint("Error editing message: $e");
    }
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      _currentMessages.removeWhere((msg) => msg.id == messageId);
      notifyListeners();

      await _repository.deleteMessage(chatId, messageId);
      
      
    } catch (e) {
      debugPrint("Error deleting message: $e");
      
    }
  }

  // Future<void> deleteMessage(String chatId, String messageId) async {
  //   try {
  //     await _repository.deleteMessage(chatId, messageId);
  //   } catch (e) {
  //     debugPrint("Error deleting message: $e");
  //   }
  // }

  // ===========================================================================
  // 3. МЕДІА ТА ФАЙЛИ (Фото, Відео, PDF)
  // ===========================================================================

  Future<void> sendMediaMessage(String chatId) async {
    final ImagePicker picker = ImagePicker();
    // pickMedia дозволяє бачити і фото, і відео в галереї
    final XFile? file = await picker.pickMedia();

    if (file != null) {
      String msgType = 'image'; // За замовчуванням

      // Перевірка розширення
      final String extension = file.name.split('.').last.toLowerCase();
      if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
        msgType = 'video';
      }
      // Перевірка mimeType (для надійності на Web)
      if (file.mimeType != null && file.mimeType!.startsWith('video/')) {
        msgType = 'video';
      }
      final chat = getChatById(chatId);
      final participants = chat?.participantIds ?? [];

      try {
        await _repository.sendFileMessage(
          chatId: chatId, 
          file: file, 
          messageType: msgType,
          chatParticipants: participants,
        );
      } catch (e) {
        debugPrint("Failed to send media: $e");
      }
    }
  }

  /// Метод для PDF документів
  Future<void> sendPdfMessage(String chatId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      final PlatformFile platformFile = result.files.first;
      // Конвертація в XFile для сумісності
      final XFile xFile = platformFile.xFile; 

      final chat = getChatById(chatId);
      final participants = chat?.participantIds ?? [];  

      try {
        await _repository.sendFileMessage(
          chatId: chatId, 
          file: xFile, 
          messageType: 'file',
          chatParticipants: participants,
        );
      } catch (e) {
        debugPrint("Failed to send PDF: $e");
      }
    }
  }

  // ===========================================================================
  // 4. УЧАСНИКИ ЧАТУ
  // ===========================================================================

  Future<void> loadChatMembers(String chatId) async {
    final chat = getChatById(chatId);
    if (chat == null || chat.participantIds.isEmpty) return;

    _isLoadingMembers = true;
    notifyListeners();

    try {
      final members = await _repository.getUsersByIds(chat.participantIds);
      _chatMembers = members;
    } catch (e) {
      debugPrint("Error loading members: $e");
    } finally {
      _isLoadingMembers = false;
      notifyListeners();
    }
  }

  Future<String?> addMemberByLogin(String chatId, String login) async {
    try {
      _isLoadingMembers = true;
      notifyListeners();

      final userId = await _repository.findUserIdByLogin(login);
      
      if (userId == null) {
        _isLoadingMembers = false;
        notifyListeners();
        return "User not found";
      }

      if (_chatMembers.any((m) => m.uid == userId)) {
        _isLoadingMembers = false;
        notifyListeners();
        return "User already in chat";
      }

      await _repository.addParticipant(chatId, userId);
      await loadChatMembers(chatId);
      
      return null; // Успіх
    } catch (e) {
      _isLoadingMembers = false;
      notifyListeners();
      return "Error: $e";
    }
  }

  Future<void> addMemberById(String chatId, String userId) async {
    try {
      if (_chatMembers.any((m) => m.uid == userId)) return;

      _isLoadingMembers = true;
      notifyListeners();

      await _repository.addParticipant(chatId, userId);
      await loadChatMembers(chatId);
    } catch (e) {
      debugPrint("Error adding member: $e");
    } finally {
      _isLoadingMembers = false;
      notifyListeners();
    }
  }

  Future<void> removeMember(String chatId, String userId) async {
    try {
      await _repository.removeParticipant(chatId, userId);
      _chatMembers.removeWhere((m) => m.uid == userId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error removing member: $e");
    }
  }

  

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    super.dispose();
  }
}































// //СТАРА ВЕРСІЯ ДО РЕФАКТОРИНГУ
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:chat_lab_kpp/features/chat/models/chat_model.dart';
// import 'package:chat_lab_kpp/features/chat/widgets/message_bubbles/message_model.dart';
// //import 'package:chat_lab_kpp/features/chat/models/chat_member_model.dart';
// import 'package:chat_lab_kpp/features/chat/repositories/chat_repository.dart';
// import '../../features/auth/models/user_model.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';

// class ChatProvider extends ChangeNotifier {
//   final ChatRepository _repository = ChatRepository();
  
//   List<UserModel> _chatMembers = [];
//   bool _isLoadingMembers = false;

//   // --- ЧАТИ (Список діалогів) ---
//   List<Chat> _chats = [];
//   List<Chat> _filteredChats = [];
//   StreamSubscription? _chatsSubscription;
//   bool _isLoadingChats = false;

//   // --- ПОВІДОМЛЕННЯ (Активний чат) ---
//   List<Message> _currentMessages = []; // Локальний стан повідомлень
//   StreamSubscription? _messagesSubscription; // Підписка на конкретний чат
//   bool _isLoadingMessages = false;
//   String? _activeChatId; // Щоб знати, який чат відкритий

//   // Геттери
//   List<UserModel> get chatMembers => _chatMembers;
//   bool get isLoadingMembers => _isLoadingMembers;
  
//   List<Chat> get chats => _filteredChats;
//   bool get isLoadingChats => _isLoadingChats;
  
//   List<Message> get currentMessages => _currentMessages;
//   bool get isLoadingMessages => _isLoadingMessages;

// String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

//   // Цей метод треба викликати при старті екрану (наприклад, в initState)
//   // void init() {
//   //   _isLoadingMessages = true;
//   //   notifyListeners();

    
//   //   // Підписуємось на Stream з репозиторію
//   //   _chatsSubscription = _repository.getChatsStream().listen((chatsData) {
//   //     _chats = chatsData;
      
//   //     // Сортуємо: найновіші повідомлення зверху
//   //     _chats.sort((a, b) => b.lastActivityTime.compareTo(a.lastActivityTime));
      
//   //     // Тимчасово: ставимо заглушку імені, бо поки не підтягуємо імена з users
//   //     for (var c in _chats) {
//   //       c.chatName = "Chat User"; 
//   //     }

//   //     _filteredChats = _chats; 
//   //     _isLoadingMessages = false;
//   //     notifyListeners();
//   //   }, onError: (error) {
//   //     print("Error: $error");
//   //     _isLoadingMessages = false;
//   //     notifyListeners();
//   //   });
//   // }

//   void init() {
//     _isLoadingChats = true;
//     notifyListeners();

//     // Тепер FirebaseAuth доступний завдяки імпорту
//     final myUid = FirebaseAuth.instance.currentUser?.uid;
//     if (myUid == null) return; 

//     _chatsSubscription = _repository.getChatsStream().listen((chatsData) async {
//       _chats = chatsData;

//       // --- МАГІЯ ІМЕН (Client-side Join) ---
//       for (var chat in _chats) {
//         if (!chat.isGroup) {
//           final otherUserId = chat.participantIds.firstWhere(
//             (id) => id != myUid, 
//             orElse: () => '',
//           );

//           if (otherUserId.isNotEmpty) {
//             final user = await _repository.getUserProfile(otherUserId);
            
//             if (user != null) {
//               chat.chatName = user.username; 
//               chat.chatImage = user.photoUrl;
//             }
//           }
//         }
//       }

//       _chats.sort((a, b) => b.lastActivityTime.compareTo(a.lastActivityTime));
      
//       _filteredChats = _chats; 
//       _isLoadingChats = false;
//       notifyListeners(); 
//     }, onError: (error) {
//       print("Error loading chats: $error");
//       _isLoadingChats = false;
//       notifyListeners();
//     });
//   }

//   // Пошук чату за String ID
//   Chat? getChatById(String id) {
//     try {
//       return _chats.firstWhere((chat) => chat.id == id);
//     } catch (e) {
//       return null;
//     }
//   }

//   void enterChat(String chatId) {
//     // Якщо ми вже в цьому чаті, нічого не перезавантажуємо (опціонально)
//     if (_activeChatId == chatId) return;

//     _activeChatId = chatId;
//     _isLoadingMessages = true;
//     _currentMessages = []; // Очищаємо старі повідомлення, щоб не миготіли
//     notifyListeners(); // Оновлюємо UI (покаже лоадер)

//     // Скасовуємо попередню підписку, якщо була
//     _messagesSubscription?.cancel();

//     // Підписуємось на нову
//     _messagesSubscription = _repository.getMessagesStream(chatId).listen(
//       (messages) {
//         _currentMessages = messages;
//         _isLoadingMessages = false;
//         notifyListeners(); // КРИТИЧНО: Кажемо UI перемалюватися
//       },
//       onError: (error) {
//         print("Error listening to messages: $error");
//         _isLoadingMessages = false;
//         notifyListeners();
//       },
//     );
//   }

//   /// Викликаємо це, коли виходимо з екрану чату (dispose)
//   void leaveChat() {
//     _messagesSubscription?.cancel();
//     _messagesSubscription = null;
//     _currentMessages = [];
//     _activeChatId = null;
//     // notifyListeners() тут можна не викликати, бо екран все одно закривається
//   }

//   // Відправка повідомлення
//   void sendMessage(String chatId, String text) {
//     if (text.trim().isEmpty) return;
//     // Оптимістичне оновлення UI не обов'язкове, бо Stream спрацює миттєво,
//     // але для ідеального UX можна додати повідомлення в список локально перед відправкою.
//     _repository.sendMessage(chatId, text);
//   }
//   void searchChats(String query) {
//      if (query.isEmpty) {
//       _filteredChats = _chats;
//     } else {
//       _filteredChats = _chats
//           .where((chat) => chat.displayName.toLowerCase().contains(query.toLowerCase()))
//           .toList();
//     }
//     notifyListeners();
//   }
  
//   Stream<List<Message>> getMessagesStream(String chatId) {
//     return _repository.getMessagesStream(chatId);
//   }

//   Future<void> createNewChat(String name, List<String> userIds) async {
//     // Викликаємо репозиторій
//     await _repository.createGroupChat(name, userIds);
//   }

//   @override
//   void dispose() {
//     _chatsSubscription?.cancel(); // Дуже важливо відписатися!
//     super.dispose();
//   }

//   // Розпочати чат з контактом
//   Future<String?> startChatWithUser(String userId) async {
//     try {
//       final chatId = await _repository.createPrivateChat(userId);
//       // Одразу оновлюємо список чатів, щоб новий чат з'явився в списку
//       // (хоча Stream і так це зробить, але це для надійності)
//       return chatId;
//     } catch (e) {
//       print("Error creating chat: $e");
//       return null;
//     }
//   }

  

//   Future<void> loadChatMembers(String chatId) async {
//     // 1. Знаходимо чат локально, щоб взяти ID учасників
//     final chat = getChatById(chatId);
//     if (chat == null || chat.participantIds.isEmpty) return;

//     _isLoadingMembers = true;
//     notifyListeners();

//     try {
//       // 2. Звертаємось до репозиторію
//       final members = await _repository.getUsersByIds(chat.participantIds);
//       _chatMembers = members;
//     } catch (e) {
//       print("Error loading members: $e");
//     } finally {
//       _isLoadingMembers = false;
//       notifyListeners();
//     }
//   }

// // Додавання учасника по ID (для вибору зі списку контактів)
//   Future<void> addMemberById(String chatId, String userId) async {
//     try {
//       // Перевірка, чи юзер вже є (локально)
//       if (_chatMembers.any((m) => m.uid == userId)) {
//         return; // Вже є, нічого не робимо
//       }

//       _isLoadingMembers = true;
//       notifyListeners();

//       // Додаємо в базу
//       await _repository.addParticipant(chatId, userId);

//       // Оновлюємо список
//       await loadChatMembers(chatId);
      
//     } catch (e) {
//       print("Error adding member: $e");
//     } finally {
//       _isLoadingMembers = false;
//       notifyListeners();
//     }
//   }

//   Future<String?> addMemberByLogin(String chatId, String login) async {
//     try {
//       _isLoadingMembers = true;
//       notifyListeners();

//       // 1. Шукаємо ID юзера
//       final userId = await _repository.findUserIdByLogin(login);
      
//       if (userId == null) {
//         _isLoadingMembers = false;
//         notifyListeners();
//         return "User not found";
//       }

//       // 2. Перевіряємо, чи він вже є (локально)
//       if (_chatMembers.any((m) => m.uid == userId)) {
//         _isLoadingMembers = false;
//         notifyListeners();
//         return "User already in chat";
//       }

//       // 3. Додаємо в базу
//       await _repository.addParticipant(chatId, userId);

//       // 4. Оновлюємо список учасників на екрані
//       await loadChatMembers(chatId);
      
//       return null; // Null означає успіх (немає помилки)
//     } catch (e) {
//       _isLoadingMembers = false;
//       notifyListeners();
//       return "Error: $e";
//     }
//   }

//   // Видалення учасника
//   Future<void> removeMember(String chatId, String userId) async {
//     try {
//       await _repository.removeParticipant(chatId, userId);
//       // Оновлюємо список локально (видаляємо зі списку без зайвого запиту до БД)
//       _chatMembers.removeWhere((m) => m.uid == userId);
//       notifyListeners();
//     } catch (e) {
//       print("Error removing member: $e");
//     }
//   }

//   //редагування та видалення повідомлень
//   Future<void> deleteMessage(String chatId, String messageId) async {
//     try {
//       await _repository.deleteMessage(chatId, messageId);
//       // Stream сам оновить UI, нічого робити не треба
//     } catch (e) {
//       print("Error deleting message: $e");
//     }
//   }

//   Future<void> editMessage(String chatId, String messageId, String newText) async {
//     try {
//       await _repository.editMessage(chatId, messageId, newText);
//     } catch (e) {
//       print("Error editing message: $e");
//     }
//   }

//   Future<void> sendImageMessage(String chatId) async {
//     final ImagePicker picker = ImagePicker();
//     // Вибираємо фото
//     final XFile? image = await picker.pickImage(
//       source: ImageSource.gallery,
//       imageQuality: 70, // Стискаємо
//     );

//     if (image != null) {
//       // Можна показати індикатор завантаження тут
//       try {
//         await _repository.sendFileMessage(
//           chatId: chatId, 
//           file: image, 
//           messageType: 'image'
//         );
//       } catch (e) {
//         print("Failed to send image: $e");
//       }
//     }
//   }

//   Future<void> sendVideoMessage(String chatId) async {
//     final ImagePicker picker = ImagePicker();
    
//     // ВИБИРАЄМО ВІДЕО
//     final XFile? video = await picker.pickVideo(
//       source: ImageSource.gallery,
//       maxDuration: const Duration(minutes: 1), // Обмеження для лаби
//     );

//     if (video != null) {
//       try {
//         // Використовуємо той самий метод репозиторію, але тип 'video'
//         await _repository.sendFileMessage(
//           chatId: chatId, 
//           file: video, 
//           messageType: 'video' // <--- ВАЖЛИВО
//         );
//       } catch (e) {
//         print("Failed to send video: $e");
//       }
//     }
//   }

//   // Універсальний метод відправки медіа (Фото або Відео)
//   Future<void> sendMediaMessage(String chatId) async {
//     final ImagePicker picker = ImagePicker();
    
//     // 1. pickMedia дозволяє бачити і фото, і відео в галереї
//     final XFile? file = await picker.pickMedia();

//     if (file != null) {
//       String msgType = 'image'; // За замовчуванням вважаємо картинкою

//       // 2. Визначаємо тип файлу за розширенням
//       // (На web file.path може не мати розширення, тому краще дивитися на file.name або mimeType)
//       final String extension = file.name.split('.').last.toLowerCase();
      
//       if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
//         msgType = 'video';
//       }
      
//       // Якщо це web і mimeType доступний, перевіряємо його для надійності
//       if (file.mimeType != null && file.mimeType!.startsWith('video/')) {
//         msgType = 'video';
//       }

//       try {
//         // Викликаємо наш існуючий метод репозиторію
//         await _repository.sendFileMessage(
//           chatId: chatId, 
//           file: file, 
//           messageType: msgType
//         );
//       } catch (e) {
//         print("Failed to send media: $e");
//       }
//     }
//   }

//   Future<void> sendPdfMessage(String chatId) async {
//   // Вибираємо тільки PDF файли
//   FilePickerResult? result = await FilePicker.platform.pickFiles(
//     type: FileType.custom,
//     allowedExtensions: ['pdf'],
//   );

//   if (result != null && result.files.isNotEmpty) {
//     // file_picker повертає PlatformFile, нам треба перетворити його в XFile
//     // На щастя, нові версії мають властивість xFile
//     final PlatformFile platformFile = result.files.first;
    
//     // Конвертація в XFile (для сумісності з репозиторієм)
//     final XFile xFile = platformFile.xFile; 

//     try {
//       await _repository.sendFileMessage(
//         chatId: chatId, 
//         file: xFile, 
//         messageType: 'file' // <-- Передаємо тип file
//       );
//     } catch (e) {
//       print("Failed to send PDF: $e");
//     }
//   }
// }
// }























































// // import 'package:flutter/material.dart';
// // import 'package:chat_lab_kpp/features/chat/models/chat_model.dart';
// // import 'package:chat_lab_kpp/features/chat/widgets/message_bubbles/message_model.dart';
// // import 'package:chat_lab_kpp/features/chat/models/chat_member_model.dart';

// // class ChatProvider extends ChangeNotifier {
// //   List<Chat> _chats = [];
// //   List<Chat> _filteredChats = []; 
// //   bool _isLoading = false;
// //   String? _errorMessage;

// //   List<Chat> get chats => _filteredChats;
// //   bool get isLoading => _isLoading;
// //   String? get errorMessage => _errorMessage; 
// //   bool get hasError => _errorMessage != null; // Допоміжний геттер

// //   // --- МЕТОД СОРТУВАННЯ ---
// //   void _sortChatsByTime() {
// //     // Сортуємо: b.compareTo(a) дасть спадання (нові зверху)
// //     _chats.sort((a, b) => b.lastActivityTime.compareTo(a.lastActivityTime));
    
    
// //     _filteredChats = List.from(_chats); 
// //   }

// //   Future<void> loadChats() async {
// //     _isLoading = true;
// //     _errorMessage = null; // Очищаємо помилки перед новим запитом
// //     notifyListeners();

// //     try {      
// //       //throw Exception("Connection timed out");
      

// //       final now = DateTime.now();

// //       // 2. Генерація даних
// //       _chats = List.generate(20, (index) {
// //         // Робимо так, щоб кожен чат мав трохи різний час останнього повідомлення
// //         final timeOffset = index * 15; // Кожен наступний чат старіший на 15 хв
// //         final lastMsgTime = now.subtract(Duration(minutes: timeOffset));

// //         // Імена для краси (перші кілька - як на дизайні)
// //         String chatName;
// //         //String avatarUrl = ''; 
        
// //         chatName = 'Chat User $index';

// //         List<ChatMember> members = [
// //           ChatMember(name: 'Kolos Andrii', status: 'Online', isMe: true, isAdmin: true),
// //           ChatMember(name: chatName, status: 'Online', isMe: false),
// //         ];
        
// //         if (index % 3 == 0) {
// //           members.add(ChatMember(name: 'Random Guest', status: 'Offline', isMe: false));
// //         }

// //         // Генеруємо повідомлення
// //         List<Message> messages = [
// //           Message(
// //             text: 'Привіт! Як справи?',
// //             timestamp: lastMsgTime.subtract(const Duration(hours: 1)),
// //             isSentByMe: false,
// //           ),
// //           Message(
// //             text: 'Це тестове повідомлення для лабораторної.',
// //             timestamp: lastMsgTime.subtract(const Duration(minutes: 5)),
// //             isSentByMe: true,
// //           ),
// //           // Останнє повідомлення (воно буде відображатись у списку)
// //           Message(
// //             text: index == 0 ? 'lalalalalalalal' : 'Message content #$index',
// //             timestamp: lastMsgTime,
// //             isSentByMe: index % 2 == 0, // Чергуємо: то я, то він
// //           ),
// //         ];

// //         // Створюємо об'єкт Чату
// //         return Chat(
// //           id: index,
// //           name: chatName,
// //           messages: messages,
// //           description: 'This is a real chat with $chatName created for KPP lab.',
// //           members: members,
          
// //         );
// //       });

      
// //       _chats.sort((a, b) => b.lastActivityTime.compareTo(a.lastActivityTime));
      
// //       _filteredChats = List.from(_chats);

// //     } catch (e) {
      
// //       _errorMessage = "Не вдалося завантажити чати. \nПеревірте з'єднання з інтернетом.";
// //       debugPrint("Error loading chats: $e"); // Вивід в консоль розробника
      
// //     } finally {
// //       _isLoading = false;
// //       notifyListeners(); // Оновлюємо UI (покажемо або список, або помилку)
// //     }
// //   }

// //   // Future<void> loadChats() async {
// //   //   _isLoading = true;
// //   //   notifyListeners();
// //   //   await Future.delayed(const Duration(seconds: 1));
// //   //   final now = DateTime.now();
// //   //   // Генеруємо чати з різним часом для наочності
// //   //   _chats = List.generate(20, (index) {
// //   //     List<ChatMember> dummyMembers = [
// //   //       ChatMember(name: 'Andrii Kolos', status: 'Online', isMe: true, isAdmin: true),
// //   //       ChatMember(name: 'User $index', status: 'Online', isMe: false),
// //   //       if (index % 2 == 0) // Додамо третього учасника в деякі чати
// //   //          ChatMember(name: 'Extra Friend', status: 'Offline', isMe: false),
// //   //     ];      
// //   //     final timeOffset = index * 15;       
// //   //     return Chat(
// //   //       id: index,
// //   //       name: 'Чат $index',
// //   //       messages: [
// //   //         Message(
// //   //           text: 'Старе повідомлення', 
// //   //           timestamp: now.subtract(Duration(days: 1, minutes: timeOffset)), 
// //   //           isSentByMe: false
// //   //         ),
// //   //         Message(
// //   //           text: 'Останнє повідомлення', 
// //   //           timestamp: now.subtract(Duration(minutes: timeOffset)), // Чим більший індекс, тим старіший чат
// //   //           isSentByMe: index % 2 == 0, // Чередуємо відправників
// //   //         ),
// //   //       ],
// //   //       description: 'Real chat with real User $index! Its not fake!!!!',
// //   //       members: dummyMembers,        
// //   //     );
// //   //   });    
// //   //   _sortChatsByTime(); 
// //   //   _isLoading = false;
// //   //   notifyListeners();
// //   // }

// //   void searchChats(String query) {
// //     if (query.isEmpty) {
// //       _filteredChats = _chats;
// //     } else {
// //       _filteredChats = _chats
// //           .where((chat) => chat.name.toLowerCase().contains(query.toLowerCase()))
// //           .toList();
// //     }
// //     notifyListeners();
// //   }

// //   void createNewChat(String name) {
// //     // Генеруємо новий ID (просто беремо максимальний + 1)
// //     final newId = _chats.isEmpty ? 1 : _chats.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
    
// //     final newChat = Chat(
// //       id: newId,
// //       name: name,
// //       messages: [], // Порожній список повідомлень
// //     );

// //     _chats.insert(0, newChat); // Додаємо на початок
// //     _filteredChats = _chats; 
    
// //     notifyListeners();
// //   }

// //   void sendMessage(int chatId, String text) {
// //     if (text.trim().isEmpty) return;

// //     final chatIndex = _chats.indexWhere((c) => c.id == chatId);
// //     if (chatIndex != -1) {
// //       final newMessage = Message(
// //         text: text,
// //         timestamp: DateTime.now(), // Використовуємо реальний час
// //         isSentByMe: true,
// //       );

// //       _chats[chatIndex].messages.add(newMessage);
      
// //       _sortChatsByTime(); 
      
// //       notifyListeners(); 
// //     }
// //   }

// //   Chat getChatById(int id) {
// //     return _chats.firstWhere((chat) => chat.id == id, orElse: () => _chats[0]);
// //   }
// // }

