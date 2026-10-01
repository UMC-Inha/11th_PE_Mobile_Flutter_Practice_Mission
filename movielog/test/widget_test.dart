import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/models/movie.dart';
import 'package:movielog/movie_log_app.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/detail/movie_detail_screen.dart';
import 'package:movielog/screens/home/widgets/featured_movie_banner.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/movie_rating_input.dart';
import 'package:movielog/screens/profile/profile_screen.dart';
import 'package:movielog/screens/rating/rating_practice_screen.dart';
import 'package:movielog/screens/signup/sign_up_screen.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/theme/app_theme.dart';

Widget _appWith(Widget home) {
  return MaterialApp(theme: AppTheme.light, home: home);
}

Widget _appWithKeyboard(Widget home, {double keyboardHeight = 300}) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        viewInsets: EdgeInsets.only(bottom: keyboardHeight),
      ),
      child: child!,
    ),
    home: home,
  );
}

void _usePhoneSize(WidgetTester tester, {double width = 360, double height = 640}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

ElevatedButton _submitButton(WidgetTester tester) {
  return tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '가입하기'));
}

void main() {
  testWidgets('앱을 실행하면 시작 화면이 표시되고, 시작하기를 누르면 뒤로가기 없는 회원가입 화면으로 이동한다',
      (WidgetTester tester) async {
    AppRouter.router.go('/start');
    await tester.pumpWidget(const MovieLogApp());
    await tester.pumpAndSettle();
    expect(find.text('시작하기'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('가입하기'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(AppRouter.router.canPop(), isFalse);
  });

  testWidgets('회원가입을 완료하면 뒤로가기 없는 홈 화면으로 이동한다', (WidgetTester tester) async {
    _usePhoneSize(tester, width: 400, height: 900);
    AppRouter.router.go('/register');
    await tester.pumpWidget(const MovieLogApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '닉네임을 입력해주세요'), '무비러버');
    await tester.enterText(find.widgetWithText(TextFormField, '이메일 주소를 입력해주세요'), 'movielover@movielog.com');
    await tester.enterText(find.widgetWithText(TextFormField, '비밀번호를 입력해주세요'), 'password1');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(find.text('오늘은 어떤\n영화를 볼까요?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(AppRouter.router.canPop(), isFalse);
  });

  testWidgets('NavigationBar로 탭을 전환하면 선택 상태와 화면이 일치한다', (WidgetTester tester) async {
    AppRouter.router.go('/home');
    await tester.pumpWidget(const MovieLogApp());
    await tester.pumpAndSettle();

    NavigationBar navBar() => tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar().selectedIndex, 0);

    await tester.tap(find.text('영화').last);
    await tester.pumpAndSettle();
    expect(navBar().selectedIndex, 1);
    expect(find.byType(GridView), findsOneWidget);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    expect(navBar().selectedIndex, 2);
    expect(find.text('내 프로필'), findsOneWidget);
  });

  testWidgets('홈의 추천 영화 카드를 누르면 같은 ID의 상세로 이동하고 뒤로 돌아올 수 있다', (WidgetTester tester) async {
    AppRouter.router.go('/home');
    await tester.pumpWidget(const MovieLogApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FeaturedMovieBanner));
    await tester.pumpAndSettle();

    expect(AppRouter.router.state.uri.path, '/movies/1');
    expect(find.text('별빛 아래 우리'), findsOneWidget);
    expect(find.text('4.5 (1,245)', findRichText: true), findsOneWidget);
    expect(AppRouter.router.canPop(), isTrue);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('오늘은 어떤\n영화를 볼까요?'), findsOneWidget);
  });

  testWidgets('extra 없이 URL로 직접 진입해도 Path Parameter로 영화를 찾는다', (WidgetTester tester) async {
    AppRouter.router.go('/movies/2');
    await tester.pumpWidget(const MovieLogApp());
    await tester.pumpAndSettle();

    expect(find.text('우주의 끝에서'), findsOneWidget);
  });

  testWidgets('영화 목록의 장르 Chip을 누르면 Query Parameter로 해당 장르만 표시된다', (WidgetTester tester) async {
    AppRouter.router.go('/movies');
    await tester.pumpWidget(const MovieLogApp());
    await tester.pumpAndSettle();

    expect(find.byType(MovieCard), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();

    expect(AppRouter.router.state.uri.toString(), '/movies?genre=SF');
    expect(find.byType(MovieCard), findsOneWidget);
    expect(find.text('우주의 끝에서'), findsOneWidget);
  });

  testWidgets('상세 화면에서 평점 Dialog와 즐겨찾기 Snackbar가 동작한다', (WidgetTester tester) async {
    _usePhoneSize(tester, width: 400, height: 900);
    await tester.pumpWidget(_appWith(MovieDetailScreen(movie: findMovieById(1))));

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.text('\'별빛 아래 우리\'을(를) 즐겨찾기에 추가했어요.'), findsOneWidget);

    await tester.tap(find.text('평점 남기기'));
    await tester.pumpAndSettle();
    expect(find.byType(MovieRatingInput), findsOneWidget);
    ElevatedButton confirm() => tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '확인'));
    expect(confirm().onPressed, isNull);
  });

  testWidgets('시작 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(_appWith(const StartScreen()));

    expect(find.text('시작하기'), findsOneWidget);
    expect(find.text('영화의 순간을\n기록하세요'), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('프로필 화면의 구성요소를 모두 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(_appWith(const ProfileScreen()));

    expect(find.text('내 프로필'), findsOneWidget);
    expect(find.text('무비러버'), findsOneWidget);
    expect(find.text('매주 주말엔 영화관으로 출근하는 프로 관람객. 좋은 영화를 보고 기록하는 것을 좋아합니다.'), findsOneWidget);
    expect(find.text('본 영화'), findsOneWidget);
    expect(find.text('342'), findsOneWidget);
    expect(find.text('평점'), findsOneWidget);
    expect(find.text('4.2'), findsOneWidget);
    expect(find.text('즐겨찾기'), findsOneWidget);
    expect(find.text('58'), findsOneWidget);
    expect(find.text('선호하는 장르'), findsOneWidget);
    expect(find.text('드라마'), findsOneWidget);
    expect(find.text('SF'), findsOneWidget);
    expect(find.text('애니메이션'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '프로필 수정'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('좁은 화면에서 시작 화면이 넘치지 않는다', (WidgetTester tester) async {
    _usePhoneSize(tester, width: 320, height: 568);
    await tester.pumpWidget(_appWith(const StartScreen()));

    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 화면에서 프로필 화면이 넘치지 않는다', (WidgetTester tester) async {
    _usePhoneSize(tester, width: 320, height: 568);
    await tester.pumpWidget(_appWith(const ProfileScreen()));

    expect(tester.takeException(), isNull);
  });

  testWidgets('회원가입 화면의 입력 전 상태에서는 가입하기 버튼이 비활성화되어 있다', (WidgetTester tester) async {
    await tester.pumpWidget(_appWith(const SignUpScreen()));

    expect(find.text('닉네임'), findsOneWidget);
    expect(find.text('이메일'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull);
  });

  testWidgets('닉네임을 두 글자 미만 입력하면 오류 메시지가 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(_appWith(const SignUpScreen()));

    await tester.enterText(find.widgetWithText(TextFormField, '닉네임을 입력해주세요'), '무');
    await tester.pump();

    expect(find.text('닉네임은 두 글자 이상 입력해주세요.'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull);
  });

  testWidgets('이메일 형식이 아니면 오류 메시지가 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(_appWith(const SignUpScreen()));

    await tester.enterText(find.widgetWithText(TextFormField, '이메일 주소를 입력해주세요'), 'movielog');
    await tester.pump();

    expect(find.text('올바른 이메일 형식이 아니에요.'), findsOneWidget);
  });

  testWidgets('닉네임·이메일·비밀번호를 모두 유효하게 입력하고 약관에 동의하면 버튼이 활성화된다', (WidgetTester tester) async {
    await tester.pumpWidget(_appWith(const SignUpScreen()));

    await tester.enterText(find.widgetWithText(TextFormField, '닉네임을 입력해주세요'), '무비러버');
    await tester.enterText(find.widgetWithText(TextFormField, '이메일 주소를 입력해주세요'), 'movielover@movielog.com');
    await tester.enterText(find.widgetWithText(TextFormField, '비밀번호를 입력해주세요'), 'password1');
    await tester.pump();
    expect(_submitButton(tester).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(_submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('좁은 화면에서 회원가입 화면이 넘치지 않는다', (WidgetTester tester) async {
    _usePhoneSize(tester, width: 320, height: 568);
    await tester.pumpWidget(_appWith(const SignUpScreen()));

    expect(tester.takeException(), isNull);
  });

  testWidgets('키보드가 열린 상태에서도 회원가입 화면이 넘치지 않는다', (WidgetTester tester) async {
    _usePhoneSize(tester, width: 360, height: 640);
    await tester.pumpWidget(_appWithKeyboard(const SignUpScreen()));

    expect(tester.takeException(), isNull);
  });

  testWidgets('평점 화면은 선택 전에는 저장 버튼이 비활성화되어 있다', (WidgetTester tester) async {
    await tester.pumpWidget(_appWith(const RatingPracticeScreen()));

    expect(find.text('별점을 선택해주세요'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '평점 저장')).onPressed, isNull);
  });
}
