import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/features/auth/presentation/login_screen.dart';
import 'package:movielog/features/home/presentation/home_screen.dart';
import 'package:movielog/features/my_page/presentation/edit_profile_screen.dart';
import 'package:movielog/features/my_page/presentation/my_page_screen.dart';

import 'support.dart';

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

  Future<void> openMy(WidgetTester tester) async {
    await tester.pumpWidget(h.app(initialLocation: AppRoutes.my));
    await settle(tester);
  }

  Future<void> openEdit(WidgetTester tester) async {
    await openMy(tester);
    await tester.tap(find.byKey(editProfileEntryKey));
    await settle(tester);
    expect(find.byKey(editNicknameFieldKey), findsOneWidget);
  }

  String textOf(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data!;

  String nicknameInput(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(editNicknameFieldKey))
      .controller!
      .text;

  /// 시스템 뒤로 가기를 Router에 보낸다. 화면이 처리하면 true.
  Future<bool> systemBack(WidgetTester tester) {
    final context = tester.element(find.byKey(editPopScopeKey));
    return Router.of(context).backButtonDispatcher!
        .invokeCallback(Future<bool>.value(false));
  }

  group('마이페이지: 내 정보', () {
    testWidgets('닉네임·이메일·가입일(YYYY.MM.DD 가입)을 보여준다', (tester) async {
      await openMy(tester);

      expect(textOf(tester, myPageNicknameKey), '케빈');
      expect(textOf(tester, myPageEmailKey), 'kevin@umc.com');
      expect(textOf(tester, myPageJoinedKey), '2026.10.10 가입');
      // 앱을 켜면서 세션 복원으로 이미 받았으므로 마이페이지가 다시 요청하지 않는다.
      expect(h.memberApi.fetchCalls, 1);
    });

    testWidgets('한 자리 월·일은 0을 채운다', (tester) async {
      h = AppHarness(
        member: MemberInfo(
          email: 'kevin@umc.com',
          nickname: '케빈',
          createdAt: DateTime(2026, 3, 5, 12),
        ),
      );
      await openMy(tester);
      expect(textOf(tester, myPageJoinedKey), '2026.03.05 가입');
    });

    testWidgets('로그인 직후에는 내 정보를 받는 동안 로딩을 보여주고 완료되면 내용이 보인다', (tester) async {
      h.storage.token = null;
      await tester.pumpWidget(h.app());
      await settle(tester);
      h.memberApi.meGate = Completer<void>();
      await tester.enterText(find.byKey(loginEmailFieldKey), 'kevin@umc.com');
      await tester.enterText(
        find.byKey(loginPasswordFieldKey),
        'Password1234!',
      );
      await tester.tap(find.byKey(loginButtonKey));
      await settle(tester);
      await settle(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.text('마이페이지'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(myPageLoadingKey), findsOneWidget);
      expect(find.byKey(myPageNicknameKey), findsNothing);

      h.memberApi.meGate!.complete();
      await settle(tester);
      expect(find.byKey(myPageLoadingKey), findsNothing);
      expect(textOf(tester, myPageNicknameKey), '케빈');
      expect(h.memberApi.fetchCalls, 1, reason: '로그인 뒤 한 번만 요청한다');
    });

    testWidgets('내 정보를 못 받으면 오류와 다시 시도 버튼이 보이고 로그인은 유지되며, 재시도로 복구된다', (
      tester,
    ) async {
      h.storage.token = null;
      await tester.pumpWidget(h.app());
      await settle(tester);
      h.memberApi.meFailure = networkFailure('/members/me');
      await tester.enterText(find.byKey(loginEmailFieldKey), 'kevin@umc.com');
      await tester.enterText(
        find.byKey(loginPasswordFieldKey),
        'Password1234!',
      );
      await tester.tap(find.byKey(loginButtonKey));
      await settle(tester);
      await settle(tester);
      await tester.tap(find.text('마이페이지'));
      await settle(tester);

      expect(find.byKey(myPageErrorKey), findsOneWidget);
      expect(find.text('내 정보를 불러오지 못했어요.'), findsOneWidget);
      expect(find.byKey(myPageNicknameKey), findsNothing);
      expect(authOf(tester).isSignedIn, isTrue);
      expect(h.storage.token, isNotNull);
      // 프로필 수정 진입 행은 내용이 있을 때만 보인다.
      expect(find.byKey(editProfileEntryKey), findsNothing);

      h.memberApi.meFailure = null;
      await tester.tap(find.byKey(myPageRetryKey));
      await settle(tester);
      expect(find.byKey(myPageErrorKey), findsNothing);
      expect(textOf(tester, myPageNicknameKey), '케빈');
    });

    testWidgets('다른 탭에 다녀와도 내 정보를 다시 요청하지 않는다', (tester) async {
      await openMy(tester);
      await tester.tap(find.text('홈'));
      await settle(tester);
      await tester.tap(find.text('마이페이지'));
      await settle(tester);
      expect(textOf(tester, myPageNicknameKey), '케빈');
      expect(h.memberApi.fetchCalls, 1);
    });
  });

  group('프로필 수정', () {
    testWidgets('이메일은 읽기 전용이고 닉네임 칸에는 현재 닉네임이 채워져 있다', (tester) async {
      await openEdit(tester);

      final email = tester.widget<TextFormField>(find.byKey(editEmailFieldKey));
      expect(email.enabled, isFalse);
      expect(email.initialValue, 'kevin@umc.com');
      expect(nicknameInput(tester), '케빈');
      // 하단 NavigationBar를 가린 자식 화면이다.
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('새 닉네임을 저장하면 마이페이지로 돌아가 바로 새 닉네임이 보인다', (tester) async {
      await openEdit(tester);
      await tester.enterText(find.byKey(editNicknameFieldKey), '새닉네임');
      await tester.pump();
      await tester.tap(find.byKey(editSaveButtonKey));
      await settle(tester);

      expect(h.memberApi.updatedNicknames, ['새닉네임']);
      expect(find.byKey(editNicknameFieldKey), findsNothing);
      expect(find.text('프로필을 수정했어요.'), findsOneWidget);
      expect(textOf(tester, myPageNicknameKey), '새닉네임');
      // 저장 뒤에는 "변경한 내용이 있어요" 확인이 뜨지 않는다.
      expect(find.text('변경한 내용이 있어요'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('닉네임을 바꾸지 않고 저장하면 요청을 보내지 않고 돌아간다', (tester) async {
      await openEdit(tester);
      await tester.tap(find.byKey(editSaveButtonKey));
      await settle(tester);
      expect(h.memberApi.updatedNicknames, isEmpty);
      expect(find.byKey(editNicknameFieldKey), findsNothing);
    });

    testWidgets('너무 짧은 닉네임은 입력칸에 오류를 보이고 요청하지 않으며, 고치면 오류가 지워진다', (
      tester,
    ) async {
      await openEdit(tester);
      await tester.enterText(find.byKey(editNicknameFieldKey), '가');
      await tester.pump();
      await tester.tap(find.byKey(editSaveButtonKey));
      await settle(tester);

      expect(find.text('닉네임은 2~12자로 입력해 주세요.'), findsOneWidget);
      expect(h.memberApi.updatedNicknames, isEmpty);
      expect(find.byKey(editNicknameFieldKey), findsOneWidget);

      await tester.enterText(find.byKey(editNicknameFieldKey), '가나');
      await tester.pump();
      expect(find.text('닉네임은 2~12자로 입력해 주세요.'), findsNothing);
    });

    testWidgets('이미 쓰는 닉네임(409)은 입력칸에 오류를 붙이고 입력값을 유지하며 로그인도 유지한다', (
      tester,
    ) async {
      await openEdit(tester);
      await tester.enterText(find.byKey(editNicknameFieldKey), '수현');
      await tester.pump();
      await tester.tap(find.byKey(editSaveButtonKey));
      await settle(tester);

      expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
      expect(nicknameInput(tester), '수현', reason: '입력값은 유지된다');
      expect(find.byKey(editNicknameFieldKey), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(authOf(tester).isSignedIn, isTrue);
      expect(authOf(tester).member?.nickname, '케빈');

      // 다시 입력하면 오류가 지워지고 다시 저장할 수 있다.
      await tester.enterText(find.byKey(editNicknameFieldKey), '수현2');
      await tester.pump();
      expect(find.text('이미 사용 중인 닉네임이에요.'), findsNothing);
      await tester.tap(find.byKey(editSaveButtonKey));
      await settle(tester);
      expect(textOf(tester, myPageNicknameKey), '수현2');
    });

    testWidgets('통신 실패는 Snackbar로 알리고 입력과 로그인을 유지한다', (tester) async {
      await openEdit(tester);
      h.memberApi.updateFailure = networkFailure('/members/me');
      await tester.enterText(find.byKey(editNicknameFieldKey), '새닉네임');
      await tester.pump();
      await tester.tap(find.byKey(editSaveButtonKey));
      await settle(tester);

      expect(find.text('네트워크 상태를 확인하고 다시 시도해 주세요.'), findsOneWidget);
      expect(nicknameInput(tester), '새닉네임');
      expect(find.byKey(editNicknameFieldKey), findsOneWidget);
      expect(authOf(tester).isSignedIn, isTrue);
      expect(h.storage.token, isNotNull);

      // 실패 안내 Snackbar가 [저장] 버튼을 가리지 않는다(실제 화면에서 가렸던 문제의 회귀 방지).
      // (SnackBar 위젯 자체의 영역에는 floating margin이 포함되므로, 눈에 보이는 Material을 잰다.)
      final snackBar = tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      final saveButton = tester.getRect(find.byKey(editSaveButtonKey));
      expect(
        snackBar.bottom,
        lessThanOrEqualTo(saveButton.top),
        reason: 'Snackbar($snackBar)가 저장 버튼($saveButton) 위에 있어야 한다',
      );

      // 서버가 돌아오면, Snackbar가 사라지기를 기다리지 않고 같은 입력으로 바로 다시 저장한다.
      h.memberApi.updateFailure = null;
      await tester.tap(find.byKey(editSaveButtonKey));
      await settle(tester);
      expect(textOf(tester, myPageNicknameKey), '새닉네임');
    });

    testWidgets('토큰이 만료(AUTH401_3)됐으면 로그인 화면으로 가서 만료를 안내한다', (tester) async {
      await openEdit(tester);
      h.memberApi.updateFailure = apiFailure(
        '/members/me',
        401,
        code: 'AUTH401_3',
        message: '토큰이 만료되었습니다.',
      );
      await tester.enterText(find.byKey(editNicknameFieldKey), '새닉네임');
      await tester.pump();
      await tester.tap(find.byKey(editSaveButtonKey));
      await settle(tester);

      expect(currentLocation(tester), AppRoutes.login);
      expect(h.storage.token, isNull);
      expect(find.text(sessionExpiredMessage), findsOneWidget);
      expect(find.byKey(editNicknameFieldKey), findsNothing);
    });

    testWidgets('저장 중에는 입력이 잠기고 뒤로 갈 수 없으며 중복 탭은 요청 한 번뿐이다', (tester) async {
      await openEdit(tester);
      h.memberApi.updateGate = Completer<void>();
      await tester.enterText(find.byKey(editNicknameFieldKey), '새닉네임');
      await tester.pump();
      await tester.tap(find.byKey(editSaveButtonKey));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        tester.widget<PopScope>(find.byKey(editPopScopeKey)).canPop,
        isFalse,
      );
      expect(
        tester.widget<TextField>(find.byKey(editNicknameFieldKey)).enabled,
        isFalse,
      );
      expect(await systemBack(tester), isTrue, reason: '저장 중 뒤로 가기는 화면이 삼킨다');
      expect(find.byKey(editNicknameFieldKey), findsOneWidget);
      expect(
        find.text('변경한 내용이 있어요'),
        findsNothing,
        reason: '저장 중에는 확인 Dialog도 띄우지 않는다',
      );
      await tester.tap(find.byKey(editSaveButtonKey), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(h.memberApi.updatedNicknames, hasLength(1));

      h.memberApi.updateGate!.complete();
      await settle(tester);
      expect(find.byKey(editNicknameFieldKey), findsNothing);
      expect(textOf(tester, myPageNicknameKey), '새닉네임');
    });

    testWidgets('변경한 내용이 있는데 뒤로 가면 확인을 묻고, 계속 수정하면 입력이 유지된다', (tester) async {
      await openEdit(tester);
      await tester.enterText(find.byKey(editNicknameFieldKey), '바꾼닉네임');
      await tester.pump();

      expect(await systemBack(tester), isTrue);
      await settle(tester);
      expect(find.text('변경한 내용이 있어요'), findsOneWidget);

      await tester.tap(find.byKey(leaveStayKey));
      await settle(tester);
      expect(find.text('변경한 내용이 있어요'), findsNothing);
      expect(find.byKey(editNicknameFieldKey), findsOneWidget);
      expect(nicknameInput(tester), '바꾼닉네임');
      expect(h.memberApi.updatedNicknames, isEmpty);
    });

    testWidgets('나가기를 누르면 저장하지 않고 마이페이지로 돌아가 닉네임은 그대로다', (tester) async {
      await openEdit(tester);
      await tester.enterText(find.byKey(editNicknameFieldKey), '바꾼닉네임');
      await tester.pump();

      await systemBack(tester);
      await settle(tester);
      await tester.tap(find.byKey(leaveConfirmKey));
      await settle(tester);

      expect(find.byKey(editNicknameFieldKey), findsNothing);
      expect(textOf(tester, myPageNicknameKey), '케빈');
      expect(h.memberApi.updatedNicknames, isEmpty);
    });

    testWidgets('변경이 없으면 확인 없이 바로 나간다', (tester) async {
      await openEdit(tester);
      await systemBack(tester);
      await settle(tester);
      expect(find.text('변경한 내용이 있어요'), findsNothing);
      expect(find.byKey(editNicknameFieldKey), findsNothing);
      expect(find.byKey(myPageNicknameKey), findsOneWidget);
    });

    testWidgets('앞뒤 공백만 바꾼 입력은 변경으로 보지 않는다', (tester) async {
      await openEdit(tester);
      await tester.enterText(find.byKey(editNicknameFieldKey), '  케빈  ');
      await tester.pump();
      await systemBack(tester);
      await settle(tester);
      expect(find.text('변경한 내용이 있어요'), findsNothing);
      expect(find.byKey(editNicknameFieldKey), findsNothing);
    });

    testWidgets('주소로 직접 열었는데 내 정보가 없으면 수정 칸 대신 로딩을 보여준다', (tester) async {
      h.storage.token = null;
      await tester.pumpWidget(h.app());
      await settle(tester);
      h.memberApi.meGate = Completer<void>();
      await tester.enterText(find.byKey(loginEmailFieldKey), 'kevin@umc.com');
      await tester.enterText(
        find.byKey(loginPasswordFieldKey),
        'Password1234!',
      );
      await tester.tap(find.byKey(loginButtonKey));
      await settle(tester);
      await settle(tester);

      goTo(tester, AppRoutes.editProfile);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(editNicknameFieldKey), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      h.memberApi.meGate!.complete();
      await settle(tester);
      expect(find.byKey(editNicknameFieldKey), findsOneWidget);
    });
  });
}
