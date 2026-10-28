import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';

/// 공유 방법을 고르는 BottomSheet입니다. 선택한 항목의 안내 문구를 반환합니다.
class ShareBottomSheet extends StatelessWidget {
  const ShareBottomSheet({super.key});

  static const _options = [
    (icon: Icons.link, label: '링크 복사', result: '링크를 복사했어요.'),
    (icon: Icons.chat_bubble_outline, label: '메시지로 공유', result: '메시지로 공유했어요.'),
    (icon: Icons.bookmark_add_outlined, label: '보고 싶은 영화에 추가', result: '보고 싶은 영화에 추가했어요.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('공유하기', style: AppTextStyles.titleMedium),
          ),
          for (final option in _options)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(option.icon),
              title: Text(option.label),
              onTap: () => Navigator.pop(context, option.result),
            ),
        ],
      ),
    );
  }
}
