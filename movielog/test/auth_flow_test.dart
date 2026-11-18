import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/features/auth/presentation/login_screen.dart';
import 'package:movielog/features/home/presentation/home_screen.dart';
import 'package:movielog/features/my_page/presentation/my_page_screen.dart';
import 'package:movielog/features/sign_up/presentation/sign_up_screen.dart';
import 'package:movielog/features/start/presentation/splash_screen.dart';
import 'package:movielog/view_models/auth_view_model.dart';

import 'support.dart';

const _email = 'kevin@umc.com';
const _password = 'Password1234!';

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  late AppHarness h;

  setUp(() => h = AppHarness());

  /// 토큰 없이 켜서 로그인 화면까지 온다.
  Future<void> openLogin(WidgetTester tester) async {
    h.storage.token = null;
    await tester.pumpWidget(h.app());
    await settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
  }

  Future<void> fillAndLogin(
    WidgetTester tester, {
    String email = _email,
    String password = _password,
  }) async {
    await tester.enterText(find.byKey(loginEmailFieldKey), email);
    await tester.enterText(find.byKey(loginPasswordFieldKey), password);
    await tester.tap(find.byKey(loginButtonKey));
    await settle(tester);
    // 로그인에 성공하면 홈이 만들어진 뒤 시작되는 인기 영화 로딩(가짜 지연)까지 흘려보낸다.
    if (authOf(tester).isSignedIn) await settle(tester);
  }

  /// 시스템 뒤로 가기처럼 Router의 가장 위 화면을 pop한다.
  void goBack(WidgetTester tester) {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).pop();
  }

  TextFormField field(WidgetTester tester, Key key) =>
      tester.widget<TextFormField>(find.byKey(key));

  group('토큰이 없을 때: 시작 → 로그인 → 홈', () {
    testWidgets('저장된 토큰이 없으면 서버에 묻지 않고 로그인 화면으로 가며 보호 화면은 열리지 않는다', (
      tester,
    ) async {
      h.storage.token = null;
      await tester.pumpWidget(h.app());
      expect(find.byType(SplashScreen), findsOneWidget); // 확인하는 동안은 시작 화면
      await settle(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(currentLocation(tester), AppRoutes.login);
      expect(find.byType(HomeScreen), findsNothing);
      expect(h.memberApi.fetchCalls, 0);
      expect(find.text(sessionExpiredMessage), findsNothing);
    });

    testWidgets('로그인하면 토큰을 저장하고 홈으로 간다', (tester) async {
      await openLogin(tester);
      await fillAndLogin(tester);

      expect(currentLocation(tester), AppRoutes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(h.storage.token, h.authApi.lastIssuedToken);
      expect(h.authApi.requests.single.email, _email);
      expect(authOf(tester).status, AuthStatus.signedIn);
      // 토큰 문자열이 화면 어디에도 보이지 않는다.
      expect(find.textContaining(h.storage.token!), findsNothing);
      // 로그인하면 앞 화면(로그인)으로 되돌아갈 수 없다.
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('로그인 요청 중에는 버튼이 로딩이고 입력이 잠기며 중복 탭은 요청 한 번뿐이다', (tester) async {
      await openLogin(tester);
      h.authApi.gate = Completer<void>();
      await tester.enterText(find.byKey(loginEmailFieldKey), _email);
      await tester.enterText(find.byKey(loginPasswordFieldKey), _password);
      await tester.tap(find.byKey(loginButtonKey));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.descendant(
          of: find.byKey(loginButtonKey),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(field(tester, loginEmailFieldKey).enabled, isFalse);
      expect(field(tester, loginPasswordFieldKey).enabled, isFalse);
      await tester.tap(find.byKey(loginButtonKey), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(h.authApi.requests, hasLength(1));
      // 로그인 요청 중에도 공개 화면(로그인)에 머문다.
      expect(currentLocation(tester), AppRoutes.login);

      h.authApi.gate!.complete();
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.home);
      expect(h.authApi.requests, hasLength(1));
    });

    testWidgets('빈 입력은 서버에 보내지 않고 입력칸 문구로 알린다', (tester) async {
      await openLogin(tester);
      await tester.tap(find.byKey(loginButtonKey));
      await settle(tester);
      expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
      expect(find.text('비밀번호를 입력해 주세요.'), findsOneWidget);
      expect(h.authApi.requests, isEmpty);
    });

    testWidgets('이메일·비밀번호가 틀리면(AUTH401_1) 폼 오류만 보이고 만료 안내나 이동은 없다', (
      tester,
    ) async {
      await openLogin(tester);
      await fillAndLogin(tester, password: 'wrong-password');

      expect(find.byKey(loginErrorKey), findsOneWidget);
      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
      expect(find.text(sessionExpiredMessage), findsNothing);
      expect(currentLocation(tester), AppRoutes.login);
      expect(h.storage.token, isNull);
      expect(h.storage.deletes, 0);
      // 입력한 이메일은 그대로 남아 다시 시도할 수 있다.
      expect(field(tester, loginEmailFieldKey).controller!.text, _email);
    });

    testWidgets('서버 오류·통신 실패·저장 실패는 서로 다른 문구로 보인다', (tester) async {
      await openLogin(tester);

      h.authApi.failure = networkFailure('/auth/login');
      await fillAndLogin(tester);
      final network = tester.widget<Text>(find.byKey(loginErrorKey)).data;
      expect(network, contains('네트워크'));

      h.authApi.failure = apiFailure(
        '/auth/login',
        500,
        code: 'COMMON500',
        message: '서버 오류가 발생했습니다.',
      );
      await fillAndLogin(tester);
      final server = tester.widget<Text>(find.byKey(loginErrorKey)).data;
      expect(server, isNot(network));
      expect(server, isNot('이메일 또는 비밀번호를 확인해 주세요.'));

      h.authApi.failure = null;
      h.storage.failWrite = true;
      await fillAndLogin(tester);
      expect(find.text('로그인 정보를 안전하게 저장하지 못했어요.'), findsOneWidget);
      expect(h.storage.token, isNull);
      expect(currentLocation(tester), AppRoutes.login);
    });

    testWidgets('회원가입 링크로 이동했다가 뒤로 오면 로그인 화면이 그대로 남아 있다', (tester) async {
      await openLogin(tester);
      await tester.enterText(find.byKey(loginEmailFieldKey), 'typed@umc.com');
      await tester.tap(find.byKey(loginGoSignUpKey));
      await settle(tester);
      expect(find.byKey(nicknameFieldKey), findsOneWidget);

      goBack(tester);
      await settle(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        field(tester, loginEmailFieldKey).controller!.text,
        'typed@umc.com',
      );
    });
  });

  group('이메일 저장(Challenge): 이메일만 저장하고 비밀번호·토큰은 저장하지 않는다', () {
    testWidgets('체크하고 로그인하면 이메일만 저장된다', (tester) async {
      await openLogin(tester);
      await tester.tap(find.byKey(rememberEmailKey));
      await tester.pump();
      await fillAndLogin(tester);

      expect(h.emailPreference.email, _email);
      expect(h.emailPreference.saves, 1);
      // 저장소에는 이메일 말고 비밀번호가 흘러가지 않는다(대역은 이메일 문자열 하나만 받는다).
      expect(h.emailPreference.email, isNot(contains(_password)));
    });

    testWidgets('체크를 풀고 로그인하면 저장해 둔 이메일도 지운다', (tester) async {
      h.emailPreference.email = _email;
      await openLogin(tester);
      expect(
        tester.widget<CheckboxListTile>(find.byKey(rememberEmailKey)).value,
        isTrue,
      );

      await tester.tap(find.byKey(rememberEmailKey)); // 체크 해제
      await tester.pump();
      await fillAndLogin(tester);

      expect(h.emailPreference.email, isNull);
      expect(h.emailPreference.clears, 1);
    });

    testWidgets('다음에 앱을 켜면 저장된 이메일이 채워지고 체크가 켜져 있다', (tester) async {
      h.emailPreference.email = 'saved@umc.com';
      await openLogin(tester);

      expect(
        field(tester, loginEmailFieldKey).controller!.text,
        'saved@umc.com',
      );
      expect(
        tester.widget<CheckboxListTile>(find.byKey(rememberEmailKey)).value,
        isTrue,
      );
      expect(field(tester, loginPasswordFieldKey).controller!.text, isEmpty);
    });

    testWidgets('로그인에 실패하면 이메일 저장을 바꾸지 않는다', (tester) async {
      await openLogin(tester);
      await tester.tap(find.byKey(rememberEmailKey));
      await tester.pump();
      await fillAndLogin(tester, password: 'wrong-password');

      expect(h.emailPreference.saves, 0);
      expect(h.emailPreference.clears, 0);
    });

    testWidgets('비밀번호 입력칸은 가려져 있다', (tester) async {
      await openLogin(tester);
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(loginPasswordFieldKey),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.obscureText, isTrue);
    });
  });

  group('앱 재시작: 토큰이 있을 때', () {
    testWidgets('복원 성공: 로그인 화면이 한 번도 보이지 않고 서버가 인정한 뒤에 홈이 열린다', (tester) async {
      h.memberApi.meGate = Completer<void>();
      await tester.pumpWidget(h.app());
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(LoginScreen), findsNothing);
        expect(
          find.byType(HomeScreen),
          findsNothing,
          reason: '서버가 인정하기 전에는 홈이 아니다',
        );
      }
      expect(find.byType(SplashScreen), findsOneWidget);

      h.memberApi.meGate!.complete();
      await settle(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(h.memberApi.fetchCalls, 1);
    });

    testWidgets('통신 실패: 시작 화면에 안내와 다시 시도가 보이고 토큰은 지우지 않으며, 다시 시도로 복구된다', (
      tester,
    ) async {
      h.memberApi.meFailure = networkFailure('/members/me');
      await tester.pumpWidget(h.app());
      await settle(tester);

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byKey(splashMessageKey), findsOneWidget);
      expect(find.text('로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      expect(find.byKey(splashRetryKey), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(h.storage.token, 'stored-token');
      expect(h.storage.deletes, 0);
      expect(find.text(sessionExpiredMessage), findsNothing);

      h.memberApi.meFailure = null;
      await tester.tap(find.byKey(splashRetryKey));
      await settle(tester);
      await settle(tester); // 홈의 인기 영화 로딩까지
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(h.storage.token, 'stored-token');
    });

    testWidgets('서버가 500을 줘도 로그인 화면으로 쫓아내지 않고 다시 시도하게 한다', (tester) async {
      h.memberApi.meFailure = apiFailure(
        '/members/me',
        500,
        code: 'COMMON500',
        message: '서버 오류',
      );
      await tester.pumpWidget(h.app());
      await settle(tester);
      expect(find.byKey(splashRetryKey), findsOneWidget);
      expect(h.storage.token, 'stored-token');
      expect(authOf(tester).status, AuthStatus.retryRequired);
    });

    testWidgets('인증 저장소를 읽지 못하면 서버에 묻지 않고 다시 시도하게 한다', (tester) async {
      h.storage.failRead = true;
      await tester.pumpWidget(h.app());
      await settle(tester);

      expect(find.text('인증 저장소를 읽지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      expect(h.memberApi.fetchCalls, 0);

      h.storage.failRead = false;
      await tester.tap(find.byKey(splashRetryKey));
      await settle(tester);
      await settle(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    for (final code in ['AUTH401_2', 'AUTH401_3', 'AUTH401_4']) {
      testWidgets('토큰이 거절되면($code) 토큰을 지우고 로그인 화면에서 만료를 한 번만 안내한다', (
        tester,
      ) async {
        h.memberApi.meFailure = apiFailure(
          '/members/me',
          401,
          code: code,
          message: '토큰 문제',
        );
        await tester.pumpWidget(h.app());
        await settle(tester);

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(h.storage.token, isNull);
        expect(find.text(sessionExpiredMessage), findsOneWidget);
        expect(authOf(tester).sessionExpired, isFalse, reason: '표시하면서 안내를 껐다');

        // Snackbar가 사라진 뒤에는 반복해서 뜨지 않는다.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(find.text(sessionExpiredMessage), findsNothing);
        await tester.tap(find.byKey(loginGoSignUpKey));
        await settle(tester);
        goBack(tester);
        await settle(tester);
        expect(find.text(sessionExpiredMessage), findsNothing);
      });
    }
  });

  group('이동 규칙(Router redirect)', () {
    testWidgets('로그인한 사용자가 /login·/sign-up으로 가면 홈으로 돌려보낸다', (tester) async {
      await tester.pumpWidget(h.app());
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.home);

      goTo(tester, AppRoutes.login);
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.home);

      goTo(tester, AppRoutes.signUp);
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.home);
      expect(find.byKey(nicknameFieldKey), findsNothing);
    });

    testWidgets('로그아웃 상태에서 보호 경로로 가면 모두 로그인 화면으로 간다', (tester) async {
      await openLogin(tester);
      for (final path in [
        AppRoutes.home,
        AppRoutes.movies,
        AppRoutes.my,
        AppRoutes.myRatings,
        AppRoutes.editProfile,
        AppRoutes.movieDetail(550),
      ]) {
        goTo(tester, path);
        await settle(tester);
        expect(currentLocation(tester), AppRoutes.login, reason: path);
      }
    });

    testWidgets('마이페이지의 로그아웃: 토큰을 지우고 로그인 화면으로 가며 만료 안내는 없다', (tester) async {
      await tester.pumpWidget(h.app(initialLocation: AppRoutes.my));
      await settle(tester);
      expect(find.byKey(myPageNicknameKey), findsOneWidget);

      await tester.tap(find.byKey(logoutButtonKey));
      await settle(tester);

      expect(currentLocation(tester), AppRoutes.login);
      expect(h.storage.token, isNull);
      expect(authOf(tester).status, AuthStatus.signedOut);
      expect(find.text(sessionExpiredMessage), findsNothing);
      // 이전에 보던 보호 화면으로 뒤로 갈 수 없다.
      goTo(tester, AppRoutes.my);
      await settle(tester);
      expect(currentLocation(tester), AppRoutes.login);
    });

    testWidgets('토큰 삭제에 실패해도 화면은 로그아웃되고 안내가 보인다', (tester) async {
      await tester.pumpWidget(h.app(initialLocation: AppRoutes.my));
      await settle(tester);
      h.storage.failDelete = true;

      await tester.tap(find.byKey(logoutButtonKey));
      await settle(tester);

      expect(currentLocation(tester), AppRoutes.login);
      expect(authOf(tester).status, AuthStatus.signedOut);
      expect(find.byKey(loginErrorKey), findsOneWidget);
      expect(find.textContaining('지우지 못했어요'), findsOneWidget);
    });

    testWidgets('앱을 쓰는 중 토큰이 만료되면(내 정보 401) 로그인 화면에서 만료를 안내한다', (tester) async {
      await openLogin(tester);
      h.memberApi.meFailure = apiFailure(
        '/members/me',
        401,
        code: 'AUTH401_3',
        message: '토큰이 만료되었습니다.',
      );
      await fillAndLogin(tester); // 로그인 직후 MainShell이 내 정보를 부른다
      await settle(tester);

      expect(currentLocation(tester), AppRoutes.login);
      expect(h.storage.token, isNull);
      expect(find.text(sessionExpiredMessage), findsOneWidget);
    });
  });
}
