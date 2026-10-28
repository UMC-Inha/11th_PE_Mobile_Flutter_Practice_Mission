import 'package:dio/dio.dart';

import 'package:movielog/data/models/member_rating_dto.dart';
import 'package:movielog/data/services/member_service.dart';

/// 실제 Spring 서버 대신 미리 정해 둔 값을 돌려주는 테스트용 Service입니다.
class FakeMemberService extends MemberService {
  FakeMemberService({
    this.ratings = const [],
    this.takenNicknames = const {},
    this.takenEmails = const {},
  }) : super(Dio());

  final List<MemberRatingDto> ratings;
  final Set<String> takenNicknames;
  final Set<String> takenEmails;

  @override
  Future<bool> isNicknameAvailable(String nickname) async =>
      !takenNicknames.contains(nickname);

  @override
  Future<bool> isEmailAvailable(String email) async =>
      !takenEmails.contains(email);

  @override
  Future<List<MemberRatingDto>> fetchRatings(int memberId) async => ratings;
}
