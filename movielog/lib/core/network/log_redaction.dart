/// 로그에 남기기 전에 민감한 값을 가린다. 토큰·비밀번호 원문은 어떤 로그에도 남기지 않는다.
const _sensitiveKeys = {
  'accesstoken',
  'refreshtoken',
  'token',
  'password',
  'authorization',
};

/// 점 두 개로 나뉜 JWT처럼 생긴 문자열(헤더가 `eyJ`로 시작)
final _jwtLike = RegExp(
  r'eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]*',
);

/// Map·List를 깊이 훑어 민감한 키의 값을 `***`로 바꾼 복사본을 돌려준다.
Object? redactSensitive(Object? data) {
  if (data is Map) {
    return {
      for (final entry in data.entries)
        entry.key: _sensitiveKeys.contains('${entry.key}'.toLowerCase())
            ? '***'
            : redactSensitive(entry.value),
    };
  }
  if (data is List) return data.map(redactSensitive).toList();
  if (data is String) return maskJwtLike(data);
  return data;
}

/// 문자열 어디에 섞여 있어도 JWT 모양은 가린다(키 이름으로 못 거른 경우의 마지막 방어선).
String maskJwtLike(String text) => text.replaceAll(_jwtLike, '***');
