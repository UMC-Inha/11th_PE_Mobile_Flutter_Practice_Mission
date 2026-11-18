import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

const myRatingsEntryKey = Key('myRatingsEntry');
const editProfileEntryKey = Key('editProfileEntry');
const logoutButtonKey = Key('logoutButton');
const myPageLoadingKey = Key('myPageLoading');
const myPageErrorKey = Key('myPageError');
const myPageRetryKey = Key('myPageRetry');
const myPageNicknameKey = Key('myPageNickname');
const myPageEmailKey = Key('myPageEmail');
const myPageJoinedKey = Key('myPageJoined');

/// 마이페이지. 내 정보는 [AuthViewModel.member]를 구독해서 그린다(context.read가 아니라 watch).
/// 그래서 프로필을 수정하면 화면 이동 없이 새 닉네임이 바로 보인다.
///
/// MainShell이 시작한 내 정보 로딩 상태를 그대로 보여준다.
/// - 아직 받지 못했거나 불러오는 중: 화면 전체에 인디케이터
/// - 실패: 재시도 버튼(로그아웃하지 않는다)
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '마이페이지',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          // 클라이언트의 저장소·메모리 세션만 비운다. 서버에서 토큰이 즉시 폐기된다고 보장하지는 않는다.
          IconButton(
            key: logoutButtonKey,
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: auth.storageCleanupInProgress ? null : auth.logout,
          ),
        ],
      ),
      body: member == null
          ? _MemberStateBody(auth: auth)
          : _MyPageContent(member: member),
    );
  }
}

class _MemberStateBody extends StatelessWidget {
  const _MemberStateBody({required this.auth});

  final AuthViewModel auth;

  @override
  Widget build(BuildContext context) {
    if (auth.memberStatus == MemberLoadStatus.error) {
      return Center(
        key: myPageErrorKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.mutedText),
            const SizedBox(height: 8),
            Text(
              auth.message ?? '내 정보를 불러오지 못했어요.',
              style: const TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 12),
            MovieLogButton(
              key: myPageRetryKey,
              label: '다시 시도',
              onPressed: () => auth.loadMember(force: true),
            ),
          ],
        ),
      );
    }
    // idle(아직 시작 전)도 빈 화면이 아니라 로딩으로 보여준다.
    return const Center(
      child: CircularProgressIndicator(key: myPageLoadingKey),
    );
  }
}

class _MyPageContent extends StatelessWidget {
  const _MyPageContent({required this.member});

  final MemberInfo member;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundImage: AssetImage(
                'assets/images/profile/profile_movielog.jpg',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.nickname,
                    key: myPageNicknameKey,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 닉네임 아래에 가입일을 "2026.10.10 가입" 형식으로 보여준다.
                  Text(
                    member.joinedLabel,
                    key: myPageJoinedKey,
                    style: const TextStyle(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.email,
                    key: myPageEmailKey,
                    style: const TextStyle(color: AppColors.mutedText),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
        ListTile(
          key: editProfileEntryKey,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
          title: const Text(
            '프로필 수정',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: const Icon(Icons.chevron_right),
          // 내 정보가 있을 때만 이 화면에 들어온다(member != null).
          onTap: () => context.push(AppRoutes.editProfile),
        ),
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
    );
  }
}
