import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Для відкриття посилань (відео)
import 'message_model.dart'; 

class SentMessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const SentMessageBubble({
    super.key, 
    required this.message,
    this.onEdit,
    this.onDelete,
  });

  // Метод для показу меню
  void _showContextMenu(BuildContext context, Offset globalPosition) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40), 
        Offset.zero & overlay.size,
      ),
      items: [
        // Редагувати можна тільки текст (картинку/відео не редагують, тільки видаляють)
        if (message.type == MessageType.text)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [Icon(Icons.edit, size: 20, color: Colors.blue), SizedBox(width: 8), Text('Edit')],
            ),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete')],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit' && onEdit != null) {
        onEdit!();
      } else if (value == 'delete' && onDelete != null) {
        onDelete!();
      }
    });
  }

  // Функція для відкриття відео в браузері
  // Future<void> _launchVideo(String url) async {
  //   final Uri uri = Uri.parse(url);
  //   if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
  //     print('Could not launch $url');
  //   }
  // }
  Future<void> _launchVideo(String url) async {
    final Uri uri = Uri.parse(url);
    
    // Спочатку перевіряємо, чи можемо відкрити
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri, 
        // Змінюємо режим на platformDefault (це відкриє нову вкладку в браузері)
        mode: LaunchMode.platformDefault, 
      );
    } else {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) => _showContextMenu(context, details.globalPosition),
      
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          // Якщо медіа - менші відступи, якщо текст - стандартні
          padding: message.type == MessageType.text 
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
              : const EdgeInsets.all(4),
          
          decoration: BoxDecoration(
            color: const Color(0xFF5F63B4),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              
              // 1. ТЕКСТОВЕ ПОВІДОМЛЕННЯ
              if (message.type == MessageType.text)
                Text(
                  message.text,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                )
              
              // 2. КАРТИНКА
              else if (message.type == MessageType.image && message.fileUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    message.fileUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 200, height: 200,
                        color: Colors.black12,
                        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => 
                        const SizedBox(
                          width: 100, height: 100,
                          child: Icon(Icons.broken_image, color: Colors.white, size: 40)
                        ),
                  ),
                )

              // 3. ВІДЕО
              else if (message.type == MessageType.video && message.fileUrl != null)
                InkWell(
                  onTap: () => _launchVideo(message.fileUrl!),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                        const SizedBox(width: 8),
                        const Text("Play Video", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )

                else if (message.type == MessageType.file && message.fileUrl != null)
                InkWell(
                  onTap: () => _launchVideo(message.fileUrl!), // Використовуємо твою функцію відкриття посилань
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white, // Білий фон для файлу
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30), // Червона іконка PDF
                        const SizedBox(width: 10),
                        Expanded( // Щоб довга назва не ламала верстку
                          child: Text(
                            message.text, // Тут буде назва файлу (ми зберегли її в репозиторії)
                            style: const TextStyle(
                              color: Colors.black87, 
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline, // Підкреслення, як посилання
                            ),
                            overflow: TextOverflow.ellipsis, // Три крапки, якщо не влазить
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 4),
              
              // ЧАС
              Text(
                message.timeString, 
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
















// import 'package:flutter/material.dart';
// import 'message_model.dart'; //

// class SentMessageBubble extends StatelessWidget {
//   final Message message;
//   // Callback-и для дій
//   final VoidCallback? onEdit;
//   final VoidCallback? onDelete;

//   const SentMessageBubble({
//     super.key, 
//     required this.message,
//     this.onEdit,
//     this.onDelete,
//   });

//   // Метод для показу меню
//   void _showContextMenu(BuildContext context, Offset globalPosition) {
//     final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
//     showMenu(
//       context: context,
//       position: RelativeRect.fromRect(
//         globalPosition & const Size(40, 40), // Прямокутник, де був клік
//         Offset.zero & overlay.size,
//       ),
//       items: [
//         const PopupMenuItem(
//           value: 'edit',
//           child: Row(
//             children: [Icon(Icons.edit, size: 20, color: Colors.blue), SizedBox(width: 8), Text('Edit')],
//           ),
//         ),
//         const PopupMenuItem(
//           value: 'delete',
//           child: Row(
//             children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete')],
//           ),
//         ),
//       ],
//     ).then((value) {
//       if (value == 'edit' && onEdit != null) {
//         onEdit!();
//       } else if (value == 'delete' && onDelete != null) {
//         onDelete!();
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Використовуємо GestureDetector для обробки правого кліку
//     return GestureDetector(
//       // Правий клік миші (Web/Desktop)
//       onSecondaryTapDown: (details) {
//         _showContextMenu(context, details.globalPosition);
//       },
//       // Довге натискання (Mobile)
//       onLongPressStart: (details) {
//         _showContextMenu(context, details.globalPosition);
//       },
//       child: Align(
//         alignment: Alignment.centerRight,
//         child: Container(
//           margin: const EdgeInsets.symmetric(vertical: 4),
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           decoration: const BoxDecoration(
//             color: Color(0xFF5F63B4),
//             borderRadius: BorderRadius.only(
//               topLeft: Radius.circular(16),
//               topRight: Radius.circular(16),
//               bottomLeft: Radius.circular(16),
//               bottomRight: Radius.circular(4),
//             ),
//           ),
//           constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
//             child: Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               // --- ВІДОБРАЖЕННЯ КОНТЕНТУ ---
//               if (message.type == MessageType.text)
//                 Text(
//                   message.text,
//                   style: const TextStyle(color: Colors.white, fontSize: 16),
//                 )
//               else if (message.type == MessageType.image && message.fileUrl != null)
//                 // ВІДЖЕТ КАРТИНКИ
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(12),
//                   child: Image.network(
//                     message.fileUrl!,
//                     fit: BoxFit.cover,
//                     // Заглушка, поки вантажиться
//                     loadingBuilder: (context, child, loadingProgress) {
//                       if (loadingProgress == null) return child;
//                       return Container(
//                         width: 200, height: 200,
//                         color: Colors.black12,
//                         child: const Center(child: CircularProgressIndicator(color: Colors.white)),
//                       );
//                     },
//                     // Обробка помилок
//                     errorBuilder: (context, error, stackTrace) => 
//                         const Icon(Icons.broken_image, color: Colors.white, size: 50),
//                   ),
//                 ),

//               const SizedBox(height: 4),
//               // Час
//               Text(
//                 message.timeString, // Переконайся, що у тебе є цей геттер або форматуй тут
//                 style: const TextStyle(color: Colors.white70, fontSize: 10),
//               ),
//             ],
//           ),
//           // child: Column(
//           //   crossAxisAlignment: CrossAxisAlignment.end,
//           //   children: [
//           //     Text(
//           //       message.text,
//           //       style: const TextStyle(color: Colors.white, fontSize: 16),
//           //     ),
//           //     const SizedBox(height: 4),
//           //     Row(
//           //       mainAxisSize: MainAxisSize.min,
//           //       children: [
//           //         // Якщо повідомлення редаговане - показуємо помітку
//           //         // (Для цього треба додати поле isEdited в MessageModel, див. нижче)
//           //         /* if (message.isEdited) 
//           //           const Padding(
//           //             padding: EdgeInsets.only(right: 4.0),
//           //             child: Icon(Icons.edit, size: 12, color: Colors.white70),
//           //           ), */
//           //         Text(
//           //           message.timeString,
//           //           style: const TextStyle(color: Colors.white70, fontSize: 10),
//           //         ),
//           //       ],
//           //     ),
//           //   ],
//           // ),
//         ),
//       ),
//     );
//   }
// }














// import 'package:flutter/material.dart';
// import 'message_model.dart'; // <-- Імпортуємо нашу модель

// class SentMessageBubble extends StatelessWidget {
//   final Message message;

//   const SentMessageBubble({super.key, required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return Align(
//       alignment: Alignment.centerRight,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 4.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: const Color(0xFF5F63B4),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 message.text,
//                 style: const TextStyle(color: Colors.white),
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               message.timeString,
//               style: const TextStyle(color: Colors.grey, fontSize: 12),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }