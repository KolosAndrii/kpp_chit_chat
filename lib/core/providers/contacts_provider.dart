import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/chat/repositories/contact_repository.dart';
import '../../features/chat/models/contact_model.dart';

class ContactsProvider extends ChangeNotifier {
  final ContactRepository _repository = ContactRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- СТАН ---
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  StreamSubscription? _contactsSubscription;
  bool _isLoading = false;

  // Пошук
  Contact? _foundUser; // Користувач, якого ми знайшли глобально
  bool _isSearching = false;
  String? _searchError;

  // --- ГЕТТЕРИ ---
  bool get isLoading => _isLoading;
  Contact? get foundUser => _foundUser;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;

  // Список онлайн
  List<Contact> get onlineContacts => 
      _filteredContacts.where((c) => c.isOnline).toList();
  
  // Список офлайн (спочатку ті, хто був недавно)
  List<Contact> get offlineContacts {
    final list = _filteredContacts.where((c) => !c.isOnline).toList();
    list.sort((a, b) {
      if (b.lastSeen == null) return -1;
      if (a.lastSeen == null) return 1;
      return b.lastSeen!.compareTo(a.lastSeen!);
    });
    return list;
  }

  // ===========================================================================
  // 1. ІНІЦІАЛІЗАЦІЯ (Завантаження контактів)
  // ===========================================================================

  void init() {
    final user = _auth.currentUser;
    if (user == null) return; 

    _isLoading = true;
    notifyListeners();

    _contactsSubscription?.cancel();
    _contactsSubscription = _repository.getContactsStream(user.uid).listen(
      (contactsData) {
        _contacts = contactsData;
        _filteredContacts = _contacts; // Оновлюємо список
        
        _isLoading = false;
        notifyListeners();
      }, 
      onError: (e) {
        debugPrint("Error loading contacts: $e");
        _isLoading = false;
        notifyListeners();
      }
    );
  }

  // ===========================================================================
  // 2. ПОШУК (Локальний та Глобальний)
  // ===========================================================================

  // Локальний фільтр (серед друзів)
  void searchContacts(String query) {
    if (query.isEmpty) {
      _filteredContacts = _contacts;
    } else {
      _filteredContacts = _contacts
          .where((c) => 
            c.username.toLowerCase().contains(query.toLowerCase()) || 
            c.login.toLowerCase().contains(query.toLowerCase())
          ).toList();
    }
    notifyListeners();
  }

  // Глобальний пошук нових юзерів за логіном
  Future<void> findUserGlobal(String login) async {
    if (login.isEmpty) return;

    _isSearching = true;
    _searchError = null;
    _foundUser = null; 
    notifyListeners();

    try {
      final user = await _repository.searchUserByLogin(login);
      
      if (user != null) {
        // Забороняємо додавати себе
        if (user.id == _auth.currentUser?.uid) {
           _searchError = "You cannot add yourself.";
        } else {
           _foundUser = user;
        }
      } else {
        _searchError = "User not found.";
      }
    } catch (e) {
      _searchError = "Error: $e";
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _foundUser = null;
    _searchError = null;
    notifyListeners();
  }

  // ===========================================================================
  // 3. УПРАВЛІННЯ КОНТАКТАМИ (Додати/Видалити)
  // ===========================================================================

  Future<void> addFoundUserToContacts() async {
    if (_foundUser == null) return;
    
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    try {
      await _repository.addContact(myUid, _foundUser!);
      
      _foundUser = null;
      _searchError = "User added successfully!";
      notifyListeners();
      
      // Автоматичне приховання повідомлення про успіх
      Future.delayed(const Duration(seconds: 3), () {
        if (_searchError == "User added successfully!") {
          _searchError = null;
          notifyListeners();
        }
      });
      
    } catch (e) {
      debugPrint("Error adding contact: $e");
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await _repository.deleteContact(contactId);
    } catch (e) {
      debugPrint("Error deleting contact: $e");
    }
  }

  @override
  void dispose() {
    _contactsSubscription?.cancel();
    super.dispose();
  }
}

































//// САРА ВЕРСІЯ ДО РЕФАКТОРИНГУ 
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:chat_lab_kpp/features/chat/repositories/contact_repository.dart';
// import 'package:chat_lab_kpp/features/chat/models/contact_model.dart';
// import 'package:firebase_auth/firebase_auth.dart';


// class ContactsProvider extends ChangeNotifier {
//   final ContactRepository _repository = ContactRepository();
  
//   List<Contact> _contacts = [];
//   List<Contact> _filteredContacts = [];
//   StreamSubscription? _contactsSubscription;
//   bool _isLoading = false;

//   Contact? _foundUser; // Користувач, якого ми знайшли глобально
//   bool _isSearching = false;
//   String? _searchError;

//   bool get isLoading => _isLoading;

//   Contact? get foundUser => _foundUser;
//   bool get isSearching => _isSearching;
//   String? get searchError => _searchError;

//   // Геттери для UI (Online / Offline)
//   // Ми фільтруємо _filteredContacts, щоб пошук працював і для цих списків
//   List<Contact> get onlineContacts => _filteredContacts.where((c) => c.isOnline).toList();
  
//   // Offline сортуємо ще й за часом (хто був нещодавно - той вище)
//   List<Contact> get offlineContacts {
//     final list = _filteredContacts.where((c) => !c.isOnline).toList();
//     // Сортування: якщо lastSeen null, кидаємо в кінець
//     list.sort((a, b) {
//       if (b.lastSeen == null) return -1;
//       if (a.lastSeen == null) return 1;
//       return b.lastSeen!.compareTo(a.lastSeen!);
//     });
//     return list;
//   }

//   // --- ІНІЦІАЛІЗАЦІЯ (Викликати в initState) ---
//   void init() {
//     // 1. Отримуємо ID поточного користувача
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return; 

//     _isLoading = true;
//     notifyListeners();

//     _contactsSubscription?.cancel();

//     // 2. ВИПРАВЛЕНО: Передаємо user.uid у репозиторій
//     _contactsSubscription = _repository.getContactsStream(user.uid).listen((contactsData) {
//       _contacts = contactsData;
      
//       // Якщо був пошук, треба б його зберегти, але для простоти скидаємо:
//       _filteredContacts = _contacts; 
      
//       _isLoading = false;
//       notifyListeners();
//     }, onError: (e) {
//       print("Error loading contacts: $e");
//       _isLoading = false;
//       notifyListeners();
//     });
//   }

//   // void init() {
//   //   _isLoading = true;
//   //   notifyListeners();

//   //   _contactsSubscription = _repository.getContactsStream().listen((contactsData) {
//   //     _contacts = contactsData;
//   //     _filteredContacts = _contacts; // Спочатку показуємо всіх
      
//   //     _isLoading = false;
//   //     notifyListeners();
//   //   }, onError: (e) {
//   //     print("Error loading contacts: $e");
//   //     _isLoading = false;
//   //     notifyListeners();
//   //   });
//   // }

//   // Пошук контактів (локально фільтруємо список, що прийшов з БД)
//   void searchContacts(String query) {
//     if (query.isEmpty) {
//       _filteredContacts = _contacts;
//     } else {
//       _filteredContacts = _contacts
//           .where((c) => c.username.toLowerCase().contains(query.toLowerCase()) || 
//                         c.login.toLowerCase().contains(query.toLowerCase()))
//           .toList();
//     }
//     notifyListeners();
//   }

//   // Видалення
//   Future<void> deleteContact(String contactId) async {
//     try {
//       await _repository.deleteContact(contactId);
//       // UI оновиться автоматично через Stream!
//     } catch (e) {
//       print("Error deleting contact: $e");
//     }
//   }

//   // 1. Глобальний пошук користувача
//   Future<void> findUserGlobal(String login) async {
//     if (login.isEmpty) return;

//     _isSearching = true;
//     _searchError = null;
//     _foundUser = null; // Очищаємо попередній результат
//     notifyListeners();

//     try {
//       final user = await _repository.searchUserByLogin(login);
      
//       if (user != null) {
//         // Перевірка: чи не шукаємо ми самі себе?
//         final myUid = FirebaseAuth.instance.currentUser?.uid;
//         if (user.id == myUid) {
//            _searchError = "You cannot add yourself.";
//         } else {
//            _foundUser = user;
//         }
//       } else {
//         _searchError = "User not found.";
//       }
//     } catch (e) {
//       _searchError = "Error: $e";
//     } finally {
//       _isSearching = false;
//       notifyListeners();
//     }
//   }

//   // 2. Додавання знайденого користувача в контакти
//   Future<void> addFoundUserToContacts() async {
//     if (_foundUser == null) return;
    
//     final myUid = FirebaseAuth.instance.currentUser?.uid;
//     if (myUid == null) return;

//     try {
//       await _repository.addContact(myUid, _foundUser!);
      
//       // Після успішного додавання очищаємо пошук
//       _foundUser = null;
//       _searchError = "User added successfully!";
//       notifyListeners();
      
//       // Прибираємо повідомлення про успіх через секунду (для UX)
//       Future.delayed(const Duration(seconds: 3), () {
//         _searchError = null;
//         notifyListeners();
//       });
      
//     } catch (e) {
//       print("Error adding contact: $e");
//     }
//   }
  
//   // Метод очищення пошуку (коли виходимо з екрану або стираємо текст)
//   void clearSearch() {
//     _foundUser = null;
//     _searchError = null;
//     notifyListeners();
//   }

//   @override
//   void dispose() {
//     _contactsSubscription?.cancel();
//     super.dispose();
//   }
// }






















// // import 'package:flutter/material.dart';
// // import 'package:chat_lab_kpp/features/chat/models/contact_model.dart';

// // class ContactsProvider extends ChangeNotifier {
// //   List<Contact> _contacts = [];
// //   List<Contact> _filteredContacts = [];
// //   bool _isLoading = false;

// //   bool get isLoading => _isLoading;

// //   // Геттери для розділених списків (використовуємо відфільтровані дані)
// //   List<Contact> get onlineContacts => _filteredContacts.where((c) => c.isOnline).toList();
// //   List<Contact> get offlineContacts => _filteredContacts.where((c) => !c.isOnline).toList();

// //   Future<void> loadContacts() async {
// //     _isLoading = true;
// //     notifyListeners();

// //     await Future.delayed(const Duration(milliseconds: 800)); // Імітація запиту

// //     // Хардкод даних згідно з твоїм дизайном
// //     _contacts = [
// //       Contact(id: 1, name: 'Ryan Gosling', avatarUrl: '', isOnline: true, statusText: 'Online'),
// //       Contact(id: 2, name: 'Mads Mikkelsen', avatarUrl: '', isOnline: true, statusText: 'Online'),
// //       Contact(id: 3, name: 'Maria Lytvyn', avatarUrl: '', isOnline: true, statusText: 'Online'),
// //       Contact(id: 8, name: 'Agoichi', avatarUrl: '', isOnline: true, statusText: 'Online'),
// //       Contact(id: 7, name: 'MyTwink', avatarUrl: '', isOnline: true, statusText: 'Online'),
// //       Contact(id: 4, name: 'Heisenberg', avatarUrl: '', isOnline: false, statusText: '10 min ago'),
// //       Contact(id: 5, name: 'Friend #1', avatarUrl: '', isOnline: false, statusText: '1 hour ago'),
// //       Contact(id: 6, name: 'Friend #2', avatarUrl: '', isOnline: false, statusText: '1 year ago'),
// //     ];

// //     _filteredContacts = _contacts;
// //     _isLoading = false;
// //     notifyListeners();
// //   }

// //   void searchContacts(String query) {
// //     if (query.isEmpty) {
// //       _filteredContacts = _contacts;
// //     } else {
// //       _filteredContacts = _contacts
// //           .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
// //           .toList();
// //     }
// //     notifyListeners();
// //   }

// //   // Метод для видалення (імітація)
// //   void deleteContact(int id) {
// //     _contacts.removeWhere((c) => c.id == id);
// //     // Оновлюємо і відфільтрований список
// //     searchContacts(""); // Або зберегти поточний запит
// //     notifyListeners();
// //   }
// // }