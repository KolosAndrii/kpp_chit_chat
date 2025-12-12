// lib/core/widgets/custom_form_field.dart

import 'package:flutter/material.dart';

class CustomFormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const CustomFormField({
    Key? key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.validator,
    this.keyboardType,
    this.suffixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              color: Color.fromARGB(150, 67, 67, 99),
              fontSize: 15,
            ),
            
            // Звичайний стан
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color.fromARGB(100, 123, 110, 201),
                width: 1.5,
              ),
            ),
            
            // Коли поле в фокусі
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color.fromARGB(255, 123, 110, 201),
                width: 2,
              ),
            ),
            
            // Коли є помилка
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.5,
              ),
            ),
            
            // Коли є помилка і поле в фокусі
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            
            // Стиль тексту помилки
            errorStyle: const TextStyle(
              fontSize: 12,
              height: 0.8,
              color: Colors.red,
            ),
            
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            
            filled: true,
            fillColor: Colors.white,
            
            suffixIcon: suffixIcon,
          ),
        ),
        const SizedBox(height: 16), // Відступ між полями
      ],
    );
  }
}