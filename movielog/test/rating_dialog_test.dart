import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/features/rating/presentation/widgets/movie_rating_dialog.dart';
import 'package:movielog/view_models/submit_status.dart';

const _openKey = Key('openDialog');

Finder _star(int index) => find
    .descendant(
      of: find.byType(MovieRatingDialog),
      matching: find.byIcon(Icons.star_rounded),
    )
    .at(index);

void main() {
  late List<({int score, String? comment})> submitted;
  late Future<void> Function(int score, String? comment) onSubmit;
  bool? result;
  bool resultReturned = false;

  setUp(() {
    submitted = [];
    result = null;
    resultReturned = false;
    onSubmit = (score, comment) async {
      submitted.add((score: score, comment: comment));
    };
  });

  Future<void> open(
    WidgetTester tester, {
    int initialScore = 0,
    String? initialComment,
    String title = '평점 남기기',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: _openKey,
              onPressed: () async {
                result = await showMovieRatingDialog(
                  context,
                  title: title,
                  movieTitle: '파이트 클럽',
                  initialScore: initialScore,
                  initialComment: initialComment,
                  onSubmit: (score, comment) => onSubmit(score, comment),
                );
                resultReturned = true;
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
  }

  ElevatedButton saveButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(saveRatingButtonKey),
          matching: find.byType(ElevatedButton),
        ),
      );

  TextField commentField(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(ratingCommentFieldKey));

  /// 시스템 뒤로가기(안드로이드 뒤로 버튼·iOS 스와이프 백). Dialog 라우트가 처리한다.
  Future<void> systemBack(WidgetTester tester) async {
    final dynamic app = tester.state(find.byType(WidgetsApp));
    await app.didPopRoute();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('별점 아래에 코멘트 입력칸이 있고, 별을 고르기 전에는 저장할 수 없다', (tester) async {
    await open(tester);

    expect(find.text('평점 남기기'), findsOneWidget);
    expect(find.text('별을 눌러 평점을 선택하세요'), findsOneWidget);
    expect(find.byKey(ratingCommentFieldKey), findsOneWidget);
    // 별점 위젯이 코멘트 입력칸보다 위에 있다.
    expect(
      tester.getTopLeft(_star(0)).dy,
      lessThan(tester.getTopLeft(find.byKey(ratingCommentFieldKey)).dy),
    );
    expect(saveButton(tester).onPressed, isNull);

    // 코멘트만 입력해도 저장할 수 없다.
    await tester.enterText(find.byKey(ratingCommentFieldKey), '좋았다');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);

    await tester.tap(_star(2));
    await tester.pump();
    expect(find.text('3점'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('코멘트는 최대 500자까지만 입력되고 별점을 눌러도 입력하던 내용이 유지된다', (tester) async {
    await open(tester);
    expect(commentField(tester).maxLength, 500);

    await tester.enterText(find.byKey(ratingCommentFieldKey), 'ㅋ' * 501);
    await tester.pump();
    expect(commentField(tester).controller!.text.length, 500);

    // 컨트롤러를 build()에서 만들면 별점을 고를 때마다 입력이 사라진다.
    await tester.enterText(find.byKey(ratingCommentFieldKey), '반전이 좋았다');
    await tester.tap(_star(4));
    await tester.pump();
    await tester.tap(_star(1));
    await tester.pump();
    expect(commentField(tester).controller!.text, '반전이 좋았다');
    expect(find.text('2점'), findsOneWidget);
  });

  testWidgets('저장하면 정수 score와 trim한 코멘트를 넘기고 true로 닫힌다', (tester) async {
    await open(tester);
    await tester.tap(_star(3));
    await tester.pump();
    await tester.enterText(find.byKey(ratingCommentFieldKey), '  다시 보고 싶다  ');
    await tester.tap(find.byKey(saveRatingButtonKey));
    await tester.pumpAndSettle();

    expect(submitted, [(score: 4, comment: '다시 보고 싶다')]);
    expect(find.byType(MovieRatingDialog), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('공백뿐인 코멘트는 null로 바꿔 보낸다', (tester) async {
    await open(tester);
    await tester.tap(_star(0));
    await tester.pump();
    await tester.enterText(find.byKey(ratingCommentFieldKey), '   ');
    await tester.tap(find.byKey(saveRatingButtonKey));
    await tester.pumpAndSettle();
    expect(submitted.single.comment, isNull);
  });

  testWidgets('취소하면 저장 요청 없이 false로 닫힌다', (tester) async {
    await open(tester);
    await tester.tap(_star(2));
    await tester.pump();
    await tester.tap(find.byKey(cancelRatingButtonKey));
    await tester.pumpAndSettle();

    expect(submitted, isEmpty);
    expect(result, isFalse);
    expect(find.byType(MovieRatingDialog), findsNothing);
  });

  testWidgets('저장 중에는 로딩 버튼, 입력 잠금, 이탈 방지(바깥 탭·뒤로가기)가 모두 걸린다', (tester) async {
    final gate = Completer<void>();
    onSubmit = (score, comment) async {
      submitted.add((score: score, comment: comment));
      await gate.future;
    };
    await open(tester);
    await tester.tap(_star(3));
    await tester.pump();
    await tester.enterText(find.byKey(ratingCommentFieldKey), '저장 중');
    await tester.tap(find.byKey(saveRatingButtonKey));
    await tester.pump(const Duration(milliseconds: 100));

    // 로딩: 인디케이터만 보이고 눌리지 않는다.
    expect(
      find.descendant(
        of: find.byKey(saveRatingButtonKey),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(saveButton(tester).onPressed, isNull);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(cancelRatingButtonKey))
          .onPressed,
      isNull,
    );
    // 입력 잠금: 코멘트 입력칸이 꺼지고 별을 눌러도 바뀌지 않는다.
    expect(commentField(tester).enabled, isFalse);
    await tester.tap(_star(0), warnIfMissed: false);
    await tester.pump();
    expect(find.text('4점'), findsOneWidget);
    // 두 번 눌러도 요청은 한 번이다.
    await tester.tap(find.byKey(saveRatingButtonKey), warnIfMissed: false);
    await tester.pump();
    expect(submitted, hasLength(1));

    // 이탈 방지: PopScope canPop=false, 바깥 탭(barrierDismissible=false), 시스템 뒤로가기.
    expect(
      tester.widget<PopScope>(find.byKey(ratingDialogPopScopeKey)).canPop,
      isFalse,
    );
    await tester.tapAt(const Offset(4, 4)); // Dialog 바깥(배리어)
    // 저장 중 인디케이터는 계속 도므로 pumpAndSettle 대신 시간만 흘려보낸다.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MovieRatingDialog), findsOneWidget);
    await systemBack(tester);
    expect(find.byType(MovieRatingDialog), findsOneWidget);
    expect(resultReturned, isFalse);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(MovieRatingDialog), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('저장하지 않을 때는 바깥 탭으로 닫히지 않는다(barrierDismissible: false)', (
    tester,
  ) async {
    await open(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(MovieRatingDialog), findsOneWidget);
  });

  testWidgets('저장 실패: 서버 문구를 Dialog에 보여주고 입력은 유지하며 버튼이 풀려 다시 시도할 수 있다', (
    tester,
  ) async {
    var fail = true;
    onSubmit = (score, comment) async {
      submitted.add((score: score, comment: comment));
      if (fail) throw const RatingSaveException('이미 이 영화에 평점을 남기셨습니다.');
    };
    await open(tester);
    await tester.tap(_star(3));
    await tester.pump();
    await tester.enterText(find.byKey(ratingCommentFieldKey), '지우면 안 되는 코멘트');
    await tester.tap(find.byKey(saveRatingButtonKey));
    await tester.pumpAndSettle();

    // 닫히지 않고, 서버가 준 문구가 보인다.
    expect(find.byType(MovieRatingDialog), findsOneWidget);
    expect(find.text('이미 이 영화에 평점을 남기셨습니다.'), findsOneWidget);
    // 입력은 그대로다.
    expect(find.text('4점'), findsOneWidget);
    expect(commentField(tester).controller!.text, '지우면 안 되는 코멘트');
    // 버튼은 로딩에 멈추지 않고 다시 눌린다.
    expect(
      find.descendant(
        of: find.byKey(saveRatingButtonKey),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(saveButton(tester).onPressed, isNotNull);
    expect(commentField(tester).enabled, isTrue);
    expect(resultReturned, isFalse);

    // 같은 값으로 다시 시도하면 오류 문구가 지워지고 성공한다.
    fail = false;
    await tester.tap(find.byKey(saveRatingButtonKey));
    await tester.pumpAndSettle();
    expect(submitted, hasLength(2));
    expect(submitted.last, (score: 4, comment: '지우면 안 되는 코멘트'));
    expect(result, isTrue);
  });

  testWidgets('서버 문구가 없는 예외는 기본 안내를 보여준다', (tester) async {
    onSubmit = (score, comment) async => throw StateError('boom');
    await open(tester);
    await tester.tap(_star(1));
    await tester.pump();
    await tester.tap(find.byKey(saveRatingButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('저장하지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('수정 모드: 기존 별점과 코멘트가 채워진 채로 열린다', (tester) async {
    await open(
      tester,
      title: '평점 수정하기',
      initialScore: 3,
      initialComment: '기존 코멘트',
    );
    expect(find.text('평점 수정하기'), findsOneWidget);
    expect(find.text('3점'), findsOneWidget);
    expect(commentField(tester).controller!.text, '기존 코멘트');
    // 바꾸지 않고도 바로 저장할 수 있다.
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('수정 모드: comment가 null이면 코멘트 칸은 빈 채로 시작한다', (tester) async {
    await open(tester, initialScore: 5, initialComment: null);
    expect(commentField(tester).controller!.text, isEmpty);
    expect(find.text('5점'), findsOneWidget);
  });

  testWidgets('초기화하고 다시 선택하면 별점이 0으로 돌아가 저장할 수 없다', (tester) async {
    await open(tester, initialScore: 4, initialComment: '유지');
    await tester.tap(find.byKey(resetRatingButtonKey));
    await tester.pump();
    expect(find.text('별을 눌러 평점을 선택하세요'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    expect(commentField(tester).controller!.text, '유지'); // 코멘트는 건드리지 않는다
  });
}
