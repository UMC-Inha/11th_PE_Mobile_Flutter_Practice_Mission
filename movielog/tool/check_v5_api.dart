// ignore_for_file: avoid_print
// 워크북 v5 API를 앱의 Service로 직접 호출해 응답 모양을 확인하는 스크립트입니다.
// 실행: dart run tool/check_v5_api.dart [닉네임] [이메일]
//
// movie_log_client.dart는 Flutter 패키지를 쓰므로, 여기서는 같은 baseUrl의 Dio를 직접 만듭니다.
import 'package:dio/dio.dart';

import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';

Future<void> main(List<String> args) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'));
  final memberCheck = MemberCheckService(dio);
  final ratingApi = RatingApiService(dio);

  final nickname = args.isNotEmpty ? args[0] : '무비러버';
  final email = args.length > 1 ? args[1] : 'movielover@movielog.com';

  print('[닉네임 중복 체크] $nickname → available: '
      '${await memberCheck.checkNickname(nickname)}');
  print('[이메일 중복 체크] $email → available: '
      '${await memberCheck.checkEmail(email)}');

  final ratings = await ratingApi.fetchMyRatings(1);
  print('[memberId 1 평점] ${ratings.length}건');
  for (final rating in ratings) {
    print('  ratingId ${rating.ratingId} · movieId ${rating.movieId} · '
        '${rating.score}점 · comment: ${rating.comment}');
  }

  // 존재하지 않는 회원은 404와 프레임워크 기본 오류 형식으로 내려옵니다.
  try {
    await ratingApi.fetchMyRatings(999999);
  } on DioException catch (error) {
    print('[memberId 999999] ${error.response?.statusCode} '
        '${error.response?.data} → "${writeMyRatingsErrorMessage(error)}"');
  }
}
