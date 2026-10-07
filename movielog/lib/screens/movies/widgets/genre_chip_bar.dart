import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// 가로로 스크롤되는 장르 선택 Chip 목록입니다.
class GenreChipBar extends StatelessWidget {
  const GenreChipBar({
    super.key,
    required this.genres,
    required this.selectedGenre,
    required this.onSelected,
  });

  final List<String> genres;
  final String selectedGenre;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genres.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = genres[index];
          final isSelected = genre == selectedGenre;

          return ChoiceChip(
            label: Text(genre),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onSelected(genre),
            labelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.white : AppColors.darkGray,
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            backgroundColor: AppColors.chipGray,
            selectedColor: AppColors.violet,
            side: BorderSide.none,
            shape: const StadiumBorder(),
          );
        },
      ),
    );
  }
}
