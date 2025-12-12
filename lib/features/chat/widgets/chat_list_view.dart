import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/widgets/custom_button.dart';

typedef ChatSelectedCallback = void Function(String chatId);
typedef OnCreateChatTap = void Function();

class ChatListView extends StatefulWidget {
  final ChatSelectedCallback? onChatSelected;
  final OnCreateChatTap? onCreateChatTap;

  const ChatListView({
    super.key,
    required this.onChatSelected,
    this.onCreateChatTap,
  });

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  final TextEditingController _searchController = TextEditingController();
  
  // 2. ЗМІНЕНО: int? -> String?
  String? _selectedChatId; 

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<ChatProvider>().searchChats(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  return Consumer<ChatProvider>(
    builder: (context, provider, child) {
      // 1. Отримуємо наш ID для перевірки прочитання
      final myUid = provider.currentUserId; 

      return Column(
        children: [
          // --- 1. ПОШУК ТА КНОПКА СТВОРЕННЯ (Без змін) ---
          Container(
            color: const Color(0xFFF5F5F5),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your chats',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2B2B40)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => provider.searchChats(val), // Додав пошук
                          decoration: const InputDecoration(
                            hintText: "Search chats...",
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CustomButton(
                      text: "+",
                      width: 50,
                      onPressed: () {
                        if (widget.onCreateChatTap != null) {
                          widget.onCreateChatTap!();
                        }
                      },
                    )
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFDDDDEE)),

          // --- 2. СПИСОК ЧАТІВ ---
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: Builder(
                builder: (context) {
                  // А) Завантаження
                  if (provider.isLoadingChats) { // Змінив на isLoadingChats (логічніше для списку)
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Б) Пусто
                  if (provider.chats.isEmpty) {
                    return const Center(
                      child: Text("No chats yet", style: TextStyle(color: Colors.grey)),
                    );
                  }

                  // В) Успіх - Список
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: provider.chats.length,
                    itemBuilder: (context, index) {
                      final chat = provider.chats[index];
                      final isSelected = chat.id == _selectedChatId;

                      final bool isUnread = myUid != null && chat.isUnreadForUser(myUid);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          color: Colors.white,
                          elevation: isSelected ? 4 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isSelected
                                ? const BorderSide(color: Color(0xFF5F63B4), width: 1)
                                : BorderSide.none,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            onTap: () {
                              setState(() {
                                _selectedChatId = chat.id;
                              });
                              if (widget.onChatSelected != null) {
                                widget.onChatSelected!(chat.id);
                              }
                            },
                            // Аватарка
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFB0B3D6),
                              backgroundImage: (chat.displayImage != null && chat.displayImage!.isNotEmpty)
                                  ? NetworkImage(chat.displayImage!)
                                  : null,
                              child: (chat.displayImage == null || chat.displayImage!.isEmpty)
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),
                            // Назва чату
                            title: Text(
                              chat.displayName,
                              style: TextStyle(
                                fontWeight: isUnread ? FontWeight.w900 : (isSelected ? FontWeight.bold : FontWeight.w600),
                                color: const Color(0xFF2B2B40),
                              ),
                            ),
                            // Текст останнього повідомлення
                            subtitle: Text(
                              chat.lastMessageText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                color: isUnread ? Colors.black87 : Colors.grey,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Час
                                if (chat.lastMessage != null)
                                  Text(
                                    "${chat.lastMessage!.timestamp.hour}:${chat.lastMessage!.timestamp.minute.toString().padLeft(2, '0')}",
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: isUnread ? const Color(0xFF5F63B4) : Colors.grey,
                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                
                                const SizedBox(height: 4),
                                  if (isUnread)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF5F63B4), // Твій акцентний колір
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      );
    },
  );
}
}


































































  // @override
  // Widget build(BuildContext context) {
  //   return Consumer<ChatProvider>(
  //     builder: (context, provider, child) {
  //       return Column(
  //         children: [
  //           // --- 1. ПОШУК ТА КНОПКА СТВОРЕННЯ ---
  //           Container(
  //             color: const Color(0xFFF5F5F5),
  //             padding: const EdgeInsets.all(16),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 const Text(
  //                   'Your chats', 
  //                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2B2B40))
  //                 ),
  //                 const SizedBox(height: 12),
  //                 Row(
  //                   children: [
  //                     Expanded(
  //                       child: Container(
  //                         decoration: BoxDecoration(
  //                           color: Colors.white,
  //                           borderRadius: BorderRadius.circular(12),
  //                           border: Border.all(color: Colors.grey.shade300),
  //                         ),
  //                         child: TextField(
  //                           controller: _searchController,
  //                           decoration: const InputDecoration(
  //                             hintText: "Search chats...",
  //                             prefixIcon: Icon(Icons.search, color: Colors.grey),
  //                             border: InputBorder.none,
  //                             contentPadding: EdgeInsets.symmetric(vertical: 12),
  //                           ),
  //                         ),
  //                       ),
  //                     ),
  //                     const SizedBox(width: 12),
  //                     CustomButton(
  //                       text: "+", 
  //                       width: 50,
  //                       onPressed: () {
  //                         if (widget.onCreateChatTap != null) {
  //                           widget.onCreateChatTap!();
  //                         }
  //                       },
  //                     )
  //                   ],
  //                 ),
  //               ],
  //             ),
  //           ),
            
  //           const Divider(height: 1, color: Color(0xFFDDDDEE)),
            
  //           // --- 2. СПИСОК ЧАТІВ ---
  //           Expanded(
  //             child: Container(
  //               color: const Color(0xFFF5F5F5),
  //               child: Builder(
  //                 builder: (context) {
  //                   // А) Завантаження
  //                   if (provider.isLoadingMessages) {
  //                     return const Center(child: CircularProgressIndicator());
  //                   }

  //                   // Б) Пусто
  //                   if (provider.chats.isEmpty) {
  //                     return const Center(
  //                       child: Text("No chats yet", style: TextStyle(color: Colors.grey)),
  //                     );
  //                   }

  //                   // В) Успіх - Список
  //                   return ListView.builder(
  //                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  //                     itemCount: provider.chats.length,
  //                     itemBuilder: (context, index) {
  //                       final chat = provider.chats[index];
  //                       final isSelected = chat.id == _selectedChatId;

  //                       final bool hasUnread = chat.unreadCount > 0;

  //                       return Padding(
  //                         padding: const EdgeInsets.only(bottom: 8),
  //                         child: Card(
  //                           color: Colors.white,
  //                           elevation: isSelected ? 4 : 0,
  //                           shape: RoundedRectangleBorder(
  //                             borderRadius: BorderRadius.circular(12),
  //                             side: isSelected 
  //                                 ? const BorderSide(color: Color(0xFF5F63B4), width: 1) 
  //                                 : BorderSide.none,
  //                           ),
  //                           child: ListTile(
  //                             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  //                             leading: CircleAvatar(
  //                               backgroundColor: const Color(0xFFB0B3D6),
  //                               backgroundImage: (chat.displayImage != null && chat.displayImage!.isNotEmpty)
  //                                   ? NetworkImage(chat.displayImage!)
  //                                   : null,
  //                               child: (chat.displayImage == null || chat.displayImage!.isEmpty)
  //                                   ? const Icon(Icons.person, color: Colors.white)
  //                                   : null,
  //                             ),
  //                             // 3. ЗМІНЕНО: chat.name -> chat.chatName
  //                             title: Text(
  //                               chat.displayName, // Він сам вирішить: це група чи юзер
  //                               style: TextStyle(
  //                                 fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
  //                                 color: const Color(0xFF2B2B40),
  //                               ),
  //                             ),
  //                             // 4. ЗМІНЕНО: lastMessageText вже є в моделі
  //                             subtitle: Text(
  //                               chat.lastMessageText,
  //                               maxLines: 1,
  //                               overflow: TextOverflow.ellipsis,
  //                               style: TextStyle(
  //                                 color: isSelected ? const Color(0xFF5F63B4) : Colors.grey,
  //                               ),
  //                             ),
  //                             // 5. ЗМІНЕНО: Перевірка через lastMessage, а не список messages
  //                             trailing: chat.lastMessage != null 
  //                                 ? Text(
  //                                       // Форматуємо час останнього повідомлення
  //                                       "${chat.lastMessage!.timestamp.hour}:${chat.lastMessage!.timestamp.minute.toString().padLeft(2, '0')}",
  //                                       style: const TextStyle(fontSize: 12, color: Colors.grey),
  //                                     ) 
  //                                 : null,
  //                             ///////////////
  //                             onTap: () {
  //                               setState(() {
  //                                 _selectedChatId = chat.id;
  //                               });
  //                               if (widget.onChatSelected != null) {
  //                                 widget.onChatSelected!(chat.id);
  //                               }
  //                             },
  //                           ),
  //                         ),
  //                       );
  //                     },
  //                   );
  //                 },
  //               ),
  //             ),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
































// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../../core/providers/chat_provider.dart';
// import '../../../core/widgets/custom_button.dart';

// // Типи для callback-функцій
// typedef ChatSelectedCallback = void Function(int chatId);
// typedef OnCreateChatTap = void Function();

// class ChatListView extends StatefulWidget {
//   final ChatSelectedCallback? onChatSelected;
//   final OnCreateChatTap? onCreateChatTap;

//   const ChatListView({
//     super.key,
//     required this.onChatSelected,
//     this.onCreateChatTap,
//   });

//   @override
//   State<ChatListView> createState() => _ChatListViewState();
// }

// class _ChatListViewState extends State<ChatListView> {
//   final TextEditingController _searchController = TextEditingController();
//   int? _selectedChatId; // Локальний стан для підсвітки

//   @override
//   void initState() {
//     super.initState();
//     _searchController.addListener(() {
//       // Передаємо запит в Provider для фільтрації
//       context.read<ChatProvider>().searchChats(_searchController.text);
//     });
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<ChatProvider>(
//       builder: (context, provider, child) {
//         return Column(
//           children: [
//             // --- 1. ПОШУК ТА КНОПКА СТВОРЕННЯ ---
//             Container(
//               color: const Color(0xFFF5F5F5),
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Your chats', 
//                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2B2B40))
//                   ),
//                   const SizedBox(height: 12),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(12),
//                             border: Border.all(color: Colors.grey.shade300),
//                           ),
//                           child: TextField(
//                             controller: _searchController,
//                             decoration: const InputDecoration(
//                               hintText: "Search chats...",
//                               prefixIcon: Icon(Icons.search, color: Colors.grey),
//                               border: InputBorder.none,
//                               contentPadding: EdgeInsets.symmetric(vertical: 12),
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       CustomButton(
//                         text: "+", 
//                         width: 50,
//                         onPressed: () {
//                           if (widget.onCreateChatTap != null) {
//                             widget.onCreateChatTap!();
//                           }
//                         },
//                       )
//                     ],
//                   ),
//                 ],
//               ),
//             ),
            
//             const Divider(height: 1, color: Color(0xFFDDDDEE)),
            
//             // --- 2. СПИСОК ЧАТІВ ---
//             Expanded(
//               child: Container(
//                 color: const Color(0xFFF5F5F5),
//                 // Використовуємо Builder для логіки станів (Loading, Error, Empty, Success)
//                 child: Builder(
//                   builder: (context) {
//                     // А) Завантаження
//                     if (provider.isLoading) {
//                       return const Center(child: CircularProgressIndicator());
//                     }

//                     // Б) Помилка
//                     if (provider.hasError) {
//                       return Center(
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             const Icon(Icons.error_outline, color: Colors.red, size: 48),
//                             const SizedBox(height: 16),
//                             Text(
//                               provider.errorMessage ?? "Error loading chats",
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(color: Colors.grey),
//                             ),
//                             const SizedBox(height: 16),
//                             ElevatedButton(
//                               onPressed: () => provider.loadChats(),
//                               child: const Text("Retry"),
//                             )
//                           ],
//                         ),
//                       );
//                     }

//                     // В) Пусто
//                     if (provider.chats.isEmpty) {
//                       return const Center(
//                         child: Text("No chats yet", style: TextStyle(color: Colors.grey)),
//                       );
//                     }

//                     // Г) Успіх - Список
//                     return ListView.builder(
//                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//                       itemCount: provider.chats.length,
//                       itemBuilder: (context, index) {
//                         final chat = provider.chats[index];
//                         final isSelected = chat.id == _selectedChatId;

//                         return Padding(
//                           padding: const EdgeInsets.only(bottom: 8),
//                           child: Card(
//                             color: Colors.white,
//                             elevation: isSelected ? 4 : 0, // Тінь тільки у вибраного
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                               side: isSelected 
//                                   ? const BorderSide(color: Color(0xFF5F63B4), width: 1) 
//                                   : BorderSide.none, // Обводка для вибраного
//                             ),
//                             child: ListTile(
//                               contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//                               leading: CircleAvatar(
//                                 backgroundColor: const Color(0xFFB0B3D6),
//                                 child: const Icon(Icons.person, color: Colors.white),
//                               ),
//                               title: Text(
//                                 chat.name, 
//                                 style: TextStyle(
//                                   fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
//                                   color: const Color(0xFF2B2B40),
//                                 ),
//                               ),
//                               subtitle: Text(
//                                 chat.lastMessageText,
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: TextStyle(
//                                   color: isSelected ? const Color(0xFF5F63B4) : Colors.grey,
//                                 ),
//                               ),
//                               trailing: chat.messages.isNotEmpty 
//                                   ? Text(
//                                       // Форматуємо час останнього повідомлення
//                                       "${chat.messages.last.timestamp.hour}:${chat.messages.last.timestamp.minute.toString().padLeft(2, '0')}",
//                                       style: const TextStyle(fontSize: 12, color: Colors.grey),
//                                     ) 
//                                   : null,
//                               onTap: () {
//                                 setState(() {
//                                   _selectedChatId = chat.id;
//                                 });
//                                 if (widget.onChatSelected != null) {
//                                   widget.onChatSelected!(chat.id);
//                                 }
//                               },
//                             ),
//                           ),
//                         );
//                       },
//                     );
//                   },
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }