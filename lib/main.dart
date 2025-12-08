import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/fruit_screen.dart';
import 'screens/chat_screen.dart';

Future<void> testAssets() async {
  try {
    debugPrint("🔍 Testing model...");
    final model = await rootBundle.load("assets/models/fruit_model.tflite");
    debugPrint("✅ Model loaded: ${model.lengthInBytes} bytes");
  } catch (e) {
    debugPrint("❌ MODEL ERROR: $e");
  }

  try {
    debugPrint("🔍 Testing labels...");
    final labels = await rootBundle.loadString("assets/models/labels.txt");
    debugPrint("✅ Labels loaded: ${labels.split('\n').length} labels");
  } catch (e) {
    debugPrint("❌ LABELS ERROR: $e");
  }

  try {
    debugPrint("🔍 Testing image...");
    final image = await rootBundle.load("assets/images/emsi.png");
    debugPrint("✅ Image loaded: ${image.lengthInBytes} bytes");
  } catch (e) {
    debugPrint("❌ IMAGE ERROR: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await testAssets();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Bousmah_App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/fruits': (context) => const FruitScreen(),
        '/chatbot': (context) => const ChatScreen(),
      },
    );
  }
}