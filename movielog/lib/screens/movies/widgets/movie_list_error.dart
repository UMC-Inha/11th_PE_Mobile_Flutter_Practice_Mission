import 'package:flutter/material.dart';

/// 영화 목록 로드에 실패했을 때 안내와 재시도 버튼을 보여주는 Error 상태입니다.
class MovieListError extends StatelessWidget {
  const MovieListError({
    super.key,
    this.message,
    required this.onRetry,
  });

  /// ViewModel이 전달한 오류 안내 문구입니다. 없으면 기본 문구를 사용합니다.
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(height: 12),
          Text(message ?? '영화를 불러오지 못했습니다.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
