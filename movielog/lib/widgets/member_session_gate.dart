import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

const memberGateLoadingKey = Key('memberGateLoading');
const memberGateErrorKey = Key('memberGateError');
const memberGateRetryKey = Key('memberGateRetry');

/// 사용자별 화면(내 즐겨찾기·영화 상세의 즐겨찾기 버튼)을 열기 전에
/// "내 정보가 준비됐고, 현재 세션([SessionGuard])과 일치하는가"를 확인하는 관문.
///
/// 준비되지 않았으면 이 위젯이 스스로 로딩 또는 오류·재시도 화면을 보여 준다.
/// - 마이페이지 탭을 거치지 않고 주소로 바로 들어와도(MainShell이 없어도) 내 정보를 한 번 요청한다.
/// - 내 정보 조회가 실패하면 로딩만 계속 돌리지 않고 다시 시도 버튼을 보여 준다(로그아웃하지 않는다).
///
/// 준비되면 [builder]에 member와 guard를 넘긴다. 사용자별 ViewModel은 여기서
/// `ValueKey('${member.email}:${guard.generation}')`로 만들어, 계정이나 세션이 바뀌면 이전
/// ViewModel을 버리고 새로 만든다.
class MemberSessionGate extends StatefulWidget {
  const MemberSessionGate({
    super.key,
    required this.title,
    required this.builder,
  });

  /// 준비 중 화면의 AppBar 제목.
  final String title;
  final Widget Function(
    BuildContext context,
    MemberInfo member,
    SessionGuard guard,
  )
  builder;

  @override
  State<MemberSessionGate> createState() => _MemberSessionGateState();
}

class _MemberSessionGateState extends State<MemberSessionGate> {
  @override
  void initState() {
    super.initState();
    // loadMember는 첫 줄에서 notifyListeners를 부르므로 첫 프레임 뒤에 부른다.
    // 이미 받았거나 받는 중이면 아무것도 하지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthViewModel>().loadMember();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final guard = context.read<SessionGuard>();
    final member = auth.member;
    if (member == null || guard.accountId != member.email) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.home),
          ),
          title: Text(widget.title),
        ),
        body: Center(
          child: member == null && auth.memberStatus == MemberLoadStatus.error
              ? Column(
                  key: memberGateErrorKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(auth.message ?? '내 정보를 불러오지 못했어요.'),
                    const SizedBox(height: 12),
                    MovieLogButton(
                      key: memberGateRetryKey,
                      label: '다시 시도',
                      onPressed: () => auth.loadMember(force: true),
                    ),
                  ],
                )
              : const CircularProgressIndicator(key: memberGateLoadingKey),
        ),
      );
    }
    return widget.builder(context, member, guard);
  }
}
