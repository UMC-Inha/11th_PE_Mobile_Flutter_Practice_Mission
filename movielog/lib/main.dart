import 'package:flutter/material.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/app/movie_log_app.dart';

/// 개발 중 특정 화면부터 실행하고 싶을 때:
/// `flutter run --dart-define=INITIAL_LOCATION=/movies`
const _initialLocation = String.fromEnvironment(
  'INITIAL_LOCATION',
  defaultValue: AppRoutes.start,
);

void main() {
  runApp(const MovieLogApp(initialLocation: _initialLocation));
}
