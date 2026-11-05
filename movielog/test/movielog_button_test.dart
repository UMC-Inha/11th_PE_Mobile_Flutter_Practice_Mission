import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/widgets/movielog_button.dart';

const _buttonKey = Key('button');

Widget host(Widget child, {double width = 400}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

ElevatedButton elevated(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton));

void main() {
  group('상태', () {
    testWidgets('기본: label이 보이고 눌린다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        host(MovieLogButton(label: '중복 확인', onPressed: () => pressed++)),
      );

      expect(find.text('중복 확인'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(elevated(tester).onPressed, isNotNull);

      await tester.tap(find.byType(MovieLogButton));
      expect(pressed, 1);
    });

    testWidgets('통신 중: 인디케이터만 보이고, onPressed가 있어도 눌리지 않는다', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        host(
          MovieLogButton(
            label: '중복 확인',
            isLoading: true,
            onPressed: () => pressed++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // label과 인디케이터를 동시에 그리지 않는다.
      expect(find.text('중복 확인'), findsNothing);
      expect(elevated(tester).onPressed, isNull);

      await tester.tap(find.byType(MovieLogButton), warnIfMissed: false);
      expect(pressed, 0);
    });

    testWidgets('비활성: onPressed가 null이면 label은 보이지만 눌리지 않는다', (tester) async {
      await tester.pumpWidget(
        host(const MovieLogButton(label: '가입하기', onPressed: null)),
      );

      expect(find.text('가입하기'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(elevated(tester).onPressed, isNull);
    });

    testWidgets('통신 중과 비활성은 같은 비활성 배경색을 쓴다', (tester) async {
      await tester.pumpWidget(
        host(const MovieLogButton(label: 'a', onPressed: null)),
      );
      final disabled = elevated(tester).style!.backgroundColor!
          .resolve({WidgetState.disabled});

      await tester.pumpWidget(
        host(MovieLogButton(label: 'a', isLoading: true, onPressed: () {})),
      );
      final loading = elevated(tester).style!.backgroundColor!
          .resolve({WidgetState.disabled});

      expect(loading, disabled);
      final enabled = elevated(tester).style!.backgroundColor!.resolve({});
      expect(enabled, isNot(disabled));
    });
  });

  group('너비', () {
    testWidgets('null: label 길이에 맞는 내용 기반 크기', (tester) async {
      await tester.pumpWidget(
        host(
          Row(
            children: [
              MovieLogButton(key: _buttonKey, label: '확인', onPressed: () {}),
            ],
          ),
        ),
      );
      final short = tester.getSize(find.byKey(_buttonKey)).width;

      await tester.pumpWidget(
        host(
          Row(
            children: [
              MovieLogButton(
                key: _buttonKey,
                label: '아주 길고 긴 중복 확인 버튼',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      final long = tester.getSize(find.byKey(_buttonKey)).width;

      expect(short, lessThan(400));
      expect(long, greaterThan(short)); // 내용에 따라 달라진다
      expect(long, lessThan(400));
    });

    testWidgets('double.infinity: 부모가 허용하는 최대 너비', (tester) async {
      await tester.pumpWidget(
        host(
          MovieLogButton(
            key: _buttonKey,
            label: '가입하기',
            width: double.infinity,
            onPressed: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.getSize(find.byKey(_buttonKey)).width, 320);

      await tester.pumpWidget(
        host(
          MovieLogButton(
            key: _buttonKey,
            label: '가입하기',
            width: double.infinity,
            onPressed: () {},
          ),
          width: 200,
        ),
      );
      expect(tester.getSize(find.byKey(_buttonKey)).width, 200);
    });

    testWidgets('고정 값: 주변과 상관없이 지정한 크기', (tester) async {
      for (final parentWidth in [200.0, 400.0]) {
        await tester.pumpWidget(
          host(
            Row(
              children: [
                MovieLogButton(
                  key: _buttonKey,
                  label: '확인',
                  width: 96,
                  onPressed: () {},
                ),
              ],
            ),
            width: parentWidth,
          ),
        );
        expect(tester.getSize(find.byKey(_buttonKey)).width, 96);
      }
    });

    testWidgets('높이는 기본 44, 지정하면 그 값', (tester) async {
      await tester.pumpWidget(
        host(MovieLogButton(key: _buttonKey, label: 'a', onPressed: () {})),
      );
      expect(tester.getSize(find.byKey(_buttonKey)).height, 44);

      await tester.pumpWidget(
        host(
          MovieLogButton(
            key: _buttonKey,
            label: 'a',
            height: 56,
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSize(find.byKey(_buttonKey)).height, 56);
    });

    testWidgets('자주 나는 오류: 너비 제약이 없는 Row 안의 double.infinity', (tester) async {
      await tester.pumpWidget(
        host(
          Row(
            children: [
              MovieLogButton(
                label: '가입하기',
                width: double.infinity,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      // Row는 자식에게 무한 너비를 허용하므로 "얼마나 넓혀야 할지" 기준이 없다.
      expect(tester.takeException(), isNotNull);
    });

    testWidgets('해결: Expanded로 먼저 너비를 정해 주면 오류 없이 남은 폭을 쓴다', (tester) async {
      await tester.pumpWidget(
        host(
          Row(
            children: [
              Expanded(
                child: MovieLogButton(
                  key: _buttonKey,
                  label: '가입하기',
                  width: double.infinity,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 80),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(_buttonKey)).width, 400 - 8 - 80);
    });
  });
}
