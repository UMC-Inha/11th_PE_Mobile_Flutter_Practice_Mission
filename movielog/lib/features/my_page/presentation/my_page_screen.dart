import 'package:flutter/material.dart';
import 'package:movielog/core/data/mock_movies.dart';
import 'package:movielog/core/theme/app_theme.dart';

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
        children: const [
          _ProfileHeader(),
          SizedBox(height: 24),
          _StatsRow(),
          SizedBox(height: 28),
          _MenuTile(icon: Icons.bookmark_border, title: '즐겨찾기한 영화'),
          _MenuTile(icon: Icons.star_border_rounded, title: '내가 남긴 평점'),
          _MenuTile(icon: Icons.settings_outlined, title: '설정'),
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

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    // Mock 표시값. 실제 기록 연동은 이후 주차에서 한다.
    return Row(
      children: [
        _StatItem(label: '본 영화', value: '${mockMovies.length}'),
        const SizedBox(width: 12),
        const _StatItem(label: '평점', value: '4.2'),
        const SizedBox(width: 12),
        _StatItem(label: '장르', value: '${movieGenres.length}'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF1EDFA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: AppColors.mutedText)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$title 화면은 다음 주차에 연결돼요.'))),
    );
  }
}
