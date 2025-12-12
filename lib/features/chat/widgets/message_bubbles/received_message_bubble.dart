import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Для відео
import 'message_model.dart'; 

class ReceivedMessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onDelete; // Тільки видалення (локальне)

  const ReceivedMessageBubble({
    super.key, 
    required this.message,
    this.onDelete,
  });

  // Відкриття відео
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

  // Меню (Тільки видалення або копіювання, редагувати чуже не можна)
  // void _showContextMenu(BuildContext context, Offset globalPosition) {
  //   final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
  //   showMenu(
  //     context: context,
  //     position: RelativeRect.fromRect(
  //       globalPosition & const Size(40, 40), 
  //       Offset.zero & overlay.size,
  //     ),
  //     items: [
  //       const PopupMenuItem(
  //         value: 'delete',
  //         child: Row(
  //           children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete')],
  //         ),
  //       ),
  //     ],
  //   ).then((value) {
  //     if (value == 'delete' && onDelete != null) {
  //       onDelete!();
  //     }
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      //onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
      //onLongPressStart: (details) => _showContextMenu(context, details.globalPosition),
      
      child: Align(
        alignment: Alignment.centerLeft, // ВИРІВНЮВАННЯ ЗЛІВА
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          // Відступи: малі для медіа, звичайні для тексту
          padding: message.type == MessageType.text 
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
              : const EdgeInsets.all(4),
          
          decoration: const BoxDecoration(
            color: Color(0xFFEBEBF2), // СВІТЛО-СІРИЙ ФОН
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4), // Гострий кут зліва знизу
            ),
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Текст зліва
            children: [
              
              // 1. ТЕКСТ
              if (message.type == MessageType.text)
                Text(
                  message.text,
                  style: const TextStyle(color: Colors.black87, fontSize: 16), // Чорний текст
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
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => 
                        const SizedBox(
                          width: 100, height: 100,
                          child: Icon(Icons.broken_image, color: Colors.grey, size: 40)
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
                      color: Colors.white, // Білий фон для відео-блоку
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_circle_fill, color: Colors.black54, size: 40),
                        const SizedBox(width: 8),
                        const Text("Play Video", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
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
                style: const TextStyle(color: Colors.black54, fontSize: 10), // Сірий час
              ),
            ],
          ),
        ),
      ),
    );
  }
}























// import 'package:flutter/material.dart';
// import 'message_model.dart'; // <-- Імпортуємо нашу модель
// import 'package:timeago/timeago.dart' as timeago; // Якщо використовуєш timeago


// class ReceivedMessageBubble extends StatelessWidget {
//   final Message message;

//   const ReceivedMessageBubble({super.key, required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return Align(
//       alignment: Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 4),
//         // Якщо картинка - менший паддінг
//         padding: message.type == MessageType.image 
//             ? const EdgeInsets.all(4) 
//             : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//         decoration: BoxDecoration(
//           color: const Color(0xFFEBEBF2), // Сірий колір для вхідних
//           borderRadius: BorderRadius.circular(16),
//         ),
//         constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // --- ЛОГІКА ВІДОБРАЖЕННЯ (ТЕКСТ або ФОТО) ---
//             if (message.type == MessageType.text)
//               Text(
//                 message.text,
//                 style: const TextStyle(color: Colors.black87, fontSize: 16),
//               )
//             else if (message.type == MessageType.image && message.fileUrl != null)
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(12),
//                 child: Image.network(
//                   message.fileUrl!,
//                   fit: BoxFit.cover,
//                   loadingBuilder: (context, child, loadingProgress) {
//                     if (loadingProgress == null) return child;
//                     return Container(
//                       width: 200, height: 200,
//                       color: Colors.black12,
//                       child: const Center(child: CircularProgressIndicator()),
//                     );
//                   },
//                   errorBuilder: (context, error, stackTrace) => 
//                       const Icon(Icons.broken_image, color: Colors.grey, size: 50),
//                 ),
//               )
//             else if (message.type == MessageType.video) // (Додамо на майбутнє для відео)
//                Container(
//                  padding: const EdgeInsets.all(10),
//                  child: Row(
//                    mainAxisSize: MainAxisSize.min,
//                    children: [
//                      const Icon(Icons.play_circle_fill, color: Colors.black54, size: 30),
//                      const SizedBox(width: 8),
//                      Expanded(child: Text("Video Message", style: const TextStyle(color: Colors.black87))),
//                    ],
//                  ),
//                ),

//             const SizedBox(height: 4),
//             Text(
//               message.timeString,
//               style: const TextStyle(color: Colors.black54, fontSize: 10),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


// // class ReceivedMessageBubble extends StatelessWidget {
// //   final Message message;

// //   const ReceivedMessageBubble({super.key, required this.message});

// //   @override
// //   Widget build(BuildContext context) {
// //     return Align(
// //       alignment: Alignment.centerLeft,
// //       child: Padding(
// //         padding: const EdgeInsets.symmetric(vertical: 4.0),
// //         child: Row(
// //           crossAxisAlignment: CrossAxisAlignment.end,
// //           children: [
// //             // Аватарка співрозмовника
// //             const CircleAvatar(
// //               radius: 18,
// //               backgroundColor: Color(0xFFB0B3D6),
// //               child: Icon(Icons.person, color: Colors.white, size: 20),
// //             ),
// //             const SizedBox(width: 8),
// //             Flexible(
// //               child: Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Container(
// //                     padding: const EdgeInsets.all(12),
// //                     decoration: BoxDecoration(
// //                       color: const Color(0xFFDCE1F4),
// //                       borderRadius: BorderRadius.circular(12),
// //                     ),
// //                     child: Text(message.text),
// //                   ),
// //                   const SizedBox(height: 4),
// //                   Text(
// //                     message.timeString,
// //                     style: const TextStyle(color: Colors.grey, fontSize: 12),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
