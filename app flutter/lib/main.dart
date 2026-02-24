import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';
import 'providers/irrigation_provider.dart';
import 'screens/login/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);


const firebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyDeoCmqLt0_OF8waCMc1F83_6RsKDNwVEY",
  appId: "1:284088493585:android:adcee58ac6443af0a933b0",
  messagingSenderId: "284088493585",
  projectId: "mikafa-538d9",
  databaseURL: "https://mikafa-538d9-default-rtdb.firebaseio.com",
  storageBucket: "mikafa-538d9.firebasestorage.app",
);
  await Firebase.initializeApp(options: firebaseOptions);

  runApp(const IrrigationApp());
}

class IrrigationApp extends StatelessWidget {
  const IrrigationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IrrigationProvider()..startListening()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mikafa',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const LoginScreen(),
      ),
    );
  }
}
