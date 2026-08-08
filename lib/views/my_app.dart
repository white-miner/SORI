import 'package:flutter/material.dart';

import '../routing/app_router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color soriPurple = Color(0xFF6C5CE7);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SORI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: soriPurple,
          primary: soriPurple,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F7FC),
        useMaterial3: true,
      ),
      initialRoute: AppRouter.admin,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
