import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/core/config/tmdb_config.dart';

/// 개발 중 특정 화면부터 실행하고 싶을 때:
/// `flutter run --dart-define=INITIAL_LOCATION=/movies`
const _initialLocation = String.fromEnvironment(
  'INITIAL_LOCATION',
  defaultValue: AppRoutes.start,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // load가 끝나기 전에 읽으면 빈 값이 나오므로 runApp 전에 반드시 기다린다.
  await dotenv.load(fileName: '.env');
  if (!TmdbConfig.hasAccessToken) {
    // Token 원문은 출력하지 않는다. 비어 있다는 사실만 알린다.
    debugPrint('[TMDB] .env의 TMDB_ACCESS_TOKEN이 비어 있습니다. (.env.example 참고)');
  }
  runApp(const MovieLogApp(initialLocation: _initialLocation));
}
