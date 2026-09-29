import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/features/sign_up/presentation/sign_up_screen.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog 회원가입',
      theme: AppTheme.light,
      home: const SignUpScreen(),
    );
  }
}
