import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/features/movies/presentation/movie_list_screen.dart';
import 'package:movielog/features/sign_up/presentation/sign_up_screen.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';

import 'support.dart';

const _passwordMessage = '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.';

const _request = CreateMemberRequest(
  email: 'kevin@umc.com',
  password: 'Password1234!',
  nickname: '케빈',
);

void main() {
  group('SignUpViewModel.submit', () {
    late FakeMovieLogApiService api;
    late SignUpViewModel vm;

    setUp(() {
      api = FakeMovieLogApiService();
      vm = SignUpViewModel(api);
    });

    tearDown(() => vm.dispose());

    /// 닉네임·이메일 중복 확인을 둘 다 "사용 가능"으로 마친 상태를 만든다.
    Future<void> confirmBoth() async {
      vm.onNicknameChanged('케빈');
      await vm.checkNickname('케빈');
      vm.onEmailChanged('kevin@umc.com');
      await vm.checkEmail('kevin@umc.com');
      expect(vm.nicknameCheckStatus, CheckStatus.available);
      expect(vm.emailCheckStatus, CheckStatus.available);
    }

    test('성공: idle → submitting → success이고 서버가 준 memberId를 읽는다', () async {
      final seen = <SubmitStatus>[];
      vm.addListener(() => seen.add(vm.submitStatus));
      expect(vm.submitStatus, SubmitStatus.idle);

      await vm.submit(_request);

      expect(seen, [SubmitStatus.submitting, SubmitStatus.success]);
      expect(vm.createdMemberId, 101);
      expect(vm.passwordErrorText, isNull);
      expect(vm.snackbarMessage, isNull);
      expect(api.signUps.single.email, 'kevin@umc.com');
    });

    test('제출 중에는 중복 탭을 무시한다(요청이 한 번만 나간다)', () async {
      api.writeGate = Completer<void>();
      final first = vm.submit(_request);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(vm.isSubmitting, isTrue);

      await vm.submit(_request); // 두 번째 탭은 바로 끝난다
      expect(api.signUps, hasLength(1));

      api.writeGate!.complete();
      await first;
      expect(vm.submitStatus, SubmitStatus.success);
      expect(api.signUps, hasLength(1));
    });

    test('201인데 memberId가 없으면 가입을 완료한 것으로 표시하지 않는다', () async {
      api.signUpWithoutResult = true;
      await vm.submit(_request);
      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.createdMemberId, isNull);
      expect(vm.snackbarMessage, contains('가입 결과를 확인하지 못했습니다'));
    });

    test('400 중 비밀번호 형식 오류는 비밀번호 입력칸 문구(passwordErrorText)로 담는다', () async {
      api.failures['signUp'] = FakeMovieLogApiService.badResponse(
        '/members',
        400,
        message: _passwordMessage,
      );
      await vm.submit(_request);
      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.passwordErrorText, _passwordMessage);
      expect(vm.snackbarMessage, isNull);
    });

    test('비밀번호 외의 400은 Snackbar 문구로 담는다', () async {
      api.failures['signUp'] = FakeMovieLogApiService.badResponse(
        '/members',
        400,
        message: '닉네임은 2자 이상이어야 합니다.',
      );
      await vm.submit(_request);
      expect(vm.passwordErrorText, isNull);
      expect(vm.snackbarMessage, '닉네임은 2자 이상이어야 합니다.');
    });

    test('409(최종 중복)는 서버 message를 Snackbar로, 확인 결과는 다시 확인하도록 지운다', () async {
      await confirmBoth();
      api.takenEmails.add('kevin@umc.com'); // 확인 직후 다른 사람이 가입했다
      await vm.submit(_request);

      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.snackbarMessage, '이미 사용 중인 이메일입니다.');
      expect(vm.passwordErrorText, isNull);
      // 가입 버튼의 조건이 되는 "사용 가능" 확인이 풀렸다.
      expect(vm.isNicknameConfirmed('케빈'), isFalse);
      expect(vm.isEmailConfirmed('kevin@umc.com'), isFalse);
      // 다시 확인하면 이제 서버가 "중복"이라고 알려 준다.
      await vm.checkEmail('kevin@umc.com');
      expect(vm.emailCheckStatus, CheckStatus.duplicated);
    });

    test('서버가 꺼졌을 때는 통신 실패 문구이고, 확인 결과는 그대로다', () async {
      await confirmBoth();
      api.failures['signUp'] = FakeTmdbMovieService.failure('/members');
      await vm.submit(_request);
      expect(vm.snackbarMessage, '네트워크 상태를 확인하고 다시 시도해 주세요.');
      expect(vm.isNicknameConfirmed('케빈'), isTrue);
      expect(vm.isEmailConfirmed('kevin@umc.com'), isTrue);
    });

    test('예상하지 못한 오류가 나도 제출 중 상태에 멈춰 있지 않는다', () async {
      api.failures['signUp'] = const FormatException('깨진 응답');
      await vm.submit(_request);
      expect(vm.submitStatus, SubmitStatus.error);
      expect(vm.isSubmitting, isFalse);
      expect(vm.snackbarMessage, isNotNull);
      // 다시 제출할 수 있다.
      api.failures.clear();
      await vm.submit(_request);
      expect(vm.submitStatus, SubmitStatus.success);
    });

    test('다시 제출하면 이전 서버 오류 문구가 먼저 지워진다', () async {
      api.failures['signUp'] = FakeMovieLogApiService.badResponse(
        '/members',
        400,
        message: _passwordMessage,
      );
      await vm.submit(_request);
      expect(vm.passwordErrorText, isNotNull);

      api.failures.clear();
      final seen = <String?>[];
      vm.addListener(() => seen.add(vm.passwordErrorText));
      await vm.submit(_request);
      expect(seen.first, isNull); // submitting으로 바뀌는 순간 이미 지워졌다
      expect(vm.passwordErrorText, isNull);
    });

    test('비밀번호를 고치면 서버 오류 문구가 사라진다', () async {
      api.failures['signUp'] = FakeMovieLogApiService.badResponse(
        '/members',
        400,
        message: _passwordMessage,
      );
      await vm.submit(_request);
      var notified = 0;
      vm.addListener(() => notified++);

      vm.onPasswordChanged();
      expect(vm.passwordErrorText, isNull);
      expect(notified, 1);

      vm.onPasswordChanged(); // 이미 없으면 다시 알리지 않는다
      expect(notified, 1);
    });

    test('닉네임·이메일을 고치면 이전 제출의 서버 오류(Snackbar 문구)도 지운다', () async {
      api.failures['signUp'] = FakeMovieLogApiService.badResponse(
        '/members',
        409,
        message: '이미 사용 중인 이메일입니다.',
      );
      await vm.submit(_request);
      expect(vm.snackbarMessage, isNotNull);
      vm.onEmailChanged('other@umc.com');
      expect(vm.snackbarMessage, isNull);

      await vm.submit(_request);
      expect(vm.snackbarMessage, isNotNull);
      vm.onNicknameChanged('민수');
      expect(vm.snackbarMessage, isNull);
    });

    test('화면이 사라진 뒤 도착한 가입 응답은 상태를 건드리지 않는다', () async {
      final local = SignUpViewModel(api);
      api.writeGate = Completer<void>();
      final pending = local.submit(_request);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      local.dispose();
      api.writeGate!.complete();
      // dispose된 뒤 notifyListeners가 불리면 여기서 예외가 난다.
      await pending;
      expect(local.createdMemberId, isNull);
    });
  });

  group('회원가입 화면', () {
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

    late FakeTmdbMovieService tmdb;
    late FakeMovieLogApiService api;
    late LearningMemberSession session;

    setUp(() {
      tmdb = FakeTmdbMovieService();
      api = FakeMovieLogApiService();
      session = LearningMemberSession();
    });

    Future<void> openSignUp(WidgetTester tester) => tester.pumpWidget(
      MovieLogApp(
        initialLocation: AppRoutes.signUp,
        tmdbService: tmdb,
        movieLogApiService: api,
        preferences: MemoryMoviePreferences(),
        session: session,
      ),
    );

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    Future<void> type(WidgetTester tester, Key key, String text) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.enterText(find.byKey(key), text);
      await tester.pump();
    }

    Future<void> tapKey(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await settle(tester);
    }

    /// 모든 입력과 두 중복 확인, 약관 동의까지 마쳐 가입 버튼이 눌리는 상태로 만든다.
    Future<void> fillValidForm(
      WidgetTester tester, {
      String password = 'Password1234!',
    }) async {
      await type(tester, nicknameFieldKey, '케빈');
      await type(tester, emailFieldKey, 'kevin@umc.com');
      await type(tester, passwordFieldKey, password);
      await tapKey(tester, termsCheckboxKey);
      await tapKey(tester, nicknameCheckButtonKey);
      await tapKey(tester, emailCheckButtonKey);
    }

    /// 시스템 뒤로가기(안드로이드 뒤로 버튼·iOS 스와이프 백)를 Router에 보낸다.
    /// 화면이 막으면(PopScope canPop: false) true, 나갈 수 있으면 false(앱이 처리하게 넘김).
    Future<bool> systemBack(WidgetTester tester) {
      final context = tester.element(find.byKey(signUpPopScopeKey));
      return Router.of(context).backButtonDispatcher!
          .invokeCallback(Future<bool>.value(false));
    }

    ElevatedButton signUpButton(WidgetTester tester) =>
        tester.widget<ElevatedButton>(
          find.descendant(
            of: find.byKey(signUpButtonKey),
            matching: find.byType(ElevatedButton),
          ),
        );

    testWidgets('로컬 비밀번호 규칙: 대·소문자·숫자·특수문자 중 하나라도 빠지면 가입 버튼이 꺼져 있다', (
      tester,
    ) async {
      await openSignUp(tester);
      await type(tester, nicknameFieldKey, '케빈');
      await type(tester, emailFieldKey, 'kevin@umc.com');
      await tapKey(tester, termsCheckboxKey);
      await tapKey(tester, nicknameCheckButtonKey);
      await tapKey(tester, emailCheckButtonKey);

      for (final weak in [
        'password1234',
        'PASSWORD1234!',
        'Password!!!!',
        'Password1234',
      ]) {
        await type(tester, passwordFieldKey, weak);
        expect(signUpButton(tester).onPressed, isNull, reason: weak);
      }
      expect(find.text('대문자·소문자·숫자·특수문자를 모두 포함해 주세요.'), findsOneWidget);

      await type(tester, passwordFieldKey, 'Password1234!');
      expect(signUpButton(tester).onPressed, isNotNull);
    });

    testWidgets('서버가 비밀번호 400을 주면 로컬 검증을 통과한 값도 입력칸에 에러로 붙는다', (tester) async {
      // 로컬 규칙(대·소·숫자·특수 포함 8자 이상)은 통과하지만 서버는 72자 초과를 거부한다.
      api.failures['signUp'] = FakeMovieLogApiService.badResponse(
        '/members',
        400,
        message: '비밀번호는 72자 이하여야 합니다.',
      );
      await openSignUp(tester);
      await fillValidForm(tester, password: 'Aa1!${'x' * 70}');
      expect(signUpButton(tester).onPressed, isNotNull);

      await tapKey(tester, signUpButtonKey);

      expect(find.text('비밀번호는 72자 이하여야 합니다.'), findsOneWidget);
      // Snackbar가 아니라 입력칸의 에러 문구다(한 곳에만 보인다).
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(nicknameFieldKey), findsOneWidget); // 화면은 그대로
      expect(session.memberId, isNull);

      // 비밀번호를 고치기 시작하면 서버 오류 문구가 사라진다.
      await type(tester, passwordFieldKey, 'Aa1!${'x' * 10}');
      expect(find.text('비밀번호는 72자 이하여야 합니다.'), findsNothing);
    });

    testWidgets('최종 409는 Snackbar로 알리고, 사용 가능 확인이 풀려 가입 버튼이 꺼진다', (
      tester,
    ) async {
      await openSignUp(tester);
      await fillValidForm(tester);
      expect(signUpButton(tester).onPressed, isNotNull);

      api.takenEmails.add('kevin@umc.com'); // 확인 이후 누군가 먼저 가입했다
      await tapKey(tester, signUpButtonKey);

      expect(find.text('이미 사용 중인 이메일입니다.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(session.memberId, isNull);
      expect(find.byKey(nicknameFieldKey), findsOneWidget);
      // 다시 확인해야 한다.
      expect(find.text('사용할 수 있는 이메일이에요.'), findsNothing);
      expect(signUpButton(tester).onPressed, isNull);

      await tapKey(tester, emailCheckButtonKey);
      expect(find.text('이미 가입된 이메일이에요.'), findsOneWidget);
    });

    testWidgets('성공하면 세션에 memberId를 보관하고 영화 목록으로 간다', (tester) async {
      await openSignUp(tester);
      await fillValidForm(tester);
      await tapKey(tester, signUpButtonKey);
      await settle(tester);

      expect(session.memberId, 101);
      expect(find.byType(MovieListScreen), findsOneWidget);
    });

    testWidgets('제출 중에는 버튼이 로딩이고 뒤로가기가 막히며, 끝나면 다시 나갈 수 있다', (tester) async {
      api.writeGate = Completer<void>();
      await openSignUp(tester);
      await fillValidForm(tester);

      PopScope popScope() =>
          tester.widget<PopScope>(find.byKey(signUpPopScopeKey));
      expect(popScope().canPop, isTrue);

      await tester.ensureVisible(find.byKey(signUpButtonKey));
      await tester.tap(find.byKey(signUpButtonKey));
      await tester.pump(const Duration(milliseconds: 200));

      // 제출 중
      expect(popScope().canPop, isFalse);
      expect(
        find.descendant(
          of: find.byKey(signUpButtonKey),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(signUpButton(tester).onPressed, isNull);
      expect(await systemBack(tester), isTrue, reason: '뒤로가기를 화면이 삼켜야 한다');
      // 중복 탭: 눌리지 않아 요청이 한 번만 나간다.
      await tester.tap(find.byKey(signUpButtonKey), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(api.signUps, hasLength(1));

      // 응답이 오면(실패여도) 다시 나갈 수 있다.
      api.failures['signUp'] = FakeMovieLogApiService.badResponse(
        '/members',
        409,
        message: '이미 사용 중인 이메일입니다.',
      );
      api.writeGate!.complete();
      await settle(tester);
      expect(popScope().canPop, isTrue);
      expect(await systemBack(tester), isFalse, reason: '끝났으면 다시 나갈 수 있다');
      expect(find.text('이미 사용 중인 이메일입니다.'), findsOneWidget);
    });
  });
}
