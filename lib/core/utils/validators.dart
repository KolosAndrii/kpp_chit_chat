// lib/core/utils/validators.dart

class Validators {
  // Валідація email
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email обов\'язковий';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Некоректний формат email';
    }
    
    return null;
  }

  // Валідація пароля
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Пароль обов\'язковий';
    }
    
    if (value.length < 6) {
      return 'Пароль має бути не менше 6 символів';
    }
    
    return null;
  }

  // Валідація імені
  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ім\'я обов\'язкове';
    }
    
    if (value.length < 2) {
      return 'Ім\'я має містити мінімум 2 символи';
    }
    
    return null;
  }

  // Валідація логіну
  static String? username(String? value) {
    if (value == null || value.isEmpty) {
      return 'Логін обов\'язковий';
    }
    
    if (value.length < 3) {
      return 'Логін має містити мінімум 3 символи';
    }
    
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value)) {
      return 'Логін може містити лише літери, цифри та _';
    }
    
    return null;
  }

  // Валідація підтвердження пароля
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Повторіть пароль';
    }
    
    if (value != password) {
      return 'Паролі не співпадають';
    }
    
    return null;
  }

  // Валідація email або логіну
  static String? emailOrUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email обов\'язковий';
    }
    
    // Перевіряємо чи це email
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final isEmail = emailRegex.hasMatch(value);
    
    // Якщо це не email, перевіряємо чи це валідний логін
    if (!isEmail) {
      final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
      if (!usernameRegex.hasMatch(value)) {
        return 'Введіть коректний email';
      }
      
      if (value.length < 3) {
        return 'Логін має містити мінімум 3 символи';
      }
    }
    
    return null;
  }

  // Загальна валідація на порожнє поле
  static String? required(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName обов\'язкове';
    }
    return null;
  }
}