/// [values]를 [concurrency]개씩만 동시에 [convert]하고, 결과를 입력과 같은 순서로 돌려준다.
///
/// `Future.wait(values.map(...))`은 요청을 한꺼번에 모두 보낸다. 즐겨찾기가 100개면 TMDB 요청
/// 100개가 동시에 나가므로, 작업자(worker) [concurrency]개가 하나씩 꺼내 처리하게 한다.
/// [convert]가 예외를 던지면 그대로 전파되므로, 항목별 실패는 호출하는 쪽에서 결과로 바꿔 준다.
Future<List<R>> mapBounded<T, R>(
  Iterable<T> values,
  int concurrency,
  Future<R> Function(T value) convert,
) async {
  final input = values.toList(growable: false);
  if (input.isEmpty) return <R>[];
  if (concurrency <= 0) {
    throw ArgumentError.value(concurrency, 'concurrency', 'must be positive');
  }
  final output = List<R?>.filled(input.length, null);
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= input.length) return;
      output[index] = await convert(input[index]);
    }
  }

  final workers = List.generate(
    concurrency.clamp(1, input.length),
    (_) => worker(),
  );
  await Future.wait(workers);
  return output.cast<R>();
}
