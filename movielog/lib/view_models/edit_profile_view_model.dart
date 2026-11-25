import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';

enum EditProfileStatus { idle, saving, success, failure }

/// 프로필(닉네임) 수정 ViewModel. 이메일은 읽기 전용이다.
///
/// 오류는 보여줄 곳에 따라 나눈다. 특정 입력칸의 문제(길이, 중복)는 필드 아래 [nicknameError]로,
/// 입력과 무관한 문제(네트워크)는 [message]로 Snackbar에 보여주고 **로그아웃하지 않는다.**
class EditProfileViewModel extends ChangeNotifier {
  EditProfileViewModel(this._memberApi, this._auth);

  final MemberApiService _memberApi;
  final AuthViewModel _auth;

  EditProfileStatus status = EditProfileStatus.idle;
  String? nicknameError;
  String? message;
  bool _disposed = false;

  /// 서버에 보내기 전에 확인할 수 있는 규칙(2~12자)은 먼저 검사해 불필요한 통신을 줄인다.
  String? validateNickname(String value) {
    final nickname = value.trim();
    if (nickname.length < 2 || nickname.length > 12) {
      return '닉네임은 2~12자로 입력해 주세요.';
    }
    return null;
  }

  /// 현재 입력이 저장된 닉네임과 다른지(= 저장하지 않은 변경이 있는지).
  bool hasChanges(String input) =>
      input.trim() != (_auth.member?.nickname ?? '');

  /// 닉네임을 다시 입력하기 시작하면 이전 오류 문구를 지운다.
  void onNicknameChanged() {
    if (nicknameError == null) return;
    nicknameError = null;
    _notify();
  }

  Future<bool> save(String input) async {
    if (status == EditProfileStatus.saving) return false; // 중복 탭 방지
    final version = _auth.sessionVersion;
    if (_disposed || !_auth.isSignedIn || _auth.member == null) return false;

    final nickname = input.trim();
    nicknameError = validateNickname(nickname);
    if (nicknameError != null) {
      _notify();
      return false;
    }

    // 현재 닉네임과 같으면 요청 없이 완료로 처리한다. 같은 값은 409가 아니지만 호출할 이유가 없다.
    if (nickname == _auth.member?.nickname) {
      status = EditProfileStatus.success;
      _notify();
      return true;
    }

    status = EditProfileStatus.saving;
    nicknameError = null;
    message = null;
    _notify();

    try {
      final updated = await _memberApi.updateNickname(nickname);
      if (_disposed || version != _auth.sessionVersion || !_auth.isSignedIn) {
        return false;
      }
      _auth.updateMember(updated); // 마이페이지가 바로 새 닉네임을 보여준다.
      status = EditProfileStatus.success;
      _notify();
      return true;
    } on DioException catch (error) {
      if (_disposed || version != _auth.sessionVersion || !_auth.isSignedIn) {
        return false;
      }
      final code = apiErrorCode(error);
      status = EditProfileStatus.failure;
      if (isSessionExpiredCode(code)) {
        // 세션 만료: 안내와 이동은 로그인 화면과 Router가 맡는다.
        await _auth.expireSession(forVersion: version);
      } else if (code == 'MEMBER409_1') {
        nicknameError = '이미 사용 중인 닉네임이에요.'; // 입력값은 유지
      } else if (code == 'COMMON400') {
        nicknameError = apiErrorMessage(error) ?? '닉네임 형식을 확인해 주세요.';
      } else if (code == 'MEMBER404_1') {
        message = '회원 정보를 찾을 수 없어요.';
      } else if (error.response == null) {
        // 응답 자체가 없다(서버 꺼짐·시간 초과). 로그아웃하지 않는다.
        message = '네트워크 상태를 확인하고 다시 시도해 주세요.';
      } else {
        // 서버가 응답했지만 처리하지 못했다(500 등). 네트워크 탓으로 돌리지 않는다.
        message = '요청에 실패했어요. 잠시 후 다시 시도해 주세요.';
      }
    } catch (_) {
      if (_disposed || version != _auth.sessionVersion) return false;
      status = EditProfileStatus.failure;
      message = '알 수 없는 오류가 발생했어요.';
    }
    _notify();
    return false;
  }

  /// 화면이 사라진 뒤 도착한 응답이 notifyListeners()를 부르지 않게 막는다.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
