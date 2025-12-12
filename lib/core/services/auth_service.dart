// lib/core/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Клас для результату операцій авторизації
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final User? user;

  AuthResult.success(this.user)
      : isSuccess = true,
        errorMessage = null;

  AuthResult.error(this.errorMessage)
      : isSuccess = false,
        user = null;
}

/// Сервіс для роботи з Firebase Authentication
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ==================== GETTERS ====================

  /// Отримати поточного користувача
  User? get currentUser => _auth.currentUser;

  /// Stream для відстеження стану авторизації
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Чи користувач авторизований
  bool get isAuthenticated => currentUser != null;

  // ==================== EMAIL/PASSWORD МЕТОДИ ====================

  /// Реєстрація через email та пароль
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String login,
  }) async {
    try {
      // Базова валідація (детальна валідація у UI)
      if (email.isEmpty || password.isEmpty || name.isEmpty) {
        return AuthResult.error('Всі поля обов\'язкові для заповнення');
      }

      // Реєстрація
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Оновлюємо профіль користувача
      await _updateUserProfile(userCredential.user, name);

      await _createUserInFirestore(
        user: userCredential.user, 
        name: name, 
        login: login
      );

      return AuthResult.success(userCredential.user);
    } on FirebaseAuthException catch (e, stackTrace) {
      return _handleFirebaseAuthError(e, stackTrace, 'signup');
    } catch (e, stackTrace) {
      return _handleGenericError(e, stackTrace);
    }
  }

  /// Вхід через email та пароль
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Базова валідація
      if (email.isEmpty || password.isEmpty) {
        return AuthResult.error('Email та пароль обов\'язкові');
      }

      // Вхід
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return AuthResult.success(userCredential.user);
    } on FirebaseAuthException catch (e, stackTrace) {
      return _handleFirebaseAuthError(e, stackTrace, 'signin');
    } catch (e, stackTrace) {
      return _handleGenericError(e, stackTrace);
    }
  }

  // ==================== GOOGLE SIGN-IN ====================

  /// Вхід через Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Відкриваємо діалог вибору Google акаунту
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return AuthResult.error('Вхід через Google скасовано');
      }

      // Отримуємо credentials
      final googleAuth = await googleUser.authentication;

      // Створюємо Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Входимо в Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      // 5. Для Google теж треба перевірити/створити запис у БД
      if (user != null) {
        // Генеруємо логін з пошти, якщо це новий юзер (напр. @john.doe)
        final generatedLogin = "@${user.email?.split('@')[0] ?? 'user'}";
        await _createUserInFirestore(
          user: user, 
          name: user.displayName ?? 'Google User', 
          login: generatedLogin // Тимчасовий логін
        );
      }

      return AuthResult.success(userCredential.user);
    } on FirebaseAuthException catch (e, stackTrace) {
      return _handleFirebaseAuthError(e, stackTrace, 'google_signin');
    } catch (e, stackTrace) {
      return _handleGenericError(e, stackTrace);
    }
  }

  

  /// Вихід з акаунту
  Future<void> signOut() async {
    try {
      await Future.wait([
        _googleSignIn.signOut(),
        _auth.signOut(),
      ]);
    } catch (e, stackTrace) {
      await Sentry.captureException(
        e,
        stackTrace: stackTrace,
        hint: Hint.withMap({'error_type': 'signout_error'}),
      );
    }
  }

  /// Видалення акаунту
  Future<AuthResult> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.error('Користувач не авторизований');
      }

      await user.delete();
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e, stackTrace) {
      return _handleFirebaseAuthError(e, stackTrace, 'delete_account');
    } catch (e, stackTrace) {
      return _handleGenericError(e, stackTrace);
    }
  }

  Future<void> _createUserInFirestore({
    required User? user, 
    required String name, 
    required String login
  }) async {
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userRef.get();

    // Якщо користувача немає в базі - створюємо
    if (!docSnapshot.exists) {
      // Форматуємо логін
      final finalLogin = login.startsWith('@') ? login : '@$login';

      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'username': name,
        'login': finalLogin,
        'photoUrl': user.photoURL ?? '', 
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _updateUserStatus(user.uid, true);
    }
  }

  /// Оновлює статус isOnline
  Future<void> _updateUserStatus(String? uid, bool isOnline) async {
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ігноруємо помилки оновлення статусу, щоб не блокувати вхід/вихід
      print("Status update error: $e");
    }
  }



  /// Оновлення профілю користувача після реєстрації
  Future<void> _updateUserProfile(User? user, String name) async {
    if (user == null) return;

    try {
      await user.updateDisplayName(name.trim());
      await user.reload();
    } catch (e, stackTrace) {
      await Sentry.captureException(
        e,
        stackTrace: stackTrace,
        hint: Hint.withMap({'error_type': 'update_profile_error'}),
      );
    }
  }

  /// Обробка помилок Firebase Authentication
  AuthResult _handleFirebaseAuthError(
    FirebaseAuthException e,
    StackTrace stackTrace,
    String errorType,
  ) {
    // Логування в Sentry
    Sentry.captureException(
      e,
      stackTrace: stackTrace,
      hint: Hint.withMap({
        'error_type': errorType,
        'error_code': e.code,
      }),
    );

    return AuthResult.error(_getFirebaseErrorMessage(e.code));
  }

  /// Обробка загальних помилок
  AuthResult _handleGenericError(dynamic e, StackTrace stackTrace) {
    Sentry.captureException(e, stackTrace: stackTrace);
    return AuthResult.error('Невідома помилка: ${e.toString()}');
  }

  /// Перетворення кодів помилок Firebase на зрозумілі повідомлення
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      // Помилки реєстрації
      case 'email-already-in-use':
        return 'Цей email вже використовується';
      case 'invalid-email':
        return 'Некоректний формат email';
      case 'operation-not-allowed':
        return 'Операція заборонена';
      case 'weak-password':
        return 'Пароль занадто слабкий (мінімум 6 символів)';

      // Помилки входу
      case 'user-disabled':
        return 'Цей акаунт заблоковано';
      case 'user-not-found':
        return 'Користувача не знайдено';
      case 'wrong-password':
        return 'Неправильний пароль';
      case 'invalid-credential':
        return 'Невірний email або пароль';

      // Помилки безпеки
      case 'too-many-requests':
        return 'Занадто багато спроб. Спробуйте пізніше';
      case 'requires-recent-login':
        return 'Потрібна повторна авторизація';

      // Мережеві помилки
      case 'network-request-failed':
        return 'Проблеми з інтернет-з\'єднанням';

      // Інші помилки
      case 'expired-action-code':
        return 'Код дії застарів';
      case 'invalid-action-code':
        return 'Невірний код дії';

      default:
        return 'Помилка авторизації: $code';
    }
  }
}










// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:sentry_flutter/sentry_flutter.dart';

// class AuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final GoogleSignIn _googleSignIn = GoogleSignIn();

//   // Отримати поточного користувача
//   User? get currentUser => _auth.currentUser;

//   // Stream для відстеження стану авторизації
//   Stream<User?> get authStateChanges => _auth.authStateChanges();

//   // ============ EMAIL/PASSWORD РЕЄСТРАЦІЯ ============
//   Future<AuthResult> signUpWithEmail({
//     required String email,
//     required String password,
//     required String name,
//   }) async {
//     try {
//       // Валідація
//       if (email.isEmpty || password.isEmpty || name.isEmpty) {
//         return AuthResult.error('Всі поля обов\'язкові для заповнення');
//       }

//       if (!_isValidEmail(email)) {
//         return AuthResult.error('Некоректний формат email');
//       }

//       if (password.length < 6) {
//         return AuthResult.error('Пароль має бути не менше 6 символів');
//       }

//       // Реєстрація
//       UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
//         email: email,
//         password: password,
//       );

//       // Оновлюємо ім'я користувача
//       await userCredential.user?.updateDisplayName(name);
//       await userCredential.user?.reload();

//       return AuthResult.success(userCredential.user);
      
//     } on FirebaseAuthException catch (e, stackTrace) {
//       // Відправляємо помилку в Sentry
//       await Sentry.captureException(
//         e,
//         stackTrace: stackTrace,
//         hint: Hint.withMap({
//           'error_type': 'signup_error',
//           'error_code': e.code,
//           'email': email,
//         }),
//       );

//       // Повертаємо зрозуміле повідомлення
//       return AuthResult.error(_getFirebaseErrorMessage(e.code));
      
//     } catch (e, stackTrace) {
//       await Sentry.captureException(e, stackTrace: stackTrace);
//       return AuthResult.error('Невідома помилка: ${e.toString()}');
//     }
//   }

//   // ============ EMAIL/PASSWORD ВХІД ============
//   Future<AuthResult> signInWithEmail({
//     required String email,
//     required String password,
//   }) async {
//     try {
//       // Валідація
//       if (email.isEmpty || password.isEmpty) {
//         return AuthResult.error('Email та пароль обов\'язкові');
//       }

//       // Вхід
//       UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );

//       return AuthResult.success(userCredential.user);
      
//     } on FirebaseAuthException catch (e, stackTrace) {
//       // Відправляємо помилку в Sentry
//       await Sentry.captureException(
//         e,
//         stackTrace: stackTrace,
//         hint: Hint.withMap({
//           'error_type': 'login_error',
//           'error_code': e.code,
//           'email': email,
//         }),
//       );

//       return AuthResult.error(_getFirebaseErrorMessage(e.code));
      
//     } catch (e, stackTrace) {
//       await Sentry.captureException(e, stackTrace: stackTrace);
//       return AuthResult.error('Невідома помилка: ${e.toString()}');
//     }
//   }

//   // ============ GOOGLE SIGN-IN ============
//   Future<AuthResult> signInWithGoogle() async {
//     try {
//       // Відкриваємо діалог вибору Google акаунту
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

//       if (googleUser == null) {
//         // Користувач скасував вхід
//         return AuthResult.error('Вхід через Google скасовано');
//       }

//       // Отримуємо credentials
//       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

//       // Створюємо Firebase credential
//       final credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );

//       // Входимо в Firebase
//       UserCredential userCredential = await _auth.signInWithCredential(credential);

//       return AuthResult.success(userCredential.user);
      
//     } on FirebaseAuthException catch (e, stackTrace) {
//       await Sentry.captureException(
//         e,
//         stackTrace: stackTrace,
//         hint: Hint.withMap({
//           'error_type': 'google_signin_error',
//           'error_code': e.code,
//         }),
//       );

//       return AuthResult.error(_getFirebaseErrorMessage(e.code));
      
//     } catch (e, stackTrace) {
//       await Sentry.captureException(e, stackTrace: stackTrace);
//       return AuthResult.error('Помилка входу через Google: ${e.toString()}');
//     }
//   }

//   // ============ ВИХІД ============
//   Future<void> signOut() async {
//     try {
//       await _googleSignIn.signOut();
//       await _auth.signOut();
//     } catch (e, stackTrace) {
//       await Sentry.captureException(e, stackTrace: stackTrace);
//     }
//   }

//   // ============ ДОПОМІЖНІ ФУНКЦІЇ ============

//   // Валідація email
//   bool _isValidEmail(String email) {
//     return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
//   }

//   // Перетворення кодів помилок Firebase на зрозумілі повідомлення
//   String _getFirebaseErrorMessage(String code) {
//     switch (code) {
//       case 'email-already-in-use':
//         return 'Цей email вже використовується';
//       case 'invalid-email':
//         return 'Некоректний формат email';
//       case 'operation-not-allowed':
//         return 'Операція заборонена';
//       case 'weak-password':
//         return 'Пароль занадто слабкий';
//       case 'user-disabled':
//         return 'Цей акаунт заблоковано';
//       case 'user-not-found':
//         return 'Користувача не знайдено';
//       case 'wrong-password':
//         return 'Неправильний пароль';
//       case 'invalid-credential':
//         return 'Невірний email або пароль';
//       case 'too-many-requests':
//         return 'Занадто багато спроб. Спробуйте пізніше';
//       case 'network-request-failed':
//         return 'Проблеми з інтернет-з\'єднанням';
//       default:
//         return 'Помилка авторизації: $code';
//     }
//   }
// }

// // ============ КЛАС ДЛЯ РЕЗУЛЬТАТУ АВТОРИЗАЦІЇ ============
// class AuthResult {
//   final bool isSuccess;
//   final String? errorMessage;
//   final User? user;

//   AuthResult.success(this.user)
//       : isSuccess = true,
//         errorMessage = null;

//   AuthResult.error(this.errorMessage)
//       : isSuccess = false,
//         user = null;
// }