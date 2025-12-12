import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/contacts_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../chat/models/contact_model.dart';

class AddMembersPage extends StatefulWidget {
  final String chatId;

  const AddMembersPage({super.key, required this.chatId});

  @override
  State<AddMembersPage> createState() => _AddMembersPageState();
}

class _AddMembersPageState extends State<AddMembersPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Ініціалізуємо контакти, якщо вони ще не завантажені
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactsProvider>().init(); // або loadContacts, якщо init немає
    });
  }

  @override
  Widget build(BuildContext context) {
    // Отримуємо список тих, хто ВЖЕ в чаті, щоб заблокувати їм кнопку "Add"
    final chatProvider = context.watch<ChatProvider>();
    final existingMemberIds = chatProvider.chatMembers.map((u) => u.uid).toSet();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Add Members", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // ПОШУК (Локальний по контактах)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEBEBF2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => context.read<ContactsProvider>().searchContacts(val),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  hintText: 'Search within contacts...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // СПИСОК КОНТАКТІВ
          Expanded(
            child: Consumer<ContactsProvider>(
              builder: (context, contactsProvider, child) {
                // Об'єднуємо онлайн і офлайн для зручності вибору
                final allContacts = [
                  ...contactsProvider.onlineContacts,
                  ...contactsProvider.offlineContacts
                ];

                if (allContacts.isEmpty) {
                  return const Center(child: Text("No contacts found."));
                }

                return ListView.builder(
                  itemCount: allContacts.length,
                  itemBuilder: (context, index) {
                    final contact = allContacts[index];
                    final isAlreadyInChat = existingMemberIds.contains(contact.id);

                    return _buildContactItem(contact, isAlreadyInChat);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(Contact contact, bool isAlreadyInChat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
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
                Text(contact.isOnline ? "Online" : "Offline", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          
          // КНОПКА ДОДАВАННЯ
          isAlreadyInChat
              ? const Text("Added", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
              : ElevatedButton(
                  onPressed: () async {
                    await context.read<ChatProvider>().addMemberById(widget.chatId, contact.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("${contact.username} added!"), duration: const Duration(seconds: 1)),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5F63B4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text("Add"),
                ),
        ],
      ),
    );
  }
}