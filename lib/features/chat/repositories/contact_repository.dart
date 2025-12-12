import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/contact_model.dart';

class ContactRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ===========================================================================
  // 1. ОТРИМАННЯ КОНТАКТІВ (З оновленням статусу)
  // ===========================================================================

  Stream<List<Contact>> getContactsStream(String myUid) {
    return _firestore
        .collection('users')
        .doc(myUid)
        .collection('contacts')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      
      List<Contact> contacts = [];
      
      for (var doc in snapshot.docs) {
        var contactData = doc.data();
        String friendUid = contactData['uid'];

        // Підтягуємо свіжі дані (статус, фото) з головної колекції users.
        // Це дозволяє бачити актуальний статус Online/Offline у списку контактів.
        try {
          var userDoc = await _firestore.collection('users').doc(friendUid).get();
          if (userDoc.exists) {
            var userData = userDoc.data()!;
            
            // Оновлюємо поля контакту актуальними даними юзера
            contactData['photoUrl'] = userData['photoUrl']; 
            contactData['username'] = userData['username'];
            contactData['isOnline'] = userData['isOnline']; // Важливо для статусу
            contactData['lastSeen'] = userData['lastSeen']; // Важливо для статусу
          }
        } catch (e) {
          print("Error fetching fresh data for $friendUid: $e");
        }

        contacts.add(Contact.fromMap(contactData, doc.id));
      }
      
      return contacts;
    });
  }

  // ===========================================================================
  // 2. ПОШУК ЮЗЕРА (Для додавання)
  // ===========================================================================

  Future<Contact?> searchUserByLogin(String loginQuery) async {
    // Додаємо @, якщо користувач забув, бо в базі зберігаємо як @login
    final formattedLogin = loginQuery.startsWith('@') ? loginQuery : '@$loginQuery';

    final snapshot = await _firestore
        .collection('users')
        .where('login', isEqualTo: formattedLogin)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return Contact.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  // ===========================================================================
  // 3. УПРАВЛІННЯ (Додати / Видалити)
  // ===========================================================================

  Future<void> addContact(String myUid, Contact newContact) async {
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('contacts')
        .doc(newContact.id) // ID документа = UID друга
        .set({
          'uid': newContact.id,
          'username': newContact.username,
          'login': newContact.login,
          'photoUrl': newContact.photoUrl,
          'addedAt': FieldValue.serverTimestamp(),
          // При додаванні інші поля (isOnline) підтягнуться автоматично через getContactsStream
        });
  }

  Future<void> deleteContact(String contactId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('contacts')
        .doc(contactId)
        .delete();
  }
}
























// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../models/contact_model.dart'; // Перевір шлях

// class ContactRepository {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   // Отримати список контактів (Stream)
//   // Stream<List<Contact>> getContactsStream() {
//   //   final myUid = _auth.currentUser?.uid;
//   //   if (myUid == null) return Stream.value([]); // Якщо не залогінені - пустий список

//   //   return _firestore
//   //       .collection('users')
//   //       .doc(myUid)
//   //       .collection('contacts')
//   //       .orderBy('addedAt', descending: true) // Сортуємо: нові зверху
//   //       .snapshots()
//   //       .map((snapshot) {
//   //     return snapshot.docs.map((doc) => Contact.fromFirestore(doc)).toList();
//   //   });
//   // }

//   // lib/features/chat/repositories/contact_repository.dart

//   Stream<List<Contact>> getContactsStream(String myUid) {
//     return _firestore
//         .collection('users')
//         .doc(myUid)
//         .collection('contacts')
//         .orderBy('addedAt', descending: true)
//         .snapshots()
//         .asyncMap((snapshot) async {
      
//       List<Contact> contacts = [];
      
//       for (var doc in snapshot.docs) {
//         var contactData = doc.data();
//         String friendUid = contactData['uid']; // ID друга

//         // 🔥 КЛЮЧОВИЙ МОМЕНТ:
//         // Ми робимо запит до головної колекції 'users', щоб взяти СВІЖЕ фото
//         try {
//           var userDoc = await _firestore.collection('users').doc(friendUid).get();
//           if (userDoc.exists) {
//             var userData = userDoc.data()!;
//             // Переписуємо старі дані свіжими
//             contactData['photoUrl'] = userData['photoUrl']; 
//             contactData['username'] = userData['username'];
//             contactData['isOnline'] = userData['isOnline'];
//             contactData['lastSeen'] = userData['lastSeen'];
//           }
//         } catch (e) {
//           print("Error fetching fresh data for $friendUid: $e");
//         }

//         // Створюємо контакт з оновленими даними
//         contacts.add(Contact.fromMap(contactData, doc.id));
//       }
      
//       return contacts;
//     });
//   }


//   // Видалити контакт
//   Future<void> deleteContact(String contactId) async {
//     final myUid = _auth.currentUser?.uid;
//     if (myUid == null) return;

//     await _firestore
//         .collection('users')
//         .doc(myUid)
//         .collection('contacts')
//         .doc(contactId)
//         .delete();
//   }
  
//   // Метод для додавання контакту (знадобиться пізніше)
//   // Future<void> addContact(String friendUid, Map<String, dynamic> friendData) async {
//   //   final myUid = _auth.currentUser?.uid;
//   //   if (myUid == null) return;
    
//   //   await _firestore
//   //       .collection('users')
//   //       .doc(myUid)
//   //       .collection('contacts')
//   //       .doc(friendUid) // ID документа = ID друга
//   //       .set(friendData);
//   // }

//   Future<Contact?> searchUserByLogin(String loginQuery) async {
//     // Додаємо @, якщо користувач забув його ввести, бо в базі ми зберігаємо з @
//     final formattedLogin = loginQuery.startsWith('@') ? loginQuery : '@$loginQuery';

//     final snapshot = await _firestore
//         .collection('users')
//         .where('login', isEqualTo: formattedLogin)
//         .limit(1) // Нам треба тільки один (унікальний)
//         .get();

//     if (snapshot.docs.isNotEmpty) {
//       // Конвертуємо документ User в модель Contact
//       return Contact.fromFirestore(snapshot.docs.first);
//     }
//     return null; // Не знайдено
//   }

//   // Метод додавання (переконайся, що він у тебе є)
//   Future<void> addContact(String myUid, Contact newContact) async {
//     await _firestore
//         .collection('users')
//         .doc(myUid)
//         .collection('contacts')
//         .doc(newContact.id) // ID друга
//         .set({
//           'uid': newContact.id,
//           'username': newContact.username,
//           'login': newContact.login,
//           'photoUrl': newContact.photoUrl,
//           'addedAt': FieldValue.serverTimestamp(),
//         });
//   }
// }