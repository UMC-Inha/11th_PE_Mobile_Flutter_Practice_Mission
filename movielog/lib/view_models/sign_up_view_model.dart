import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/view_models/load_error_message.dart';
import 'package:movielog/view_models/submit_status.dart';
import 'package:movielog/view_models/write_error_message.dart';

/// 중복 확인 한 칸(닉네임 또는 이메일)의 상태.
///
/// - idle: 아직 확인하지 않았거나, 입력이 바뀌어 이전 결과가 무효화된 상태
/// - checking: 요청이 진행 중인 상태
/// - available: 서버가 사용 가능하다고 응답한 상태
/// - duplicated: 서버가 이미 사용 중이라고 응답한 상태(`available: false`)
/// - error: 통신 자체가 실패한 상태(DioException, 타임아웃 등)
enum CheckStatus { idle, checking, available, duplicated, error }

/// 회원가입 화면 ViewModel. 닉네임·이메일 중복 체크를 자체 백엔드에 묻고,
/// 모든 입력이 유효하면 회원가입 POST를 보낸다.
///
/// 두 입력칸이 같은 화면에 있어도 상태는 칸마다 따로 가진다.
/// 하나로 합치면 닉네임 결과와 이메일 결과가 서로 영향을 주기 때문이다.
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(MovieLogApiService api) : _api = api {
    _nickname = _FieldCheck(
      request: (value) => api.checkNickname(value).then((r) => r.available),
      duplicatedMessage: '이미 사용 중인 닉네임이에요.',
      failureFallback: '확인하지 못했어요. 서버가 켜져 있는지 확인해 주세요.',
      notify: _notify,
    );
    _email = _FieldCheck(
      request: (value) => api.checkEmail(value).then((r) => r.available),
      duplicatedMessage: '이미 가입된 이메일이에요.',
      failureFallback: '확인하지 못했어요. 서버가 켜져 있는지 확인해 주세요.',
      notify: _notify,
    );
  }

  final MovieLogApiService _api;
  late final _FieldCheck _nickname;
  late final _FieldCheck _email;
  bool _disposed = false;

  /// 회원가입 제출 상태. submitting인 동안 중복 탭과 화면 이탈을 막는다.
  SubmitStatus submitStatus = SubmitStatus.idle;

  /// 가입 성공 응답에서 읽은 실제 memberId. 성공 전에는 null.
  int? createdMemberId;

  /// 비밀번호 입력칸에 바로 붙일 수 있는 서버 오류(필드 단위). TextFormField.errorText에 연결한다.
  String? passwordErrorText;

  /// 어느 입력칸에도 붙지 않는 서버 오류(화면 단위). 화면이 한 번 꺼내 Snackbar로 보여준다.
  String? snackbarMessage;

  bool get isSubmitting => submitStatus == SubmitStatus.submitting;

  CheckStatus get nicknameCheckStatus => _nickname.status;

  /// 중복(`available: false`)과 통신 실패의 문구가 서로 다르다. 없으면 null.
  String? get nicknameErrorText => _nickname.errorText;

  /// 통신 중이거나 이미 중복으로 확인된 값이면 다시 누를 수 없다.
  bool get canCheckNickname => _nickname.canCheck;

  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;

  /// 지금 입력값이 "사용 가능"으로 확인된 값 그대로인지. 가입 버튼 활성 조건에 쓴다.
  bool isNicknameConfirmed(String value) => _nickname.isConfirmed(value);
  bool isEmailConfirmed(String value) => _email.isConfirmed(value);

  void onNicknameChanged(String value) {
    snackbarMessage = null; // 이전 제출의 서버 오류도 함께 무효화한다.
    _nickname.onChanged(value);
  }

  void onEmailChanged(String value) {
    snackbarMessage = null;
    _email.onChanged(value);
  }

  /// 서버가 비밀번호를 거부한 뒤 사용자가 다시 입력하기 시작하면 오류 문구를 지운다.
  void onPasswordChanged() {
    if (passwordErrorText == null) return;
    passwordErrorText = null;
    _notify();
  }

  Future<void> checkNickname(String value) => _nickname.check(value);
  Future<void> checkEmail(String value) => _email.check(value);

  /// 회원가입 POST. 로컬 Form 검증과 두 중복 확인을 통과한 뒤에만 호출한다.
  ///
  /// 중복 확인 직후에도 다른 사용자가 같은 값을 가입할 수 있어서, 여기서 받는 409가
  /// 최종 중복 결과다. 400 중 비밀번호 형식 오류는 입력칸에, 그 밖의 400·409는 Snackbar에 담는다.
  Future<void> submit(CreateMemberRequest request) async {
    if (isSubmitting) return; // 요청 중 중복 탭은 무시한다.
    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    _notify();

    try {
      final response = await _api.signUp(request);
      if (_disposed) return;
      final id = response.result?.memberId;
      // 201인데 memberId가 없으면 가입을 완료한 것으로 표시하지 않고 계약 오류로 처리한다.
      if (id == null) throw StateError('회원가입 결과에 memberId가 없습니다.');
      createdMemberId = id;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      final status = error.response?.statusCode;
      final message = writeSignUpErrorMessage(error);
      if (status == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message;
      }
      if (status == 409) {
        // 확인 때는 사용 가능했던 값이 그 사이 쓰였다. 이전 확인 결과를 지워
        // 다시 확인하게 하고, 그때 서버가 알려 주는 "중복" 상태를 입력창에 붙인다.
        _nickname.resetConfirmation();
        _email.resetConfirmation();
      }
    } catch (_) {
      // StateError(계약 오류)뿐 아니라 파싱 실패 같은 예상 밖 오류도 submitting에 멈추지 않게 한다.
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nickname.invalidate();
    _email.invalidate();
    super.dispose();
  }
}

/// 한 입력칸의 중복 확인 규칙을 한곳에 모은 내부 객체.
class _FieldCheck {
  _FieldCheck({
    required this.request,
    required this.duplicatedMessage,
    required this.failureFallback,
    required this.notify,
  });

  /// 서버에 묻는다. 사용할 수 있으면 true.
  final Future<bool> Function(String value) request;
  final String duplicatedMessage;
  final String failureFallback;
  final VoidCallback notify;

  CheckStatus status = CheckStatus.idle;
  String? errorText;

  /// 지금 입력값(trim). 입력이 바뀔 때마다 갱신된다.
  String _current = '';

  /// 마지막으로 "중복"이라고 확인된 값. 마지막으로 "확인한" 값과 따로 기억해야
  /// 같은 값을 다시 입력했을 때 서버에 묻지 않고 곧바로 에러 상태로 돌아갈 수 있다.
  String? _duplicated;

  /// 마지막으로 "사용 가능"이라고 확인된 값.
  String? _available;

  /// 새 요청이나 입력 변경이 생길 때마다 올려, 늦게 도착한 이전 응답을 버린다.
  int _requestVersion = 0;

  bool get canCheck =>
      status != CheckStatus.checking && status != CheckStatus.duplicated;

  bool isConfirmed(String value) =>
      status == CheckStatus.available && _available == value.trim();

  /// 가입 요청이 이 값을 거부했을 때, "사용 가능"이던 확인 결과를 지워 다시 확인하게 한다.
  /// 이미 중복·오류로 표시된 칸은 건드리지 않는다.
  void resetConfirmation() {
    if (status != CheckStatus.available) return;
    status = CheckStatus.idle;
    _available = null;
    errorText = null;
    _requestVersion++;
  }

  void onChanged(String value) {
    final trimmed = value.trim();
    // 앞뒤 공백만 바뀐 입력은 이전 결과를 지우지 않는다.
    if (trimmed == _current) return;
    _current = trimmed;
    _requestVersion++; // 기다리던 이전 응답을 무효화한다.
    _available = null;

    if (_duplicated != null && trimmed == _duplicated) {
      // 서버에 다시 묻지 않고 곧바로 에러 상태와 문구를 복원한다.
      status = CheckStatus.duplicated;
      errorText = duplicatedMessage;
    } else {
      status = CheckStatus.idle;
      errorText = null;
    }
    notify();
  }

  Future<void> check(String value) async {
    final requested = value.trim();
    if (requested.isEmpty || requested != _current || !canCheck) return;

    final version = ++_requestVersion;
    status = CheckStatus.checking;
    errorText = null;
    notify();

    try {
      final available = await request(requested);
      if (_isStale(version, requested)) return;
      if (available) {
        status = CheckStatus.available;
        errorText = null;
        _available = requested;
      } else {
        status = CheckStatus.duplicated;
        errorText = duplicatedMessage;
        _duplicated = requested;
      }
    } catch (error) {
      // DioException뿐 아니라 파싱 실패도 "checking"에 멈춰 있지 않도록 에러로 돌린다.
      if (_isStale(version, requested)) return;
      status = CheckStatus.error;
      errorText = loadErrorMessage(error, fallback: failureFallback);
    }
    notify();
  }

  bool _isStale(int version, String requested) =>
      version != _requestVersion || requested != _current;

  /// 화면이 사라진 뒤 도착하는 응답이 상태를 건드리지 못하게 한다.
  void invalidate() => _requestVersion++;
}
