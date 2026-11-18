import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/view_models/auth_view_model.dart';

void main() {
  const locations = [
    '/', // 시작(스플래시)
    '/login',
    '/sign-up',
    '/home',
    '/movies',
    '/movies/550',
    '/my',
    '/my/ratings',
    '/my/profile/edit',
  ];
  const publicPaths = {'/login', '/sign-up'};

  /// 기대값을 authRedirect와 다른 방식(명시적인 표)으로 적어, 구현을 그대로 베끼지 않는다.
  String? expected(AuthStatus status, String location) {
    switch (status) {
      case AuthStatus.initializing:
      case AuthStatus.retryRequired:
        return location == '/' ? null : '/';
      case AuthStatus.signedOut:
      case AuthStatus.authenticating:
        return publicPaths.contains(location) ? null : '/login';
      case AuthStatus.signedIn:
        return (location == '/' || publicPaths.contains(location))
            ? '/home'
            : null;
    }
  }

  group('authRedirect 표 (상태 5개 × 위치 9개)', () {
    for (final status in AuthStatus.values) {
      for (final location in locations) {
        test('${status.name} · $location → ${expected(status, location)}', () {
          expect(authRedirect(status, location), expected(status, location));
        });
      }
    }
  });

  test('토큰 확인 중에는 로그인·홈을 잠깐도 보여주지 않고 시작 화면으로 돌려보낸다', () {
    for (final status in [AuthStatus.initializing, AuthStatus.retryRequired]) {
      expect(authRedirect(status, '/login'), '/');
      expect(authRedirect(status, '/home'), '/');
      expect(authRedirect(status, '/my'), '/');
    }
  });

  test('로그아웃 상태에서는 보호 화면(탭·상세·프로필 수정)에 들어갈 수 없다', () {
    for (final location in [
      '/home',
      '/movies',
      '/movies/550',
      '/my',
      '/my/ratings',
      '/my/profile/edit',
    ]) {
      expect(authRedirect(AuthStatus.signedOut, location), '/login');
    }
  });

  test('로그인 요청 중(authenticating)에도 공개 화면만 허용한다', () {
    expect(authRedirect(AuthStatus.authenticating, '/login'), isNull);
    expect(authRedirect(AuthStatus.authenticating, '/home'), '/login');
  });
}
