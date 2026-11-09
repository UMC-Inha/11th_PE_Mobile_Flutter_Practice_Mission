import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:provider/provider.dart';

import 'dart:async';

import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/movie_log_app.dart';
import 'package:movielog/screens/my_ratings/my_ratings_screen.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/detail/movie_detail_screen.dart';
import 'package:movielog/screens/movies/widgets/movie_list_error.dart';
import 'package:movielog/screens/detail/widgets/rating_dialog.dart';
import 'package:movielog/screens/movies/movie_list_screen.dart';
import 'package:movielog/widgets/movie_rating_input.dart';
import 'package:movielog/screens/profile/profile_screen.dart';
import 'package:movielog/screens/rating/rating_practice_screen.dart';
import 'package:movielog/screens/signup/sign_up_screen.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/theme/app_theme.dart';

import 'fakes/fake_sign_up_service.dart';
import 'fakes/fake_rating_api_service.dart';
import 'fakes/fake_tmdb_movie_service.dart';

/// 회원가입 화면이 쓰는 서버 Service와 ViewModel을 가짜로 함께 등록합니다.
Widget _appWith(Widget home, {FakeSignUpService? signUpService}) {
  final service = signUpService ?? FakeSignUpService();
  return MultiProvider(
    providers: [
      Provider<SignUpService>.value(value: service),
      ChangeNotifierProvider<LearningMemberSession>(
        create: (_) => LearningMemberSession(),
      ),
      ChangeNotifierProvider<SignUpViewModel>(
        create: (_) => SignUpViewModel(service),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: home),
  );
}

/// 실제 서버 대신 가짜 Service를 넣은 앱 전체입니다.
/// [memberId]는 이미 학습용 회원가입을 마친 상태로 시작할 때 넘깁니다.
MovieLogApp _fakeApp({
  FakeSignUpService? signUpService,
  FakeRatingApiService? ratingApiService,
  FakeTmdbMovieService? tmdbMovieService,
  LearningMemberSession? session,
  int? memberId = 1,
}) {
  // TMDB를 넣지 않으면 실제 Service를 쓰고, 테스트 환경의 HTTP 요청은 모두 실패합니다.
  return MovieLogApp(
    signUpService: signUpService ?? FakeSignUpService(),
    ratingApiService: ratingApiService ?? FakeRatingApiService(),
    tmdbMovieService: tmdbMovieService,
    learningMemberSession: session ?? LearningMemberSession(memberId: memberId),
  );
}

final _nicknameField = find.widgetWithText(TextFormField, '닉네임을 입력해주세요');
final _emailField = find.widgetWithText(TextFormField, '이메일 주소를 입력해주세요');
final _passwordField = find.widgetWithText(TextFormField, '비밀번호를 입력해주세요');
Finder get _nicknameCheckButton => find.widgetWithText(ElevatedButton, '중복 확인').first;
Finder get _emailCheckButton => find.widgetWithText(ElevatedButton, '중복 확인').last;

Widget _appWithKeyboard(Widget home, {double keyboardHeight = 300}) {
  final service = FakeSignUpService();
  return MultiProvider(
    providers: [
      Provider<SignUpService>.value(value: service),
      ChangeNotifierProvider<SignUpViewModel>(create: (_) => SignUpViewModel(service)),
    ],
    child: MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        viewInsets: EdgeInsets.only(bottom: keyboardHeight),
      ),
      child: child!,
    ),
    home: home,
    ),
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
  setUp(() {
    // 테스트에서는 실제 저장소 대신 메모리 저장소를 사용합니다.
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    // 테스트에서는 실제 .env 대신 가짜 Token을 사용합니다. (테스트 환경의 HTTP 요청은 모두 실패로 응답합니다.)
    dotenv.loadFromString(envString: 'TMDB_ACCESS_TOKEN=test-token');
  });

  testWidgets('앱을 실행하면 시작 화면이 표시되고, 시작하기를 누르면 뒤로가기 없는 회원가입 화면으로 이동한다',
      (WidgetTester tester) async {
    AppRouter.router.go('/start');
    await tester.pumpWidget(_fakeApp());
    await tester.pumpAndSettle();
    expect(find.text('시작하기'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('가입하기'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(AppRouter.router.canPop(), isFalse);
  });

  testWidgets('회원가입에 성공하면 memberId를 세션에 저장하고 뒤로가기 없는 영화 목록으로 이동한다', (WidgetTester tester) async {
    _usePhoneSize(tester, width: 400, height: 900);
    AppRouter.router.go('/register');
    final session = LearningMemberSession();
    final service = FakeSignUpService(createdMemberId: 42);
    await tester.pumpWidget(_fakeApp(signUpService: service, session: session));
    await tester.pumpAndSettle();

    await tester.enterText(_nicknameField, '무비러버');
    await tester.enterText(_emailField, 'movielover@movielog.com');
    await tester.enterText(_passwordField, 'Password1!');
    await tester.pump();
    await tester.tap(_nicknameCheckButton);
    await tester.tap(_emailCheckButton);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(session.memberId, 42);
    expect(service.signUpRequests.single['nickname'], '무비러버');
    expect(find.byType(MovieListScreen), findsOneWidget);
    expect(find.text('회원가입을 완료했어요. (memberId 42)'), findsOneWidget);
    expect(AppRouter.router.canPop(), isFalse);
  });

  testWidgets('최종 가입 409는 Snackbar로, 비밀번호 400은 비밀번호 입력칸에 보여준다', (WidgetTester tester) async {
    _usePhoneSize(tester, width: 400, height: 900);
    final service = FakeSignUpService()
      ..signUpFailStatus = 409
      ..signUpFailMessage = '이미 사용 중인 이메일입니다.';
    await tester.pumpWidget(_appWith(const SignUpScreen(), signUpService: service));

    await tester.enterText(_nicknameField, '무비러버');
    await tester.enterText(_emailField, 'movielover@movielog.com');
    await tester.enterText(_passwordField, 'Password1!');
    await tester.pump();
    await tester.tap(_nicknameCheckButton);
    await tester.tap(_emailCheckButton);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SnackBar, '이미 사용 중인 이메일입니다.'), findsOneWidget);
    // 실패해도 입력은 그대로 남아 있습니다.
    expect(find.text('movielover@movielog.com'), findsOneWidget);

    const passwordError = '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.';
    service
      ..signUpFailStatus = 400
      ..signUpFailMessage = passwordError;
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: _passwordField, matching: find.text(passwordError)), findsOneWidget);

    // 비밀번호를 고치면 서버 오류가 사라집니다.
    await tester.enterText(_passwordField, 'Password2!');
    await tester.pump();
    expect(find.text(passwordError), findsNothing);
  });

  testWidgets('제출 중에는 가입하기 버튼이 로딩 상태로 바뀌어 중복 탭을 막는다', (WidgetTester tester) async {
    _usePhoneSize(tester, width: 400, height: 900);
    final service = FakeSignUpService();
    await tester.pumpWidget(_appWith(const SignUpScreen(), signUpService: service));

    await tester.enterText(_nicknameField, '무비러버');
    await tester.enterText(_emailField, 'movielover@movielog.com');
    await tester.enterText(_passwordField, 'Password1!');
    await tester.pump();
    await tester.tap(_nicknameCheckButton);
    await tester.tap(_emailCheckButton);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // 이 테스트는 GoRouter 없이 화면만 띄우므로 이동하지 않도록 실패 응답으로 끝냅니다.
    service
      ..gate = Completer<void>()
      ..signUpFailStatus = 409;
    await tester.tap(find.text('가입하기'));
    await tester.pump();
    // 버튼 안에는 인디케이터만 보입니다.
    expect(find.text('가입하기'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(service.signUpRequests, hasLength(1));

    service.gate!.complete();
    await tester.pumpAndSettle();
    // 제출이 끝나면 버튼이 다시 보입니다.
    expect(find.text('가입하기'), findsOneWidget);
  });

  testWidgets('NavigationBar로 탭을 전환하면 선택 상태와 화면이 일치한다', (WidgetTester tester) async {
    AppRouter.router.go('/home');
    await tester.pumpWidget(_fakeApp());
    await tester.pumpAndSettle();

    NavigationBar navBar() => tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar().selectedIndex, 0);

    await tester.tap(find.text('영화').last);
    await tester.pumpAndSettle();
    expect(navBar().selectedIndex, 1);
    expect(find.byType(MovieListScreen), findsOneWidget);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    expect(navBar().selectedIndex, 2);
    expect(find.text('내 프로필'), findsOneWidget);
  });

  testWidgets('extra 없이 URL로 직접 진입하면 TMDB 상세 API로 영화를 다시 조회한다', (WidgetTester tester) async {
    final tmdb = FakeTmdbMovieService();
    AppRouter.router.go('/movies/2');
    await tester.pumpWidget(_fakeApp(tmdbMovieService: tmdb));
    await tester.pumpAndSettle();

    expect(tmdb.detailRequests, [2]);
    expect(find.text('영화 2'), findsOneWidget);
  });

  testWidgets('extra 없이 직접 진입했는데 TMDB 조회가 실패하면 안내를 보여준다', (WidgetTester tester) async {
    AppRouter.router.go('/movies/2');
    await tester.pumpWidget(_fakeApp());
    await tester.pumpAndSettle();

    expect(find.text('영화를 불러오지 못했습니다.'), findsOneWidget);
  });

  testWidgets('웹·데스크톱에서도 마우스로 끌어 가로 목록을 스크롤할 수 있다', (WidgetTester tester) async {
    AppRouter.router.go('/start');
    await tester.pumpWidget(_fakeApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.scrollBehavior!.dragDevices, contains(PointerDeviceKind.mouse));
  });

  testWidgets('영화 목록 요청이 실패하면 Error 상태와 재시도 버튼을 보여준다', (WidgetTester tester) async {
    AppRouter.router.go('/movies');
    await tester.pumpWidget(_fakeApp());
    await tester.pumpAndSettle();

    expect(find.byType(MovieListError), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('상세 화면에서 평점 Dialog와 즐겨찾기 Snackbar가 동작한다', (WidgetTester tester) async {
    _usePhoneSize(tester, width: 400, height: 900);
    final movie = FakeTmdbMovieService().movie(550);
    await tester.pumpWidget(_appWith(ChangeNotifierProvider<MovieDetailViewModel>(
      create: (_) => MovieDetailViewModel(FakeRatingApiService(), 1, movie),
      child: const MovieDetailScreen(),
    )));

    // overview가 비어 있으면 안내 문구를 보여줍니다.
    expect(find.text('줄거리 정보가 없어요.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.text("'영화 550'을(를) 즐겨찾기에 추가했어요."), findsOneWidget);

    await tester.tap(find.text('평점 남기기'));
    await tester.pumpAndSettle();
    expect(find.byType(MovieRatingInput), findsOneWidget);
    expect(find.byType(RatingDialog), findsOneWidget);
    // 별점 아래에 코멘트 입력칸이 있습니다.
    expect(find.widgetWithText(TextField, '코멘트를 남겨보세요 (선택)'), findsOneWidget);
    ElevatedButton confirm() => tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '확인'));
    // 코멘트만 입력하고 별점을 고르지 않으면 확인할 수 없습니다.
    await tester.enterText(find.byType(TextField), '재밌어요');
    await tester.pump();
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

  testWidgets('형식이 유효하고 두 중복 확인을 통과한 뒤 약관에 동의하면 버튼이 활성화된다', (WidgetTester tester) async {
    _usePhoneSize(tester, width: 400, height: 900);
    await tester.pumpWidget(_appWith(const SignUpScreen()));

    await tester.enterText(_nicknameField, '무비러버');
    await tester.enterText(_emailField, 'movielover@movielog.com');
    await tester.enterText(_passwordField, 'Password1!');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    // 중복 확인 전에는 가입할 수 없습니다.
    expect(_submitButton(tester).onPressed, isNull);

    await tester.tap(_nicknameCheckButton);
    await tester.tap(_emailCheckButton);
    await tester.pumpAndSettle();

    expect(find.text('사용할 수 있는 닉네임입니다.'), findsOneWidget);
    expect(find.text('사용할 수 있는 이메일입니다.'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('중복 확인 중에는 버튼이 비활성화되고 가운데에 인디케이터만 보인다', (WidgetTester tester) async {
    final service = FakeSignUpService()..gate = Completer<void>();
    await tester.pumpWidget(_appWith(const SignUpScreen(), signUpService: service));

    await tester.enterText(_nicknameField, '무비러버');
    await tester.pump();
    await tester.tap(_nicknameCheckButton);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '중복 확인'), findsOneWidget);

    service.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('사용할 수 있는 닉네임입니다.'), findsOneWidget);
  });

  testWidgets('중복 확인 실패는 중복 응답과 다른 문구로 보여준다', (WidgetTester tester) async {
    final service = FakeSignUpService(fail: true);
    await tester.pumpWidget(_appWith(const SignUpScreen(), signUpService: service));

    await tester.enterText(_nicknameField, '무비러버');
    await tester.pump();
    await tester.tap(_nicknameCheckButton);
    await tester.pumpAndSettle();

    expect(find.text('중복 확인에 실패했습니다. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
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

  testWidgets('마이페이지에서 내가 등록한 평점으로 이동하면 하단 탭 없이 평점을 보여주고, 뒤로가면 돌아온다', (WidgetTester tester) async {
    _usePhoneSize(tester, width: 400, height: 900);
    AppRouter.router.go('/my');
    await tester.pumpWidget(_fakeApp(
      ratingApiService: FakeRatingApiService(ratings: [sampleRating()]),
      tmdbMovieService: FakeTmdbMovieService(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('내가 등록한 평점'));
    await tester.pumpAndSettle();

    expect(find.byType(MyRatingsScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('영화 550'), findsOneWidget);
    expect(find.text('최고의 영화!'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('내 프로필'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('평점 조회가 실패하면 Error 문구와 다시 시도 버튼을 보여준다', (WidgetTester tester) async {
    AppRouter.router.go('/my/ratings');
    await tester.pumpWidget(_fakeApp(
      ratingApiService: FakeRatingApiService(failStatusCode: 404),
    ));
    await tester.pumpAndSettle();

    expect(find.text('존재하지 않는 회원입니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('평점 응답을 기다리는 동안 Loading 인디케이터를 보여준다', (WidgetTester tester) async {
    final service = FakeRatingApiService(ratings: [sampleRating(comment: null)])
      ..gate = Completer<void>();
    AppRouter.router.go('/my/ratings');
    await tester.pumpWidget(_fakeApp(
      ratingApiService: service,
      tmdbMovieService: FakeTmdbMovieService(missingMovieIds: {550}),
    ));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    service.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // TMDB에서 못 찾은 영화는 placeholder로, 후기가 null이면 후기를 그리지 않습니다.
    expect(find.text('영화 정보 없음'), findsOneWidget);
    expect(find.text('movieId 550'), findsOneWidget);
    expect(find.text('최고의 영화!'), findsNothing);
    expect(find.text('일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.'), findsOneWidget);
  });

  testWidgets('평점이 없으면 Empty 안내를 보여준다', (WidgetTester tester) async {
    AppRouter.router.go('/my/ratings');
    await tester.pumpWidget(_fakeApp());
    await tester.pumpAndSettle();

    expect(find.text('아직 등록된 평점이 없어요.'), findsOneWidget);
  });

  testWidgets('서버가 중복이라고 하면 입력창이 에러 상태가 되고, 같은 값을 다시 입력하면 요청 없이 에러로 돌아온다', (WidgetTester tester) async {
    final service = FakeSignUpService(takenNicknames: {'무비러버'});
    await tester.pumpWidget(_appWith(const SignUpScreen(), signUpService: service));

    await tester.enterText(_nicknameField, '무비러버');
    await tester.pump();
    await tester.tap(_nicknameCheckButton);
    await tester.pumpAndSettle();

    expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
    ElevatedButton checkButton() => tester.widget<ElevatedButton>(_nicknameCheckButton);
    expect(checkButton().onPressed, isNull);

    await tester.enterText(_nicknameField, '무비러');
    await tester.pump();
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
    expect(checkButton().onPressed, isNotNull);

    await tester.enterText(_nicknameField, '무비러버');
    await tester.pump();
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
    expect(checkButton().onPressed, isNull);
    expect(service.nicknameRequests, ['무비러버']);
  });

  testWidgets('평점 화면은 선택 전에는 저장 버튼이 비활성화되어 있다', (WidgetTester tester) async {
    await tester.pumpWidget(_appWith(const RatingPracticeScreen()));

    expect(find.text('별점을 선택해주세요'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '평점 저장')).onPressed, isNull);
  });
}
