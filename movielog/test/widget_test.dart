import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/features/movies/presentation/movie_detail_screen.dart';
import 'package:movielog/features/movies/presentation/movie_list_screen.dart';
import 'package:movielog/features/movies/presentation/widgets/genre_filter_sheet.dart';
import 'package:movielog/features/rating/presentation/widgets/movie_rating_dialog.dart';
import 'package:movielog/features/sign_up/presentation/sign_up_screen.dart';
import 'package:movielog/features/start/presentation/start_screen.dart';

Finder dialogStar(int index) => find
    .descendant(
      of: find.byType(MovieRatingDialog),
      matching: find.byIcon(Icons.star_rounded),
    )
    .at(index);

void main() {
  // 폰 크기 화면에서 테스트한다.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1170,
      2532,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
  });
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets('시작 → 회원가입 → 홈으로 가고, 홈에서는 뒤로 갈 곳이 없다', (tester) async {
    await tester.pumpWidget(const MovieLogApp());
    await tester.tap(find.byKey(startButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('가입하기'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(signUpButtonKey)).onPressed,
      isNull,
    );

    await tester.enterText(find.byKey(nicknameFieldKey), '무비러버');
    await tester.enterText(find.byKey(emailFieldKey), 'movielog@example.com');
    await tester.enterText(find.byKey(passwordFieldKey), 'password1234');
    await tester.tap(find.byKey(termsCheckboxKey));
    await tester.pump();
    await tester.ensureVisible(find.byKey(signUpButtonKey));
    await tester.tap(find.byKey(signUpButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('지금 많이 보는 영화'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('이메일에 @만 있으면 가입 버튼이 켜지지 않는다', (tester) async {
    await tester.pumpWidget(
      const MovieLogApp(initialLocation: AppRoutes.signUp),
    );
    await tester.enterText(find.byKey(nicknameFieldKey), '무비러버');
    await tester.enterText(find.byKey(emailFieldKey), 'a@b');
    await tester.enterText(find.byKey(passwordFieldKey), 'password1234');
    await tester.tap(find.byKey(termsCheckboxKey));
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.byKey(signUpButtonKey)).onPressed,
      isNull,
    );
  });

  testWidgets('홈 카드 → 상세(Path Parameter) → 뒤로 가면 홈', (tester) async {
    await tester.pumpWidget(const MovieLogApp(initialLocation: AppRoutes.home));
    await tester.tap(find.byKey(const Key('featured-under-the-starlight')));
    await tester.pumpAndSettle();

    expect(find.text('별빛 아래 우리'), findsOneWidget);
    expect(find.text('평균 평점'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('지금 많이 보는 영화'), findsOneWidget);
  });

  testWidgets('NavigationBar로 탭을 전환한다', (tester) async {
    await tester.pumpWidget(const MovieLogApp(initialLocation: AppRoutes.home));

    await tester.tap(find.text('영화'));
    await tester.pumpAndSettle();
    expect(find.text('전체 영화 6편'), findsOneWidget);

    await tester.tap(find.text('마이페이지').last);
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾기한 영화'), findsOneWidget);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
  });

  testWidgets('BottomSheet에서 고른 장르는 확인을 눌러야 목록에 반영된다', (tester) async {
    await tester.pumpWidget(
      const MovieLogApp(initialLocation: AppRoutes.movies),
    );

    await tester.tap(find.byKey(filterButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('genreCheckbox-SF')));
    await tester.pump();
    // 아직 확인 전이므로 목록은 그대로다.
    expect(find.text('전체 영화 6편'), findsOneWidget);

    await tester.tap(find.byKey(applyFilterButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('SF · 2편'), findsOneWidget);

    // 아무것도 고르지 않고 확인하면 전체 목록으로 돌아간다.
    await tester.tap(find.byKey(filterButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('genreCheckbox-SF')));
    await tester.tap(find.byKey(applyFilterButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('전체 영화 6편'), findsOneWidget);
  });

  testWidgets('Query Parameter로 장르 필터를 연다', (tester) async {
    await tester.pumpWidget(
      MovieLogApp(initialLocation: moviesLocation({'드라마'})),
    );
    await tester.pumpAndSettle();
    expect(find.text('드라마 · 1편'), findsOneWidget);
  });

  testWidgets('상세: 즐겨찾기 Snackbar와 평점 Dialog', (tester) async {
    await tester.pumpWidget(
      MovieLogApp(initialLocation: AppRoutes.movieDetail('night-shadows')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(favoriteButtonKey));
    await tester.pump();
    expect(find.text('즐겨찾기에 추가했어요.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);

    await tester.tap(find.byKey(favoriteButtonKey));
    await tester.pump();
    expect(find.text('즐겨찾기에서 삭제했어요.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(rateButtonKey));
    await tester.tap(find.byKey(rateButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(MovieRatingDialog), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(saveRatingButtonKey)).onPressed,
      isNull,
    );

    await tester.tap(dialogStar(3));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(saveRatingButtonKey)).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(resetRatingButtonKey));
    await tester.pump();
    expect(find.text('별을 눌러 평점을 선택하세요'), findsOneWidget);

    await tester.tap(dialogStar(4));
    await tester.pump();
    await tester.tap(find.byKey(saveRatingButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(MovieRatingDialog), findsNothing);
    expect(find.textContaining('내 평점'), findsOneWidget);
  });
}
