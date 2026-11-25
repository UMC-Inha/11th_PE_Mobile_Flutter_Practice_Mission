import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../view_models/auth_view_model.dart';
import '../../widgets/common_app_bar.dart';
import 'widgets/edit_profile_button.dart';
import 'widgets/favorite_genres.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;

    return Scaffold(
      appBar: CommonAppBar(
        title: '내 프로필',
        actions: [
          TextButton(onPressed: auth.logout, child: const Text('로그아웃')),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileHeader(
                nickname: member?.nickname ?? '',
                email: member?.email ?? '',
              ),
              const SizedBox(height: 24),
              Center(
                child: EditProfileButton(
                  onPressed: member == null
                      ? null
                      : () => context.push('/my/profile/edit'),
                ),
              ),
              const SizedBox(height: 32),
              const ProfileStats(),
              const SizedBox(height: 40),
              const FavoriteGenres(),
              const SizedBox(height: 24),
              const Divider(color: AppColors.divider),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.star_outline_rounded,
                  color: AppColors.violet,
                ),
                title: const Text(
                  '내가 등록한 평점',
                  style: AppTextStyles.titleMedium,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/my/ratings'),
              ),
              const Divider(color: AppColors.divider),
              // 내 정보(member)가 준비된 뒤에만 진입할 수 있습니다.
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: member != null,
                leading: const Icon(
                  Icons.bookmark_outline,
                  color: AppColors.violet,
                ),
                title: const Text('내 즐겨찾기', style: AppTextStyles.titleMedium),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/my/favorites'),
              ),
              const Divider(color: AppColors.divider),
            ],
          ),
        ),
      ),
    );
  }
}
