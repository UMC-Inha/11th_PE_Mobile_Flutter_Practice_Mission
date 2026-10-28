import 'package:flutter/foundation.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/view_models/load_error_message.dart';

enum DuplicateCheckStatus { unchecked, checking, available, taken, failed }

class DuplicateCheckState {
  const DuplicateCheckState({
    this.status = DuplicateCheckStatus.unchecked,
    this.checkedValue,
    this.message,
  });

  final DuplicateCheckStatus status;

  /// 서버에 확인한 값. 입력이 이 값과 달라지면 다시 확인해야 한다.
  final String? checkedValue;
  final String? message;
}

/// 회원가입 화면 ViewModel. 닉네임·이메일 중복 체크를 자체 백엔드에 묻는다.
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._api);

  final MovieLogApiService _api;

  DuplicateCheckState nickname = const DuplicateCheckState();
  DuplicateCheckState email = const DuplicateCheckState();

  bool _disposed = false;

  bool isNicknameConfirmed(String value) => _confirmed(nickname, value);
  bool isEmailConfirmed(String value) => _confirmed(email, value);

  /// 확인한 뒤 입력을 고치면 확인 결과를 지운다.
  void onNicknameChanged(String value) {
    if (nickname.checkedValue != value.trim() &&
        nickname.status != DuplicateCheckStatus.unchecked) {
      nickname = const DuplicateCheckState();
      notifyListeners();
    }
  }

  void onEmailChanged(String value) {
    if (email.checkedValue != value.trim() &&
        email.status != DuplicateCheckStatus.unchecked) {
      email = const DuplicateCheckState();
      notifyListeners();
    }
  }

  Future<void> checkNickname(String value) async {
    final target = value.trim();
    nickname = DuplicateCheckState(
      status: DuplicateCheckStatus.checking,
      checkedValue: target,
    );
    notifyListeners();
    nickname = await _check(
      target,
      () => _api.checkNickname(target).then((r) => r.available),
      availableMessage: '사용할 수 있는 닉네임이에요.',
      takenMessage: '이미 사용 중인 닉네임이에요.',
    );
    if (!_disposed) notifyListeners();
  }

  Future<void> checkEmail(String value) async {
    final target = value.trim();
    email = DuplicateCheckState(
      status: DuplicateCheckStatus.checking,
      checkedValue: target,
    );
    notifyListeners();
    email = await _check(
      target,
      () => _api.checkEmail(target).then((r) => r.available),
      availableMessage: '사용할 수 있는 이메일이에요.',
      takenMessage: '이미 가입된 이메일이에요.',
    );
    if (!_disposed) notifyListeners();
  }

  Future<DuplicateCheckState> _check(
    String target,
    Future<bool> Function() request, {
    required String availableMessage,
    required String takenMessage,
  }) async {
    try {
      final available = await request();
      return DuplicateCheckState(
        status: available
            ? DuplicateCheckStatus.available
            : DuplicateCheckStatus.taken,
        checkedValue: target,
        message: available ? availableMessage : takenMessage,
      );
    } catch (error) {
      return DuplicateCheckState(
        status: DuplicateCheckStatus.failed,
        checkedValue: target,
        message: loadErrorMessage(
          error,
          fallback: '확인하지 못했어요. 서버가 켜져 있는지 확인해 주세요.',
        ),
      );
    }
  }

  bool _confirmed(DuplicateCheckState state, String value) =>
      state.status == DuplicateCheckStatus.available &&
      state.checkedValue == value.trim();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
