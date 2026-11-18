import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

const editEmailFieldKey = Key('editEmailField');
const editNicknameFieldKey = Key('editNicknameField');
const editSaveButtonKey = Key('editSaveButton');
const editPopScopeKey = Key('editPopScope');
const leaveConfirmKey = Key('leaveConfirm');
const leaveStayKey = Key('leaveStay');

/// 프로필(닉네임) 수정 화면. 이메일은 읽기 전용이다.
///
/// - 저장 중에는 화면을 벗어날 수 없다(PopScope).
/// - 저장하지 않은 변경이 있는데 뒤로 가려 하면 확인 Dialog를 띄운다.
///   "나가기"를 누르면 마이페이지로 돌아가고, "계속 수정"이면 이 화면에 머문다.
/// - 성공하면 Snackbar로 알리고 pop한다. 새 닉네임은 이미 [AuthViewModel.member]에 반영되어 있다.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _controller;

  /// 저장에 성공했거나 사용자가 "나가기"를 확인한 뒤에는 막지 않는다.
  bool _allowLeave = false;

  @override
  void initState() {
    super.initState();
    final member = context.read<AuthViewModel>().member;
    _controller = TextEditingController(text: member?.nickname ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final viewModel = context.read<EditProfileViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final success = await viewModel.save(_controller.text);
    if (!mounted) return;

    if (success) {
      setState(() => _allowLeave = true);
      messenger.showSnackBar(const SnackBar(content: Text('프로필을 수정했어요.')));
      router.pop(); // 마이페이지로 돌아가면 새 닉네임이 이미 반영되어 있다.
    } else if (viewModel.message != null) {
      // 기본(fixed) Snackbar는 화면 맨 아래에 붙어 [저장] 버튼을 가린다. 실패 안내를 읽는 동안
      // 곧바로 다시 저장할 수 있도록, 버튼 위로 띄운다.
      messenger.showSnackBar(
        SnackBar(
          content: Text(viewModel.message!),
          behavior: SnackBarBehavior.floating,
          margin: _failureSnackBarMargin,
        ),
      );
    }
  }

  /// 아래쪽 여백 = 본문 padding(24) + 저장 버튼 높이(52) + 버튼과의 간격(20).
  static const _failureSnackBarMargin = EdgeInsets.fromLTRB(24, 0, 24, 96);

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('변경한 내용이 있어요'),
        content: const Text('저장하지 않고 나가면 입력한 내용이 사라져요.'),
        actions: [
          TextButton(
            key: leaveStayKey,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('계속 수정'),
          ),
          TextButton(
            key: leaveConfirmKey,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    setState(() => _allowLeave = true);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthViewModel, String?>(
      (a) => a.member?.email,
    );
    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, _) {
        final saving = viewModel.status == EditProfileStatus.saving;
        final dirty = viewModel.hasChanges(_controller.text);
        return PopScope(
          key: editPopScopeKey,
          // 저장 중에는 막고, 저장하지 않은 변경이 있으면 막은 뒤 확인을 묻는다.
          canPop: _allowLeave || (!saving && !dirty),
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || saving) return;
            _confirmLeave();
          },
          child: Scaffold(
            appBar: AppBar(centerTitle: true, title: const Text('프로필 수정')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  TextFormField(
                    key: editEmailFieldKey,
                    initialValue: email,
                    enabled: false, // 이메일은 읽기 전용이다.
                    decoration: const InputDecoration(labelText: '이메일'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: editNicknameFieldKey,
                    controller: _controller,
                    enabled: !saving,
                    maxLength: 12,
                    onChanged: (_) {
                      viewModel.onNicknameChanged();
                      setState(() {}); // 변경 여부(dirty)를 다시 계산한다.
                    },
                    decoration: InputDecoration(
                      labelText: '닉네임',
                      errorText: viewModel.nicknameError,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: MovieLogButton(
                      key: editSaveButtonKey,
                      label: '저장',
                      height: 52,
                      isLoading: saving,
                      onPressed: saving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
