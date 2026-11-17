import 'package:dio/dio.dart';
import 'package:movielog/data/services/movielog_api_service.dart';
import 'package:movielog/view_models/load_error_message.dart';

String _messageOf(DioException error, String fallback) {
  final common = parseErrorResponse(error);
  if (common != null && common.message.isNotEmpty) return common.message;
  // 응답 자체가 없는 통신 실패(서버 꺼짐·시간 초과)는 그 원인을 알려 준다.
  if (error.type != DioExceptionType.badResponse) {
    return loadErrorMessage(error, fallback: fallback);
  }
  return fallback;
}

/// 회원가입 실패 문구. 서버 message에 사용자에게 보여줄 문장이 이미 들어 있어
/// code별로 문구를 새로 만들지 않고 그대로 쓴다.
String writeSignUpErrorMessage(DioException error) =>
    _messageOf(error, '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.');

/// 평점 등록·수정·삭제 실패 문구. 같은 404라도 등록에서는 "유저", 수정·삭제에서는 "평점"을
/// 가리키므로 code로 문구를 만들지 않고 서버 message를 그대로 쓴다.
/// code는 문구가 아니라 "다시 조회할지"처럼 그다음 UI 행동을 정하는 데만 쓴다.
String writeErrorMessage(DioException error) =>
    _messageOf(error, '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
