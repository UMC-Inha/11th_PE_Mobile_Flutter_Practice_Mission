import 'package:flutter/foundation.dart';

/// 화면이 사라진(dispose) 뒤에는 `notifyListeners()`를 부르지 않게 막는 mixin.
///
/// 서버 응답은 늦게 도착할 수 있다. 그 사이 화면을 벗어났다면 이미 dispose된 ViewModel에
/// 알림을 보내 오류가 난다. ViewModel에 `with SafeNotify`를 붙이고, 비동기 작업 끝에서는
/// `notifyListeners()` 대신 [notifyIfAlive], 결과를 반영하기 전에는 [isDisposed]를 확인한다.
mixin SafeNotify on ChangeNotifier {
  bool _disposed = false;
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }
}
