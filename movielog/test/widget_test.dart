import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/features/sign_up/presentation/sign_up_screen.dart';

void main() {
  testWidgets('유효한 입력과 약관 동의 후 가입 버튼이 활성화된다', (tester) async {
    await tester.pumpWidget(const MovieLogApp());

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

    expect(
      tester.widget<FilledButton>(find.byKey(signUpButtonKey)).onPressed,
      isNotNull,
    );
  });
}
