import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/core/data/mock_movies.dart';

import 'support.dart';

void main() {
  testWidgets('실제 Flutter Widget을 렌더링해 상태 인증 화면과 전환 프레임 저장', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('Manrope');
    font.addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
    final korean = File('/System/Library/Fonts/AppleSDGothicNeo.ttc');
    await tester.runAsync(() async {
      await font.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      if (await korean.exists()) {
        final fallback = FontLoader('Apple SD Gothic Neo');
        fallback.addFont(
          Future.value(ByteData.sublistView(await korean.readAsBytes())),
        );
        await fallback.load();
      }
      await Directory('evidence/frames').create(recursive: true);
    });
    final boundaryKey = GlobalKey();
    final preferences = MemoryMoviePreferences();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        for (final movie in mockMovies) {
          await precacheImage(
            AssetImage(movie.posterPath),
            boundaryKey.currentContext!,
          );
        }
      });
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('evidence/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> open(String location, String id) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MovieLogApp(
            key: ValueKey(id),
            initialLocation: location,
            preferences: preferences,
          ),
        ),
      );
    }

    Future<void> loaded() async {
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
    }

    await open('/movies', 'success');
    await capture('01_loading');
    await loaded();
    await capture('02_success');
    await open('/movies?mode=empty', 'empty');
    await loaded();
    await capture('03_empty');
    await open('/movies?mode=failure', 'error');
    await loaded();
    await capture('04_error');
    // 영상은 테스트가 실제 화면에 탭을 보내고 매 100ms 렌더링한 프레임이다.
    int frame = 0;
    Future<void> frames(int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await capture('frames/retry-${(frame++).toString().padLeft(3, '0')}');
      }
    }

    await frames(10);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await frames(25);
    await capture('05_retry_success');
    await tester.tap(find.byKey(const Key('genreChip-SF')));
    await tester.pumpAndSettle();
    await capture('06_saved_genre');
    await open('/movies', 'restarted');
    await loaded();
    await capture('07_restored_genre');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
