import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/widgets/movielog_button.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 300, child: child)),
    ),
  );
}

void main() {
  testWidgets('width가 null이면 내용, double.infinity면 부모 최대, 고정값이면 그 값만큼 차지한다',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(
      Column(
        children: [
          // Row의 마지막 자식처럼 너비를 강제하지 않는 자리에 둡니다.
          Row(
            children: [
              const Expanded(child: SizedBox()),
              MovieLogButton(key: const Key('null'), label: '중복 확인', onPressed: () {}),
            ],
          ),
          MovieLogButton(
            key: const Key('infinity'),
            label: '가입하기',
            width: double.infinity,
            onPressed: () {},
          ),
          Row(
            children: [
              MovieLogButton(
                key: const Key('fixed'),
                label: '확인',
                width: 96,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    ));

    final nullWidth = tester.getSize(find.byKey(const Key('null'))).width;
    expect(nullWidth, lessThan(300));
    expect(nullWidth, greaterThan(0));
    expect(tester.getSize(find.byKey(const Key('infinity'))).width, 300);
    expect(tester.getSize(find.byKey(const Key('fixed'))).width, 96);
  });

  testWidgets('기본 · 통신 중 · 비활성 상태를 구분한다', (WidgetTester tester) async {
    var tapped = 0;
    Future<void> pump({required bool isLoading, required bool enabled}) {
      return tester.pumpWidget(_host(MovieLogButton(
        label: '중복 확인',
        isLoading: isLoading,
        onPressed: enabled ? () => tapped++ : null,
      )));
    }

    ElevatedButton button() => tester.widget(find.byType(ElevatedButton));

    // 기본
    await pump(isLoading: false, enabled: true);
    await tester.tap(find.byType(ElevatedButton));
    expect(tapped, 1);
    expect(find.text('중복 확인'), findsOneWidget);

    // 통신 중: onPressed가 있어도 비활성이고 인디케이터만 보입니다.
    await pump(isLoading: true, enabled: true);
    expect(button().onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('중복 확인'), findsNothing);

    // 비활성
    await pump(isLoading: false, enabled: false);
    expect(button().onPressed, isNull);
    expect(find.text('중복 확인'), findsOneWidget);
  });
}
