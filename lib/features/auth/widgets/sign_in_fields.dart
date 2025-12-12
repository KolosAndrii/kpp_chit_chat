// lib/features/auth/widgets/sign_in_fields.dart

import 'package:flutter/material.dart';
import '../../../core/widgets/custom_form_field.dart';
import '../../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';

/// Поля для входу
class SignInFields extends StatelessWidget {
  final AuthController controller;

  const SignInFields({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Використовуємо Column і додаємо під кожним полем текст серверної помилки (якщо є).
    return Column(
      children: [
        SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomFormField(
                label: 'Email або логін',
                controller: controller.emailController,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.emailOrUsername,
              ),
              if (controller.emailError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                  child: Text(
                    controller.emailError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomFormField(
                label: 'Пароль',
                controller: controller.passwordController,
                obscureText: controller.obscurePassword,
                validator: Validators.password,
                suffixIcon: IconButton(
                  icon: Icon(
                    controller.obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: const Color.fromARGB(150, 67, 67, 99),
                  ),
                  onPressed: controller.togglePasswordVisibility,
                ),
              ),
              if (controller.passwordError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                  child: Text(
                    controller.passwordError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}