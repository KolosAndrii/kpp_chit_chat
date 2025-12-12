// lib/pages/auth_page.dart

import 'package:flutter/material.dart';
import 'main_page.dart';
import '../core/widgets/custom_button.dart';
import '../core/services/analytics_service.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/widgets/sign_in_fields.dart';
import '../features/auth/widgets/sign_up_fields.dart';
import '../features/auth/widgets/google_sign_in_button.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../core/widgets/sentry_test_button.dart'; 

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  late final AuthController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AuthController();
    AnalyticsService.logScreenView('AuthPage');

    // Слухаємо зміни контролера
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ==================== ОБРОБНИКИ ====================

  Future<void> _handleSubmit() async {
    // Очистимо серверні помилки перед валідацією
    _controller.clearFieldErrors();

    final bool isValid = _formKey.currentState!.validate();

    if (!isValid) {
      await Sentry.captureMessage(
        'Validation error on AuthPage',
        level: SentryLevel.warning,
      );
      return;
    }

    // Якщо локальна валідація не пройшла — покажемо помилки валідатора в UI (validator має повернути рядок)
    // if (!_formKey.currentState!.validate()) {
    //   return;
    // }

    await AnalyticsService.logAuthAttempt(_controller.isLogin);

    final success = _controller.isLogin
        ? await _controller.handleSignIn()
        : await _controller.handleSignUp();

    if (success && mounted) {
      _navigateToMainPage();
    }
  }

  Future<void> _handleGoogleSignIn() async {
    // Google входить — також очищуємо серверні помилки перед дією
    _controller.clearFieldErrors();

    final success = await _controller.handleGoogleSignIn();
    if (success && mounted) {
      _navigateToMainPage();
    }
  }

  void _navigateToMainPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MainPage()),
    );
  }

  void _toggleAuthMode() {
    _controller.toggleAuthMode();
    _formKey.currentState?.reset();
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final formWidth = screenWidth * 0.9;
    const maxFormWidth = 600.0;

    return Scaffold(
      appBar: _buildAppBar(),
      body: Center(
        child: SingleChildScrollView(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildFormContainer(formWidth, maxFormWidth),
              _buildFloatingTitle(),
            ],
          ),
        ),
      ),
    );
  }


  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color.fromARGB(255, 67, 67, 99),
      title: const Text(
        'ChitChat',
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          fontSize: 22,
          color: Color.fromARGB(255, 222, 211, 247),
          letterSpacing: 1.2,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildFormContainer(double formWidth, double maxFormWidth) {
    return Container(
      width: formWidth > maxFormWidth ? maxFormWidth : formWidth,
      constraints: const BoxConstraints(minHeight: 600),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 231, 232, 255),
        border: Border.all(
          color: const Color.fromARGB(31, 46, 41, 78),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 50),

            // Поля форми
            _controller.isLogin
                ? SignInFields(controller: _controller)
                : SignUpFields(controller: _controller),

            const SizedBox(height: 16),

            const SizedBox(height: 8),

            // Кнопка входу/реєстрації
            _buildSubmitButton(),

            if (_controller.isLogin)
              GoogleSignInButton(
                onPressed: _handleGoogleSignIn,
                isLoading: _controller.isLoading,
              ),

            const SizedBox(height: 24),

            // Перемикач режиму
            _buildToggleButton(),

            const SizedBox(height: 16),

            const SentryTestButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: 280,
      child: _controller.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 123, 110, 201),
              ),
            )
          : CustomButton(
              text: _controller.isLogin ? 'Увійти' : 'Зареєструватися',
              onPressed: _handleSubmit,
            ),
    );
  }

  Widget _buildToggleButton() {
    return TextButton(
      onPressed: _toggleAuthMode,
      child: Text(
        _controller.isLogin
            ? 'Немає акаунту? Зареєструватися'
            : 'Є акаунт? Увійти',
        style: const TextStyle(
          color: Color.fromARGB(255, 123, 110, 201),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildFloatingTitle() {
    return Positioned(
      top: 20,
      left: -30,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 30,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 123, 110, 201),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          _controller.isLogin ? 'Авторизація' : 'Реєстрація',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}