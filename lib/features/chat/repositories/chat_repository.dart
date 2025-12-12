import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_model.dart';
import '../widgets/message_bubbles/message_model.dart';
import '../../auth/models/user_model.dart';
//import 'storage_repository.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  //final StorageRepository _storageRepo = StorageRepository();
  // ===========================================================================
  // ОТРИМАННЯ ДАНИХ 
  // ===========================================================================

  Stream<List<Chat>> getChatsStream() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participantIds', arrayContains: myUid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Chat.fromFirestore(doc, myUid)).toList();
    });
  }

  Stream<List<Message>> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    // Примітка: 'whereIn' приймає максимум 10 значень.
    final snapshot = await _firestore
        .collection('users')
        .where('uid', whereIn: userIds)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
    } catch (e) {
      print("Error fetching user profile: $e");
    }
    return null;
  }

  Future<String?> findUserIdByLogin(String login) async {
    final formattedLogin = login.startsWith('@') ? login : '@$login';
    final snapshot = await _firestore
        .collection('users')
        .where('login', isEqualTo: formattedLogin)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id;
    }
    return null;
  }

  // ===========================================================================
  // УПРАВЛІННЯ ЧАТАМИ (Створення, Оновлення)
  // ===========================================================================

  Future<void> createGroupChat(String groupName, List<String> friendIds) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    final chatRef = _firestore.collection('chats').doc();
    final allParticipants = [myUid, ...friendIds];
    final unreadMap = {for (var id in allParticipants) id: 0};

    final chatData = {
      'isGroup': true,
      'adminId': myUid,
      'groupName': groupName,
      'groupImage': null,
      'participantIds': allParticipants,
      'unreadCount': unreadMap,
      'lastMessage': null,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivityTime': FieldValue.serverTimestamp(),
    };

    await chatRef.set(chatData);
  }

  Future<String> createPrivateChat(String otherUserId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) throw Exception("User not logged in");

    final List<String> ids = [myUid, otherUserId]..sort();
    final String chatId = "${ids[0]}_${ids[1]}";

    final chatDoc = _firestore.collection('chats').doc(chatId);
    final snapshot = await chatDoc.get();

    if (!snapshot.exists) {
      await chatDoc.set({
        'isGroup': false,
        'groupName': null,
        'groupImage': null,
        'participantIds': [myUid, otherUserId],
        'unreadCount': {myUid: 0, otherUserId: 0},
        'lastMessage': null,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivityTime': FieldValue.serverTimestamp(),
      });
    }

    return chatId;
  }

  Future<void> addParticipant(String chatId, String newUserId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'participantIds': FieldValue.arrayUnion([newUserId]),
      'unreadCount.$newUserId': 0,
    });
  }

  Future<void> removeParticipant(String chatId, String userIdToRemove) async {
    await _firestore.collection('chats').doc(chatId).update({
      'participantIds': FieldValue.arrayRemove([userIdToRemove]),
      'unreadCount.$userIdToRemove': FieldValue.delete(),
    });
  }

  Future<void> leaveChat(String chatId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    // Використовуємо arrayRemove, щоб стерти себе зі списку
    await _firestore.collection('chats').doc(chatId).update({
      'participantIds': FieldValue.arrayRemove([myUid]),
      'unreadCount.$myUid': FieldValue.delete(), // Також видаляємо свій лічильник
    });
  }

  // ===========================================================================
  // 3. ПОВІДОМЛЕННЯ (Текст, Файли, Редагування)
  // ===========================================================================

  Future<void> sendMessage(String chatId, String text, List<String> participantIds) async {  final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    final timestamp = Timestamp.now();
    
    final messageData = {
      'text': text,
      'senderId': myUid,
      'timestamp': timestamp,
      'isRead': false,
      'type': 'text',
      'readBy': [myUid],
    };

    final batch = _firestore.batch();

    final messageRef = _firestore.collection('chats').doc(chatId).collection('messages').doc();
    batch.set(messageRef, messageData);

    Map<String, dynamic> updateData = {
      'lastMessage': messageData,
      'lastActivityTime': timestamp,
    };

    for (var userId in participantIds) {
      if (userId != myUid) {
        updateData['unreadCount.$userId'] = FieldValue.increment(1);
      }
    }

    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, updateData);  

    // final messageRef = _firestore.collection('chats').doc(chatId).collection('messages').doc();
    // batch.set(messageRef, messageData);

    // final chatRef = _firestore.collection('chats').doc(chatId);
    // batch.update(chatRef, {
    //   'lastMessage': messageData,
    // });

    await batch.commit();
  }

  Future<void> sendFileMessage({
    required String chatId,
    required XFile file,
    required String messageType,
    required List<String> chatParticipants, 
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    try {
      // --- (Код підготовки метаданих та завантаження залишається без змін) ---
      String mimeType = 'application/octet-stream';
      String messageText = '📁 File';

      if (messageType == 'image') {
        mimeType = 'image/jpeg';
        messageText = '📷 Photo';
      } else if (messageType == 'video') {
        mimeType = 'video/mp4';
        messageText = '🎥 Video';
      } else if (messageType == 'file') {
        mimeType = 'application/pdf';
        messageText = file.name;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${file.name}';
      final ref = _storage.ref().child('chats/$chatId/$fileName');

      final Uint8List fileBytes = await file.readAsBytes();
      final metadata = SettableMetadata(contentType: mimeType);

      final uploadTask = await ref.putData(fileBytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final now = FieldValue.serverTimestamp();
      // -----------------------------------------------------------------------

      // Формування даних повідомлення
      final messageData = {
        'senderId': myUid,
        'text': messageText,
        'type': messageType,
        'fileUrl': downloadUrl,
        'timestamp': now,
        'readBy': [myUid], // Ти вже прочитав своє повідомлення
      };

      // 1. Додаємо саме повідомлення
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // 2. Готуємо дані для оновлення чату (Last Message + Лічильники)
      final Map<String, dynamic> updateData = {
        'lastMessage': messageData,
        'lastActivityTime': now,
      };

      // 3. ЦИКЛ: Збільшуємо лічильник (+1) для всіх учасників, КРІМ МЕНЕ
      for (var userId in chatParticipants) {
        if (userId != myUid) {
          updateData['unreadCount.$userId'] = FieldValue.increment(1);
        }
      }

      // 4. Оновлюємо документ чату
      await _firestore.collection('chats').doc(chatId).update(updateData);

    } catch (e) {
      print("Error sending file: $e");
      rethrow;
    }
  }

  

  Future<void> markChatAsRead(String chatId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    try {
      final chatDocRef = _firestore.collection('chats').doc(chatId);
      
      // 1. СПОЧАТКУ ОТРИМУЄМО ДАНІ, ЩОБ ПЕРЕВІРИТИ ЧИ Є lastMessage
      final chatSnapshot = await chatDocRef.get();

      if (!chatSnapshot.exists) return;

      final data = chatSnapshot.data();
      
      // Перевіряємо, чи є взагалі lastMessage (щоб не створити пустий об'єкт у порожньому чаті)
      if (data != null && data['lastMessage'] != null) {
        await chatDocRef.update({
          'lastMessage.readBy': FieldValue.arrayUnion([myUid]),
          'unreadCount.$myUid': 0,
        });
      } else {
        await chatDocRef.update({
          'unreadCount.$myUid': 0,
        });
      }

      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final batch = _firestore.batch();
      bool needsCommit = false;

      for (var doc in snapshot.docs) {
        final msgData = doc.data();
        final List<dynamic> readBy = msgData['readBy'] ?? [];

        if (!readBy.contains(myUid)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([myUid])
          });
          needsCommit = true;
        }
      }

      if (needsCommit) {
        await batch.commit();
      }
      
    } catch (e) {
      print("Error marking chat as read: $e");
    }
  }

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text': newText,
      'isEdited': true,
    });
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      final chatRef = _firestore.collection('chats').doc(chatId);
      final messagesRef = chatRef.collection('messages');

      await messagesRef.doc(messageId).delete();
      final snapshot = await messagesRef
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final newLastMsgDoc = snapshot.docs.first;
        final newLastMsgData = newLastMsgDoc.data();

        newLastMsgData['id'] = newLastMsgDoc.id; 

        await chatRef.update({
          'lastMessage': newLastMsgData,
          'lastActivityTime': newLastMsgData['timestamp'], 
        });
      } else {
        await chatRef.update({
          'lastMessage': null, // Видаляємо поле lastMessage
        });
      }
    } catch (e) {
      print("Error deleting message: $e");
      rethrow;
    }
  }

  // Future<void> deleteMessage(String chatId, String messageId) async {
  //   await _firestore
  //       .collection('chats')
  //       .doc(chatId)
  //       .collection('messages')
  //       .doc(messageId)
  //       .delete();
  // }
}






























































// Future<void> sendFileMessage({
  //   required String chatId, 
  //   required XFile file, 
  //   required String messageType // 'image', 'video', 'file'
  // }) async {
  //   final myUid = _auth.currentUser?.uid;
  //   if (myUid == null) return;

  //   try {
  //     // 1. Підготовка метаданих
  //     String mimeType = 'application/octet-stream';
  //     String messageText = '📁 File';

  //     if (messageType == 'image') {
  //       mimeType = 'image/jpeg';
  //       messageText = '📷 Photo';
  //     } else if (messageType == 'video') {
  //       mimeType = 'video/mp4';
  //       messageText = '🎥 Video';
  //     } else if (messageType == 'file') {
  //       mimeType = 'application/pdf';
  //       messageText = file.name; // Зберігаємо назву файлу
  //     }

  //     // 2. Завантаження в Storage
  //     final timestamp = DateTime.now().millisecondsSinceEpoch;
  //     final fileName = '${timestamp}_${file.name}';
  //     final ref = _storage.ref().child('chats/$chatId/$fileName');
      
  //     final Uint8List fileBytes = await file.readAsBytes();
  //     final metadata = SettableMetadata(contentType: mimeType);

  //     final uploadTask = await ref.putData(fileBytes, metadata);
  //     final downloadUrl = await uploadTask.ref.getDownloadURL();

  //     final now = FieldValue.serverTimestamp();

  //     // 3. Формування даних повідомлення
  //     final messageData = {
  //       'senderId': myUid,
  //       'text': messageText, 
  //       'type': messageType,
  //       'fileUrl': downloadUrl,
  //       'timestamp': now,
  //       'isRead': false,
  //       'readBy': [myUid],
  //     };

  //     await _firestore
  //         .collection('chats')
  //         .doc(chatId)
  //         .collection('messages')
  //         .add(messageData);

  //     await _firestore.collection('chats').doc(chatId).update({
  //       'lastMessage': messageData,
  //       'lastActivityTime': now,
  //     });

  //   } catch (e) {
  //     print("Error sending file: $e");
  //     rethrow;
  //   }
  // }


// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../models/chat_model.dart';
// import 'package:chat_lab_kpp/features/chat/widgets/message_bubbles/message_model.dart';
// import '../../auth/models/user_model.dart';
// import 'dart:typed_data';
// import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart';


// class ChatRepository {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   final FirebaseStorage _storage = FirebaseStorage.instance;

//   // 1. Отримати потік (Stream) чатів
//   // Stream дозволяє оновлювати список в реальному часі, коли приходить повідомлення
//   Stream<List<Chat>> getChatsStream() {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) return Stream.value([]);

//     return _firestore
//         .collection('chats')
//         .where('participantIds', arrayContains: myUid)
//         .snapshots() // Слухаємо зміни
//         .map((snapshot) {
//       // Перетворюємо документи в об'єкти Chat
//       return snapshot.docs.map((doc) => Chat.fromFirestore(doc, myUid)).toList();
//     });
//   }

//   // 2. Отримати повідомлення конкретного чату
//   Stream<List<Message>> getMessagesStream(String chatId) {
//     return _firestore
//         .collection('chats')
//         .doc(chatId)
//         .collection('messages')
//         .orderBy('timestamp', descending: true) // Сортуємо: нові знизу (або зверху, залежить від UI)
//         .snapshots()
//         .map((snapshot) {
//       return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
//     });
//   }

//   // 3. Відправка повідомлення (Пункт 5 лаби)
//   Future<void> sendMessage(String chatId, String text) async {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) return;

//     final timestamp = Timestamp.now();
    
//     // Дані для повідомлення
//     final messageData = {
//       'text': text,
//       'senderId': myUid,
//       'timestamp': timestamp,
//       'isRead': false,
//       'type': 'text',
//     };

//     // BATCH WRITE: Пишемо в два місця одночасно
//     final batch = _firestore.batch();

//     // А. Додаємо саме повідомлення в підколекцію
//     final messageRef = _firestore.collection('chats').doc(chatId).collection('messages').doc();
//     batch.set(messageRef, messageData);

//     // Б. Оновлюємо "прев'ю" чату (щоб в списку змінився текст)
//     final chatRef = _firestore.collection('chats').doc(chatId);
//     batch.update(chatRef, {
//       'lastMessage': messageData,
//       // Тут можна додати логіку збільшення лічильника непрочитаних для іншого юзера
//     });

//     await batch.commit();
//   }

//   // Створення нового групового чату
//   Future<void> createGroupChat(String groupName, List<String> friendIds) async {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) return;

//     final chatRef = _firestore.collection('chats').doc();

//     // Об'єднуємо мій ID + ID друзів
//     final allParticipants = [myUid, ...friendIds];
    
//     // Створюємо мапу для лічильників (для всіх ставимо 0)
//     final unreadMap = {for (var id in allParticipants) id: 0};

//     final chatData = {
//       'isGroup': true,
//       'groupName': groupName,
//       'groupImage': null,
//       'participantIds': allParticipants, // Зберігаємо повний список
//       'unreadCount': unreadMap,
//       'lastMessage': null,
//       'createdAt': FieldValue.serverTimestamp(),
//     };

//     await chatRef.set(chatData);
//   }

//   // Створення або отримання існуючого приватного чату
//   Future<String> createPrivateChat(String otherUserId) async {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) throw Exception("User not logged in");

//     // Генеруємо унікальний ID для пари користувачів (щоб не було дублікатів)
//     // Сортуємо ID, щоб userA_userB було те саме, що userB_userA
//     final List<String> ids = [myUid, otherUserId]..sort();
//     final String chatId = "${ids[0]}_${ids[1]}";

//     final chatDoc = _firestore.collection('chats').doc(chatId);
//     final snapshot = await chatDoc.get();

//     // Якщо чату ще немає — створюємо його
//     if (!snapshot.exists) {
//       await chatDoc.set({
//         'isGroup': false,
//         'groupName': null, // Ім'я не потрібне, воно буде братись з профілю співрозмовника
//         'groupImage': null,
//         'participantIds': [myUid, otherUserId], // Додаємо обох!
//         'unreadCount': {myUid: 0, otherUserId: 0},
//         'lastMessage': null,
//         'createdAt': FieldValue.serverTimestamp(),
//       });
//     }

//     return chatId; // Повертаємо ID, щоб одразу відкрити цей чат
//   }

//   Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
//     if (userIds.isEmpty) return [];

//     // Firestore обмеження: 'whereIn' приймає максимум 10 значень.
//     // Для лаби це ок, для продакшену треба розбивати на пачки по 10.
//     final snapshot = await _firestore
//         .collection('users')
//         .where('uid', whereIn: userIds)
//         .get();

//     return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
//   }

//   Future<UserModel?> getUserProfile(String userId) async {
//     try {
//       final doc = await _firestore.collection('users').doc(userId).get();
//       if (doc.exists) {
//         return UserModel.fromFirestore(doc);
//       }
//     } catch (e) {
//       print("Error fetching user profile: $e");
//     }
//     return null;
//   }

//   // Додати учасника в чат
//   Future<void> addParticipant(String chatId, String newUserId) async {
//     await _firestore.collection('chats').doc(chatId).update({
//       'participantIds': FieldValue.arrayUnion([newUserId]),
//       // Також ініціалізуємо лічильник для нього
//       'unreadCount.$newUserId': 0,
//     });
//   }

//   // Видалити учасника з чату
//   Future<void> removeParticipant(String chatId, String userIdToRemove) async {
//     await _firestore.collection('chats').doc(chatId).update({
//       'participantIds': FieldValue.arrayRemove([userIdToRemove]),
//       // Видаляємо лічильник (через FieldValue.delete() для конкретного ключа мапи)
//       'unreadCount.$userIdToRemove': FieldValue.delete(),
//     });
//   }

//   // Редагування повідомлення
//   Future<void> editMessage(String chatId, String messageId, String newText) async {
//     final docRef = _firestore
//         .collection('chats')
//         .doc(chatId)
//         .collection('messages')
//         .doc(messageId);

//     await docRef.update({
//       'text': newText,
//       'isEdited': true, // Прапорець, щоб показати "(edited)"
//     });
    
//     // (Опціонально) Тут треба б оновити lastMessage в чаті, якщо це було останнє повідомлення,
//     // але для простоти поки пропустимо.
//   }

//   // Видалення повідомлення
//   Future<void> deleteMessage(String chatId, String messageId) async {
//     await _firestore
//         .collection('chats')
//         .doc(chatId)
//         .collection('messages')
//         .doc(messageId)
//         .delete();
//   }

//   // Пошук юзера за логіном (дублюємо логіку з контактів для зручності)
//   Future<String?> findUserIdByLogin(String login) async {
//     final formattedLogin = login.startsWith('@') ? login : '@$login';
//     final snapshot = await _firestore
//         .collection('users')
//         .where('login', isEqualTo: formattedLogin)
//         .limit(1)
//         .get();
    
//     if (snapshot.docs.isNotEmpty) {
//       return snapshot.docs.first.id;
//     }
//     return null;
//   }

//   Future<void> sendFileMessage({
//     required String chatId, 
//     required XFile file, 
//     required String messageType // 'image'
//   }) async {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) return;

//     try {
//       // 1. Завантаження в Storage
//       final timestamp = DateTime.now().millisecondsSinceEpoch;
//       final fileName = '${timestamp}_${file.name}';
//       final ref = _storage.ref().child('chats/$chatId/$fileName');

//       final Uint8List fileBytes = await file.readAsBytes();
//       //final metadata = SettableMetadata(contentType: 'image/jpeg');
//       // String mimeType = 'image/jpeg'; // Дефолт
//       // if (messageType == 'video') {
//       //   mimeType = 'video/mp4'; 
//       // }

//       String mimeType = 'application/octet-stream'; // Дефолт
//       if (messageType == 'image') mimeType = 'image/jpeg';
//       else if (messageType == 'video') mimeType = 'video/mp4';
//       else if (messageType == 'file') mimeType = 'application/pdf';

//       // Встановлюємо метадані
//       final metadata = SettableMetadata(contentType: mimeType); // <--- ВИПРАВЛЕНО

//       final uploadTask = ref.putData(fileBytes, metadata);

//       final snapshot = await uploadTask;
//       final downloadUrl = await snapshot.ref.getDownloadURL();

//       final now = FieldValue.serverTimestamp();

//       String messageText = '📁 File';
//         if (messageType == 'image') messageText = '📷 Photo';
//         else if (messageType == 'video') messageText = '🎥 Video';
//         else if (messageType == 'file') messageText = file.name;

//       final messageData = {
//           'senderId': myUid,
//           'text': messageText, 
//           'type': messageType,
//           'fileUrl': downloadUrl,
//           'timestamp': now,
//           'isRead': false,
//         };
//       // 2. Створення об'єкта повідомлення (Map)
//       // final messageData = {
//       //       'senderId': myUid,
//       //       // ТУТ ЗМІНИТИ: Додаємо перевірку на відео для гарного тексту
//       //       'text': messageType == 'image' 
//       //           ? '📷 Photo' 
//       //           : (messageType == 'video' ? '🎥 Video' : '📁 File'), 
//       //       'type': messageType,
//       //       'fileUrl': downloadUrl,
//       //       'timestamp': now,
//       //       'isRead': false,
//       //     };

//       // 3. Запис у колекцію повідомлень
//       await _firestore
//           .collection('chats')
//           .doc(chatId)
//           .collection('messages')
//           .add(messageData);

//       // 4. Оновлення останнього повідомлення чату (ЗАПИСУЄМО MAP, А НЕ STRING)
//       await _firestore.collection('chats').doc(chatId).update({
//         'lastMessage': messageData, // <--- ОСЬ ТУТ БУЛА ПОМИЛКА
//         'lastActivityTime': now,
//       });

//     } catch (e) {
//       print("Error sending file: $e");
//       throw e;
//     }
//   }
// }