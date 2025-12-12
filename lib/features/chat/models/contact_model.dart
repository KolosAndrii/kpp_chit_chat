import 'package:cloud_firestore/cloud_firestore.dart';

class Contact {
  final String id; // Це uid друга
  final String username;
  final String email;
  final String login;
  final String? photoUrl;
  final DateTime? addedAt;

  // Це поля, які ми будемо підтягувати з глобальної колекції users (статус)
  bool isOnline;
  DateTime? lastSeen;

  Contact({
    required this.id,
    required this.username,
    required this.login,
    required this.email,
    this.photoUrl,
    this.addedAt,
    this.isOnline = false, // Дефолтне значення
    this.lastSeen,

  });

  factory Contact.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Contact(
      id: data['uid'] ?? doc.id, // uid зберігається в полі
      username: data['username'] ?? 'Unknown',
      login: data['login'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory Contact.fromMap(Map<String, dynamic> data, String documentId) {
    return Contact(
      id: documentId,
      username: data['username'] ?? '',
      login: data['login'] ?? '',
      photoUrl: data['photoUrl'],
      email: data['email'] ?? '',
      // Обробка Timestamp для Firestore
      isOnline: data['isOnline'] ?? false,
      lastSeen: data['lastSeen'] != null 
          ? (data['lastSeen'] as Timestamp).toDate() 
          : null,
      addedAt: data['addedAt'] != null 
          ? (data['addedAt'] as Timestamp).toDate() 
          : null,
    );
  }
  
}













// class Contact {
//   final int id;
//   final String name;
//   final String avatarUrl; // Або шлях до асету
//   final bool isOnline;
//   final String statusText; // "Online" або "10 min ago"

//   final String login;
//   final String email;
//   final String registrationDate;
//   final String about;

//   Contact({
//     required this.id,
//     required this.name,
//     required this.avatarUrl,
//     required this.isOnline,
//     required this.statusText,
//     this.login = 'UserLogin123',
//     this.email = 'user***@gmail.com',
//     this.registrationDate = '01.10.2025',
//     this.about = 'I am a student in NULP, and this is my KPP lab 2. Here you can add some extra info.',
//   });
// }