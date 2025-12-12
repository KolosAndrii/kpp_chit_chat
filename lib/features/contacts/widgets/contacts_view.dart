import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/providers/contacts_provider.dart';
import '../../chat/models/contact_model.dart';
import '../../../core/providers/chat_provider.dart';

class ContactsView extends StatefulWidget {
  final Function(Contact)? onContactTap;
  final Function(String chatId)? onChatStarted;

  const ContactsView({
    super.key, 
    this.onContactTap, 
    this.onChatStarted
  });

  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text;
      if (query.isEmpty) {
        context.read<ContactsProvider>().clearSearch();
        context.read<ContactsProvider>().searchContacts(""); 
      } else {
        context.read<ContactsProvider>().searchContacts(query);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    const Color buttonColor = Color(0xFF4F506D); 

    final provider = context.watch<ContactsProvider>();

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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Contacts',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2B2B40)),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 28),
                  onPressed: () {},
                  color: const Color(0xFF2B2B40),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),

          // --- CONTENT ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // SEARCH BAR
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBEBF2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search, color: Colors.grey),
                              hintText: 'Find new contacts',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          provider.findUserGlobal(_searchController.text.trim());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: const Text('FIND', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  
                  if (provider.searchError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Text(provider.searchError!, style: TextStyle(color: Colors.orange.shade800), textAlign: TextAlign.center),
                    ),

                  // FOUND USER CARD
                  if (provider.foundUser != null)
                    _buildFoundUserCard(provider),

                  // CONTACT LISTS
                  Expanded(
                    child: Consumer<ContactsProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (provider.onlineContacts.isEmpty && provider.offlineContacts.isEmpty) {
                           return const Center(child: Text("No contacts found", style: TextStyle(color: Colors.grey)));
                        }
                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (provider.onlineContacts.isNotEmpty)
                                _buildSection(title: 'ONLINE', contacts: provider.onlineContacts, bgColor: sectionBgColor),
                              const SizedBox(height: 24),
                              if (provider.offlineContacts.isNotEmpty)
                                _buildSection(title: 'OFFLINE', contacts: provider.offlineContacts, bgColor: sectionBgColor),
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

  Widget _buildFoundUserCard(ContactsProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5F63B4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Found User:", style: TextStyle(color: Color(0xFF5F63B4), fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSafeAvatar(provider.foundUser!.photoUrl, 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(provider.foundUser!.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(provider.foundUser!.login, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => provider.addFoundUserToContacts(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5F63B4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("ADD"),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Contact> contacts, required Color bgColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF4F506D), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: contacts.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _buildContactCard(contacts[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(Contact contact) {
    return InkWell(
      onTap: () {
        if (widget.onContactTap != null) widget.onContactTap!(contact);
      },
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildSafeAvatar(contact.photoUrl, 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2B2B40))),
                  Text(_getStatusText(contact), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.message_outlined, color: Color(0xFF5F63B4)),
              tooltip: "Write message",
              onPressed: () async {
                final chatId = await context.read<ChatProvider>().startChatWithUser(contact.id);
                if (chatId != null && widget.onChatStarted != null) {
                  widget.onChatStarted!(chatId); 
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFF4F506D)),
              onPressed: () => context.read<ContactsProvider>().deleteContact(contact.id),
            ),
          ],
        ),
      ),
    );
  }

  // --- ОКРЕМИЙ МЕТОД ДЛЯ АВАТАРКИ (Щоб не було помилок) ---
  Widget _buildSafeAvatar(String? photoUrl, double radius) {
    ImageProvider? imageProvider;
    
    if (photoUrl != null && photoUrl.isNotEmpty) {
      imageProvider = NetworkImage(photoUrl);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFB0B3D6),
      // Якщо провайдера немає (null), ставимо null у backgroundImage
      backgroundImage: imageProvider,
      // Якщо провайдера немає, ставимо null у onBackgroundImageError (це виправить Assertion failed)
      onBackgroundImageError: imageProvider != null 
          ? (exception, stackTrace) { print("Image load error"); } 
          : null,
      child: imageProvider == null 
          ? const Icon(Icons.person, color: Colors.white) 
          : null,
    );
  }
}










// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:timeago/timeago.dart' as timeago; // Для форматування часу
// import '../../../core/providers/contacts_provider.dart';
// import '../../chat/models/contact_model.dart'; // Перевір шлях до моделі
// import '../../../core/providers/chat_provider.dart';

// class ContactsView extends StatefulWidget {
//   final Function(Contact)? onContactTap;
//   final Function(String chatId)? onChatStarted;

//   const ContactsView({
//     super.key, 
//     this.onContactTap, 
//     this.onChatStarted
//   });
//   //const ContactsView({super.key, this.onContactTap});

//   @override
//   State<ContactsView> createState() => _ContactsViewState();
// }

// class _ContactsViewState extends State<ContactsView> {
//   final TextEditingController _searchController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     // Слухаємо зміни тексту:
//     // Якщо поле пусте -> показуємо локальні контакти.
//     // Якщо пишемо -> можна викликати локальний фільтр (searchContacts)
//     _searchController.addListener(() {
//       final query = _searchController.text;
//       if (query.isEmpty) {
//         context.read<ContactsProvider>().clearSearch();
//         context.read<ContactsProvider>().searchContacts(""); // Скидаємо фільтр
//       } else {
//         // Локальний пошук серед вже доданих
//         context.read<ContactsProvider>().searchContacts(query);
//       }
//     });
//     // _searchController.addListener(() {
//     //   context.read<ContactsProvider>().searchContacts(_searchController.text);
//     // });
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   // Допоміжна функція для тексту статусу
//   String _getStatusText(Contact contact) {
//     if (contact.isOnline) return 'Online';
//     if (contact.lastSeen == null) return 'Offline';
//     return timeago.format(contact.lastSeen!); // "15 min ago"
//   }

//   @override
//   Widget build(BuildContext context) {
//     final Color borderColor = const Color(0xFF4F506D).withOpacity(0.5);
//     final Color sectionBgColor = const Color(0xFFEBEBF2); 
//     const Color buttonColor = Color(0xFF4F506D); 

//     final provider = context.watch<ContactsProvider>();

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
//             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text(
//                   'Your Contacts',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2B2B40)),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.settings_outlined, size: 28),
//                   onPressed: () {},
//                   color: const Color(0xFF2B2B40),
//                 ),
//               ],
//             ),
//           ),
//           const Divider(height: 1, color: Color(0xFFE0E0E0)),

//           // --- SEARCH & CONTENT ---
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Column(
//                 children: [
//                   // Рядок пошуку і кнопка FIND
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFEBEBF2),
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: TextField(
//                             controller: _searchController,
//                             decoration: const InputDecoration(
//                               prefixIcon: Icon(Icons.search, color: Colors.grey),
//                               hintText: 'Find new contacts',
//                               border: InputBorder.none,
//                               contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       ElevatedButton(
//                         onPressed: () {
//                           FocusScope.of(context).unfocus(); // Ховаємо клавіатуру
//                           provider.findUserGlobal(_searchController.text.trim());
//                           //context.read<ContactsProvider>().searchContacts(_searchController.text);
//                         },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: buttonColor,
//                           foregroundColor: Colors.white,
//                           padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                           elevation: 0,
//                         ),
//                         child: const Text('FIND', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 30),
                  
//                   if (provider.searchError != null)
//                     Container(
//                       padding: const EdgeInsets.all(12),
//                       width: double.infinity,
//                       decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
//                       child: Text(provider.searchError!, style: TextStyle(color: Colors.orange.shade800), textAlign: TextAlign.center),
//                     ),

//                   // КАРТКА ЗНАЙДЕНОГО ЮЗЕРА
//                   if (provider.foundUser != null)
//                     Container(
//                       margin: const EdgeInsets.only(bottom: 24),
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFF0F0F8),
//                         borderRadius: BorderRadius.circular(16),
//                         border: Border.all(color: const Color(0xFF5F63B4), width: 1.5), // Акцентна рамка
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text("Found User:", style: TextStyle(color: Color(0xFF5F63B4), fontWeight: FontWeight.bold)),
//                           const SizedBox(height: 10),
//                           Row(
//                             children: [
//                               CircleAvatar(
//                                 radius: 24,
//                                 backgroundColor: const Color(0xFFB0B3D6),
//                                 backgroundImage: (provider.foundUser!.photoUrl != null && provider.foundUser!.photoUrl!.isNotEmpty)
//                                     ? NetworkImage(provider.foundUser!.photoUrl!)
//                                     : null,
//                                 child: (provider.foundUser!.photoUrl == null || provider.foundUser!.photoUrl!.isEmpty)
//                                     ? const Icon(Icons.person, color: Colors.white) : null,
//                               ),
//                               const SizedBox(width: 16),
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(provider.foundUser!.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                                     Text(provider.foundUser!.login, style: const TextStyle(color: Colors.grey)),
//                                   ],
//                                 ),
//                               ),
//                               ElevatedButton(
//                                 onPressed: () {
//                                   // ДОДАВАННЯ В КОНТАКТИ
//                                   provider.addFoundUserToContacts();
//                                 },
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: const Color(0xFF5F63B4),
//                                   foregroundColor: Colors.white,
//                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                                 ),
//                                 child: const Text("ADD"),
//                               )
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),

//                   // Списки контактів
//                   Expanded(
//                     child: Consumer<ContactsProvider>(
//                       builder: (context, provider, child) {
//                         if (provider.isLoading) {
//                           return const Center(child: CircularProgressIndicator());
//                         }

//                         // Якщо контактів немає взагалі
//                         if (provider.onlineContacts.isEmpty && provider.offlineContacts.isEmpty) {
//                            return const Center(child: Text("No contacts found", style: TextStyle(color: Colors.grey)));
//                         }

//                         return SingleChildScrollView(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               // --- ONLINE SECTION ---
//                               if (provider.onlineContacts.isNotEmpty)
//                                 _buildSection(
//                                   title: 'ONLINE',
//                                   contacts: provider.onlineContacts,
//                                   bgColor: sectionBgColor,
//                                 ),
                              
//                               const SizedBox(height: 24),

//                               // --- OFFLINE SECTION ---
//                               if (provider.offlineContacts.isNotEmpty)
//                                 _buildSection(
//                                   title: 'OFFLINE',
//                                   contacts: provider.offlineContacts,
//                                   bgColor: sectionBgColor,
//                                 ),
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

//   Widget _buildSection({
//     required String title,
//     required List<Contact> contacts,
//     required Color bgColor,
//   }) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: bgColor,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               color: Color(0xFF4F506D),
//               fontWeight: FontWeight.bold,
//               fontSize: 14,
//               letterSpacing: 0.5,
//             ),
//           ),
//           const SizedBox(height: 12),
//           ListView.separated(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: contacts.length,
//             separatorBuilder: (ctx, i) => const SizedBox(height: 8),
//             itemBuilder: (context, index) {
//               final contact = contacts[index];
//               return _buildContactCard(contact);
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildContactCard(Contact contact) {
//     return InkWell(
//       onTap: () {
//         if (widget.onContactTap != null) {
//           widget.onContactTap!(contact);
//         }
//       },
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//         ),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         child: Row(
//           children: [
//             CircleAvatar(
//               radius: 20,
//               backgroundColor: const Color(0xFFB0B3D6),
//               // 1. ЗМІНЕНО: photoUrl замість avatarUrl
//               backgroundImage: (contact.photoUrl != null && contact.photoUrl!.isNotEmpty) 
//                   ? NetworkImage(contact.photoUrl!) 
//                   : null,
//               child: (contact.photoUrl == null || contact.photoUrl!.isEmpty) 
//                   ? const Icon(Icons.person, color: Colors.white) 
//                   : null,
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // 2. ЗМІНЕНО: username замість name
//                   Text(
//                     contact.username,
//                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2B2B40)),
//                   ),
//                   // 3. ЗМІНЕНО: _getStatusText замість statusText
//                   Text(
//                     _getStatusText(contact),
//                     style: const TextStyle(color: Colors.grey, fontSize: 13),
//                   ),
//                 ],
//               ),
//             ),
            
//             IconButton(
//               icon: const Icon(Icons.message_outlined, color: Color(0xFF5F63B4)),
//               tooltip: "Write message",
//               onPressed: () async {
//                 // Створюємо або відкриваємо чат
//                 final chatId = await context.read<ChatProvider>().startChatWithUser(contact.id);
                
//                 // Якщо чат успішно створено/знайдено і передано колбек
//                 if (chatId != null && widget.onChatStarted != null) {
//                   widget.onChatStarted!(chatId); // Передаємо ID чату в MainPage
//                 } else if (chatId != null) {
//                    ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text("Chat created! Please go to Chats tab.")),
//                   );
//                 }
//               },
//             ),

//             // Кнопка видалення
//             IconButton(
//               icon: const Icon(Icons.delete_outline, color: Color(0xFF4F506D)),
//               onPressed: () {
//                  // Тут викликаємо видалення з провайдера
//                  context.read<ContactsProvider>().deleteContact(contact.id);
//               },
//             ),
//             IconButton(
//               icon: const Icon(Icons.settings_outlined, color: Color(0xFF4F506D)),
//               onPressed: () {},
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
// import '../../chat/models/contact_model.dart';

// class ContactsView extends StatefulWidget {
//   final Function(Contact)? onContactTap;
  
//   const ContactsView({super.key, this.onContactTap});
//   //const ContactsView({super.key});

//   @override
//   State<ContactsView> createState() => _ContactsViewState();
// }

// class _ContactsViewState extends State<ContactsView> {
//   final TextEditingController _searchController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _searchController.addListener(() {
//       context.read<ContactsProvider>().searchContacts(_searchController.text);
//     });
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Основні кольори з дизайну
//     final Color borderColor = const Color(0xFF4F506D).withOpacity(0.5);
//     final Color sectionBgColor = const Color(0xFFEBEBF2); // Світло-фіолетовий фон секцій
//     const Color buttonColor = Color(0xFF4F506D); // Темно-синій/фіолетовий

//     return Container(
//       // 1. Зовнішня рамка (Container border)
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
//             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text(
//                   'Your Contacts',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2B2B40)),
//                 ),
//                 // Шестерня справа зверху
//                 IconButton(
//                   icon: const Icon(Icons.settings_outlined, size: 28), // Шестикутна іконка
//                   onPressed: () {},
//                   color: const Color(0xFF2B2B40),
//                 ),
//               ],
//             ),
//           ),
//           const Divider(height: 1, color: Color(0xFFE0E0E0)),

//           // --- SEARCH & CONTENT ---
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Column(
//                 children: [
//                   // Рядок пошуку і кнопка FIND
//                   Row(
//                     children: [
//                       Expanded(
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFEBEBF2), // Сірий фон інпуту
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: TextField(
//                             controller: _searchController,
//                             decoration: const InputDecoration(
//                               prefixIcon: Icon(Icons.search, color: Colors.grey),
//                               hintText: 'Find new contacts',
//                               border: InputBorder.none,
//                               contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       ElevatedButton(
//                         onPressed: () {
//                           // Логіка пошуку вже працює через listener, але кнопка з дизайну
//                           context.read<ContactsProvider>().searchContacts(_searchController.text);
//                         },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: buttonColor,
//                           foregroundColor: Colors.white,
//                           padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                           elevation: 0,
//                         ),
//                         child: const Text('FIND', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 30),

//                   // Списки контактів
//                   Expanded(
//                     child: Consumer<ContactsProvider>(
//                       builder: (context, provider, child) {
//                         if (provider.isLoading) {
//                           return const Center(child: CircularProgressIndicator());
//                         }

//                         return SingleChildScrollView(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               // --- ONLINE SECTION ---
//                               if (provider.onlineContacts.isNotEmpty)
//                                 _buildSection(
//                                   title: 'ONLINE',
//                                   contacts: provider.onlineContacts,
//                                   bgColor: sectionBgColor,
//                                 ),
                              
//                               const SizedBox(height: 24),

//                               // --- OFFLINE SECTION ---
//                               if (provider.offlineContacts.isNotEmpty)
//                                 _buildSection(
//                                   title: 'OFFLINE',
//                                   contacts: provider.offlineContacts,
//                                   bgColor: sectionBgColor,
//                                 ),
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

//   // Метод для побудови секції (сірий блок з картками)
//   Widget _buildSection({
//     required String title,
//     required List<Contact> contacts,
//     required Color bgColor,
//   }) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: bgColor,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               color: Color(0xFF4F506D),
//               fontWeight: FontWeight.bold,
//               fontSize: 14,
//               letterSpacing: 0.5,
//             ),
//           ),
//           const SizedBox(height: 12),
//           ListView.separated(
//             shrinkWrap: true, // Важливо всередині ScrollView
//             physics: const NeverScrollableScrollPhysics(), // Скролить батьківський віджет
//             itemCount: contacts.length,
//             separatorBuilder: (ctx, i) => const SizedBox(height: 8),
//             itemBuilder: (context, index) {
//               final contact = contacts[index];
//               return _buildContactCard(contact);
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   // Картка окремого контакту
//   Widget _buildContactCard(Contact contact) {
//     return  InkWell(
//       onTap: () {
//         if (widget.onContactTap != null) {
//           widget.onContactTap!(contact);
//         }
//       },
//       child: Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 20,
//             backgroundColor: const Color(0xFFB0B3D6), // Заглушка, якщо немає картинки
//             backgroundImage: contact.avatarUrl.isNotEmpty ? NetworkImage(contact.avatarUrl) : null,
//             child: contact.avatarUrl.isEmpty 
//                 ? const Icon(Icons.person, color: Colors.white) 
//                 : null,
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   contact.name,
//                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2B2B40)),
//                 ),
//                 Text(
//                   contact.statusText,
//                   style: const TextStyle(color: Colors.grey, fontSize: 13),
//                 ),
//               ],
//             ),
//           ),
//           // Іконки дій (Видалити, Налаштування)
//           IconButton(
//             icon: const Icon(Icons.delete_outline, color: Color(0xFF4F506D)),
//             onPressed: () {
//                context.read<ContactsProvider>().deleteContact(contact.id);
//             },
//           ),
//           IconButton(
//             icon: const Icon(Icons.settings_outlined, color: Color(0xFF4F506D)), // Шестикутник
//             onPressed: () {},
//           ),
//         ],
//       ),
//     ),
//   );
//   }
// }