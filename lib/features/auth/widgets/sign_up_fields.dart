// lib/features/auth/widgets/sign_up_fields.dart

import 'package:flutter/material.dart';
import '../../../core/widgets/custom_form_field.dart';
import '../../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';

/// Поля для реєстрації
class SignUpFields extends StatelessWidget {
  final AuthController controller;

  const SignUpFields({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Додаємо відображення серверних помилок під відповідними полями
    return Column(
      children: [
        SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomFormField(
                label: 'Email',
                controller: controller.emailController,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
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
                label: 'Логін',
                controller: controller.loginController,
                validator: Validators.username,
              ),
              if (controller.loginError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                  child: Text(
                    controller.loginError!,
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
                label: 'Ім\'я',
                controller: controller.nameController,
                validator: Validators.name,
              ),
              if (controller.nameError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                  child: Text(
                    controller.nameError!,
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
        const SizedBox(height: 12),
        SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomFormField(
                label: 'Повторіть пароль',
                controller: controller.confirmPasswordController,
                obscureText: controller.obscureConfirmPassword,
                validator: (value) => Validators.confirmPassword(
                  value,
                  controller.passwordController.text,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    controller.obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: const Color.fromARGB(150, 67, 67, 99),
                  ),
                  onPressed: controller.toggleConfirmPasswordVisibility,
                ),
              ),
              if (controller.confirmPasswordError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                  child: Text(
                    controller.confirmPasswordError!,
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