import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/providers/contacts_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../models/contact_model.dart';

class CreateChatView extends StatefulWidget {
  final VoidCallback onChatCreated; 

  const CreateChatView({super.key, required this.onChatCreated});

  @override
  State<CreateChatView> createState() => _CreateChatViewState();
}

class _CreateChatViewState extends State<CreateChatView> {
  final TextEditingController _chatNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Множина вибраних ID
  final Set<String> _selectedUserIds = {};

  @override
  void dispose() {
    _chatNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleCreate() {
    final name = _chatNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter chat name')),
      );
      return;
    }

    // Створюємо групу з вибраними учасниками
    context.read<ChatProvider>().createNewChat(name, _selectedUserIds.toList());
    
    widget.onChatCreated();
  }

  // --- 1. ДОДАНО: Метод перемикання вибору ---
  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  String _getStatusText(Contact contact) {
    if (contact.isOnline) return 'Online';
    if (contact.lastSeen == null) return 'Offline';
    return timeago.format(contact.lastSeen!);
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor = const Color(0xFF4F506D).withValues(alpha: 0.5);
    final Color sectionBgColor = const Color(0xFFEBEBF2);
    const Color createButtonColor = Color(0xFF5F63B4);

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          // --- HEADER ---
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // ВИПРАВЛЕНО ТУТ:
                if (MediaQuery.of(context).size.width > 800) ...[
                  const Text(
                    'Create chat',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2B2B40)),
                  ),
                  const SizedBox(width: 30),
                ], 
                Expanded(
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBEBF2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _chatNameController,
                      decoration: const InputDecoration(
                        hintText: 'Group Name',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Індикатор кількості вибраних
                if (_selectedUserIds.isNotEmpty)
                   Padding(
                     padding: const EdgeInsets.only(right: 16.0),
                     child: Text("${_selectedUserIds.length} members", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                   ),

                ElevatedButton(
                  onPressed: _handleCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: createButtonColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('CREATE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
                
                // const SizedBox(width: 12),
                // IconButton(
                //   icon: const Icon(Icons.settings_outlined, size: 28),
                //   onPressed: () {},
                //   color: const Color(0xFF2B2B40),
                // ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),

          // --- BODY (Contacts List) ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                   // Search Bar
                   Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBEBF2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => context.read<ContactsProvider>().searchContacts(val),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          hintText: 'Filter contacts...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Lists
                  Expanded(
                    child: Consumer<ContactsProvider>(
                      builder: (context, provider, child) {
                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (provider.onlineContacts.isNotEmpty)
                                _buildSection('ONLINE', provider.onlineContacts, sectionBgColor),
                              
                              const SizedBox(height: 24),

                              if (provider.offlineContacts.isNotEmpty)
                                _buildSection('OFFLINE', provider.offlineContacts, sectionBgColor),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Contact> contacts, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF4F506D), fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: contacts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            // 2. ВИПРАВЛЕНО: Викликаємо _buildSelectableContactItem
            itemBuilder: (context, index) => _buildSelectableContactItem(contacts[index]),
          ),
        ],
      ),
    );
  }

  // Віджет з логікою вибору (Multi-select)
  Widget _buildSelectableContactItem(Contact contact) {
    final isSelected = _selectedUserIds.contains(contact.id);
    final activeColor = const Color(0xFF5F63B4);

    return InkWell(
      onTap: () => _toggleSelection(contact.id), 
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: activeColor, width: 1) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
        child: Row(
          children: [
            CircleAvatar(
               radius: 20,
               backgroundColor: const Color(0xFFB0B3D6),
               backgroundImage: (contact.photoUrl != null && contact.photoUrl!.isNotEmpty) 
                   ? NetworkImage(contact.photoUrl!) 
                   : null,
               child: (contact.photoUrl == null || contact.photoUrl!.isEmpty) 
                   ? const Icon(Icons.person, color: Colors.white) 
                   : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(_getStatusText(contact), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            
            // КНОПКА ВИБОРУ
            ElevatedButton(
              onPressed: () => _toggleSelection(contact.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? Colors.grey[300] : activeColor,
                foregroundColor: isSelected ? Colors.black54 : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                elevation: 0,
              ),
              child: isSelected 
                  ? const Row(children: [Icon(Icons.check, size: 16), SizedBox(width: 4), Text('Added')])
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}





// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:timeago/timeago.dart' as timeago; //
// import '../../../core/providers/contacts_provider.dart';
// import '../../../core/providers/chat_provider.dart';
// import '../models/contact_model.dart';

// class CreateChatView extends StatefulWidget {
//   final VoidCallback onChatCreated; 

//   const CreateChatView({super.key, required this.onChatCreated});

//   @override
//   State<CreateChatView> createState() => _CreateChatViewState();
// }

// class _CreateChatViewState extends State<CreateChatView> {
//   final TextEditingController _chatNameController = TextEditingController();
//   final TextEditingController _searchController = TextEditingController();

//   // 1. ДОДАНО: Множина вибраних ID (Set гарантує унікальність)
//   final Set<String> _selectedUserIds = {};

//   @override
//   void dispose() {
//     _chatNameController.dispose();
//     _searchController.dispose();
//     super.dispose();
//   }

//   void _handleCreate() {
//     final name = _chatNameController.text.trim();
//     if (name.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please enter chat name')),
//       );
//       return;
//     }

//     // ВИПРАВЛЕНО: Тепер цей метод існує в ChatProvider
//     //context.read<ChatProvider>().createNewChat(name);
//     context.read<ChatProvider>().createNewChat(name, _selectedUserIds.toList());

//     widget.onChatCreated();
//   }

//   // Допоміжна функція для статусу (замість contact.statusText)
//   String _getStatusText(Contact contact) {
//     if (contact.isOnline) return 'Online';
//     if (contact.lastSeen == null) return 'Offline';
//     return timeago.format(contact.lastSeen!);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final Color borderColor = const Color(0xFF4F506D).withOpacity(0.5);
//     final Color sectionBgColor = const Color(0xFFEBEBF2);
//     const Color createButtonColor = Color(0xFF5F63B4);

//     return Container(
//       margin: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: borderColor, width: 1),
//       ),
//       child: Column(
//         children: [
//           // --- HEADER ---
//           Padding(
//             padding: const EdgeInsets.all(24),
//             child: Row(
//               children: [
//                 const Text(
//                   'Create chat',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2B2B40)),
//                 ),
//                 const SizedBox(width: 30),
//                 Expanded(
//                   child: Container(
//                     height: 50,
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFFEBEBF2),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: TextField(
//                       controller: _chatNameController,
//                       decoration: const InputDecoration(
//                         hintText: 'Create chat name...',
//                         border: InputBorder.none,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 ElevatedButton(
//                   onPressed: _handleCreate,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: createButtonColor,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                   ),
//                   child: const Text('CREATE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
//                 ),
//                 const SizedBox(width: 12),
//                 IconButton(
//                   icon: const Icon(Icons.settings_outlined, size: 28),
//                   onPressed: () {},
//                   color: const Color(0xFF2B2B40),
//                 ),
//               ],
//             ),
//           ),
//           const Divider(height: 1, color: Color(0xFFE0E0E0)),

//           // --- BODY (Contacts List) ---
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Column(
//                 children: [
//                    // Search Bar
//                    Container(
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFEBEBF2),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: TextField(
//                         controller: _searchController,
//                         onChanged: (val) => context.read<ContactsProvider>().searchContacts(val),
//                         decoration: const InputDecoration(
//                           prefixIcon: Icon(Icons.search, color: Colors.grey),
//                           hintText: 'Find contacts...',
//                           border: InputBorder.none,
//                           contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//                         ),
//                       ),
//                     ),
//                   const SizedBox(height: 24),

//                   // Lists
//                   Expanded(
//                     child: Consumer<ContactsProvider>(
//                       builder: (context, provider, child) {
//                         return SingleChildScrollView(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               if (provider.onlineContacts.isNotEmpty)
//                                 _buildSection('ONLINE', provider.onlineContacts, sectionBgColor, createButtonColor),
                              
//                               const SizedBox(height: 24),

//                               if (provider.offlineContacts.isNotEmpty)
//                                 _buildSection('OFFLINE', provider.offlineContacts, sectionBgColor, createButtonColor),
//                             ],
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSection(String title, List<Contact> contacts, Color bgColor, Color btnColor) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: bgColor,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title, style: const TextStyle(color: Color(0xFF4F506D), fontWeight: FontWeight.bold, fontSize: 14)),
//           const SizedBox(height: 12),
//           ListView.separated(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: contacts.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 8),
//             itemBuilder: (context, index) => _buildContactItem(contacts[index], btnColor),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildContactItem(Contact contact, Color btnColor) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
//       child: Row(
//         children: [
//           CircleAvatar(
//              radius: 20,
//              backgroundColor: const Color(0xFFB0B3D6),
//              // ВИПРАВЛЕНО: photoUrl замість avatarUrl
//              backgroundImage: (contact.photoUrl != null && contact.photoUrl!.isNotEmpty) 
//                  ? NetworkImage(contact.photoUrl!) 
//                  : null,
//              child: (contact.photoUrl == null || contact.photoUrl!.isEmpty) 
//                  ? const Icon(Icons.person, color: Colors.white) 
//                  : null,
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // ВИПРАВЛЕНО: username замість name
//                 Text(contact.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                 // ВИПРАВЛЕНО: Функція _getStatusText замість contact.statusText
//                 Text(_getStatusText(contact), style: const TextStyle(color: Colors.grey, fontSize: 13)),
//               ],
//             ),
//           ),
//           IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFF4F506D)), onPressed: () {}),
//           IconButton(icon: const Icon(Icons.settings_outlined, color: Color(0xFF4F506D)), onPressed: () {}),
//           const SizedBox(width: 12),
          
//           ElevatedButton(
//             onPressed: () {
//                 // Тут можна додати логіку додавання юзера в масив createGroupChat
//               },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: btnColor,
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//             ),
//             child: const Text('Add'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSelectableContactItem(Contact contact) {
//     final isSelected = _selectedUserIds.contains(contact.id);
//     final activeColor = const Color(0xFF5F63B4);

//     return InkWell(
//       onTap: () => _toggleSelection(contact.id), // Клік по всій картці вибирає
//       child: Container(
//         decoration: BoxDecoration(
//           color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.white, // Підсвітка
//           borderRadius: BorderRadius.circular(12),
//           border: isSelected ? Border.all(color: activeColor, width: 1) : null,
//         ),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
//         child: Row(
//           children: [
//             CircleAvatar(
//                radius: 20,
//                backgroundColor: const Color(0xFFB0B3D6),
//                backgroundImage: (contact.photoUrl != null && contact.photoUrl!.isNotEmpty) 
//                    ? NetworkImage(contact.photoUrl!) 
//                    : null,
//                child: (contact.photoUrl == null || contact.photoUrl!.isEmpty) 
//                    ? const Icon(Icons.person, color: Colors.white) 
//                    : null,
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(contact.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                   Text(_getStatusText(contact), style: const TextStyle(color: Colors.grey, fontSize: 13)),
//                 ],
//               ),
//             ),
            
//             // КНОПКА ВИБОРУ
//             ElevatedButton(
//               onPressed: () => _toggleSelection(contact.id),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: isSelected ? Colors.grey[300] : activeColor,
//                 foregroundColor: isSelected ? Colors.black54 : Colors.white,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                 elevation: 0,
//               ),
//               child: isSelected 
//                   ? const Row(children: [Icon(Icons.check, size: 16), SizedBox(width: 4), Text('Added')])
//                   : const Text('Add'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


















// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../../core/providers/contacts_provider.dart';
// import '../../../core/providers/chat_provider.dart';
// import '../models/contact_model.dart';

// class CreateChatView extends StatefulWidget {
//   final VoidCallback onChatCreated; // Щоб повернутися назад після створення

//   const CreateChatView({super.key, required this.onChatCreated});

//   @override
//   State<CreateChatView> createState() => _CreateChatViewState();
// }

// class _CreateChatViewState extends State<CreateChatView> {
//   final TextEditingController _chatNameController = TextEditingController();
//   final TextEditingController _searchController = TextEditingController();

//   @override
//   void dispose() {
//     _chatNameController.dispose();
//     _searchController.dispose();
//     super.dispose();
//   }

//   void _handleCreate() {
//     final name = _chatNameController.text.trim();
//     if (name.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please enter chat name')),
//       );
//       return;
//     }

//     // Створюємо чат через провайдер
//     context.read<ChatProvider>().createNewChat(name);
    
//     // Повертаємось назад
//     widget.onChatCreated();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final Color borderColor = const Color(0xFF4F506D).withOpacity(0.5);
//     final Color sectionBgColor = const Color(0xFFEBEBF2);
//     //const Color buttonColor = Color(0xFF4F506D);
//     const Color createButtonColor = Color(0xFF5F63B4); // Більш синій для кнопки CREATE

//     return Container(
//       margin: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: borderColor, width: 1),
//       ),
//       child: Column(
//         children: [
//           // --- HEADER (Create Chat & Input) ---
//           Padding(
//             padding: const EdgeInsets.all(24),
//             child: Row(
//               children: [
//                 const Text(
//                   'Create chat',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2B2B40)),
//                 ),
//                 const SizedBox(width: 30),
//                 Expanded(
//                   child: Container(
//                     height: 50,
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFFEBEBF2),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: TextField(
//                       controller: _chatNameController,
//                       decoration: const InputDecoration(
//                         hintText: 'Create chat name...',
//                         border: InputBorder.none,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 ElevatedButton(
//                   onPressed: _handleCreate,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: createButtonColor,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                   ),
//                   child: const Text('CREATE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
//                 ),
//                 const SizedBox(width: 12),
//                 IconButton(
//                   icon: const Icon(Icons.settings_outlined, size: 28),
//                   onPressed: () {},
//                   color: const Color(0xFF2B2B40),
//                 ),
//               ],
//             ),
//           ),
//           const Divider(height: 1, color: Color(0xFFE0E0E0)),

//           // --- BODY (Contacts List) ---
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Column(
//                 children: [
//                    // Search Bar
//                    Container(
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFEBEBF2),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: TextField(
//                         controller: _searchController,
//                         onChanged: (val) => context.read<ContactsProvider>().searchContacts(val),
//                         decoration: const InputDecoration(
//                           prefixIcon: Icon(Icons.search, color: Colors.grey),
//                           hintText: 'Find contacts...',
//                           border: InputBorder.none,
//                           contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//                         ),
//                       ),
//                     ),
//                   const SizedBox(height: 24),

//                   // Lists
//                   Expanded(
//                     child: Consumer<ContactsProvider>(
//                       builder: (context, provider, child) {
//                         return SingleChildScrollView(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               if (provider.onlineContacts.isNotEmpty)
//                                 _buildSection('ONLINE', provider.onlineContacts, sectionBgColor, createButtonColor),
                              
//                               const SizedBox(height: 24),

//                               if (provider.offlineContacts.isNotEmpty)
//                                 _buildSection('OFFLINE', provider.offlineContacts, sectionBgColor, createButtonColor),
//                             ],
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSection(String title, List<Contact> contacts, Color bgColor, Color btnColor) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: bgColor,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title, style: const TextStyle(color: Color(0xFF4F506D), fontWeight: FontWeight.bold, fontSize: 14)),
//           const SizedBox(height: 12),
//           ListView.separated(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: contacts.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 8),
//             itemBuilder: (context, index) => _buildContactItem(contacts[index], btnColor),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildContactItem(Contact contact, Color btnColor) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Менший падінг по вертикалі
//       child: Row(
//         children: [
//           CircleAvatar(
//              radius: 20,
//              backgroundColor: const Color(0xFFB0B3D6),
//              backgroundImage: contact.avatarUrl.isNotEmpty ? NetworkImage(contact.avatarUrl) : null,
//              child: contact.avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                 Text(contact.statusText, style: const TextStyle(color: Colors.grey, fontSize: 13)),
//               ],
//             ),
//           ),
//           IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFF4F506D)), onPressed: () {}),
//           IconButton(icon: const Icon(Icons.settings_outlined, color: Color(0xFF4F506D)), onPressed: () {}),
//           const SizedBox(width: 12),
          
//           // Кнопка ADD
//           ElevatedButton(
//             onPressed: () {
//               },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: btnColor,
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//             ),
//             child: const Text('Add'),
//           ),
//         ],
//       ),
//     );
//   }
// }