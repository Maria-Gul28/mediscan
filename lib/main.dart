import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MediScanApp());
}

class MediScanApp extends StatelessWidget {
  const MediScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'MediScan',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF1B5E3A),
          scaffoldBackgroundColor: const Color(0xFFF3F5F4),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
