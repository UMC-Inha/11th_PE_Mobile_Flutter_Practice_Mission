import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/create_member_request.dart';
import '../../theme/app_colors.dart';
import '../../view_models/learning_member_session.dart';
import '../../view_models/sign_up_view_model.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/movielog_button.dart';
import 'widgets/movie_log_text_form_field.dart';
import 'widgets/sign_up_footer.dart';
import 'widgets/sign_up_header.dart';
import 'widgets/terms_agreement_checkbox.dart';

/// 넓은 화면(폭 700 이상)에서 Form을 가운데 정렬하고 폭을 제한하는 기준입니다.
const double _wideScreenBreakpoint = 700;
const double _wideScreenFormMaxWidth = 560;

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _agreedToTerms = false;
  bool _obscurePassword = true;

  /// 형식 검사(validator)와 서버 중복 확인이 모두 통과하고, 제출 중이 아니어야 가입할 수 있습니다.
  bool _canSubmit(SignUpViewModel viewModel) =>
      !viewModel.isSubmitting &&
      _validateNickname(_nicknameController.text) == null &&
      _validateEmail(_emailController.text) == null &&
      _validatePassword(_passwordController.text) == null &&
      viewModel.nicknameCheckStatus == CheckStatus.available &&
      viewModel.emailCheckStatus == CheckStatus.available &&
      _agreedToTerms;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // validator는 형식만 검사합니다. 서버 중복 여부는 ViewModel의 errorText가 담당합니다.
  String? _validateNickname(String? value) {
    final nickname = value?.trim() ?? '';

    if (nickname.isEmpty) {
      return '닉네임을 입력해주세요.';
    }
    if (nickname.length < 2) {
      return '닉네임은 두 글자 이상 입력해주세요.';
    }
    if (nickname.length > 12) {
      return '닉네임은 12자 이하로 입력해주세요.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    final emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

    if (email.isEmpty) {
      return '이메일을 입력해주세요.';
    }
    if (!emailPattern.hasMatch(email)) {
      return '올바른 이메일 형식이 아니에요.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return '비밀번호를 입력해주세요.';
    }
    if (password.trim() != password) {
      return '비밀번호 앞뒤에는 공백을 넣을 수 없어요.';
    }
    if (password.length < 8) {
      return '비밀번호는 8자 이상 입력해주세요.';
    }
    // 서버 규칙: 소문자·대문자·숫자·특수문자(!@#\$%^&*)를 각각 하나 이상 포함합니다.
    // 클라이언트 검증은 빠른 안내용이며 서버 검증을 대체하지 않습니다.
    if (!RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password) ||
        !RegExp(r'[!@#$%^&*]').hasMatch(password)) {
      return '대문자·소문자·숫자·특수문자(!@#\$%^&*)를 모두 포함해주세요.';
    }
    return null;
  }

  /// 입력창 안쪽의 체크 표시입니다. 서버가 사용 가능하다고 응답했을 때만 체크를 보여줍니다.
  Widget? _checkIcon(
    String currentValue,
    String? Function(String?) validator,
    CheckStatus status,
  ) {
    if (currentValue.trim().isEmpty) return null;
    if (validator(currentValue) != null ||
        status == CheckStatus.duplicated ||
        status == CheckStatus.error) {
      return const Icon(Icons.error_outline, color: AppColors.error);
    }
    if (status == CheckStatus.available) {
      return const Icon(Icons.check_circle_outline, color: AppColors.violet);
    }
    return null;
  }

  Future<void> _handleSubmit(SignUpViewModel viewModel) async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || !_canSubmit(viewModel)) return;
    FocusScope.of(context).unfocus();

    // 비밀번호는 요청 body로만 보내고 로그·저장소에 남기지 않습니다.
    await viewModel.submit(
      CreateMemberRequest(
        email: _emailController.text,
        password: _passwordController.text,
        nickname: _nicknameController.text,
      ),
    );
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final memberId = viewModel.createdMemberId;
    if (viewModel.submitStatus == SubmitStatus.success && memberId != null) {
      // 가입 결과의 memberId를 학습용 세션에 보관해 이후 평점 요청에 사용합니다.
      context.read<LearningMemberSession>().setMemberId(memberId);
      // 가입 완료 후에는 회원가입 화면으로 돌아올 수 없도록 go로 위치를 교체합니다.
      Router.neglect(context, () => context.go('/movies'));
      messenger.showSnackBar(
        SnackBar(content: Text('회원가입을 완료했어요. (memberId $memberId)')),
      );
      return;
    }

    // 409 중복처럼 입력칸 하나에 붙일 수 없는 오류는 Snackbar로 보여줍니다.
    final message = viewModel.snackbarMessage;
    if (message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 회원가입 화면에서는 뒤로 가기가 동작하지 않도록 뒤로가기 버튼을 두지 않습니다.
      appBar: const CommonAppBar(title: '회원가입', centerTitle: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final formMaxWidth = constraints.maxWidth >= _wideScreenBreakpoint
                ? _wideScreenFormMaxWidth
                : double.infinity;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: formMaxWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Consumer<SignUpViewModel>(
                    builder: (context, viewModel, child) => Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SignUpHeader(),
                          const SizedBox(height: 32),
                          MovieLogTextFormField(
                            controller: _nicknameController,
                            labelText: '닉네임',
                            hintText: '닉네임을 입력해주세요',
                            textInputAction: TextInputAction.next,
                            suffixIcon: _checkIcon(
                              _nicknameController.text,
                              _validateNickname,
                              viewModel.nicknameCheckStatus,
                            ),
                            validator: _validateNickname,
                            errorText: viewModel.nicknameErrorText,
                            helperText:
                                viewModel.nicknameCheckStatus ==
                                    CheckStatus.available
                                ? '사용할 수 있는 닉네임입니다.'
                                : null,
                            onChanged: viewModel.onNicknameChanged,
                            // 입력창 옆 보조 버튼이므로 width를 주지 않아 내용 기반 크기를 씁니다.
                            trailing: MovieLogButton(
                              label: '중복 확인',
                              isLoading:
                                  viewModel.nicknameCheckStatus ==
                                  CheckStatus.checking,
                              onPressed:
                                  viewModel.canCheckNickname &&
                                      _validateNickname(
                                            _nicknameController.text,
                                          ) ==
                                          null
                                  ? () => viewModel.checkNickname(
                                      _nicknameController.text,
                                    )
                                  : null,
                            ),
                            onFieldSubmitted: (_) =>
                                _emailFocusNode.requestFocus(),
                          ),
                          const SizedBox(height: 16),
                          MovieLogTextFormField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            labelText: '이메일',
                            hintText: '이메일 주소를 입력해주세요',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            suffixIcon: _checkIcon(
                              _emailController.text,
                              _validateEmail,
                              viewModel.emailCheckStatus,
                            ),
                            validator: _validateEmail,
                            errorText: viewModel.emailErrorText,
                            helperText:
                                viewModel.emailCheckStatus ==
                                    CheckStatus.available
                                ? '사용할 수 있는 이메일입니다.'
                                : null,
                            onChanged: viewModel.onEmailChanged,
                            trailing: MovieLogButton(
                              label: '중복 확인',
                              isLoading:
                                  viewModel.emailCheckStatus ==
                                  CheckStatus.checking,
                              onPressed:
                                  viewModel.canCheckEmail &&
                                      _validateEmail(_emailController.text) ==
                                          null
                                  ? () => viewModel.checkEmail(
                                      _emailController.text,
                                    )
                                  : null,
                            ),
                            onFieldSubmitted: (_) =>
                                _passwordFocusNode.requestFocus(),
                          ),
                          const SizedBox(height: 16),
                          MovieLogTextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            labelText: '비밀번호',
                            hintText: '비밀번호를 입력해주세요',
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.gray,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            validator: _validatePassword,
                            // 로컬 validator가 통과해도 서버가 거부한 비밀번호면 계속 에러로 보입니다.
                            errorText: viewModel.passwordErrorText,
                            onChanged: (_) {
                              setState(() {});
                              viewModel.onPasswordChanged();
                            },
                            onFieldSubmitted: (_) => _handleSubmit(viewModel),
                          ),
                          const SizedBox(height: 16),
                          TermsAgreementCheckbox(
                            value: _agreedToTerms,
                            onChanged: (value) =>
                                setState(() => _agreedToTerms = value),
                          ),
                          const SizedBox(height: 8),
                          // Form 하단 버튼이므로 전체 너비를 사용합니다.
                          MovieLogButton(
                            label: '가입하기',
                            width: double.infinity,
                            isLoading: viewModel.isSubmitting,
                            onPressed: _canSubmit(viewModel)
                                ? () => _handleSubmit(viewModel)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          const SignUpFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
