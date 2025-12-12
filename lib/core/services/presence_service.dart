import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PresenceService with WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Чи ініціалізований сервіс
  bool _initialized = false;

  void configure() {
    if (_initialized) return;
    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
    
    // Встановлюємо статус онлайн при старті, якщо юзер залогінений
    if (_auth.currentUser != null) {
      _setUserOnline(true);
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserOnline(false); // Ставимо офлайн при знищенні
    _initialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_auth.currentUser == null) return;

    if (state == AppLifecycleState.resumed) {
      // Додаток відкрит
      _setUserOnline(true);
    } else {
      // Додаток згорнутий або неактивний
      _setUserOnline(false);
    }
  }

  Future<void> _setUserOnline(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating presence: $e");
    }
  }
}