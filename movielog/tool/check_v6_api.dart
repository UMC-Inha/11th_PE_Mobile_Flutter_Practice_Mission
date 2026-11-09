// ignore_for_file: avoid_print
// 워크북 v6 조회 API를 앱의 Service로 직접 호출해 응답 모양을 확인하는 스크립트입니다.
// 실행: dart run tool/check_v6_api.dart [닉네임] [이메일] [memberId]
//
// 쓰기 API(회원가입·평점 등록·수정·삭제)는 서버 데이터를 바꾸므로 이 스크립트에서 호출하지 않습니다.
// movie_log_client.dart는 Flutter 패키지를 쓰므로, 여기서는 같은 baseUrl의 Dio를 직접 만듭니다.
import 'package:dio/dio.dart';

import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';

Future<void> main(List<String> args) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'));
  final signUp = SignUpService(dio);
  final ratingApi = RatingApiService(dio);

  final nickname = args.isNotEmpty ? args[0] : '무비러버';
  final email = args.length > 1 ? args[1] : 'movielover@movielog.com';
  final memberId = args.length > 2 ? int.parse(args[2]) : 1;

  print('[닉네임 중복 체크] $nickname → available: '
      '${await signUp.checkNickname(nickname)}');
  print('[이메일 중복 체크] $email → available: '
      '${await signUp.checkEmail(email)}');

  final ratings = await ratingApi.fetchMyRatings(memberId);
  print('[memberId $memberId 평점] ${ratings.length}건');
  for (final rating in ratings) {
    print('  ratingId ${rating.ratingId} · movieId ${rating.movieId} · '
        '${rating.score}점 · comment: ${rating.comment}');
  }

  // v6 오류는 공통 응답 형식으로 내려옵니다.
  try {
    await ratingApi.fetchMyRatings(999999);
  } on DioException catch (error) {
    print('[memberId 999999] ${error.response?.statusCode} '
        '${error.response?.data} → "${writeMyRatingsErrorMessage(error)}"');
  }
}
