import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/providers/contacts_provider.dart';
import '../../auth/models/user_model.dart';
import '../../chat/models/contact_model.dart';

class ChatInfoView extends StatefulWidget {
  final String chatId;
  final VoidCallback? onLeaveSuccess;

  const ChatInfoView({super.key, required this.chatId, this.onLeaveSuccess,});

  @override
  State<ChatInfoView> createState() => _ChatInfoViewState();
}

class _ChatInfoViewState extends State<ChatInfoView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchMode = false; // Режим пошуку нових людей

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Завантажуємо учасників чату
      context.read<ChatProvider>().loadChatMembers(widget.chatId);
      // Завантажуємо контакти (щоб було з кого вибирати при додаванні)
      context.read<ContactsProvider>().init();
    });

    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _isSearchMode = query.isNotEmpty;
    });
    
    if (_isSearchMode) {
      // Фільтруємо контакти локально
      context.read<ContactsProvider>().searchContacts(query);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // --- ЛОГІКА ВИДАЛЕННЯ (для учасників) ---
  void _confirmRemoveMember(String userId, String userName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Member?"),
        content: Text("Are you sure you want to remove $userName?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ChatProvider>().removeMember(widget.chatId, userId);
              if (mounted) context.read<ChatProvider>().loadChatMembers(widget.chatId);
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- ЛОГІКА ДОДАВАННЯ (для контактів) ---
  Future<void> _addContactToChat(Contact contact) async {
    await context.read<ChatProvider>().addMemberById(widget.chatId, contact.id);
    // Очищаємо пошук після додавання
    _searchController.clear(); 
    _searchFocusNode.unfocus();
    if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${contact.username} added!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final contactsProvider = context.watch<ContactsProvider>();
    final chat = chatProvider.getChatById(widget.chatId);

    const Color buttonColor = Color(0xFF5F63B4);
    final Color borderColor = const Color(0xFF4F506D).withValues(alpha: 0.2);

    if (chat == null) return const Center(child: CircularProgressIndicator());

    return Container(
      //width: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chat Info', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // --- SEARCH BAR ---
          _buildSearchBar(),
          const SizedBox(height: 24),

          // --- HEADER & BUTTON ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isSearchMode ? 'Contacts to Add' : 'Members', 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              if (!_isSearchMode) // Показуємо кнопку, тільки якщо ми ще не шукаємо
                ElevatedButton(
                  onPressed: () {
                    // Просто переводимо фокус на поле пошуку
                    FocusScope.of(context).requestFocus(_searchFocusNode);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Add New Member', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // --- DYNAMIC LIST ---
          Expanded(
            flex: 2,
            child: _isSearchMode 
                ? _buildContactsList(contactsProvider, chatProvider) // Список для додавання
                : _buildMembersList(chatProvider),                   // Список поточних учасників
          ),

          const SizedBox(height: 24),

          // Chat Description
          const Text('Chat description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              chat.isGroup ? (chat.groupName ?? 'Group Chat') : 'Private conversation',
              style: const TextStyle(color: Colors.black54, height: 1.4),
            ),
          ),
          const SizedBox(height: 24),

          if (chat.isGroup) 
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLeaveChat(context),
                icon: const Icon(Icons.exit_to_app, color: Colors.red),
                label: const Text("Leave Group", style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          const SizedBox(height: 24),
          const Spacer(),
        ],
      ),
    );
  }

  // --- ВІДЖЕТИ СПИСКІВ ---

  // 1. Список поточних учасників
  Widget _buildMembersList(ChatProvider provider) {
    if (provider.isLoadingMembers) return const Center(child: CircularProgressIndicator());
    if (provider.chatMembers.isEmpty) return const Text("No members found");

    return ListView.separated(
      itemCount: provider.chatMembers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final member = provider.chatMembers[index];
        return _buildMemberItem(member);
      },
    );
  }

  // 2. Список контактів для додавання (Фільтрований)
  Widget _buildContactsList(ContactsProvider contactsProvider, ChatProvider chatProvider) {
    // Об'єднуємо всі контакти (онлайн + офлайн)
    final allContacts = [
      ...contactsProvider.onlineContacts, 
      ...contactsProvider.offlineContacts
    ];
    
    // Виключаємо тих, хто ВЖЕ в чаті
    final existingIds = chatProvider.chatMembers.map((u) => u.uid).toSet();
    final availableContacts = allContacts.where((c) => !existingIds.contains(c.id)).toList();

    if (availableContacts.isEmpty) {
      return const Center(child: Text("No matching contacts to add."));
    }

    return ListView.separated(
      itemCount: availableContacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildContactItemToAdd(availableContacts[index]);
      },
    );
  }

  // --- ЕЛЕМЕНТИ СПИСКУ ---

  Widget _buildSearchBar() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search to add member...',
          prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
          suffixIcon: _isSearchMode 
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18), 
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  }
                ) 
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildMemberItem(UserModel member) {
    final currentUid = context.read<ChatProvider>().currentUserId;
    final chat = context.read<ChatProvider>().getChatById(widget.chatId); // Отримуємо об'єкт чату
    
    if (chat == null) return const SizedBox();
    final isMe = member.uid == currentUid;

    final amIAdmin = chat.adminId == currentUid;
    final canDelete = amIAdmin && !isMe;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFB0B3D6),
            backgroundImage: (member.photoUrl != null && member.photoUrl!.isNotEmpty) 
                ? NetworkImage(member.photoUrl!) 
                : null,
            child: (member.photoUrl == null || member.photoUrl!.isEmpty) 
                ? const Icon(Icons.person, color: Colors.white, size: 20) 
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(member.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      const Text('(You)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ]
                  ],
                ),
                Text(member.isOnline ? 'Online' : 'Offline', 
                     style: TextStyle(color: member.isOnline ? Colors.green : Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.grey[600], size: 20),
              onPressed: () => _confirmRemoveMember(member.uid, member.username),
            ),
        ],
      ),
    );
  }

  // Картка контакту (Кандидат на додавання)
  Widget _buildContactItemToAdd(Contact contact) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5FA), // Трохи інший фон, щоб відрізнити
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5F63B4).withValues(alpha: 0.3)), // Синя рамка
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFB0B3D6),
            backgroundImage: (contact.photoUrl != null && contact.photoUrl!.isNotEmpty) 
                ? NetworkImage(contact.photoUrl!) 
                : null,
            child: (contact.photoUrl == null || contact.photoUrl!.isEmpty) 
                ? const Icon(Icons.person, color: Colors.white, size: 20) 
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(contact.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          // Кнопка ДОДАТИ
          ElevatedButton(
            onPressed: () => _addContactToChat(contact),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5F63B4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(60, 30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Add", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Leave Chat?"),
        content: const Text("Are you sure you want to leave this group?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Закриваємо діалог
              
              // Виконуємо вихід
              await context.read<ChatProvider>().leaveChat(widget.chatId);
              
              // 2. ВИКЛИКАЄМО CALLBACK, ЩОБ ПОВІДОМИТИ MAIN PAGE
              if (widget.onLeaveSuccess != null) {
                widget.onLeaveSuccess!();
              }
            },
            child: const Text("Leave", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

















































// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../../core/providers/chat_provider.dart';
// import '../../auth/models/user_model.dart'; // Імпорт моделі юзера
// import 'add_members_page.dart';

// class ChatInfoView extends StatefulWidget {
//   final String chatId;

//   const ChatInfoView({super.key, required this.chatId});

//   @override
//   State<ChatInfoView> createState() => _ChatInfoViewState();
// }

// class _ChatInfoViewState extends State<ChatInfoView> {
  
//   @override
//   void initState() {
//     super.initState();
//     // ВАЖЛИВО: Кажемо провайдеру завантажити дані реальних людей
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<ChatProvider>().loadChatMembers(widget.chatId);
//     });
//   }

//   void _confirmRemoveMember(String userId, String userName) {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text("Remove Member?"),
//         content: Text("Are you sure you want to remove $userName from this chat?"),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text("Cancel"),
//           ),
//           TextButton(
//             onPressed: () async {
//               Navigator.pop(ctx); // Закриваємо діалог
              
//               // Викликаємо провайдер для видалення
//               await context.read<ChatProvider>().removeMember(widget.chatId, userId);
              
//               // Після видалення треба оновити список (хоча removeMember і так це робить локально)
//               // Але для певності можна перезавантажити
//               if (mounted) {
//                  context.read<ChatProvider>().loadChatMembers(widget.chatId);
//               }
//             },
//             child: const Text("Remove", style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Слухаємо зміни
//     final provider = context.watch<ChatProvider>();
//     final chat = provider.getChatById(widget.chatId);

//     const Color buttonColor = Color(0xFF5F63B4);
//     final Color borderColor = const Color(0xFF4F506D).withValues(alpha: 0.2);

//     if (chat == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Container(
//       width: 350,
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         border: Border(left: BorderSide(color: borderColor)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text('Chat Info', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 20),

//           _buildSearchBar(), 
//           const SizedBox(height: 24),

//           // Заголовок Member
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text('Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => AddMembersPage(chatId: widget.chatId),
//                     ),
//                   );
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: buttonColor,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                 ),
//                 child: const Text('Add New Member', style: TextStyle(fontSize: 12)),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),

//           // --- СПИСОК УЧАСНИКІВ (РЕАЛЬНІ ДАНІ) ---
//           Expanded(
//             flex: 2, 
//             child: Builder(
//               builder: (context) {
//                 if (provider.isLoadingMembers) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
                
//                 if (provider.chatMembers.isEmpty) {
//                   return const Text("No members found");
//                 }

//                 return ListView.separated(
//                   itemCount: provider.chatMembers.length,
//                   separatorBuilder: (_, __) => const SizedBox(height: 10),
//                   itemBuilder: (context, index) {
//                     final member = provider.chatMembers[index];
//                     // Передаємо реальний об'єкт UserModel
//                     return _buildMemberItem(member);
//                   },
//                 );
//               }
//             ),
//           ),

//           const SizedBox(height: 24),

//           // Chat Description
//           const Text('Chat description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 10),
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: const Color(0xFFF5F5FA),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.grey.shade300),
//             ),
//             child: Text(
//               chat.isGroup ? (chat.groupName ?? 'Group Chat') : 'Private conversation',
//               style: const TextStyle(color: Colors.black54, height: 1.4),
//             ),
//           ),

//           const SizedBox(height: 24),
//           const Spacer(),
//         ],
//       ),
//     );
//   }
  
//   Widget _buildSearchBar() {
//       return Container(
//             height: 45,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: Colors.grey.shade300),
//             ),
//             child: const TextField(
//               decoration: InputDecoration(
//                 hintText: 'Search member',
//                 prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
//                 border: InputBorder.none,
//                 contentPadding: EdgeInsets.symmetric(vertical: 10),
//               ),
//             ),
//           );
//   }

//   // --- ВІДЖЕТ УЧАСНИКА (ОНОВЛЕНИЙ) ---
//   Widget _buildMemberItem(UserModel member) {
//     final currentUid = context.read<ChatProvider>().currentUserId;
//     final isMe = member.uid == currentUid;

//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade200),
//       ),
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 18,
//             backgroundColor: const Color(0xFFB0B3D6),
//             // Показуємо реальне фото
//             backgroundImage: (member.photoUrl != null && member.photoUrl!.isNotEmpty) 
//                 ? NetworkImage(member.photoUrl!) 
//                 : null,
//             child: (member.photoUrl == null || member.photoUrl!.isEmpty) 
//                 ? const Icon(Icons.person, color: Colors.white, size: 20) 
//                 : null,
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Показуємо реальне ім'я
//                 Text(member.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//                 // Показуємо логін або статус
//                 Text(member.isOnline ? 'Online' : 'Offline', 
//                      style: TextStyle(color: member.isOnline ? Colors.green : Colors.grey, fontSize: 12)),
//               ],
//             ),
//           ),
//           // Додаткові дії (якщо це не я)
//           if (!isMe)
//             IconButton(
//               icon: Icon(Icons.delete_outline, color: Colors.grey[600], size: 20),
//               onPressed: () {
//                  _confirmRemoveMember(member.uid, member.username);
//               },
//             ),
//         ],
//       ),
//     );
//   }
// }









// // СТВОРЕННЯ ЧАТУ ЧЕРЕЗ ДІАЛОГОВЕ ВІЕНО!
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../../core/providers/chat_provider.dart';
// import '../../auth/models/user_model.dart';

// class ChatInfoView extends StatefulWidget {
//   final String chatId;

//   const ChatInfoView({super.key, required this.chatId});

//   @override
//   State<ChatInfoView> createState() => _ChatInfoViewState();
// }

// class _ChatInfoViewState extends State<ChatInfoView> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<ChatProvider>().loadChatMembers(widget.chatId);
//     });
//   }

//   // --- ДІАЛОГ ДОДАВАННЯ ---
//   void _showAddMemberDialog(BuildContext context) {
//     final loginController = TextEditingController();
    
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text("Add New Member"),
//         content: TextField(
//           controller: loginController,
//           decoration: const InputDecoration(
//             hintText: "Enter login (e.g. @ryan)",
//             border: OutlineInputBorder(),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text("Cancel"),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               final login = loginController.text.trim();
//               if (login.isEmpty) return;

//               Navigator.pop(ctx); // Закриваємо діалог

//               // Викликаємо провайдер
//               final error = await context.read<ChatProvider>().addMemberByLogin(widget.chatId, login);

//               if (mounted) {
//                 if (error == null) {
//                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User added!"), backgroundColor: Colors.green));
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
//                 }
//               }
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5F63B4), foregroundColor: Colors.white),
//             child: const Text("Add"),
//           ),
//         ],
//       ),
//     );
//   }

//   // --- ЛОГІКА ВИДАЛЕННЯ ---
//   void _removeMember(String userId) {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text("Remove user?"),
//         content: const Text("Are you sure you want to remove this user from the chat?"),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(ctx);
//               context.read<ChatProvider>().removeMember(widget.chatId, userId);
//             },
//             child: const Text("Remove", style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final provider = context.watch<ChatProvider>();
//     final chat = provider.getChatById(widget.chatId);

//     const Color buttonColor = Color(0xFF5F63B4);
//     final Color borderColor = const Color(0xFF4F506D).withValues(alpha: 0.2);

//     if (chat == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Container(
//       width: 350,
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         border: Border(left: BorderSide(color: borderColor)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text('Chat Info', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 20),

//           // Пошук у списку (локальний фільтр можна додати пізніше)
//           _buildSearchBar(), 
//           const SizedBox(height: 24),

//           // Заголовок Member + Кнопка Add
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text('Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               ElevatedButton(
//                 onPressed: () => _showAddMemberDialog(context), // Виклик діалогу
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: buttonColor,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                 ),
//                 child: const Text('Add New Member', style: TextStyle(fontSize: 12)),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),

//           // --- СПИСОК УЧАСНИКІВ ---
//           Expanded(
//             flex: 2, 
//             child: Builder(
//               builder: (context) {
//                 if (provider.isLoadingMembers) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
                
//                 if (provider.chatMembers.isEmpty) {
//                   return const Text("No members found");
//                 }

//                 return ListView.separated(
//                   itemCount: provider.chatMembers.length,
//                   separatorBuilder: (_, __) => const SizedBox(height: 10),
//                   itemBuilder: (context, index) {
//                     final member = provider.chatMembers[index];
//                     return _buildMemberItem(member);
//                   },
//                 );
//               }
//             ),
//           ),

//           const SizedBox(height: 24),

//           // Chat Description
//           const Text('Chat description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 10),
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: const Color(0xFFF5F5FA),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.grey.shade300),
//             ),
//             child: Text(
//               chat.isGroup ? (chat.groupName ?? 'Group Chat') : 'Private conversation',
//               style: const TextStyle(color: Colors.black54, height: 1.4),
//             ),
//           ),

//           const SizedBox(height: 24),
//           const Spacer(),
//         ],
//       ),
//     );
//   }
  
//   Widget _buildSearchBar() {
//       return Container(
//             height: 45,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: Colors.grey.shade300),
//             ),
//             child: const TextField(
//               decoration: InputDecoration(
//                 hintText: 'Search member',
//                 prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
//                 border: InputBorder.none,
//                 contentPadding: EdgeInsets.symmetric(vertical: 10),
//               ),
//             ),
//           );
//   }

//   Widget _buildMemberItem(UserModel member) {
//     // Перевіряємо, чи це я
//     final currentUid = context.read<ChatProvider>().currentUserId;
//     final isMe = member.uid == currentUid;

//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade200),
//       ),
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 18,
//             backgroundColor: const Color(0xFFB0B3D6),
//             backgroundImage: (member.photoUrl != null && member.photoUrl!.isNotEmpty) 
//                 ? NetworkImage(member.photoUrl!) 
//                 : null,
//             child: (member.photoUrl == null || member.photoUrl!.isEmpty) 
//                 ? const Icon(Icons.person, color: Colors.white, size: 20) 
//                 : null,
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Text(member.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//                     if (isMe) ...[
//                       const SizedBox(width: 4),
//                       const Text('(You)', style: TextStyle(color: Colors.grey, fontSize: 12)),
//                     ]
//                   ],
//                 ),
//                 Text(member.isOnline ? 'Online' : 'Offline', 
//                      style: TextStyle(color: member.isOnline ? Colors.green : Colors.grey, fontSize: 12)),
//               ],
//             ),
//           ),
          
//           // Кнопка видалення (активна для всіх, крім себе, поки немає перевірки на адміна)
//           if (!isMe)
//             IconButton(
//               icon: Icon(Icons.delete_outline, color: Colors.grey[600], size: 20),
//               onPressed: () => _removeMember(member.uid),
//             ),
//         ],
//       ),
//     );
//   }
// }



































































// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../../core/providers/chat_provider.dart';
// import '../../auth/models/user_model.dart';
// //import '../../chat/models/chat_member_model.dart'; // Імпорт моделі

// class ChatInfoView extends StatelessWidget {
//   final String chatId; // 1. ЗМІНЕНО: int -> String
//   const ChatInfoView({super.key, required this.chatId});



//   @override
//   Widget build(BuildContext context) {
//     // Отримуємо провайдер
//     final provider = context.watch<ChatProvider>();
    
//     // 2. Шукаємо чат (може повернути null, якщо чат ще вантажиться)
//     final chat = provider.getChatById(chatId);

//     const Color buttonColor = Color(0xFF5F63B4);
//     final Color borderColor = const Color(0xFF4F506D).withOpacity(0.2);

//     // 3. Перевірка: якщо чат не знайдено (або видалено/вантажиться)
//     if (chat == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Container(
//       width: 350,
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         border: Border(left: BorderSide(color: borderColor)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text('Chat Info', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 20),

//           _buildSearchBar(), 
//           const SizedBox(height: 24),

//           // Заголовок Member
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text('Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               ElevatedButton(
//                 onPressed: () {
//                    // Тут логіка додавання
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: buttonColor,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                 ),
//                 child: const Text('Add New Member', style: TextStyle(fontSize: 12)),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),

//           // --- СПИСОК УЧАСНИКІВ ---
//           // Увага: У новій моделі Firestore у нас є тільки participantIds (String).
//           // Поки що виводимо просто список ID або заглушки.
//           // Щоб отримати імена, треба робити окремий запит до Users (це наступний рівень).
//           Expanded( 
//             flex: 2, 
//             child: ListView.separated(
//               itemCount: chat.participantIds.length, // Використовуємо participantIds
//               separatorBuilder: (_, __) => const SizedBox(height: 10),
//               itemBuilder: (context, index) {
//                 final userId = chat.participantIds[index];
//                 // Тимчасово малюємо заглушку з ID юзера
//                 return _buildMemberItemStub(userId);
//               },
//             ),
//           ),

//           const SizedBox(height: 24),

//           // Chat Description (У новій моделі поки немає поля description, тому ставимо заглушку)
//           const Text('Chat description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 10),
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: const Color(0xFFF5F5FA),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.grey.shade300),
//             ),
//             child: const Text(
//               'Chat description is not implemented in Firestore yet.', // Заглушка
//               style: TextStyle(color: Colors.black54, height: 1.4),
//             ),
//           ),

//           const SizedBox(height: 24),

//           const Spacer(),
//         ],
//       ),
//     );
//   }
  
//   Widget _buildSearchBar() {
//       return Container(
//             height: 45,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: Colors.grey.shade300),
//             ),
//             child: const TextField(
//               decoration: InputDecoration(
//                 hintText: 'Search member',
//                 prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
//                 border: InputBorder.none,
//                 contentPadding: EdgeInsets.symmetric(vertical: 10),
//               ),
//             ),
//           );
//   }

//   // Тимчасовий віджет для відображення учасника (тільки по ID)
//   Widget _buildMemberItemStub(String userId) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade200),
//       ),
//       child: Row(
//         children: [
//           const CircleAvatar(
//             radius: 18,
//             backgroundColor: Color(0xFFB0B3D6),
//             child: Icon(Icons.person, color: Colors.white, size: 20),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text("User ID: ${userId.substring(0, 5)}...", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//                 const Text("Loading name...", style: TextStyle(color: Colors.grey, fontSize: 12)),
//               ],
//             ),
//           ),
//           IconButton(
//             icon: Icon(Icons.delete_outline, color: Colors.grey[600], size: 20),
//             onPressed: () {},
//           ),
//         ],
//       ),
//     );
//   }
// }































// class ChatInfoView extends StatelessWidget {
//   final int chatId;
//   const ChatInfoView({super.key, required this.chatId});

//   @override
//   Widget build(BuildContext context) {
//     // Отримуємо дані. Використовуємо select або watch.
//     // Тут краще watch, бо якщо додасться учасник, треба перемалювати.
//     final provider = context.watch<ChatProvider>();
//     final chat = provider.getChatById(chatId);

//     const Color buttonColor = Color(0xFF5F63B4);
//     final Color borderColor = const Color(0xFF4F506D).withOpacity(0.2);

//     return Container(
//       width: 350,
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         border: Border(left: BorderSide(color: borderColor)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text('Chat Info', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 20),

//           // Пошук учасника
//           _buildSearchBar(), 
//           const SizedBox(height: 24),

//           // Заголовок Member + Кнопка
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text('Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               ElevatedButton(
//                 onPressed: () {
//                    // Тут можна викликати діалог, який звернеться до Provider
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: buttonColor,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                 ),
//                 child: const Text('Add New Member', style: TextStyle(fontSize: 12)),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),

//           // --- DYNAMIC MEMBER LIST ---
//           // Тут ми використовуємо дані з моделі!
//           Expanded( // Додаємо Expanded, якщо список великий
//             flex: 2, 
//             child: ListView.separated(
//               itemCount: chat.members.length,
//               separatorBuilder: (_, __) => const SizedBox(height: 10),
//               itemBuilder: (context, index) {
//                 final member = chat.members[index];
//                 return _buildMemberItem(member);
//               },
//             ),
//           ),

//           const SizedBox(height: 24),

//           // Chat Description
//           const Text('Chat description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 10),
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: const Color(0xFFF5F5FA),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.grey.shade300),
//             ),
//             // Дані з моделі
//             child: Text(
//               chat.description.isNotEmpty ? chat.description : 'No description provided',
//               style: const TextStyle(color: Colors.black54, height: 1.4),
//             ),
//           ),

//           const SizedBox(height: 24),

//           const Text('Media files', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 10),
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.grey.shade300),
//                boxShadow: [
//                 BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
//               ]
//             ),
//             // Перевірка на пустоту з моделі
//             child: Text(
//               chat.mediaFiles.isEmpty ? 'Empty yet...' : '${chat.mediaFiles.length} files shared',
//               style: const TextStyle(color: Colors.black54),
//             ),
//           ),
          
//           // Spacer щоб підняти контент вгору, якщо його мало
//           const Spacer(),
//         ],
//       ),
//     );
//   }
  
//   Widget _buildSearchBar() {
//       return Container(
//             height: 45,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: Colors.grey.shade300),
//             ),
//             child: const TextField(
//               decoration: InputDecoration(
//                 hintText: 'Search member',
//                 prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
//                 border: InputBorder.none,
//                 contentPadding: EdgeInsets.symmetric(vertical: 10),
//               ),
//             ),
//           );
//   }

//   // Приймає ОБ'ЄКТ, а не набір параметрів
//   Widget _buildMemberItem(ChatMember member) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade200),
//         boxShadow: [
//           BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
//         ]
//       ),
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 18,
//             backgroundColor: const Color(0xFFB0B3D6),
//             backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
//             child: member.avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//                 Text(member.status, style: const TextStyle(color: Colors.grey, fontSize: 12)),
//               ],
//             ),
//           ),
//           if (member.isMe)
//             const Text('You', style: TextStyle(color: Colors.grey, fontSize: 12))
//           else
//             Row(
//               children: [
//                  // Кнопки дій можуть викликати методи провайдера
//                  IconButton(
//                     padding: EdgeInsets.zero,
//                     constraints: const BoxConstraints(),
//                     icon: Icon(Icons.settings_outlined, color: Colors.grey[600], size: 20),
//                     onPressed: () {},
//                  ),
//                  const SizedBox(width: 12),
//                  IconButton(
//                     padding: EdgeInsets.zero,
//                     constraints: const BoxConstraints(),
//                     icon: Icon(Icons.delete_outline, color: Colors.grey[600], size: 20),
//                     onPressed: () {
//                         // context.read<ChatProvider>().removeMember(chatId, member.id);
//                     },
//                  ),
//               ],
//             )
//         ],
//       ),
//     );
//   }
// }