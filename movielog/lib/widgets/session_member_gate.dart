import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/session/session_guard.dart';
import '../data/models/member_info.dart';
import '../view_models/auth_view_model.dart';
import 'common_app_bar.dart';
import 'movielog_button.dart';

/// 내 정보(member)가 준비되고 [SessionGuard]의 현재 세션과 일치할 때만 [builder]를 그립니다.
/// 준비 전에는 로딩, 내 정보 조회 실패면 재시도 버튼을 보여줍니다.
class SessionMemberGate extends StatefulWidget {
  const SessionMemberGate({
    super.key,
    required this.title,
    required this.builder,
  });

  final String title;
  final Widget Function(
    BuildContext context,
    MemberInfo member,
    SessionGuard guard,
  )
  builder;

  @override
  State<SessionMemberGate> createState() => _SessionMemberGateState();
}

class _SessionMemberGateState extends State<SessionMemberGate> {
  @override
  void initState() {
    super.initState();
    // 하단 탭(MainScreen)을 거치지 않고 진입해 내 정보가 없으면 한 번 불러옵니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthViewModel>();
      if (auth.member == null && auth.memberStatus == MemberLoadStatus.idle) {
        auth.loadMember();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;
    final guard = context.read<SessionGuard>();

    if (member == null || guard.accountId != member.email) {
      return Scaffold(
        appBar: CommonAppBar(
          title: widget.title,
          centerTitle: true,
          onBack: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        body: Center(
          child: member == null && auth.memberStatus == MemberLoadStatus.error
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(auth.message ?? '내 정보를 불러오지 못했어요.'),
                    const SizedBox(height: 12),
                    MovieLogButton(
                      label: '내 정보 다시 조회',
                      onPressed: () => auth.loadMember(force: true),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    return widget.builder(context, member, guard);
  }
}
