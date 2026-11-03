import 'package:flutter/material.dart';

import '../../../data/models/tmdb_genre_dto.dart';
import '../../../theme/app_colors.dart';

/// 가로로 스크롤되는 장르 선택 Chip 목록입니다.
/// 맨 앞의 '전체' Chip은 장르 ID null(필터 없음)을 의미합니다.
class GenreChipBar extends StatelessWidget {
  const GenreChipBar({
    super.key,
    required this.genres,
    required this.selectedGenreId,
    required this.onSelected,
    this.enabled = true,
  });

  final List<TmdbGenreDto> genres;
  final int? selectedGenreId;
  final ValueChanged<int?> onSelected;

  /// false면 Chip을 누를 수 없습니다. (영화 목록을 불러오는 중)
  final bool enabled;

  static const _allGenreLabel = '전체';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genres.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = index == 0 ? null : genres[index - 1];
          final genreId = genre?.id;
          final isSelected = genreId == selectedGenreId;

          return ChoiceChip(
            label: Text(genre?.name ?? _allGenreLabel),
            selected: isSelected,
            showCheckmark: false,
            onSelected: enabled ? (_) => onSelected(genreId) : null,
            labelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.white : AppColors.darkGray,
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            backgroundColor: AppColors.chipGray,
            selectedColor: AppColors.violet,
            // 로딩 중 비활성화돼도 선택된 장르는 그대로 보이게 합니다.
            disabledColor: isSelected ? AppColors.violet : AppColors.chipGray,
            side: BorderSide.none,
            shape: const StadiumBorder(),
          );
        },
      ),
    );
  }
}
