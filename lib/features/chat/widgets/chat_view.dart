// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../../core/providers/chat_provider.dart';
// //import 'package:chat_lab_kpp/features/chat/widgets/message_bubbles/message_model.dart';
// import 'message_bubbles/received_message_bubble.dart';
// import 'message_bubbles/sent_message_bubble.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago; // Не забудь додати timeago в pubspec.yaml
import 'package:cloud_firestore/cloud_firestore.dart'; // Для StreamBuilder
import '../../../core/providers/chat_provider.dart';
import 'message_bubbles/received_message_bubble.dart';
import 'message_bubbles/sent_message_bubble.dart';

class ChatView extends StatefulWidget {
  final String chatId;
  final VoidCallback? onOpenInfo;

  const ChatView({
    super.key, 
    required this.chatId, 
    this.onOpenInfo, 
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _editingMessageId; // ID повідомлення, яке редагуємо зараз
  bool get _isEditing => _editingMessageId != null;

  @override
  void initState() {
    super.initState();
    // ВАЖЛИВО: Ініціалізуємо підписку при вході на екран
    // Використовуємо addPostFrameCallback, щоб не було конфліктів під час build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().enterChat(widget.chatId);
    });
  }

  @override
  void didUpdateWidget(covariant ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Якщо ID чату змінився (ми клікнули на інший чат),
    // треба примусово завантажити повідомлення нового чату.
    if (oldWidget.chatId != widget.chatId) {
      // Очищаємо контролер, щоб текст старого чату не залишився в полі вводу
      _messageController.clear(); 
      // Завантажуємо новий чат
      context.read<ChatProvider>().enterChat(widget.chatId);
    }
  }

  @override
  void dispose() {
    // ВАЖЛИВО: Відписуємось при виході, щоб не їсти пам'ять
    // Оскільки dispose працює коли віджет знищується, context ще доступний, 
    // але треба бути обережним з listen: false
    _messageController.dispose();
    _scrollController.dispose();
    
    super.dispose();
  }
  
  Widget _buildUserStatus(String? otherUserId) {
    if (otherUserId == null) return const SizedBox();

    // Слухаємо документ конкретного юзера в реальному часі
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('...', style: TextStyle(color: Colors.grey, fontSize: 12));

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox();

        final bool isOnline = data['isOnline'] ?? false;
        final Timestamp? lastSeen = data['lastSeen'];

        if (isOnline) {
          return const Text(
            'Online', 
            style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w500)
          );
        } else {
          String statusText = 'Offline';
          if (lastSeen != null) {
            statusText = 'Last seen ${timeago.format(lastSeen.toDate())}';
          }
          return Text(
            statusText, 
            style: const TextStyle(fontSize: 13, color: Colors.grey)
          );
        }
      },
    );
  }

  // void _handleSend() {
  //   final text = _messageController.text;
  //   if (text.isEmpty) return;
  //   context.read<ChatProvider>().sendMessage(widget.chatId, text);
  //   _messageController.clear();
  // }
  void _handleSend() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_isEditing) {
      context.read<ChatProvider>().editMessage(widget.chatId, _editingMessageId!, text);
            setState(() {
        _editingMessageId = null;
      });
    } else {
      context.read<ChatProvider>().sendMessage(widget.chatId, text);
    }    
    _messageController.clear();
  }

  void _startEditing(String id, String currentText) {
    setState(() {
      _editingMessageId = id;
      _messageController.text = currentText;
    });
    // Ставимо фокус на поле вводу (щоб курсор з'явився)
    // (Потрібен FocusNode, якщо хочеш ідеально, але поки так ок)
  }

  void _deleteMessage(String id) {
    // Можна додати діалог підтвердження
    context.read<ChatProvider>().deleteMessage(widget.chatId, id);
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Слухаємо зміни (watch)
    final provider = context.watch<ChatProvider>();
    final chat = provider.getChatById(widget.chatId);
    final myUid = provider.currentUserId;

    const Color primaryDarkColor = Color(0xFF4F506D);
    const Color iconColor = Color(0xFF4F506D);
    const Color borderColor = Color(0xFFB0B3D6);

    if (chat == null) {
      return const Center(child: CircularProgressIndicator());
    }

    String? otherUserId;
    if (!chat.isGroup && chat.participantIds.length == 2) {
        otherUserId = chat.participantIds.firstWhere((id) => id != myUid, orElse: () => '');
    }

    return Column(
      children: [
        // --- 1. HEADER ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))), 
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFB0B3D6),
                backgroundImage: chat.displayImage != null ? NetworkImage(chat.displayImage!) : null,
                child: chat.displayImage == null ? const Icon(Icons.person, color: Colors.white) : null,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.displayName, 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryDarkColor)
                  ),
                  if (chat.isGroup)
                     Text('${chat.participantIds.length} members', style: const TextStyle(color: Colors.grey, fontSize: 13))
                  else
                     _buildUserStatus(otherUserId),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 26),
                color: iconColor,
                onPressed: widget.onOpenInfo, 
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 26),
                color: iconColor,
                onPressed: () {},
              ),
            ],
          ),
        ),

        // --- 2. MESSAGE LIST (ТЕПЕР ЧЕРЕЗ ПРОВАЙДЕР) ---
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Builder(
              builder: (context) {
                // А) Завантаження
                if (provider.isLoadingMessages) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                // Б) Список повідомлень з провайдера
                final messages = provider.currentMessages;

                // В) Пусто
                if (messages.isEmpty) {
                   return const Center(child: Text("No messages yet", style: TextStyle(color: Colors.grey)));
                }

                // Г) Відображення
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Нові знизу
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    if (message.isSentByMe) {
                      return SentMessageBubble(
                        message: message,
                        onEdit: () => _startEditing(message.id, message.text),
                        onDelete: () => _deleteMessage(message.id),
                      );
                      } else {
                      return ReceivedMessageBubble(message: message);
                    }
                  },
                );
              },
            ),
          ),
        ),

        // --- 3. INPUT AREA ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          color: Colors.white,
          child: Column( 
            mainAxisSize: MainAxisSize.min, // Важливо: займаємо мінімум місця по вертикалі
            children: [
              
              if (_isEditing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: const Border(left: BorderSide(color: Color(0xFF4F506D), width: 4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 16, color: Color(0xFF4F506D)),
                      const SizedBox(width: 8),
                      const Expanded(child: Text("Editing message...", style: TextStyle(color: Colors.black54))),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _cancelEditing, // Кнопка "Х" для скасування
                      )
                    ],
                  ),
                ),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1), 
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (_) => _handleSend(),
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.black38),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _handleSend,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          // ЗМІНА КОЛЬОРУ: Помаранчевий при редагуванні, синій звичайно
                          color: _isEditing ? Colors.orange : const Color(0xFF4F506D),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        // ЗМІНА ІКОНКИ: Галочка при редагуванні, Літачок звичайно
                        child: Icon(
                          _isEditing ? Icons.check : Icons.send, 
                          color: Colors.white, 
                          size: 20
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.attach_file), // Іконка скріпки
                      color: const Color(0xFF4F506D),
                      tooltip: "Send Photo or Video",
                      onPressed: () {
                        // Викликаємо новий метод
                        context.read<ChatProvider>().sendMediaMessage(widget.chatId);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf),
                      onPressed: () {
                        // Викликаємо метод провайдера
                        context.read<ChatProvider>().sendPdfMessage(widget.chatId);
                      },
                    ),
                    // IconButton(
                    //   icon: const Icon(Icons.check_box_outlined),
                    //   color: const Color(0xFF4F506D),
                    //   onPressed: () {},
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}





















// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../../core/providers/chat_provider.dart';
// import 'message_bubbles/received_message_bubble.dart';
// import 'message_bubbles/sent_message_bubble.dart';

// class ChatView extends StatefulWidget {
//   final int chatId;
//   // Callback для відкриття меню інформації
//   final VoidCallback? onOpenInfo;

//   const ChatView({
//     super.key, 
//     required this.chatId, 
//     this.onOpenInfo, 
//   });

//   @override
//   State<ChatView> createState() => _ChatViewState();
// }

// class _ChatViewState extends State<ChatView> {
//   final TextEditingController _messageController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();

//   @override
//   void dispose() {
//     _messageController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   void _handleSend() {
//     final text = _messageController.text;
//     if (text.isEmpty) return;

//     context.read<ChatProvider>().sendMessage(widget.chatId, text);
//     _messageController.clear();
    
//     Future.delayed(const Duration(milliseconds: 100), () {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final provider = context.watch<ChatProvider>();
//     final chat = provider.getChatById(widget.chatId);

//     const Color primaryDarkColor = Color(0xFF4F506D);
//     const Color iconColor = Color(0xFF4F506D);
//     const Color borderColor = Color(0xFFB0B3D6);

//     return Column(
//       children: [
//         // --- 1. HEADER ---
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
//           decoration: const BoxDecoration(
//             color: Colors.white,
//             border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))), 
//           ),
//           child: Row(
//             children: [
//               CircleAvatar(
//                 radius: 22,
//                 backgroundColor: const Color(0xFFB0B3D6),
//                 child: const Icon(Icons.person, color: Colors.white),
//               ),
//               const SizedBox(width: 16),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     chat.name, 
//                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryDarkColor)
//                   ),
//                   const Text(
//                     'Online', 
//                     style: TextStyle(fontSize: 13, color: Colors.grey)
//                   ),
//                 ],
//               ),
              
//               const Spacer(),
              
              
//               IconButton(
//                 icon: const Icon(Icons.settings_outlined, size: 26),
//                 color: iconColor,
//                 onPressed: widget.onOpenInfo, 
//               ),
//               IconButton(
//                 icon: const Icon(Icons.info_outline, size: 26),
//                 color: iconColor,
//                 onPressed: () {},
//               ),
//             ],
//           ),
//         ),

//         // --- 2. MESSAGE LIST ---
//         Expanded(
//           child: Container(
//             color: Colors.white,
//             padding: const EdgeInsets.symmetric(horizontal: 24),
//             child: ListView.builder(
//               controller: _scrollController,
//               itemCount: chat.messages.length,
//               padding: const EdgeInsets.symmetric(vertical: 20),
//               itemBuilder: (context, index) {
//                 final message = chat.messages[index];
//                 if (message.isSentByMe) {
//                   return SentMessageBubble(message: message);
//                 } else {
//                   return ReceivedMessageBubble(message: message);
//                 }
//               },
//             ),
//           ),
//         ),

//         // --- 3. INPUT AREA ---
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
//           color: Colors.white,
//           child: Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: borderColor, width: 1), 
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     onSubmitted: (_) => _handleSend(),
//                     style: const TextStyle(color: Colors.black87),
//                     decoration: const InputDecoration(
//                       hintText: 'Type a message...',
//                       hintStyle: TextStyle(color: Colors.black38),
//                       border: InputBorder.none,
//                       contentPadding: EdgeInsets.symmetric(horizontal: 16),
//                     ),
//                   ),
//                 ),
//                 InkWell(
//                   onTap: _handleSend,
//                   child: Container(
//                     padding: const EdgeInsets.all(10),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF4F506D),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Icon(Icons.send, color: Colors.white, size: 20),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 IconButton(
//                   icon: const Icon(Icons.attach_file),
//                   color: const Color(0xFF4F506D),
//                   onPressed: () {},
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.check_box_outlined),
//                   color: const Color(0xFF4F506D),
//                   onPressed: () {},
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
