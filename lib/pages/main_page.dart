import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 1. ДОДАНО
import 'package:firebase_auth/firebase_auth.dart';     // 1. ДОДАНО

// ВІДЖЕТИ UI
import '../features/chat/widgets/chat_list_view.dart';
import '../features/chat/widgets/chat_view.dart';
import '../features/chat/widgets/desktop_side_menu.dart';
import '../features/chat/widgets/bottom_nav_bar.dart'; 
import '../features/contacts/widgets/contacts_view.dart';
import '../features/chat/widgets/create_chat_view.dart'; 
import '../features/chat/widgets/chat_info_view.dart';
import '../features/contacts/widgets/user_profile_view.dart'; 

// МОДЕЛІ
import 'package:chat_lab_kpp/features/chat/models/contact_model.dart';

// СЕРВІСИ
import '../core/services/analytics_service.dart';
import '../core/services/auth_service.dart';
import '../pages/auth_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // --- СТАН (STATE) ---
  String? _selectedChatId;
  
  int _selectedMenuIndex = 0; 
  bool _isCreatingChat = false;
  bool _showChatInfo = false;
  Contact? _selectedContactForProfile;

  // --- ЖИТТЄВИЙ ЦИКЛ ---
  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('MainPage');
  }

  void _resetNavigationState() {
    setState(() {
      _isCreatingChat = false;
      _showChatInfo = false;
      _selectedContactForProfile = null;
    });
  }

  void _onMenuItemSelected(int index) {
    _resetNavigationState();
    setState(() {
      _selectedMenuIndex = index;
      if (index != 0 && index != 2) {
        _selectedChatId = null;
      }
    });
    AnalyticsService.logMenuItemSelected(index, _getMenuName(index));
  }

  void _onChatSelected(String chatId) {
    _resetNavigationState();
    setState(() {
      _selectedMenuIndex = 0;
      _selectedChatId = chatId;
    });
    AnalyticsService.logChatSelected(chatId.hashCode); 
  }

  void _startCreateChat() {
    _resetNavigationState();
    setState(() {
      _selectedMenuIndex = 0;
      _isCreatingChat = true;
      _selectedChatId = null;
    });
  }

  void _finishCreateChat() {
    setState(() => _isCreatingChat = false);
  }

  void _toggleChatInfo() {
    setState(() => _showChatInfo = !_showChatInfo);
  }

  void _openContactProfile(Contact contact) {
    setState(() => _selectedContactForProfile = contact);
  }

  void _closeContactProfile() {
    setState(() => _selectedContactForProfile = null);
  }

  Future<void> _handleLogout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
    }
  }

  String _getMenuName(int index) {
    const names = ['chats', 'profile', 'contacts', 'settings'];
    return (index >= 0 && index < names.length) ? names[index] : 'unknown';
  }

  Widget _buildUserProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("Not authorized"));

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("Profile data unavailable"));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        
        // Створюємо об'єкт Contact з даних поточного юзера
        final me = Contact(
          id: uid,
          username: data['username'] ?? 'Me',
          login: data['login'] ?? '',
          photoUrl: data['photoUrl'] ?? '',
          email: data['email'] ?? '',
          isOnline: true,
          lastSeen: DateTime.now(),
          addedAt: (data['createdAt'] as Timestamp?)?.toDate(), 
        );

        // Відображаємо профіль без кнопки "Назад" (onClose: null)
        return UserProfileView(contact: me);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 900;
          return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 900
          ? CustomBottomNavBar(selectedIndex: _selectedMenuIndex, onItemSelected: _onMenuItemSelected)
          : null,
    );
  }

  AppBar _buildAppBar() {
    final user = FirebaseAuth.instance.currentUser;

    return AppBar(
      backgroundColor: const Color(0xFF4F506D),
      elevation: 1,
      title: const Text('ChitChat', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Color.fromARGB(255, 221, 220, 220)),
          onPressed: () {},
        ),
        const SizedBox(width: 8),

        // --- ДИНАМІЧНІ ДАНІ ЮЗЕРА ---
        if (user != null)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                // Поки вантажиться, показуємо спіннер або пусте місце
                return const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                );
              }

              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final username = data?['username'] ?? 'User';
              final photoUrl = data?['photoUrl'];

              return InkWell(
                // Можна додати клік на шапку, щоб відкрити профіль
                onTap: () => _onMenuItemSelected(1), 
                child: Row(
                  children: [
                    Text(
                      username, 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)
                    ),
                    const SizedBox(width: 12),
                    _buildUserAvatar(photoUrl),
                  ],
                ),
              );
            },
          ),
        
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white), 
          tooltip: 'Вийти', 
          onPressed: _handleLogout
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  // Допоміжний метод для красивої аватарки
  Widget _buildUserAvatar(String? photoUrl) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFB0B3D6),
      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
          ? NetworkImage(photoUrl)
          : null,
      child: (photoUrl == null || photoUrl.isEmpty)
          ? const Icon(Icons.person, color: Colors.white, size: 20)
          : null,
    );
  }
  
  // AppBar _buildAppBar() {
  //   return AppBar(
  //     backgroundColor: const Color(0xFF4F506D),
  //     elevation: 1,
  //     title: const Text('ChitChat', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
  //     actions: [
  //       IconButton(icon: const Icon(Icons.notifications_none, color: Color.fromARGB(255, 221, 220, 220)), onPressed: () {}),
  //       const SizedBox(width: 16),
  //       const Text('Kolos Andrii', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
  //       const SizedBox(width: 8),
  //       const CircleAvatar(radius: 18, backgroundColor: Color(0xFFB0B3D6), child: Icon(Icons.person, color: Colors.white, size: 20)),
  //       IconButton(icon: const Icon(Icons.logout, color: Colors.white), tooltip: 'Вийти', onPressed: _handleLogout),
  //       const SizedBox(width: 16),
  //     ],
  //   );
  // }

  // --- DESKTOP LAYOUT ---

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        DesktopSideMenu(selectedIndex: _selectedMenuIndex, onMenuItemTap: _onMenuItemSelected),
        Expanded(
          child: _buildDesktopContent(),
        ),
      ],
    );
  }

  Widget _buildDesktopContent() {
    // 1. Створення чату
    if (_isCreatingChat) {
      return _buildSplitView(
        left: _buildChatList(),
        right: CreateChatView(onChatCreated: _finishCreateChat),
      );
    }

    // 2. Чати
    if (_selectedMenuIndex == 0) {
      if (_showChatInfo && _selectedChatId != null) {
        return Row(
          children: [
            Expanded(child: _buildChatView(isMobile: false)),
            const VerticalDivider(width: 1),
            SizedBox(width: 350, 
            child: ChatInfoView(
              chatId: _selectedChatId!,
              onLeaveSuccess: () {
                  setState(() {
                    _selectedChatId = null; // Скидаємо вибір чату
                    _showChatInfo = false;  // Закриваємо інфо
                  });
                },
             )
            ),
          ],
        );
      }
      return _buildSplitView(
        left: _buildChatList(),
        right: _buildChatView(isMobile: false),
      );
    }

    // 3. МІЙ ПРОФІЛЬ (ВИПРАВЛЕНО)
    if (_selectedMenuIndex == 1) {
       return _buildUserProfile();
    }

    // 4. Контакти
    if (_selectedMenuIndex == 2) {
      if (_selectedContactForProfile != null) {
        return _buildSplitView(
          left: _buildChatList(),
          right: UserProfileView(contact: _selectedContactForProfile!, onClose: _closeContactProfile),
        );
      }
      return _buildSplitView(
        left: _buildChatList(),
        right: ContactsView(
          onContactTap: _openContactProfile,
          onChatStarted: (chatId) {
             _onChatSelected(chatId); 
          },
        ),
      );
    }

    // 5. Settings
    if (_selectedMenuIndex == 3) return const Center(child: Text('Settings Page'));

    return Center(child: Text('Сторінка $_selectedMenuIndex'));
  }

  // --- MOBILE LAYOUT ---
  Widget _buildMobileLayout() {
    // 1. Створення чату
    if (_isCreatingChat) {
      return _buildMobileScaffold(
        'New Chat', 
        CreateChatView(onChatCreated: _finishCreateChat), 
        onBack: () => setState(() => _isCreatingChat = false)
      );
    }

    // 2. Чати
    if (_selectedMenuIndex == 0) {
      // А) Інформація про чат
      if (_showChatInfo && _selectedChatId != null) {
        return _buildMobileScaffold(
          'Chat Info', 
          ChatInfoView(chatId: _selectedChatId!,
          onLeaveSuccess: () {
              setState(() {
                _selectedChatId = null; // Повертаємось до списку
                _showChatInfo = false;
              });
            },
          ), 
          onBack: () => setState(() => _showChatInfo = false)
        );
      }
      
      // Б) Відкритий чат
      if (_selectedChatId != null) {
        return Column(
          children: [
            _buildMobileBackHeader("Back to chats", () => setState(() => _selectedChatId = null)),
            Expanded(child: _buildChatView(isMobile: true)),
          ],
        );
      }
      
      // В) Список чатів (ГОЛОВНА ЗМІНА ТУТ)
      // Передаємо isMobile: true, щоб прибрати SizedBox(width: 350)
      return _buildChatList(isMobile: true);
    }

    // 3. Мій профіль
    if (_selectedMenuIndex == 1) {
       return _buildUserProfile();
    }

    // 4. Контакти
    if (_selectedMenuIndex == 2) {
      if (_selectedContactForProfile != null) {
         return UserProfileView(contact: _selectedContactForProfile!, onClose: _closeContactProfile);
      }
      return ContactsView(
        onContactTap: _openContactProfile,
        onChatStarted: (chatId) {
           _onChatSelected(chatId);
        },
      );
    }

    // 5. Налаштування
    if (_selectedMenuIndex == 3) return const Center(child: Text('Settings Page'));

    return const SizedBox();
  }

  // Widget _buildMobileLayout() {
  //   if (_isCreatingChat) {
  //     return _buildMobileScaffold('New Chat', CreateChatView(onChatCreated: _finishCreateChat), onBack: () => setState(() => _isCreatingChat = false));
  //   }

  //   // Чати
  //   if (_selectedMenuIndex == 0) {
  //     if (_showChatInfo && _selectedChatId != null) {
  //       return _buildMobileScaffold('Chat Info', ChatInfoView(chatId: _selectedChatId!), onBack: () => setState(() => _showChatInfo = false));
  //     }
  //     if (_selectedChatId != null) {
  //       return Column(
  //         children: [
  //           _buildMobileBackHeader("Back to chats", () => setState(() => _selectedChatId = null)),
  //           Expanded(child: _buildChatView(isMobile: true)),
  //         ],
  //       );
  //     }
  //     return _buildChatList();
  //   }

  //   // МІЙ ПРОФІЛЬ (ВИПРАВЛЕНО)
  //   if (_selectedMenuIndex == 1) {
  //      return _buildUserProfile();
  //   }

  //   // Контакти
  //   if (_selectedMenuIndex == 2) {
  //     if (_selectedContactForProfile != null) {
  //        return UserProfileView(contact: _selectedContactForProfile!, onClose: _closeContactProfile);
  //     }
  //     return ContactsView(
  //       onContactTap: _openContactProfile,
  //       onChatStarted: (chatId) {
  //          _onChatSelected(chatId);
  //       },
  //     );
  //   }

  //   if (_selectedMenuIndex == 3) return const Center(child: Text('Settings Page'));

  //   return const SizedBox();
  // }

  // --- REUSABLE WIDGETS ---
  Widget _buildSplitView({required Widget left, required Widget right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch, // <--- ДОДАЙ ЦЕЙ РЯДОК
      children: [
        left,
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: right),
      ],
    );
  }
  
  // Widget _buildSplitView({required Widget left, required Widget right}) {
  //   return Row(
  //     children: [
  //       left,
  //       const VerticalDivider(width: 1, thickness: 1),
  //       Expanded(child: right),
  //     ],
  //   );
  // }

  Widget _buildChatList({bool isMobile = false}) {
    // Якщо мобільний - розтягуємо на всю ширину і висоту
    if (isMobile) {
      return ChatListView(
        onChatSelected: _onChatSelected,
        onCreateChatTap: _startCreateChat,
      );
    } 
    
    // Якщо десктоп - фіксована ширина
    return SizedBox(
      width: 350,
      child: ChatListView(
        onChatSelected: _onChatSelected,
        onCreateChatTap: _startCreateChat,
      ),
    );
  }

  Widget _buildChatView({required bool isMobile}) {
    if (_selectedChatId == null) return const Center(child: Text('Оберіть чат'));

    return Container(
      margin: isMobile ? EdgeInsets.zero : const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(12.0),
        border: isMobile ? null : Border.all(color: const Color(0xFF4F506D).withValues(alpha: 0.7)),
        boxShadow: isMobile ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: ChatView(
        chatId: _selectedChatId!,
        onOpenInfo: _toggleChatInfo,
      ),
    );
  }

  Widget _buildMobileScaffold(String title, Widget body, {required VoidCallback onBack}) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        title: Text(title),
      ),
      body: body,
    );
  }

  Widget _buildMobileBackHeader(String text, VoidCallback onBack) {
    return Container(
      color: const Color(0xFF4F506D),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}







































// import 'package:flutter/material.dart';

// // ВІДЖЕТИ UI
// import '../features/chat/widgets/chat_list_view.dart';
// import '../features/chat/widgets/chat_view.dart';
// import '../features/chat/widgets/desktop_side_menu.dart';
// import '../features/chat/widgets/bottom_nav_bar.dart'; 
// import '../features/contacts/widgets/contacts_view.dart';
// import '../features/chat/widgets/create_chat_view.dart'; 
// import '../features/chat/widgets/chat_info_view.dart';
// import '../features/contacts/widgets/user_profile_view.dart'; 

// // МОДЕЛІ
// import 'package:chat_lab_kpp/features/chat/models/contact_model.dart';

// // СЕРВІСИ
// import '../core/services/analytics_service.dart';
// import '../core/services/auth_service.dart';
// import '../pages/auth_page.dart';

// class MainPage extends StatefulWidget {
//   const MainPage({super.key});

//   @override
//   _MainPageState createState() => _MainPageState();
// }

// class _MainPageState extends State<MainPage> {
//   // --- СТАН (STATE) ---
  
//   // 1. ЗМІНЕНО: int? -> String? (ID чату у Firestore - це рядок)
//   String? _selectedChatId;
  
//   int _selectedMenuIndex = 0; 
//   bool _isCreatingChat = false;
//   bool _showChatInfo = false;
//   Contact? _selectedContactForProfile;

//   // --- ЖИТТЄВИЙ ЦИКЛ ---
//   @override
//   void initState() {
//     super.initState();
//     AnalyticsService.logScreenView('MainPage');
//   }

//   void _resetNavigationState() {
//     setState(() {
//       _isCreatingChat = false;
//       _showChatInfo = false;
//       _selectedContactForProfile = null;
//     });
//   }

//   void _onMenuItemSelected(int index) {
//     _resetNavigationState();
//     setState(() {
//       _selectedMenuIndex = index;
//       // Скидаємо вибір чату тільки якщо йдемо з вкладок, де він не потрібен
//       if (index != 0 && index != 2) {
//         _selectedChatId = null;
//       }
//     });
//     AnalyticsService.logMenuItemSelected(index, _getMenuName(index));
//   }

//   // 2. ЗМІНЕНО: int -> String
//   void _onChatSelected(String chatId) {
//     _resetNavigationState();
//     setState(() {
//       _selectedMenuIndex = 0;
//       _selectedChatId = chatId;
//     });
//     // Переконайся, що твій AnalyticsService приймає String або використовуй toString()
//     AnalyticsService.logChatSelected(chatId.hashCode); 
//   }

//   void _startCreateChat() {
//     _resetNavigationState();
//     setState(() {
//       _selectedMenuIndex = 0;
//       _isCreatingChat = true;
//       _selectedChatId = null;
//     });
//   }

//   void _finishCreateChat() {
//     setState(() => _isCreatingChat = false);
//   }

//   void _toggleChatInfo() {
//     setState(() => _showChatInfo = !_showChatInfo);
//   }

//   void _openContactProfile(Contact contact) {
//     setState(() => _selectedContactForProfile = contact);
//   }

//   void _closeContactProfile() {
//     setState(() => _selectedContactForProfile = null);
//   }

//   Future<void> _handleLogout() async {
//     await AuthService().signOut();
//     if (mounted) {
//       Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
//     }
//   }

//   String _getMenuName(int index) {
//     const names = ['chats', 'profile', 'contacts', 'settings'];
//     return (index >= 0 && index < names.length) ? names[index] : 'unknown';
//   }


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: _buildAppBar(),
//       body: LayoutBuilder(
//         builder: (context, constraints) {
//           bool isMobile = constraints.maxWidth < 900;
//           return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
//         },
//       ),
//       bottomNavigationBar: MediaQuery.of(context).size.width < 900
//           ? CustomBottomNavBar(selectedIndex: _selectedMenuIndex, onItemSelected: _onMenuItemSelected)
//           : null,
//     );
//   }

//   AppBar _buildAppBar() {
//     return AppBar(
//       backgroundColor: const Color(0xFF4F506D),
//       elevation: 1,
//       title: const Text('ChitChat', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
//       actions: [
//         IconButton(icon: const Icon(Icons.notifications_none, color: Color.fromARGB(255, 221, 220, 220)), onPressed: () {}),
//         const SizedBox(width: 16),
//         const Text('Kolos Andrii', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
//         const SizedBox(width: 8),
//         const CircleAvatar(radius: 18, backgroundColor: Color(0xFFB0B3D6), child: Icon(Icons.person, color: Colors.white, size: 20)),
//         IconButton(icon: const Icon(Icons.logout, color: Colors.white), tooltip: 'Вийти', onPressed: _handleLogout),
//         const SizedBox(width: 16),
//       ],
//     );
//   }

//   // --- DESKTOP LAYOUT ---

//   Widget _buildDesktopLayout() {
//     return Row(
//       children: [
//         DesktopSideMenu(selectedIndex: _selectedMenuIndex, onMenuItemTap: _onMenuItemSelected),
//         Expanded(
//           child: _buildDesktopContent(),
//         ),
//       ],
//     );
//   }

//   Widget _buildDesktopContent() {
//     // Базова структура: [ Список (завжди) | Роздільник | Контент ]
    
//     // 1. Якщо ми в режимі створення чату
//     if (_isCreatingChat) {
//       return _buildSplitView(
//         left: _buildChatList(),
//         right: CreateChatView(onChatCreated: _finishCreateChat),
//       );
//     }

//     // 2. Якщо ми в Чатах
//     if (_selectedMenuIndex == 0) {
//       // Якщо відкрито Інфо -> [ Чат | Інфо ] (Список зникає)
//       if (_showChatInfo && _selectedChatId != null) {
//         return Row(
//           children: [
//             Expanded(child: _buildChatView(isMobile: false)),
//             const VerticalDivider(width: 1),
//             // Тут передаємо String ID
//             SizedBox(width: 350, child: ChatInfoView(chatId: _selectedChatId!)),
//           ],
//         );
//       }
//       // Звичайний режим -> [ Список | Чат ]
//       return _buildSplitView(
//         left: _buildChatList(),
//         right: _buildChatView(isMobile: false),
//       );
//     }

//     // 3. Якщо ми в Контактах
//     if (_selectedMenuIndex == 2) {
//       // Якщо обрано профіль -> [ Список чатів | Профіль ]
//       if (_selectedContactForProfile != null) {
//         return _buildSplitView(
//           left: _buildChatList(),
//           right: UserProfileView(contact: _selectedContactForProfile!, onClose: _closeContactProfile),
//         );
//       }
//       // Інакше -> [ Список чатів | Список контактів ]
//       return _buildSplitView(
//         left: _buildChatList(),
//         right: ContactsView(onContactTap: _openContactProfile,onChatStarted: (chatId) {
//              _onChatSelected(chatId); // Це твій існуючий метод у MainPage
//           },),
        
//       );
//     }

//     // 4. Інші сторінки
//     return Center(child: Text('Сторінка $_selectedMenuIndex'));
//   }

//   // --- MOBILE LAYOUT ---

//   Widget _buildMobileLayout() {
//     // Мобільна навігація працює як стек: показуємо щось одне

//     // 1. Модальні вікна/Екрани дій
//     if (_isCreatingChat) {
//       return _buildMobileScaffold('New Chat', CreateChatView(onChatCreated: _finishCreateChat), onBack: () => setState(() => _isCreatingChat = false));
//     }

//     // 2. Вкладка Чати
//     if (_selectedMenuIndex == 0) {
//       if (_showChatInfo && _selectedChatId != null) {
//         return _buildMobileScaffold('Chat Info', ChatInfoView(chatId: _selectedChatId!), onBack: () => setState(() => _showChatInfo = false));
//       }
//       if (_selectedChatId != null) {
//         // Екран самого чату
//         return Column(
//           children: [
//             _buildMobileBackHeader("Back to chats", () => setState(() => _selectedChatId = null)),
//             Expanded(child: _buildChatView(isMobile: true)),
//           ],
//         );
//       }
//       return _buildChatList();
//     }

//     // 3. Вкладка Контакти
//     if (_selectedMenuIndex == 2) {
//       if (_selectedContactForProfile != null) {
//          // Екран профілю на весь екран
//          return UserProfileView(contact: _selectedContactForProfile!, onClose: _closeContactProfile);
//       }
//       return ContactsView(onContactTap: _openContactProfile,
//       onChatStarted: (chatId) {
//              _onChatSelected(chatId); // Це твій існуючий метод у MainPage
//           },
//         );
//     }

//     // 4. Інші
//     if (_selectedMenuIndex == 1) return const Center(child: Text('Profile Page'));
//     if (_selectedMenuIndex == 3) return const Center(child: Text('Settings Page'));

//     return const SizedBox();
//   }

//   // --- REUSABLE WIDGET BUILDERS (UI COMPONENTS) ---

//   // Універсальний розділювач для десктопу: [ Ліво | Лінія | Право ]
//   Widget _buildSplitView({required Widget left, required Widget right}) {
//     return Row(
//       children: [
//         left,
//         const VerticalDivider(width: 1, thickness: 1),
//         Expanded(child: right),
//       ],
//     );
//   }

//   Widget _buildChatList() {
//     return SizedBox(
//       width: 350,
//       child: ChatListView(
//         onChatSelected: _onChatSelected,
//         onCreateChatTap: _startCreateChat,
//       ),
//     );
//   }

//   Widget _buildChatView({required bool isMobile}) {
//     if (_selectedChatId == null) return const Center(child: Text('Оберіть чат'));

//     // Стилізація контейнера чату
//     return Container(
//       margin: isMobile ? EdgeInsets.zero : const EdgeInsets.all(20),
//       clipBehavior: Clip.antiAlias,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(12.0),
//         // 3. ЗМІНЕНО: withOpacity -> withValues (новий стандарт Flutter)
//         border: isMobile ? null : Border.all(color: const Color(0xFF4F506D).withValues(alpha: 0.7)),
//         boxShadow: isMobile ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))],
//       ),
//       child: ChatView(
//         chatId: _selectedChatId!,
//         onOpenInfo: _toggleChatInfo,
//       ),
//     );
//   }

//   // Допоміжний скаффолд для мобільних підсторінок
//   Widget _buildMobileScaffold(String title, Widget body, {required VoidCallback onBack}) {
//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
//         title: Text(title),
//       ),
//       body: body,
//     );
//   }

//   // Заголовок "Назад" для мобільного чату
//   Widget _buildMobileBackHeader(String text, VoidCallback onBack) {
//     return Container(
//       color: const Color(0xFF4F506D),
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//       child: Row(
//         children: [
//           IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack),
//           Text(text, style: const TextStyle(color: Colors.white)),
//         ],
//       ),
//     );
//   }
// }















// // import 'package:flutter/material.dart';

// // import '../features/chat/widgets/chat_list_view.dart';
// // import '../features/chat/widgets/chat_view.dart';
// // import '../features/chat/widgets/desktop_side_menu.dart';
// // import '../features/chat/widgets/bottom_nav_bar.dart'; 
// // import '../features/contacts/widgets/contacts_view.dart';
// // import '../features/chat/widgets/create_chat_view.dart'; 
// // import '../features/chat/widgets/chat_info_view.dart';
// // import '../features/contacts/widgets/user_profile_view.dart'; 
// // import 'package:chat_lab_kpp/features/chat/models/contact_model.dart';

// // // --- СЕРВІСИ ---
// // import '../core/services/analytics_service.dart';
// // import '../core/services/auth_service.dart';
// // import '../pages/auth_page.dart';

// // class MainPage extends StatefulWidget {
// //   const MainPage({super.key});

// //   @override
// //   _MainPageState createState() => _MainPageState();
// // }

// // class _MainPageState extends State<MainPage> {
// //   // --- СТАН (STATE) ---
// //   int? _selectedChatId;
// //   int _selectedMenuIndex = 0; 
// //   bool _isCreatingChat = false;
// //   bool _showChatInfo = false;
// //   Contact? _selectedContactForProfile;

// //   // --- ЖИТТЄВИЙ ЦИКЛ ---
// //   @override
// //   void initState() {
// //     super.initState();
// //     AnalyticsService.logScreenView('MainPage');
// //   }

// //   void _resetNavigationState() {
// //     setState(() {
// //       _isCreatingChat = false;
// //       _showChatInfo = false;
// //       _selectedContactForProfile = null;
// //     });
// //   }

// //   void _onMenuItemSelected(int index) {
// //     _resetNavigationState();
// //     setState(() {
// //       _selectedMenuIndex = index;
// //       // Скидаємо вибір чату тільки якщо йдемо з вкладок, де він не потрібен
// //       if (index != 0 && index != 2) {
// //         _selectedChatId = null;
// //       }
// //     });
// //     AnalyticsService.logMenuItemSelected(index, _getMenuName(index));
// //   }

// //   void _onChatSelected(int chatId) {
// //     _resetNavigationState();
// //     setState(() {
// //       _selectedMenuIndex = 0;
// //       _selectedChatId = chatId;
// //     });
// //     AnalyticsService.logChatSelected(chatId);
// //   }

// //   void _startCreateChat() {
// //     _resetNavigationState();
// //     setState(() {
// //       _selectedMenuIndex = 0;
// //       _isCreatingChat = true;
// //       _selectedChatId = null;
// //     });
// //   }

// //   void _finishCreateChat() {
// //     setState(() => _isCreatingChat = false);
// //   }

// //   void _toggleChatInfo() {
// //     setState(() => _showChatInfo = !_showChatInfo);
// //   }

// //   void _openContactProfile(Contact contact) {
// //     setState(() => _selectedContactForProfile = contact);
// //   }

// //   void _closeContactProfile() {
// //     setState(() => _selectedContactForProfile = null);
// //   }

// //   Future<void> _handleLogout() async {
// //     await AuthService().signOut();
// //     if (mounted) {
// //       Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
// //     }
// //   }

// //   String _getMenuName(int index) {
// //     const names = ['chats', 'profile', 'contacts', 'settings'];
// //     return (index >= 0 && index < names.length) ? names[index] : 'unknown';
// //   }


// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: Colors.white,
// //       appBar: _buildAppBar(),
// //       body: LayoutBuilder(
// //         builder: (context, constraints) {
// //           bool isMobile = constraints.maxWidth < 900;
// //           return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
// //         },
// //       ),
// //       bottomNavigationBar: MediaQuery.of(context).size.width < 900
// //           ? CustomBottomNavBar(selectedIndex: _selectedMenuIndex, onItemSelected: _onMenuItemSelected)
// //           : null,
// //     );
// //   }

// //   AppBar _buildAppBar() {
// //     return AppBar(
// //       backgroundColor: const Color(0xFF4F506D),
// //       elevation: 1,
// //       title: const Text('ChitChat', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
// //       actions: [
// //         IconButton(icon: const Icon(Icons.notifications_none, color: Color.fromARGB(255, 221, 220, 220)), onPressed: () {}),
// //         const SizedBox(width: 16),
// //         const Text('Kolos Andrii', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
// //         const SizedBox(width: 8),
// //         const CircleAvatar(radius: 18, backgroundColor: Color(0xFFB0B3D6), child: Icon(Icons.person, color: Colors.white, size: 20)),
// //         IconButton(icon: const Icon(Icons.logout, color: Colors.white), tooltip: 'Вийти', onPressed: _handleLogout),
// //         const SizedBox(width: 16),
// //       ],
// //     );
// //   }

// //   // --- DESKTOP LAYOUT ---

// //   Widget _buildDesktopLayout() {
// //     return Row(
// //       children: [
// //         DesktopSideMenu(selectedIndex: _selectedMenuIndex, onMenuItemTap: _onMenuItemSelected),
// //         Expanded(
// //           child: _buildDesktopContent(),
// //         ),
// //       ],
// //     );
// //   }

// //   Widget _buildDesktopContent() {
// //     // Базова структура: [ Список (завжди) | Роздільник | Контент ]
    
// //     // 1. Якщо ми в режимі створення чату
// //     if (_isCreatingChat) {
// //       return _buildSplitView(
// //         left: _buildChatList(),
// //         right: CreateChatView(onChatCreated: _finishCreateChat),
// //       );
// //     }

// //     // 2. Якщо ми в Чатах
// //     if (_selectedMenuIndex == 0) {
// //       // Якщо відкрито Інфо -> [ Чат | Інфо ] (Список зникає)
// //       if (_showChatInfo && _selectedChatId != null) {
// //         return Row(
// //           children: [
// //             Expanded(child: _buildChatView(isMobile: false)),
// //             const VerticalDivider(width: 1),
// //             SizedBox(width: 350, child: ChatInfoView(chatId: _selectedChatId!)),
// //           ],
// //         );
// //       }
// //       // Звичайний режим -> [ Список | Чат ]
// //       return _buildSplitView(
// //         left: _buildChatList(),
// //         right: _buildChatView(isMobile: false),
// //       );
// //     }

// //     // 3. Якщо ми в Контактах
// //     if (_selectedMenuIndex == 2) {
// //       // Якщо обрано профіль -> [ Список чатів | Профіль ]
// //       if (_selectedContactForProfile != null) {
// //         return _buildSplitView(
// //           left: _buildChatList(),
// //           right: UserProfileView(contact: _selectedContactForProfile!, onClose: _closeContactProfile),
// //         );
// //       }
// //       // Інакше -> [ Список чатів | Список контактів ]
// //       return _buildSplitView(
// //         left: _buildChatList(),
// //         right: ContactsView(onContactTap: _openContactProfile),
// //       );
// //     }

// //     // 4. Інші сторінки
// //     return Center(child: Text('Сторінка $_selectedMenuIndex'));
// //   }

// //   // --- MOBILE LAYOUT ---

// //   Widget _buildMobileLayout() {
// //     // Мобільна навігація працює як стек: показуємо щось одне

// //     // 1. Модальні вікна/Екрани дій
// //     if (_isCreatingChat) {
// //       return _buildMobileScaffold('New Chat', CreateChatView(onChatCreated: _finishCreateChat), onBack: () => setState(() => _isCreatingChat = false));
// //     }

// //     // 2. Вкладка Чати
// //     if (_selectedMenuIndex == 0) {
// //       if (_showChatInfo && _selectedChatId != null) {
// //         return _buildMobileScaffold('Chat Info', ChatInfoView(chatId: _selectedChatId!), onBack: () => setState(() => _showChatInfo = false));
// //       }
// //       if (_selectedChatId != null) {
// //         // Екран самого чату
// //         return Column(
// //           children: [
// //             _buildMobileBackHeader("Back to chats", () => setState(() => _selectedChatId = null)),
// //             Expanded(child: _buildChatView(isMobile: true)),
// //           ],
// //         );
// //       }
// //       return _buildChatList();
// //     }

// //     // 3. Вкладка Контакти
// //     if (_selectedMenuIndex == 2) {
// //       if (_selectedContactForProfile != null) {
// //          // Екран профілю на весь екран
// //          return UserProfileView(contact: _selectedContactForProfile!, onClose: _closeContactProfile);
// //       }
// //       return ContactsView(onContactTap: _openContactProfile);
// //     }

// //     // 4. Інші
// //     if (_selectedMenuIndex == 1) return const Center(child: Text('Profile Page'));
// //     if (_selectedMenuIndex == 3) return const Center(child: Text('Settings Page'));

// //     return const SizedBox();
// //   }

// //   // --- REUSABLE WIDGET BUILDERS (UI COMPONENTS) ---

// //   // Універсальний розділювач для десктопу: [ Ліво | Лінія | Право ]
// //   Widget _buildSplitView({required Widget left, required Widget right}) {
// //     return Row(
// //       children: [
// //         left,
// //         const VerticalDivider(width: 1, thickness: 1),
// //         Expanded(child: right),
// //       ],
// //     );
// //   }

// //   Widget _buildChatList() {
// //     return SizedBox(
// //       width: 350,
// //       child: ChatListView(
// //         onChatSelected: _onChatSelected,
// //         onCreateChatTap: _startCreateChat,
// //       ),
// //     );
// //   }

// //   Widget _buildChatView({required bool isMobile}) {
// //     if (_selectedChatId == null) return const Center(child: Text('Оберіть чат'));

// //     // Стилізація контейнера чату
// //     return Container(
// //       margin: isMobile ? EdgeInsets.zero : const EdgeInsets.all(20),
// //       clipBehavior: Clip.antiAlias,
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(12.0),
// //         border: isMobile ? null : Border.all(color: const Color(0xFF4F506D).withOpacity(0.7)),
// //         boxShadow: isMobile ? null : [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
// //       ),
// //       child: ChatView(
// //         chatId: _selectedChatId!,
// //         onOpenInfo: _toggleChatInfo,
// //       ),
// //     );
// //   }

// //   // Допоміжний скаффолд для мобільних підсторінок
// //   Widget _buildMobileScaffold(String title, Widget body, {required VoidCallback onBack}) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
// //         title: Text(title),
// //       ),
// //       body: body,
// //     );
// //   }

// //   // Заголовок "Назад" для мобільного чату
// //   Widget _buildMobileBackHeader(String text, VoidCallback onBack) {
// //     return Container(
// //       color: const Color(0xFF4F506D),
// //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
// //       child: Row(
// //         children: [
// //           IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack),
// //           Text(text, style: const TextStyle(color: Colors.white)),
// //         ],
// //       ),
// //     );
// //   }
// // }














