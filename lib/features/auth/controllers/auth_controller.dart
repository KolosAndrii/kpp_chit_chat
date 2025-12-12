// lib/features/auth/controllers/auth_controller.dart

import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/analytics_service.dart';

import 'package:image_picker/image_picker.dart'; // Додай це
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../chat/repositories/storage_repository.dart';

/// Контролер для управління станом та логікою авторизації
class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // Стан
  bool _isLogin = true;
  bool _isLoading = false;

  // Поля помилок (серверні помилки, які маємо показати під конкретним полем)
  String? _emailError;
  String? _passwordError;
  String? _loginError;
  String? _nameError;
  String? _confirmPasswordError;

  // Getters
  bool get isLogin => _isLogin;
  bool get isLoading => _isLoading;
  String? get emailError => _emailError;
  String? get passwordError => _passwordError;
  String? get loginError => _loginError;
  String? get nameError => _nameError;
  String? get confirmPasswordError => _confirmPasswordError;

  // Контролери полів
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final loginController = TextEditingController();

  final StorageRepository _storageRepository = StorageRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Видимість паролів
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool get obscurePassword => _obscurePassword;
  bool get obscureConfirmPassword => _obscureConfirmPassword;

  AuthController() {
    // Коли користувач змінює текст у полі, прибираємо відповідну серверну помилку.
    emailController.addListener(() {
      if (_emailError != null) {
        _emailError = null;
        notifyListeners();
      }
    });
    loginController.addListener(() {
      if (_loginError != null) {
        _loginError = null;
        notifyListeners();
      }
    });
    passwordController.addListener(() {
      if (_passwordError != null) {
        _passwordError = null;
        notifyListeners();
      }
    });
    nameController.addListener(() {
      if (_nameError != null) {
        _nameError = null;
        notifyListeners();
      }
    });
    confirmPasswordController.addListener(() {
      if (_confirmPasswordError != null) {
        _confirmPasswordError = null;
        notifyListeners();
      }
    });
  }

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _obscureConfirmPassword = !_obscureConfirmPassword;
    notifyListeners();
  }

  // Очистити всі серверні помилки полів
  void clearFieldErrors() {
    var changed = false;
    if (_emailError != null) {
      _emailError = null;
      changed = true;
    }
    if (_passwordError != null) {
      _passwordError = null;
      changed = true;
    }
    if (_loginError != null) {
      _loginError = null;
      changed = true;
    }
    if (_nameError != null) {
      _nameError = null;
      changed = true;
    }
    if (_confirmPasswordError != null) {
      _confirmPasswordError = null;
      changed = true;
    }
    if (changed) notifyListeners();
  }


  /// Реєстрація через email
  Future<bool> handleSignUp() async {
    clearFieldErrors();
    _setLoading(true);

    final result = await _authService.signUpWithEmail(
      email: emailController.text.trim(),
      password: passwordController.text,
      name: nameController.text.trim(),
      login: loginController.text.trim(),
    );

    _setLoading(false);

    if (result.isSuccess) {
      await AnalyticsService.logSignUp('email');
      return true;
    } else {
      _setFieldErrorsFromMessage(result.errorMessage ?? 'Помилка реєстрації', forSignUp: true);
      return false;
    }
  }

  /// Вхід через email
  Future<bool> handleSignIn() async {
    clearFieldErrors();
    _setLoading(true);

    final result = await _authService.signInWithEmail(
      email: emailController.text.trim(),
      password: passwordController.text,
    );

    _setLoading(false);

    if (result.isSuccess) {
      await AnalyticsService.logLogin('email');
      return true;
    } else {
      _setFieldErrorsFromMessage(result.errorMessage ?? 'Помилка входу', forSignUp: false);
      return false;
    }
  }

  /// Вхід через Google
  Future<bool> handleGoogleSignIn() async {
    clearFieldErrors();
    _setLoading(true);

    final result = await _authService.signInWithGoogle();

    _setLoading(false);

    if (result.isSuccess) {
      await AnalyticsService.logLogin('google');
      return true;
    } else {
      // Загальна помилка Google — показуємо під email/login полі
      _setFieldErrorsFromMessage(result.errorMessage ?? 'Помилка входу через Google', forSignUp: false);
      return false;
    }
  }

  /// Перемикання режиму (вхід/реєстрація)
  void toggleAuthMode() {
    _isLogin = !_isLogin;
    clearFieldErrors();
    AnalyticsService.logAuthModeChange(_isLogin);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // На основі тексту помилки намагаємось прив'язати її до відповідного поля.
  // Якщо не вдається чітко визначити поле — ставимо її під email/login поле за замовчуванням.
  void _setFieldErrorsFromMessage(String message, {required bool forSignUp}) {
    final msg = message.toLowerCase();

    // Скидаємо попередні
    _emailError = null;
    _passwordError = null;
    _loginError = null;
    _nameError = null;
    _confirmPasswordError = null;

    bool assigned = false;

    if (msg.contains('password') || msg.contains('пароль') || msg.contains('incorrect') || msg.contains('невір') || msg.contains('неправ')) {
      _passwordError = message;
      assigned = true;
    }

    if (msg.contains('email') || msg.contains('адрес') || msg.contains('e-mail') || msg.contains('@')) {
      _emailError = message;
      assigned = true;
    }

    if (msg.contains('login') || msg.contains('логін') || msg.contains('username') || msg.contains('нік') || msg.contains('нікнейм')) {
      _loginError = message;
      assigned = true;
    }

    if (msg.contains('name') || msg.contains('ім\'я') || msg.contains('імя')) {
      _nameError = message;
      assigned = true;
    }

    if (msg.contains('confirm') || msg.contains('повтор') || msg.contains('пароль не співпада')) {
      _confirmPasswordError = message;
      assigned = true;
    }

    if (!assigned && forSignUp) {
      if (msg.contains('exists') || msg.contains('вже') || msg.contains('taken') || msg.contains('duplicate') || msg.contains('зайнято')) {
       
        if (msg.contains('логін') || msg.contains('login') || msg.contains('username')) {
          _loginError = message;
        } else {
          _emailError = message;
        }
        assigned = true;
      }
    }

    if (!assigned) {
      if (_isLogin) {
        _emailError = message;
      } else {
        _emailError = message;
      }
    }

    notifyListeners();
  }
/////
  Future<void> updateProfilePhoto() async { 
    final ImagePicker picker = ImagePicker();
    
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 70, 
    );

    if (image == null) return; 

    _setLoading(true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final String storagePath = 'users/${user.uid}/avatar_$timestamp.jpg';

      final String downloadUrl = await _storageRepository.uploadImage(
        image: image,
        path: storagePath,
      );

      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': downloadUrl,
      });

      await user.updatePhotoURL(downloadUrl);

      notifyListeners();
    } catch (e) {
      print("Error uploading avatar: $e");
    } finally {
      _setLoading(false);
    }
  }

  


  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    loginController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}













// // lib/features/auth/controllers/auth_controller.dart

// import 'package:flutter/material.dart';
// import '../../../core/services/auth_service.dart';
// import '../../../core/services/analytics_service.dart';

// /// Контролер для управління станом та логікою авторизації
// class AuthController extends ChangeNotifier {
//   final AuthService _authService = AuthService();
  
//   // Стан
//   bool _isLogin = true;
//   bool _isLoading = false;
//   String? _generalError;
  
//   // Getters
//   bool get isLogin => _isLogin;
//   bool get isLoading => _isLoading;
//   String? get generalError => _generalError;
  
//   // Контролери полів
//   final emailController = TextEditingController();
//   final passwordController = TextEditingController();
//   final nameController = TextEditingController();
//   final confirmPasswordController = TextEditingController();
//   final loginController = TextEditingController();
  
//   // Видимість паролів
//   bool _obscurePassword = true;
//   bool _obscureConfirmPassword = true;
  
//   bool get obscurePassword => _obscurePassword;
//   bool get obscureConfirmPassword => _obscureConfirmPassword;
  
//   void togglePasswordVisibility() {
//     _obscurePassword = !_obscurePassword;
//     notifyListeners();
//   }
  
//   void toggleConfirmPasswordVisibility() {
//     _obscureConfirmPassword = !_obscureConfirmPassword;
//     notifyListeners();
//   }
  
//   //   void clearGeneralError() {
//   //   if (generalError != null) {
//   //     generalError = null;
//   //     notifyListeners(); // Або ваш метод оновлення стану
//   //   }
//   // }

//   // ==================== МЕТОДИ АВТОРИЗАЦІЇ ====================
  
//   /// Реєстрація через email
//   Future<bool> handleSignUp() async {
//     _clearError();
//     _setLoading(true);
    
//     final result = await _authService.signUpWithEmail(
//       email: emailController.text.trim(),
//       password: passwordController.text,
//       name: nameController.text.trim(),
//     );
    
//     _setLoading(false);
    
//     if (result.isSuccess) {
//       await AnalyticsService.logSignUp('email');
//       return true;
//     } else {
//       _setError(result.errorMessage ?? 'Помилка реєстрації');
//       return false;
//     }
//   }
  
//   /// Вхід через email
//   Future<bool> handleSignIn() async {
//     _clearError();
//     _setLoading(true);
    
//     final result = await _authService.signInWithEmail(
//       email: emailController.text.trim(),
//       password: passwordController.text,
//     );
    
//     _setLoading(false);
    
//     if (result.isSuccess) {
//       await AnalyticsService.logLogin('email');
//       return true;
//     } else {
//       _setError(result.errorMessage ?? 'Помилка входу');
//       return false;
//     }
//   }
  
//   /// Вхід через Google
//   Future<bool> handleGoogleSignIn() async {
//     _clearError();
//     _setLoading(true);
    
//     final result = await _authService.signInWithGoogle();
    
//     _setLoading(false);
    
//     if (result.isSuccess) {
//       await AnalyticsService.logLogin('google');
//       return true;
//     } else {
//       _setError(result.errorMessage ?? 'Помилка входу через Google');
//       return false;
//     }
//   }
  
//   /// Перемикання режиму (вхід/реєстрація)
//   void toggleAuthMode() {
//     _isLogin = !_isLogin;
//     _clearError();
//     AnalyticsService.logAuthModeChange(_isLogin);
//     notifyListeners();
//   }
  
//   // ==================== ПРИВАТНІ МЕТОДИ ====================
  
//   void _setLoading(bool value) {
//     _isLoading = value;
//     notifyListeners();
//   }
  
//   void _setError(String error) {
//     _generalError = error;
//     notifyListeners();
//   }
  
//   void _clearError() {
//     _generalError = null;
//     notifyListeners();
//   }
  
//   @override
//   void dispose() {
//     emailController.dispose();
//     passwordController.dispose();
//     nameController.dispose();
//     loginController.dispose();
//     confirmPasswordController.dispose();
//     super.dispose();
//   }
// }