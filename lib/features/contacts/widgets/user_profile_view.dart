import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../chat/models/contact_model.dart';

class UserProfileView extends StatelessWidget {
  final Contact contact;
  final VoidCallback? onClose;

  const UserProfileView({
    super.key,
    required this.contact,
    this.onClose,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return "${date.day}.${date.month}.${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    // Кольори
    final Color borderColor = const Color(0xFF4F506D).withOpacity(0.5);
    final Color contentBgColor = const Color(0xFFEBEBF2);
    const Color primaryTextColor = Color(0xFF2B2B40);

    return Container(
      // На мобільному прибираємо зовнішні відступи для економії місця
      margin: MediaQuery.of(context).size.width < 900 ? EdgeInsets.zero : const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                if (onClose != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: onClose,
                      color: primaryTextColor,
                    ),
                  ),
                Expanded(
                  child: Text(
                    '${contact.username}\'s Profile',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),

          // --- CONTENT (ADAPTIVE) ---
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: contentBgColor,
                // На мобільному скруглення знизу не обов'язкові, якщо на весь екран
                borderRadius: BorderRadius.circular(12),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Якщо ширина менше 800 пікселів -> Мобільний режим
                  if (constraints.maxWidth < 800) {
                    return _buildMobileLayout(context);
                  } else {
                    return _buildDesktopLayout(context);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- DESKTOP LAYOUT (Дві колонки) ---
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: _buildLeftColumn(context), // Інфо
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 5,
          child: _buildRightColumn(context), // About
        ),
      ],
    );
  }

  // --- MOBILE LAYOUT (Одна колонка + Скрол) ---
  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildLeftColumn(context), // Спочатку інфо
          const SizedBox(height: 24),
          _buildRightColumn(context), // Потім About знизу
        ],
      ),
    );
  }

  // --- ЛІВА КОЛОНКА (Аватар, Логін, Пошта) ---
  Widget _buildLeftColumn(BuildContext context) {
    const Color labelColor = Color(0xFF4F506D);
    final myUid = context.read<ChatProvider>().currentUserId;
    final isMe = contact.id == myUid;

    return Column(
      children: [
        // 1. Main Info Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: const Color(0xFFB0B3D6),
                    backgroundImage: (contact.photoUrl != null && contact.photoUrl!.isNotEmpty)
                        ? NetworkImage(contact.photoUrl!)
                        : null,
                    child: (contact.photoUrl == null || contact.photoUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 40, color: Colors.white)
                        : null,
                  ),
                  if (isMe)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () async {
                          final authController = AuthController();
                          await authController.updateProfilePhoto();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(blurRadius: 2, color: Colors.black26)],
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Color(0xFF4F506D)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 20),
              // Name & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.username,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2B2B40)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Added: ${_formatDate(contact.addedAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 2. Login
        _buildInfoCard(label: 'Login:', value: contact.login, labelColor: labelColor),
        const SizedBox(height: 16),
        // 3. Email
        _buildInfoCard(label: 'Email:', value: contact.email, labelColor: labelColor),
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context) {
    const Color primaryTextColor = Color(0xFF2B2B40);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tell about you',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryTextColor),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 200), 
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            "Information not available yet.",
            style: TextStyle(fontSize: 14, color: Color(0xFF5F63B4), height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required String label, required String value, required Color labelColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: labelColor),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, color: Color(0xFF9E9EB3)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}





































































//   import 'package:flutter/material.dart';
//   import 'package:chat_lab_kpp/features/chat/models/contact_model.dart';

//   // import 'dart:io'; // Import for File
//   import '../../../features/auth/controllers/auth_controller.dart'; // Your AuthController
//   import 'package:provider/provider.dart';
//   import '../../../core/providers/chat_provider.dart';

//   class UserProfileView extends StatelessWidget {
//     final Contact contact;
//     final VoidCallback? onClose; 

//     const UserProfileView({
//       super.key, 
//       required this.contact,
//       this.onClose,
//     });

//     // Helper method for date formatting
//     String _formatDate(DateTime? date) {
//       if (date == null) return 'Unknown';
//       return "${date.day}.${date.month}.${date.year}";
//     }

//     @override
//     Widget build(BuildContext context) {
//       final Color borderColor = const Color(0xFF4F506D).withOpacity(0.5);
//       final Color contentBgColor = const Color(0xFFEBEBF2); 
//       const Color primaryTextColor = Color(0xFF2B2B40);
//       const Color labelColor = Color(0xFF4F506D);

//       // Get current user ID to determine if this is "my" profile
//       final myUid = context.read<ChatProvider>().currentUserId;
//       // Assuming Contact model has an 'id' or 'uid' field. Adjust if it's named differently.
//       final isMe = contact.id == myUid; 

//       return Container(
//         margin: const EdgeInsets.all(20),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: borderColor, width: 1),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // --- HEADER ---
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//               child: Row(
//                 children: [
//                   if (onClose != null)
//                     Padding(
//                       padding: const EdgeInsets.only(right: 16),
//                       child: IconButton(
//                         icon: const Icon(Icons.arrow_back),
//                         onPressed: onClose,
//                         color: primaryTextColor,
//                       ),
//                     ),
//                   Text(
//                     '${contact.username}\'s Profile', 
//                     style: const TextStyle(
//                       fontSize: 24, 
//                       fontWeight: FontWeight.bold, 
//                       color: primaryTextColor
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const Divider(height: 1, color: Color(0xFFE0E0E0)),

//             // --- CONTENT AREA ---
//             Expanded(
//               child: Container(
//                 width: double.infinity,
//                 margin: const EdgeInsets.all(24),
//                 padding: const EdgeInsets.all(24),
//                 decoration: BoxDecoration(
//                   color: contentBgColor,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Expanded(
//                       flex: 4, 
//                       child: Column(
//                         children: [
//                           // 1. Main Info Card (Avatar + Name)
//                           Container(
//                             padding: const EdgeInsets.all(20),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Row(
//                               children: [
//                                 // Avatar with Edit Button logic
//                                 Stack(
//                                   children: [
//                                     CircleAvatar(
//                                       radius: 35,
//                                       backgroundColor: const Color(0xFFB0B3D6), 
//                                       backgroundImage: (contact.photoUrl != null && contact.photoUrl!.isNotEmpty) 
//                                           ? NetworkImage(contact.photoUrl!) 
//                                           : null,
//                                       child: (contact.photoUrl == null || contact.photoUrl!.isEmpty) 
//                                           ? const Icon(Icons.person, size: 40, color: Colors.white) 
//                                           : null,
//                                     ),
//                                     // Edit Button (Only visible if it's the current user's profile)
//                                     if (isMe)
//                                       Positioned(
//                                         bottom: 0,
//                                         right: 0,
//                                         child: InkWell(
//                                           onTap: () async {
//                                             final authController = AuthController(); 
//                                             await authController.updateProfilePhoto();
                                            
//                                           },
//                                           child: Container(
//                                             padding: const EdgeInsets.all(4),
//                                             decoration: const BoxDecoration(
//                                               color: Colors.white,
//                                               shape: BoxShape.circle,
//                                               boxShadow: [BoxShadow(blurRadius: 2, color: Colors.black26)]
//                                             ),
//                                             child: const Icon(Icons.camera_alt, size: 16, color: Color(0xFF4F506D)),
//                                           ),
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                                 const SizedBox(width: 20),
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       Text(
//                                         contact.username,
//                                         style: const TextStyle(
//                                           fontSize: 22, 
//                                           fontWeight: FontWeight.bold,
//                                           color: primaryTextColor,
//                                         ),
//                                       ),
//                                       const SizedBox(height: 4),
//                                       Text(
//                                         contact.isOnline ? 'Online' : 'Offline',
//                                         style: TextStyle(
//                                           fontSize: 14, 
//                                           color: Colors.grey[400],
//                                         ),
//                                       ),
//                                       const SizedBox(height: 8),
//                                       Text(
//                                         'Added: ${_formatDate(contact.addedAt)}',
//                                         style: TextStyle(
//                                           fontSize: 12, 
//                                           color: Colors.grey[400],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           const SizedBox(height: 16),

//                           // 2. Login Card
//                           _buildInfoCard(label: 'Login:', value: contact.login, labelColor: labelColor),
//                           const SizedBox(height: 16),

//                           // 3. Email Card
//                           _buildInfoCard(label: 'Email:', value: "hidden@email.com", labelColor: labelColor),
//                         ],
//                       ),
//                     ),
                    
//                     const SizedBox(width: 24), // Spacer between columns

//                     // --- RIGHT COLUMN (About) ---
//                     Expanded(
//                       flex: 5,
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Tell about you',
//                             style: TextStyle(
//                               fontSize: 20, 
//                               fontWeight: FontWeight.bold, 
//                               color: primaryTextColor
//                             ),
//                           ),
//                           const SizedBox(height: 12),
//                           Expanded(
//                             child: Container(
//                               width: double.infinity,
//                               padding: const EdgeInsets.all(24),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                               child: const Text(
//                                 "Information not available yet.",
//                                 style: TextStyle(
//                                   fontSize: 14, 
//                                   color: Color(0xFF5F63B4), 
//                                   height: 1.5,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       );
//     }

//     Widget _buildInfoCard({required String label, required String value, required Color labelColor}) {
//       return Container(
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 14, 
//                 fontWeight: FontWeight.bold, 
//                 color: labelColor,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               value,
//               style: const TextStyle(
//                 fontSize: 16, 
//                 color: Color(0xFF9E9EB3), 
//               ),
//             ),
//           ],
//         ),
//       );
//     }
//   }


























//   // import 'package:flutter/material.dart';
//   // //import 'package:intl/intl.dart'; // Для форматування дати (додай intl в pubspec, якщо немає, або використовуй toString)
//   // import 'package:chat_lab_kpp/features/chat/models/contact_model.dart';
//   // import 'package:image_picker/image_picker.dart'; 
//   // import '../../../features/auth/controllers/auth_controller.dart'; // Твій контролер
//   // import 'package:provider/provider.dart';
//   // import '../../../core/providers/chat_provider.dart';


//   // class UserProfileView extends StatelessWidget {
//   //   final Contact contact;
//   //   final VoidCallback? onClose; 

//   //   const UserProfileView({
//   //     super.key, 
//   //     required this.contact,
//   //     this.onClose,
//   //   });

//   //   // Допоміжний метод для форматування дати
//   //   String _formatDate(DateTime? date) {
//   //     if (date == null) return 'Unknown';
//   //     return "${date.day}.${date.month}.${date.year}";
//   //   }

//   //   @override
//   //   Widget build(BuildContext context) {
//   //     final Color borderColor = const Color(0xFF4F506D).withOpacity(0.5);
//   //     final Color contentBgColor = const Color(0xFFEBEBF2); 
//   //     const Color primaryTextColor = Color(0xFF2B2B40);
//   //     const Color labelColor = Color(0xFF4F506D);

//   //     final myUid = context.read<ChatProvider>().currentUserId;
//   //     final isMe = contact.id == myUid;

//   //     return Container(
//   //       margin: const EdgeInsets.all(20),
//   //       decoration: BoxDecoration(
//   //         color: Colors.white,
//   //         borderRadius: BorderRadius.circular(20),
//   //         border: Border.all(color: borderColor, width: 1),
//   //       ),
//   //       child: Column(
//   //         crossAxisAlignment: CrossAxisAlignment.start,
//   //         children: [
//   //           // --- HEADER ---
//   //           Padding(
//   //             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//   //             child: Row(
//   //               children: [
//   //                 if (onClose != null)
//   //                    Padding(
//   //                      padding: const EdgeInsets.only(right: 16),
//   //                      child: IconButton(
//   //                        icon: const Icon(Icons.arrow_back),
//   //                        onPressed: onClose,
//   //                        color: primaryTextColor,
//   //                      ),
//   //                    ),
//   //                 // 1. ЗМІНЕНО: contact.name -> contact.username
//   //                 Text(
//   //                   '${contact.username}\'s Profile', 
//   //                   style: const TextStyle(
//   //                     fontSize: 24, 
//   //                     fontWeight: FontWeight.bold, 
//   //                     color: primaryTextColor
//   //                   ),
//   //                 ),
//   //               ],
//   //             ),
// //           ),
// //           const Divider(height: 1, color: Color(0xFFE0E0E0)),

// //           // --- CONTENT AREA ---
// //           Expanded(
// //             child: Container(
// //               width: double.infinity,
// //               margin: const EdgeInsets.all(24),
// //               padding: const EdgeInsets.all(24),
// //               decoration: BoxDecoration(
// //                 color: contentBgColor,
// //                 borderRadius: BorderRadius.circular(12),
// //               ),
// //               child: Row(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Expanded(
// //                     flex: 4, 
// //                     child: Column(
// //                       children: [
// //                         // 1. Main Info Card (Avatar + Name)
// //                         Container(
// //                           padding: const EdgeInsets.all(20),
// //                           decoration: BoxDecoration(
// //                             color: Colors.white,
// //                             borderRadius: BorderRadius.circular(12),
// //                           ),
// //                           child: Row(
// //                             children: [
// //                               CircleAvatar(
// //                                 radius: 35,
// //                                 backgroundColor: const Color(0xFFB0B3D6), 
// //                                 // 2. ЗМІНЕНО: avatarUrl -> photoUrl
// //                                 backgroundImage: (contact.photoUrl != null && contact.photoUrl!.isNotEmpty) 
// //                                     ? NetworkImage(contact.photoUrl!) 
// //                                     : null,
// //                                 child: (contact.photoUrl == null || contact.photoUrl!.isEmpty) 
// //                                     ? const Icon(Icons.person, size: 40, color: Colors.white) 
// //                                     : null,
// //                               ),
// //                               const SizedBox(width: 20),
// //                               Expanded(
// //                                 child: Column(
// //                                   crossAxisAlignment: CrossAxisAlignment.start,
// //                                   children: [
// //                                     // 3. ЗМІНЕНО: name -> username
// //                                     Text(
// //                                       contact.username,
// //                                       style: const TextStyle(
// //                                         fontSize: 22, 
// //                                         fontWeight: FontWeight.bold,
// //                                         color: primaryTextColor,
// //                                       ),
// //                                     ),
// //                                     const SizedBox(height: 4),
// //                                     Text(
// //                                       contact.isOnline ? 'Online' : 'Offline',
// //                                       style: TextStyle(
// //                                         fontSize: 14, 
// //                                         color: Colors.grey[400],
// //                                       ),
// //                                     ),
// //                                     const SizedBox(height: 8),
// //                                     // 4. ЗМІНЕНО: registrationDate -> addedAt (форматуємо)
// //                                     Text(
// //                                       'Added: ${_formatDate(contact.addedAt)}',
// //                                       style: TextStyle(
// //                                         fontSize: 12, 
// //                                         color: Colors.grey[400],
// //                                       ),
// //                                     ),
// //                                   ],
// //                                 ),
// //                               ),
// //                             ],
// //                           ),
// //                         ),
// //                         const SizedBox(height: 16),

// //                         // 2. Login Card
// //                         _buildInfoCard(label: 'Login:', value: contact.login, labelColor: labelColor),
// //                         const SizedBox(height: 16),

// //                         // 3. Email Card
// //                         // 5. ЗМІНЕНО: email немає в моделі, ставимо заглушку або login
// //                         _buildInfoCard(label: 'Email:', value: "hidden@email.com", labelColor: labelColor),
// //                       ],
// //                     ),
// //                   ),
                  
// //                   const SizedBox(width: 24), // Відступ між колонками

// //                   // --- RIGHT COLUMN (About) ---
// //                   Expanded(
// //                     flex: 5,
// //                     child: Column(
// //                       crossAxisAlignment: CrossAxisAlignment.start,
// //                       children: [
// //                         const Text(
// //                           'Tell about you',
// //                           style: TextStyle(
// //                             fontSize: 20, 
// //                             fontWeight: FontWeight.bold, 
// //                             color: primaryTextColor
// //                           ),
// //                         ),
// //                         const SizedBox(height: 12),
// //                         Expanded(
// //                           child: Container(
// //                             width: double.infinity,
// //                             padding: const EdgeInsets.all(24),
// //                             decoration: BoxDecoration(
// //                               color: Colors.white,
// //                               borderRadius: BorderRadius.circular(12),
// //                             ),
// //                             child: const Text(
// //                               // 6. ЗМІНЕНО: about немає в моделі, ставимо заглушку
// //                               "Information not available yet.",
// //                               style: TextStyle(
// //                                 fontSize: 14, 
// //                                 color: Color(0xFF5F63B4), 
// //                                 height: 1.5,
// //                               ),
// //                             ),
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildInfoCard({required String label, required String value, required Color labelColor}) {
// //     return Container(
// //       width: double.infinity,
// //       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(12),
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Text(
// //             label,
// //             style: TextStyle(
// //               fontSize: 14, 
// //               fontWeight: FontWeight.bold, 
// //               color: labelColor,
// //             ),
// //           ),
// //           const SizedBox(height: 4),
// //           Text(
// //             value,
// //             style: const TextStyle(
// //               fontSize: 16, 
// //               color: Color(0xFF9E9EB3), 
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }



















// // import 'package:flutter/material.dart';
// // import 'package:chat_lab_kpp/features/chat/models/contact_model.dart';

// // class UserProfileView extends StatelessWidget {
// //   final Contact contact;
// //   final VoidCallback? onClose; // Щоб можна було закрити/повернутися

// //   const UserProfileView({
// //     super.key, 
// //     required this.contact,
// //     this.onClose,
// //   });

// //   @override
// //   Widget build(BuildContext context) {
// //     final Color borderColor = const Color(0xFF4F506D).withOpacity(0.5);
// //     final Color contentBgColor = const Color(0xFFEBEBF2); // Фіолетово-сірий фон
// //     const Color primaryTextColor = Color(0xFF2B2B40);
// //     const Color labelColor = Color(0xFF4F506D);

// //     return Container(
// //       margin: const EdgeInsets.all(20),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(20),
// //         border: Border.all(color: borderColor, width: 1),
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           // --- HEADER ---
// //           Padding(
// //             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
// //             child: Row(
// //               children: [
// //                 if (onClose != null)
// //                    Padding(
// //                      padding: const EdgeInsets.only(right: 16),
// //                      child: IconButton(
// //                        icon: const Icon(Icons.arrow_back),
// //                        onPressed: onClose,
// //                        color: primaryTextColor,
// //                      ),
// //                    ),
// //                 Text(
// //                   '${contact.name}\'s Profile', // Динамічний заголовок
// //                   style: const TextStyle(
// //                     fontSize: 24, 
// //                     fontWeight: FontWeight.bold, 
// //                     color: primaryTextColor
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //           const Divider(height: 1, color: Color(0xFFE0E0E0)),

// //           // --- CONTENT AREA ---
// //           Expanded(
// //             child: Container(
// //               width: double.infinity,
// //               margin: const EdgeInsets.all(24),
// //               padding: const EdgeInsets.all(24),
// //               decoration: BoxDecoration(
// //                 color: contentBgColor,
// //                 borderRadius: BorderRadius.circular(12),
// //               ),
// //               child: Row(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Expanded(
// //                     flex: 4, 
// //                     child: Column(
// //                       children: [
// //                         // 1. Main Info Card (Avatar + Name)
// //                         Container(
// //                           padding: const EdgeInsets.all(20),
// //                           decoration: BoxDecoration(
// //                             color: Colors.white,
// //                             borderRadius: BorderRadius.circular(12),
// //                           ),
// //                           child: Row(
// //                             children: [
// //                               CircleAvatar(
// //                                 radius: 35,
// //                                 backgroundColor: const Color(0xFFB0B3D6), 
// //                                 backgroundImage: contact.avatarUrl.isNotEmpty 
// //                                     ? NetworkImage(contact.avatarUrl) 
// //                                     : null,
// //                                 child: contact.avatarUrl.isEmpty 
// //                                     ? const Icon(Icons.person, size: 40, color: Colors.white) 
// //                                     : null,
// //                               ),
// //                               const SizedBox(width: 20),
// //                               Expanded(
// //                                 child: Column(
// //                                   crossAxisAlignment: CrossAxisAlignment.start,
// //                                   children: [
// //                                     Text(
// //                                       contact.name,
// //                                       style: const TextStyle(
// //                                         fontSize: 22, 
// //                                         fontWeight: FontWeight.bold,
// //                                         color: primaryTextColor,
// //                                       ),
// //                                     ),
// //                                     const SizedBox(height: 4),
// //                                     Text(
// //                                       contact.isOnline ? 'Online' : 'Offline',
// //                                       style: TextStyle(
// //                                         fontSize: 14, 
// //                                         color: Colors.grey[400],
// //                                       ),
// //                                     ),
// //                                     const SizedBox(height: 8),
// //                                     Text(
// //                                       'Registration date: ${contact.registrationDate}',
// //                                       style: TextStyle(
// //                                         fontSize: 12, 
// //                                         color: Colors.grey[400],
// //                                       ),
// //                                     ),
// //                                   ],
// //                                 ),
// //                               ),
// //                             ],
// //                           ),
// //                         ),
// //                         const SizedBox(height: 16),

// //                         // 2. Login Card
// //                         _buildInfoCard(label: 'Login:', value: contact.login, labelColor: labelColor),
// //                         const SizedBox(height: 16),

// //                         // 3. Email Card
// //                         _buildInfoCard(label: 'Email:', value: contact.email, labelColor: labelColor),
// //                       ],
// //                     ),
// //                   ),
                  
// //                   const SizedBox(width: 24), // Відступ між колонками

// //                   // --- RIGHT COLUMN (About) ---
// //                   Expanded(
// //                     flex: 5,
// //                     child: Column(
// //                       crossAxisAlignment: CrossAxisAlignment.start,
// //                       children: [
// //                         const Text(
// //                           'Tell about you',
// //                           style: TextStyle(
// //                             fontSize: 20, 
// //                             fontWeight: FontWeight.bold, 
// //                             color: primaryTextColor
// //                           ),
// //                         ),
// //                         const SizedBox(height: 12),
// //                         Expanded(
// //                           child: Container(
// //                             width: double.infinity,
// //                             padding: const EdgeInsets.all(24),
// //                             decoration: BoxDecoration(
// //                               color: Colors.white,
// //                               borderRadius: BorderRadius.circular(12),
// //                             ),
// //                             child: Text(
// //                               contact.about,
// //                               style: const TextStyle(
// //                                 fontSize: 14, 
// //                                 color: Color(0xFF5F63B4), // Синій колір тексту як на скріні
// //                                 height: 1.5,
// //                               ),
// //                             ),
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildInfoCard({required String label, required String value, required Color labelColor}) {
// //     return Container(
// //       width: double.infinity,
// //       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(12),
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Text(
// //             label,
// //             style: TextStyle(
// //               fontSize: 14, 
// //               fontWeight: FontWeight.bold, 
// //               color: labelColor,
// //             ),
// //           ),
// //           const SizedBox(height: 4),
// //           Text(
// //             value,
// //             style: const TextStyle(
// //               fontSize: 16, 
// //               color: Color(0xFF9E9EB3), // Світло-сірий текст значення
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }