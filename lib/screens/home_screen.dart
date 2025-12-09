
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    // Retrieve arguments passed from Login Page
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final email = args?['email'] as String? ?? 'user@example.com';
    
    // Derive name from email (e.g. radia.omalek -> Radia Omalek)
    String name = 'User';
    if (email.contains('@')) {
      final localPart = email.split('@')[0];
      // Split by dot or underscore if present
      final parts = localPart.split(RegExp(r'[._]'));
      name = parts.map((part) {
        if (part.isEmpty) return '';
        return part[0].toUpperCase() + part.substring(1);
      }).join(' ');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.teal,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundImage: AssetImage('assets/images/img_pp.jpeg'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    email,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Fruits Classifier'),
              onTap: () {
                  Navigator.pop(context); // close drawer
                  Navigator.pushNamed(context, '/fruits');
              },
            ),

            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Emsi CHATBOT'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/chatbot');
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Profile'),
              onTap: () {
                // Navigate to Profile Page
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              trailing: const Icon(Icons.arrow_forward),
              title: const Text('Settings'),
              onTap: () {
                // Navigate to Settings Page
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                // Handle logout action
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Text(
          'Welcome $name!',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
