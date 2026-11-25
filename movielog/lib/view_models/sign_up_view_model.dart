import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/create_member_request.dart';
import '../data/services/sign_up_service.dart';
import 'submit_status.dart';

export 'submit_status.dart';

enum CheckStatus { idle, checking, available, duplicated, error }

/// 회원가입 화면의 닉네임·이메일 중복 확인 상태와 가입 제출 상태를 관리합니다.
/// 두 입력란은 서로 영향을 주지 않도록 필드별로 상태를 따로 둡니다.
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);
  final SignUpService _service;

  final _nickname = _DuplicateCheckField(duplicatedMessage: '이미 사용 중인 닉네임입니다.');
  final _email = _DuplicateCheckField(duplicatedMessage: '이미 가입된 이메일입니다.');

  bool _disposed = false;

  // ── 닉네임 ──────────────────────────────────────────────

  CheckStatus get nicknameCheckStatus => _nickname.status;
  String? get nicknameErrorText => _nickname.errorText;
  bool get canCheckNickname => _nickname.canCheck;

  void onNicknameChanged(String value) => _onChanged(_nickname, value);

  Future<void> checkNickname(String value) =>
      _check(_nickname, value, _service.checkNickname);

  // ── 이메일 ──────────────────────────────────────────────

  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;

  void onEmailChanged(String value) => _onChanged(_email, value);

  Future<void> checkEmail(String value) =>
      _check(_email, value, _service.checkEmail);

  // ── 회원가입 제출 ────────────────────────────────────────

  SubmitStatus submitStatus = SubmitStatus.idle;

  /// 가입 성공 응답 result에서 읽은 실제 memberId입니다.
  int? createdMemberId;

  /// 서버가 비밀번호 형식을 거부한 400입니다. 비밀번호 입력칸 아래에 표시합니다.
  String? passwordErrorText;

  /// 입력칸 하나에 붙일 수 없는 오류(409 중복, 그 외 400, 통신 실패)입니다. Snackbar로 표시합니다.
  String? snackbarMessage;

  bool get isSubmitting => submitStatus == SubmitStatus.submitting;

  void onPasswordChanged() {
    if (passwordErrorText == null) return;
    passwordErrorText = null;
    notifyListeners();
  }

  Future<void> submit(CreateMemberRequest request) async {
    if (isSubmitting) return;
    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    notifyListeners();

    try {
      final response = await _service.signUp(request);
      final id = response.result?.memberId;
      if (id == null) throw StateError('회원가입 결과에 memberId가 없습니다.');
      if (_disposed) return;
      createdMemberId = id;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      final message = writeSignUpErrorMessage(error);
      if (error.response?.statusCode == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message;
      }
    } on StateError {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    } on TypeError {
      // 성공 응답이 계약과 다른 모양이면 가입 완료로 표시하지 않습니다.
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    }
    notifyListeners();
  }

  // ── 공통 처리 ───────────────────────────────────────────

  /// 입력이 바뀌면 기다리던 이전 응답을 무효화합니다.
  /// 마지막으로 중복이었던 값과 같으면 API를 다시 부르지 않고 바로 중복 상태로 되돌립니다.
  /// 이전 가입 시도의 서버 오류(409 등)도 함께 지웁니다.
  void _onChanged(_DuplicateCheckField field, String value) {
    if (submitStatus == SubmitStatus.error) {
      submitStatus = SubmitStatus.idle;
      snackbarMessage = null;
    }
    final trimmed = value.trim();
    field.current = trimmed;
    field.requestVersion++;
    if (field.duplicatedValue != null && trimmed == field.duplicatedValue) {
      field.status = CheckStatus.duplicated;
      field.errorText = field.duplicatedMessage;
    } else {
      field.status = CheckStatus.idle;
      field.errorText = null;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _check(
    _DuplicateCheckField field,
    String value,
    Future<bool> Function(String) request,
  ) async {
    final requested = value.trim();
    if (requested.isEmpty || requested != field.current || !field.canCheck) {
      return;
    }

    final version = ++field.requestVersion;
    field.status = CheckStatus.checking;
    field.errorText = null;
    notifyListeners();

    // 화면을 떠났거나, 입력이 바뀌었거나, 더 새로운 요청이 있으면 응답을 버립니다.
    bool isStale() =>
        _disposed ||
        version != field.requestVersion ||
        field.current != requested;

    try {
      final available = await request(requested);
      if (isStale()) return;
      if (available) {
        field.status = CheckStatus.available;
        field.errorText = null;
      } else {
        // 서버가 정상 응답한 중복입니다. 통신 실패와 다른 문구를 사용합니다.
        field.status = CheckStatus.duplicated;
        field.errorText = field.duplicatedMessage;
        field.duplicatedValue = requested;
      }
    } on DioException {
      if (isStale()) return;
      field.status = CheckStatus.error;
      field.errorText = '중복 확인에 실패했습니다. 다시 시도해 주세요.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nickname.requestVersion++;
    _email.requestVersion++;
    super.dispose();
  }
}

/// 입력란 하나의 중복 확인 상태입니다.
class _DuplicateCheckField {
  _DuplicateCheckField({required this.duplicatedMessage});

  final String duplicatedMessage;

  CheckStatus status = CheckStatus.idle;
  String? errorText;

  /// 서버가 마지막으로 "중복"이라고 응답한 값입니다.
  String? duplicatedValue;

  /// 현재 입력창에 있는 값(trim)입니다.
  String current = '';
  int requestVersion = 0;

  bool get canCheck =>
      status != CheckStatus.checking && status != CheckStatus.duplicated;
}
