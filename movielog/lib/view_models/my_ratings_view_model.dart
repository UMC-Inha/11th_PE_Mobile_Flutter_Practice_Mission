import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/member_rating_dto.dart';
import '../data/services/member_service.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// 프로필 화면의 내 평점 기록 상태를 관리합니다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, {required this.memberId});
  final MemberService _service;
  final int memberId;

  List<MemberRatingDto> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  bool _disposed = false;

  Future<void> load() async {
    status = MyRatingsLoadStatus.loading;
    notifyListeners();

    try {
      final result = await _service.fetchRatings(memberId);
      if (_disposed) return;
      ratings = result;
      status = ratings.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
    } on DioException {
      if (_disposed) return;
      status = MyRatingsLoadStatus.error;
      message = '서버에 연결하지 못했어요.';
    } catch (error, stackTrace) {
      debugPrint('평점 기록 처리 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_disposed) return;
      status = MyRatingsLoadStatus.error;
      message = '평점 기록을 불러오지 못했어요.';
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
