import 'package:flutter/foundation.dart';

/// 화면이 사라진(dispose) 뒤에는 notifyListeners()를 호출하지 않도록 막습니다.
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
