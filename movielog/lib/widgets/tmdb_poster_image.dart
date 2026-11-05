import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';

const posterPlaceholderKey = Key('posterPlaceholder');
const posterLoadingKey = Key('posterLoading');

/// TMDB `poster_path`(파일 경로만 옴) → 이미지 URL 조합, null 처리, 로드 실패 처리를
/// 화면마다 반복하지 않도록 묶은 재사용 Widget.
class TmdbPosterImage extends StatelessWidget {
  const TmdbPosterImage({
    super.key,
    required this.posterPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.size = 'w500',
  });

  final String? posterPath;

  /// null이면 부모 크기에 맞춘다(Grid 카드의 Expanded 등).
  final double? width;
  final double? height;
  final BoxFit fit;

  /// TMDB 이미지 크기. 작은 썸네일은 w185, 카드 w342, 상세 w500, 배경 w780.
  final String size;

  static const baseUrl = 'https://image.tmdb.org/t/p';

  /// "/abc.jpg" → "https://image.tmdb.org/t/p/w500/abc.jpg". 비었으면 null.
  static String? imageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.trim().isEmpty) return null;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$baseUrl/$size$normalized';
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl(posterPath, size: size);
    if (url == null) return _placeholder();

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      // 첫 프레임이 그려지기 전까지 회색 자리를 둔다. loadingBuilder는 첫 응답 조각이
      // 오기 전에는 progress가 null이라 빈 칸이 되므로 frameBuilder로 판단한다.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return Container(
          key: posterLoadingKey,
          width: width,
          height: height,
          color: const Color(0xFFE8ECF2),
        );
      },
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      key: posterPlaceholderKey,
      width: width,
      height: height,
      color: const Color(0xFFEDEAF2),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported_outlined, color: AppColors.mutedText),
          SizedBox(height: 6),
          Text(
            '포스터 없음',
            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
