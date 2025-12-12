// lib/features/layout/widgets/custom_bottom_nav_bar.dart

import 'package:flutter/material.dart';
import 'desktop_side_menu.dart'; // Тип MenuItemCallback вже визначений тут

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final MenuItemCallback onItemSelected; // Використовуємо той самий тип колбеку

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onItemSelected, // Використовуємо переданий колбек
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF4F506D),
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Чати'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профіль'),
        BottomNavigationBarItem(icon: Icon(Icons.contacts), label: 'Контакти'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Опції'),
      ],
    );
  }
}