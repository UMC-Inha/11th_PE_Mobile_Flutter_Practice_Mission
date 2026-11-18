import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/view_models/load_error_message.dart';

/// 앱의 인증 상태.
/// - initializing: 앱을 켠 직후 저장된 토큰을 확인하는 중(이 동안은 시작 화면만 보인다)
/// - signedOut: 로그인하지 않은 상태(직접 로그아웃·만료·로그인 실패 포함)
/// - authenticating: 로그인 요청 중
/// - signedIn: 로그인된 상태. 앱 재시작은 GET /members/me가 성공한 뒤에만 이 상태가 된다.
/// - retryRequired: 토큰은 있는데 서버·저장소 문제로 확인하지 못한 상태(토큰은 지우지 않는다)
enum AuthStatus {
  initializing,
  signedOut,
  authenticating,
  signedIn,
  retryRequired,
}

enum MemberLoadStatus { idle, loading, success, error }

/// 로그인·세션 복원·로그아웃·만료 처리를 한곳에서 맡는 ViewModel.
///
/// **sessionVersion**: 로그인·복원·정리가 시작될 때마다 올라간다. 이전 세션에서 늦게 도착한
/// 응답(특히 401)이 새 세션을 지우거나 새 화면을 덮어쓰지 못하게, 비동기 작업은 시작 때의 값을
/// 기억해 두었다가 끝났을 때 지금 값과 같은지 확인한다.
///
/// 화면 이동은 이 ViewModel이 하지 않는다. 상태만 바꾸면 Router의 redirect가 이동시킨다.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authApi, this._memberApi, this._storage);

  final AuthApiService _authApi;
  final MemberApiService _memberApi;
  final TokenStorage _storage;

  AuthStatus status = AuthStatus.initializing;
  MemberInfo? member;
  MemberLoadStatus memberStatus = MemberLoadStatus.idle;

  /// 로그인 화면의 Form 오류나 세션 확인 실패 안내.
  String? message;

  /// 세션이 **만료돼서** 정리됐을 때만 켜진다. 직접 로그아웃·로그인 실패(AUTH401_1)는 켜지 않는다.
  bool sessionExpired = false;

  /// 저장된 토큰을 지우는 동안 새 로그인을 막기 위한 표시.
  bool storageCleanupInProgress = false;

  int _sessionVersion = 0;
  int get sessionVersion => _sessionVersion;
  bool get isSignedIn => status == AuthStatus.signedIn;

  bool _disposed = false;
  Future<void>? _tokenWrite;

  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;

  /// 인증 **상태**가 바뀔 때만 알리는 Listenable. Router의 refreshListenable로 쓴다.
  ///
  /// 이 ViewModel은 내 정보·안내 문구가 바뀔 때도 notifyListeners를 부른다. Router가 그때마다
  /// 현재 주소를 다시 해석하면, 방금 pop한 화면이 되살아난다(프로필을 저장해도 수정 화면이 닫히지
  /// 않던 문제). 이동 규칙(redirect)은 상태만 보고 정하므로 상태가 바뀔 때만 다시 실행하면 된다.
  final ValueNotifier<AuthStatus> _statusNotifier = ValueNotifier(
    AuthStatus.initializing,
  );
  ValueListenable<AuthStatus> get statusListenable => _statusNotifier;

  void _notify() {
    if (_disposed) return;
    _statusNotifier.value = status; // 값이 같으면 알리지 않는다.
    notifyListeners();
  }

  /// 로그인. 토큰을 저장한 뒤 signedIn이 되고, 내 정보는 MainShell이 loadMember()로 불러온다.
  Future<void> login(String email, String password) async {
    if (_disposed ||
        storageCleanupInProgress ||
        status == AuthStatus.authenticating) {
      return;
    }
    final version = ++_sessionVersion;
    status = AuthStatus.authenticating;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = false;
    message = null;
    _notify();

    final LoginResult result;
    try {
      result = await _authApi.login(
        LoginRequest(email: email, password: password),
      );
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = _loginFailureMessage(error);
      _notify();
      return;
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = '로그인 응답을 확인하지 못했어요. 잠시 후 다시 시도해 주세요.';
      _notify();
      return;
    }
    if (!_isCurrent(version)) return;

    final writing = _storage.saveAccessToken(result.accessToken);
    _tokenWrite = writing;
    try {
      await writing;
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = '로그인 정보를 안전하게 저장하지 못했어요.';
      _notify();
      return;
    } finally {
      if (identical(_tokenWrite, writing)) _tokenWrite = null;
    }
    if (!_isCurrent(version)) return;
    status = AuthStatus.signedIn;
    _notify();
  }

  /// 로그인 입력 오류(AUTH401_1), 서버가 거부한 입력, 통신 실패를 서로 다른 문구로 나눈다.
  String _loginFailureMessage(DioException error) {
    final code = apiErrorCode(error);
    if (code == 'AUTH401_1') return '이메일 또는 비밀번호를 확인해 주세요.';
    if (code == 'COMMON400') {
      return apiErrorMessage(error) ?? '입력한 내용을 확인해 주세요.';
    }
    if (error.type != DioExceptionType.badResponse) {
      return loadErrorMessage(
        error,
        fallback: '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.',
      );
    }
    return '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.';
  }

  /// 앱을 켤 때 저장된 토큰을 읽고 서버에 물어 세션을 되살린다.
  ///
  /// 토큰 문자열이 있다는 이유만으로 signedIn을 확정하지 않는다(만료된 토큰으로 보호 화면에
  /// 들어갔다가 뒤늦게 401을 받게 된다). 네트워크 실패는 토큰을 지우지 않고 재시도 상태로 둔다.
  Future<void> restoreSession() async {
    if (storageCleanupInProgress || _disposed) return;
    final version = ++_sessionVersion;
    status = AuthStatus.initializing;
    message = null;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    _notify();
    try {
      final token = await _storage.readAccessToken();
      if (!_isCurrent(version)) return;
      if (token == null || token.isEmpty) {
        status = AuthStatus.signedOut;
      } else {
        final verifiedMember = await _memberApi.fetchMe();
        if (!_isCurrent(version)) return;
        member = verifiedMember;
        memberStatus = MemberLoadStatus.success;
        status = AuthStatus.signedIn;
      }
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredCode(apiErrorCode(error))) {
        await _clearCurrentSession(expired: true);
        return;
      }
      if (error.error is StateError) {
        // 서버가 아니라 기기 저장소(Interceptor)가 실패한 경우.
        status = AuthStatus.retryRequired;
        message = '인증 저장소를 읽지 못했어요. 다시 시도해 주세요.';
      } else {
        status = AuthStatus.retryRequired;
        message = '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.';
      }
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.retryRequired;
      message = '인증 저장소를 읽지 못했어요. 다시 시도해 주세요.';
    }
    if (_isCurrent(version)) _notify();
  }

  /// 내 정보를 불러와 [member]에 보관한다. MainShell이 한 번 호출하고, 다른 화면은 같은 값을 쓴다.
  /// 첫 줄에서 notifyListeners를 부르므로 build 도중이 아니라 post-frame에서 호출해야 한다.
  Future<void> loadMember({bool force = false}) async {
    if (status != AuthStatus.signedIn) return;
    if (memberStatus == MemberLoadStatus.loading) return;
    if (member != null && !force) return;

    final version = _sessionVersion;
    memberStatus = MemberLoadStatus.loading;
    _notify();
    try {
      final me = await _memberApi.fetchMe();
      if (!_isCurrent(version)) return; // 로그아웃·계정 전환 뒤 늦게 온 응답 무시
      member = me;
      memberStatus = MemberLoadStatus.success;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredCode(apiErrorCode(error))) {
        await _clearCurrentSession(expired: true);
        return;
      }
      // 네트워크 실패는 로그아웃 사유가 아니다. 재시도할 수 있게 error로 남긴다.
      memberStatus = MemberLoadStatus.error;
      message = '내 정보를 불러오지 못했어요.';
    } catch (_) {
      if (!_isCurrent(version)) return;
      memberStatus = MemberLoadStatus.error;
      message = '내 정보를 불러오지 못했어요.';
    }
    _notify();
  }

  /// 프로필 수정 성공 응답으로 메모리의 내 정보를 바꾼다. GET me를 다시 부르지 않는다.
  void updateMember(MemberInfo updated) {
    if (_disposed || status != AuthStatus.signedIn) return;
    member = updated;
    memberStatus = MemberLoadStatus.success;
    _notify();
  }

  /// 직접 누른 로그아웃. 클라이언트의 저장소·메모리 세션만 비우고, 서버에서 토큰이 즉시
  /// 폐기됐다고 보장하지 않는다. 만료 안내 Snackbar는 켜지 않는다.
  Future<void> logout() => _clearCurrentSession(expired: false);

  /// 보호 요청이 AUTH401_2/3/4를 받았을 때 다른 ViewModel이 세션 정리를 요청하는 진입점.
  ///
  /// [forVersion]은 그 요청을 **보낼 때**의 sessionVersion이다. 다르면(그 사이 로그아웃·재로그인이
  /// 있었으면) 이미 지난 세션의 늦은 401이므로 무시한다. 같은 세션에서 동시에 여러 요청이 401을
  /// 받아도 첫 번째가 version을 올리므로 정리는 한 번만 실행된다.
  Future<void> expireSession({int? forVersion}) {
    if (status != AuthStatus.signedIn) return Future.value();
    if (forVersion != null && forVersion != _sessionVersion) {
      return Future.value();
    }
    return _clearCurrentSession(expired: true);
  }

  Future<void> _clearCurrentSession({required bool expired}) async {
    if (_disposed || storageCleanupInProgress) return;
    final version = ++_sessionVersion;
    storageCleanupInProgress = true;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = expired;
    status = AuthStatus.signedOut;
    message = null;
    _notify();
    try {
      // 진행 중이던 토큰 저장을 기다린 뒤 삭제한다. 정리 중 새 로그인은 막는다.
      try {
        await _tokenWrite;
      } catch (_) {
        // 저장이 실패했어도 삭제는 시도한다.
      }
      await _storage.deleteAccessToken();
    } catch (_) {
      if (_isCurrent(version)) {
        message = '저장된 인증 정보를 지우지 못했어요. 앱 재실행 전에 저장소 상태를 확인해 주세요.';
      }
    } finally {
      storageCleanupInProgress = false;
      if (_isCurrent(version)) _notify();
    }
  }

  /// 만료 안내를 한 번 보여준 뒤 꺼서 같은 Snackbar가 반복되지 않게 한다.
  void consumeSessionExpired() {
    sessionExpired = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    _statusNotifier.dispose();
    super.dispose();
  }
}
