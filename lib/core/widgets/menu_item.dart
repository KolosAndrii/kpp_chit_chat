import 'package:flutter/material.dart';

class MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected; // <-- Нова властивість

  const MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false, // <-- Значення за замовчуванням
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonColor = isSelected
        ? const Color(0xFFBFC0D2) // Активний - насичений фіолетовий
        : const Color(0xFFBFC0D2); // Неактивний - світлий фіолетовий/сірий

    final contentColor = isSelected
        ? Color.fromARGB(255, 45, 46, 71)// Активний - білий текст
        : const Color.fromARGB(255, 45, 46, 71); // Неактивний - темний текст

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: buttonColor, // <-- Використовуємо динамічний колір
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: const Color(0xFF4F506D).withOpacity(0.1),
          splashColor: const Color(0xFF4F506D).withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Row(
              children: [
                Icon(icon, color: contentColor, size: 22), // <-- Динамічний колір
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: contentColor, // <-- Динамічний колір
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



