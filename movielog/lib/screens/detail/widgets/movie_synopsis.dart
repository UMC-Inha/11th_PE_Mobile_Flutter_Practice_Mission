import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 상세 화면의 시놉시스 영역입니다.
class MovieSynopsis extends StatelessWidget {
  const MovieSynopsis({super.key, required this.synopsis});

  final String synopsis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('시놉시스', style: AppTextStyles.titleLarge.copyWith(fontSize: 22)),
          const SizedBox(height: 12),
          Text(
            synopsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.darkGray,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
