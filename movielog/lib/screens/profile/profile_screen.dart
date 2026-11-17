import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common_app_bar.dart';
import 'widgets/edit_profile_button.dart';
import 'widgets/favorite_genres.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '내 프로필'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ProfileHeader(),
              const SizedBox(height: 24),
              const Center(child: EditProfileButton()),
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
            ],
          ),
        ),
      ),
    );
  }
}
