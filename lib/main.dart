import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/services/presence_service.dart';

// НОВЕ: Імпорти для Provider
import 'package:provider/provider.dart'; 
// import 'features/chat/models/chat_model.dart'; // Шлях може відрізнятись, перевір
import 'core/providers/chat_provider.dart'; // Шлях до твого провайдера
import 'core/providers/contacts_provider.dart';

import 'core/services/analytics_service.dart';
import 'pages/auth_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyA01xiOZD0I3dJDgH0OCAkbTTFHV1l1Eg8",
      authDomain: "kpplabchat.firebaseapp.com",
      projectId: "kpplabchat",
      storageBucket: "kpplabchat.firebasestorage.app",
      messagingSenderId: "695427828303",
      appId: "1:695427828303:web:dc1d04f2a29f06ab6d783a",
      measurementId: "G-5RQ5C71RQD",
    ),
  );

  const String _dsn = 'https://f1393670a01619175c463fde3fd089d1@o4510289936187392.ingest.de.sentry.io/4510289953423440';

  await SentryFlutter.init(
    (options) {
      options.dsn = _dsn;
      options.environment = 'production';
      options.tracesSampleRate = 1.0;
      options.enableAutoSessionTracking = true;
    },
    appRunner: () => runApp(
      MultiProvider(
        providers: [
          // Створюємо ChatProvider і одразу запускаємо завантаження даних
          ChangeNotifierProvider(
            create: (_) => ChatProvider()..init(),
          ),
          ChangeNotifierProvider(
            create: (_) => ContactsProvider()..init(),
          ),
          // ChangeNotifierProvider(
          //   create: (_) => ChatProvider()..loadChats(),
          // ),
          // ChangeNotifierProvider(create: (_) => ContactsProvider()..loadContacts()),
        ],
        child: MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  
  @override
  void initState() {
    super.initState();
    
    PresenceService().configure();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChitChat Web',
      debugShowCheckedModeBanner: false,
      home: AuthPage(), 
      navigatorObservers: [AnalyticsService.observer],
    );
  }
}







// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'ChitChat Web',
//       debugShowCheckedModeBanner: false,
//       home: AuthPage(), 
//       navigatorObservers: [AnalyticsService.observer],
//     );
//   }
//   @override
// void initState() {
//   super.initState();
//   // Запускаємо стеження за статусом
//   PresenceService().configure();
// }
// }






// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_analytics/firebase_analytics.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'core/services/analytics_service.dart';
// import 'pages/auth_page.dart'; // імпорт сторінки авторизації
// import 'package:sentry_flutter/sentry_flutter.dart';

// void main() async {
//   // debugPaintSizeEnabled = true;
//   WidgetsFlutterBinding.ensureInitialized();

//   await Firebase.initializeApp( 
//     options: const FirebaseOptions(
//       apiKey: "AIzaSyA01xiOZD0I3dJDgH0OCAkbTTFHV1l1Eg8",
//       authDomain: "kpplabchat.firebaseapp.com",
//       projectId: "kpplabchat",
//       storageBucket: "kpplabchat.firebasestorage.app",
//       messagingSenderId: "695427828303",
//       appId: "1:695427828303:web:dc1d04f2a29f06ab6d783a",
//       measurementId: "G-5RQ5C71RQD",
//     ),
//   );

// const String _dsn = 'https://f1393670a01619175c463fde3fd089d1@o4510289936187392.ingest.de.sentry.io/4510289953423440'; 

//   await SentryFlutter.init(
//     (options) {
//       options.dsn = _dsn; 
//       options.environment = 'production'; // або 'development' для тестування
//       options.tracesSampleRate = 1.0;
//       options.enableAutoSessionTracking = true;
//     },
//     appRunner: () => runApp(MyApp()), // 8. Запуск додатку всередині Sentry
//   );

//   // runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'ChitChat Web',
//       debugShowCheckedModeBanner: false,
//       home: AuthPage(), // стартова сторінка
//       navigatorObservers: [AnalyticsService.observer],
//     );
//   }
// }
