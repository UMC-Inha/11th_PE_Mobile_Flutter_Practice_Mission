import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/theme/app_theme.dart';

const myRatingsEntryKey = Key('myRatingsEntry');

/// 마이페이지. 평점 목록 자체는 자식 화면(`/my/ratings`)이 보여준다.
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '마이페이지',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _ProfileHeader(),
          const SizedBox(height: 24),
          const Divider(height: 1),
          ListTile(
            key: myRatingsEntryKey,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.star_outline, color: AppColors.primary),
            title: const Text(
              '내가 등록한 평점',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: const Icon(Icons.chevron_right),
            // push: 마이페이지를 스택에 남겨 BackButton으로 되돌아오게 한다.
            onTap: () => context.push(AppRoutes.myRatings),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundImage: AssetImage(
            'assets/images/profile/profile_movielog.jpg',
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '케빈',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '별빛 아래에서 영화를 기록하는 중',
                style: TextStyle(color: AppColors.mutedText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
