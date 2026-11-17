import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/features/sign_up/presentation/sign_up_screen.dart';

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

  late FakeTmdbMovieService tmdb;
  late FakeMovieLogApiService api;

  setUp(() {
    tmdb = FakeTmdbMovieService();
    api = FakeMovieLogApiService();
  });

  Future<void> openSignUp(WidgetTester tester) => tester.pumpWidget(
    MovieLogApp(
      initialLocation: AppRoutes.signUp,
      tmdbService: tmdb,
      movieLogApiService: api,
      preferences: MemoryMoviePreferences(),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  ElevatedButton buttonOf(WidgetTester tester, Key key) =>
      tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(ElevatedButton),
        ),
      );

  /// 입력창의 errorText. 서버 쪽 오류(중복 등)가 ViewModel에서 여기로 연결된다.
  String? errorTextOf(WidgetTester tester, Key fieldKey) => tester
      .widget<InputDecorator>(
        find.descendant(
          of: find.byKey(fieldKey),
          matching: find.byType(InputDecorator),
        ),
      )
      .decoration
      .errorText;

  Future<void> type(WidgetTester tester, Key key, String text) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.enterText(find.byKey(key), text);
    await tester.pump();
  }

  Future<void> tapCheck(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await settle(tester);
  }

  testWidgets('중복 확인 버튼은 입력창 바깥 오른쪽에 8px 띄워 나란히 놓인다', (tester) async {
    await openSignUp(tester);
    await tester.pump();

    for (final (field, button) in [
      (nicknameFieldKey, nicknameCheckButtonKey),
      (emailFieldKey, emailCheckButtonKey),
    ]) {
      final fieldRect = tester.getRect(find.byKey(field));
      final buttonRect = tester.getRect(find.byKey(button));
      expect(buttonRect.left - fieldRect.right, 8); // 겹치지 않고 8px 간격
      expect(buttonRect.top, lessThanOrEqualTo(fieldRect.bottom));
      expect(buttonRect.bottom, greaterThan(fieldRect.top));
    }
  });

  testWidgets('가입하기 버튼은 Form 전체 너비(double.infinity)를 쓴다', (tester) async {
    await openSignUp(tester);
    await tester.pump();
    final signUp = find.byKey(signUpButtonKey);
    await tester.ensureVisible(signUp);
    // 화면 폭 390 − 좌우 패딩 24×2
    expect(tester.getSize(signUp).width, 342);
    // 보조 버튼은 내용 기반 크기라 훨씬 좁다.
    expect(
      tester.getSize(find.byKey(nicknameCheckButtonKey)).width,
      lessThan(150),
    );
  });

  testWidgets('확인 전 · 통신 중 · 사용 가능 · 중복 네 상태가 구분되어 보인다', (tester) async {
    await openSignUp(tester);
    await tester.pump();

    // 1) 확인 전: 형식이 맞아야 버튼이 켜진다.
    expect(buttonOf(tester, nicknameCheckButtonKey).onPressed, isNull);
    await type(tester, nicknameFieldKey, '케빈');
    expect(buttonOf(tester, nicknameCheckButtonKey).onPressed, isNotNull);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(errorTextOf(tester, nicknameFieldKey), isNull);

    // 2) 통신 중: 인디케이터만 보이고 버튼이 비활성
    api.gate = Completer<void>();
    await tester.tap(find.byKey(nicknameCheckButtonKey));
    await tester.pump(const Duration(milliseconds: 200));
    final button = find.byKey(nicknameCheckButtonKey);
    expect(
      find.descendant(
        of: button,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: button, matching: find.text('중복 확인')),
      findsNothing,
    );
    expect(buttonOf(tester, nicknameCheckButtonKey).onPressed, isNull);

    // 3) 사용 가능: 입력창 안쪽 체크 표시와 안내 문구
    api.gate!.complete();
    await settle(tester);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('사용할 수 있는 닉네임이에요.'), findsOneWidget);
    expect(errorTextOf(tester, nicknameFieldKey), isNull);
    expect(buttonOf(tester, nicknameCheckButtonKey).onPressed, isNotNull);
    expect(
      find.descendant(
        of: find.byKey(nicknameCheckButtonKey),
        matching: find.text('중복 확인'),
      ),
      findsOneWidget,
    );

    // 4) 중복: 입력창이 에러 상태가 되고 버튼이 즉시 비활성
    api.gate = null;
    await type(tester, nicknameFieldKey, '수현');
    await tapCheck(tester, nicknameCheckButtonKey);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(errorTextOf(tester, nicknameFieldKey), '이미 사용 중인 닉네임이에요.');
    expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
    expect(buttonOf(tester, nicknameCheckButtonKey).onPressed, isNull);
  });

  testWidgets('입력을 바꾸면 이전 결과가 즉시 사라지고 버튼이 다시 눌린다', (tester) async {
    await openSignUp(tester);
    await type(tester, nicknameFieldKey, '수현');
    await tapCheck(tester, nicknameCheckButtonKey);
    expect(errorTextOf(tester, nicknameFieldKey), isNotNull);

    await type(tester, nicknameFieldKey, '수현이');

    expect(errorTextOf(tester, nicknameFieldKey), isNull);
    expect(buttonOf(tester, nicknameCheckButtonKey).onPressed, isNotNull);

    // 사용 가능 확인 뒤에도 입력을 바꾸면 체크 표시와 안내가 사라진다.
    await tapCheck(tester, nicknameCheckButtonKey);
    expect(find.text('사용할 수 있는 닉네임이에요.'), findsOneWidget);
    await type(tester, nicknameFieldKey, '수현이2');
    expect(find.text('사용할 수 있는 닉네임이에요.'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('중복이었던 문구를 그대로 다시 입력하면 서버에 묻지 않고 즉시 에러로 돌아간다', (tester) async {
    await openSignUp(tester);
    await type(tester, nicknameFieldKey, '수현');
    await tapCheck(tester, nicknameCheckButtonKey);
    await type(tester, nicknameFieldKey, '수현이');
    expect(api.checkedNicknames, ['수현']);

    await type(tester, nicknameFieldKey, '수현');

    expect(errorTextOf(tester, nicknameFieldKey), '이미 사용 중인 닉네임이에요.');
    expect(buttonOf(tester, nicknameCheckButtonKey).onPressed, isNull);
    expect(api.checkedNicknames, ['수현']); // 요청이 나가지 않았다
  });

  testWidgets('통신 실패와 정상 중복 응답은 다른 문구로 보인다', (tester) async {
    await openSignUp(tester);
    await type(tester, nicknameFieldKey, '수현');
    await tapCheck(tester, nicknameCheckButtonKey);
    final duplicated = errorTextOf(tester, nicknameFieldKey);

    api.fail = true;
    await type(tester, nicknameFieldKey, '케빈');
    await tapCheck(tester, nicknameCheckButtonKey);
    final failed = errorTextOf(tester, nicknameFieldKey);

    expect(duplicated, '이미 사용 중인 닉네임이에요.');
    expect(failed, '네트워크 상태를 확인하고 다시 시도해 주세요.');
    // 입력창 폭이 좁아도 안내 문구가 "다시 …"처럼 말줄임으로 잘리지 않아야 한다.
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('네트워크 상태를 확인하고 다시 시도해 주세요.'),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    // 통신 실패는 같은 값으로 다시 눌러 볼 수 있다.
    expect(buttonOf(tester, nicknameCheckButtonKey).onPressed, isNotNull);
  });

  testWidgets('이메일 입력란에도 같은 규칙이 적용되고 닉네임과 서로 영향을 주지 않는다', (tester) async {
    await openSignUp(tester);
    await type(tester, nicknameFieldKey, '케빈');
    await tapCheck(tester, nicknameCheckButtonKey);
    await type(tester, emailFieldKey, 'noco@umc.com');
    await tapCheck(tester, emailCheckButtonKey);

    expect(errorTextOf(tester, emailFieldKey), '이미 가입된 이메일이에요.');
    expect(buttonOf(tester, emailCheckButtonKey).onPressed, isNull);
    // 닉네임 결과는 그대로
    expect(find.text('사용할 수 있는 닉네임이에요.'), findsOneWidget);
    expect(errorTextOf(tester, nicknameFieldKey), isNull);

    await type(tester, emailFieldKey, 'noco2@umc.com');
    expect(errorTextOf(tester, emailFieldKey), isNull);
    expect(buttonOf(tester, emailCheckButtonKey).onPressed, isNotNull);
    await type(tester, emailFieldKey, 'noco@umc.com');
    expect(errorTextOf(tester, emailFieldKey), '이미 가입된 이메일이에요.');
    expect(api.checkedEmails, ['noco@umc.com']);
  });

  testWidgets('형식이 틀린 값은 서버에 묻지 않는다', (tester) async {
    await openSignUp(tester);
    await type(tester, emailFieldKey, 'not-an-email');
    expect(buttonOf(tester, emailCheckButtonKey).onPressed, isNull);
    await type(tester, nicknameFieldKey, '가');
    expect(buttonOf(tester, nicknameCheckButtonKey).onPressed, isNull);
    expect(api.checkedEmails, isEmpty);
    expect(api.checkedNicknames, isEmpty);
  });
}
