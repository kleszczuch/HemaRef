import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'loginPage.dart';
import 'mainPage.dart';
import 'tournament_data.dart';
import 'settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BracketData>(create: (_) => BracketData()),
        ChangeNotifierProvider<AppSettingsData>(create: (_) => AppSettingsData()),
      ],
      child: MaterialApp(
        title: 'HEMA REF',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: FirebaseAuth.instance.currentUser != null
            ? const MainScreen()
            : const LoginPage(),
      ),
    );
  }
}