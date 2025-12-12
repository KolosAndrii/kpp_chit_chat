import 'package:flutter/material.dart';
import '../../../core/widgets/menu_item.dart'; // Переконайтесь, що шлях правильний

typedef MenuItemCallback = void Function(int index);

class DesktopSideMenu extends StatelessWidget {
  final int selectedIndex;
  final MenuItemCallback onMenuItemTap;

  const DesktopSideMenu({
    super.key,
    required this.selectedIndex,
    required this.onMenuItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240, // Ширина меню
      //color: const Color(0xFF4F506D), // Темний фон
      child: Column(
        children: [
          const SizedBox(height: 40), // Відступ зверху
          MenuItem(
            icon: Icons.chat,
            label: 'Чати',
            isSelected: selectedIndex == 0,
            onTap: () => onMenuItemTap(0),
          ),
          MenuItem(
            icon: Icons.person,
            label: 'Профіль',
            isSelected: selectedIndex == 1,
            onTap: () => onMenuItemTap(1),
          ),
          MenuItem(
            icon: Icons.contacts,
            label: 'Контакти',
            isSelected: selectedIndex == 2,
            onTap: () => onMenuItemTap(2),
          ),
          MenuItem(
            icon: Icons.settings,
            label: 'Налаштування',
            isSelected: selectedIndex == 3,
            onTap: () => onMenuItemTap(3),
          ),
        ],
      ),
    );
  }
}
// 