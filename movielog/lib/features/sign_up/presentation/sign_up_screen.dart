import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/features/rating/presentation/widgets/rating_practice_card.dart';
import 'package:movielog/features/sign_up/presentation/widgets/duplicate_check_field.dart';
import 'package:movielog/features/sign_up/presentation/widgets/movie_log_text_form_field.dart';
import 'package:movielog/features/sign_up/presentation/widgets/terms_agreement_tile.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

/// 제출(가입 요청) 중에는 뒤로가기·스와이프 백이 막혀야 한다. 테스트가 canPop을 확인한다.
const signUpPopScopeKey = Key('signUpPopScope');
const nicknameFieldKey = Key('nicknameField');
const emailFieldKey = Key('emailField');
const passwordFieldKey = Key('passwordField');
const termsCheckboxKey = Key('termsCheckbox');
const signUpButtonKey = Key('signUpButton');
const nicknameCheckButtonKey = Key('nicknameCheckButton');
const emailCheckButtonKey = Key('emailCheckButton');

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
  double _rating = 0;

  bool _canSubmit(SignUpViewModel viewModel) {
    // 버튼 활성화 조건과 최종 검증 규칙이 어긋나지 않도록 validator를 재사용한다.
    // 5주차: 닉네임·이메일은 지금 입력값 그대로 서버 중복 확인을 통과해야 한다.
    return _validateNickname(_nicknameController.text) == null &&
        _validateEmail(_emailController.text) == null &&
        _validatePassword(_passwordController.text) == null &&
        viewModel.isNicknameConfirmed(_nicknameController.text) &&
        viewModel.isEmailConfirmed(_emailController.text) &&
        _agreedToTerms &&
        !viewModel.isSubmitting;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _updateFormState() {
    setState(() {});
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    final viewModel = context.read<SignUpViewModel>();
    final session = context.read<LearningMemberSession>();
    final nickname = _nicknameController.text.trim();
    await viewModel.submit(
      CreateMemberRequest(
        email: _emailController.text,
        password: _passwordController.text,
        nickname: _nicknameController.text,
      ),
    );
    // await 뒤에는 화면이 이미 사라졌을 수 있다.
    if (!mounted) return;

    final createdId = viewModel.createdMemberId;
    if (viewModel.submitStatus == SubmitStatus.success && createdId != null) {
      // 가입 결과의 memberId를 학습용 세션에 보관해 영화 상세·마이페이지가 읽게 한다.
      session.setMemberId(createdId);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$nickname님, 가입을 환영해요!')));
      // go: 회원가입 화면을 스택에서 지워 영화 목록에서 뒤로 가도 돌아오지 않는다.
      context.go(AppRoutes.movies);
      return;
    }

    final message = viewModel.snackbarMessage;
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _saveRating() {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$_rating점 평점을 저장했어요.')));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SignUpViewModel>();
    final canSubmit = _canSubmit(viewModel);
    // 제출 중에는 시스템 뒤로가기·스와이프 백을 막는다. 이미 서버에 도착한 요청의 결과를
    // 반영하지 못한 채 화면만 사라지는 일을 없애려는 것이다. 끝나면(성공·실패) 다시 나갈 수 있다.
    return PopScope(
      key: signUpPopScopeKey,
      canPop: !viewModel.isSubmitting,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxFormWidth = constraints.maxWidth >= 700
                  ? 560.0
                  : double.infinity;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxFormWidth),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _WelcomeHeader(),
                          const SizedBox(height: 32),
                          // 입력창과 버튼은 Row의 별도 형제다. 버튼은 width를 주지 않아
                          // 내용 기반 크기를 쓰고, 입력창이 남은 폭을 Expanded로 차지한다.
                          DuplicateCheckField(
                            fieldKey: nicknameFieldKey,
                            buttonKey: nicknameCheckButtonKey,
                            controller: _nicknameController,
                            label: '닉네임',
                            hint: '2~12자 입력',
                            prefixIcon: Icons.person_outline,
                            validator: _validateNickname,
                            status: viewModel.nicknameCheckStatus,
                            errorText: viewModel.nicknameErrorText,
                            canCheck: viewModel.canCheckNickname,
                            availableMessage: '사용할 수 있는 닉네임이에요.',
                            onChanged: () {
                              viewModel.onNicknameChanged(
                                _nicknameController.text,
                              );
                              _updateFormState();
                            },
                            onCheck: () => viewModel.checkNickname(
                              _nicknameController.text,
                            ),
                            onSubmitted: _emailFocusNode.requestFocus,
                          ),
                          const SizedBox(height: 16),
                          DuplicateCheckField(
                            fieldKey: emailFieldKey,
                            buttonKey: emailCheckButtonKey,
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            label: '이메일',
                            hint: 'movielog@example.com',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                            status: viewModel.emailCheckStatus,
                            errorText: viewModel.emailErrorText,
                            canCheck: viewModel.canCheckEmail,
                            availableMessage: '사용할 수 있는 이메일이에요.',
                            onChanged: () {
                              viewModel.onEmailChanged(_emailController.text);
                              _updateFormState();
                            },
                            onCheck: () =>
                                viewModel.checkEmail(_emailController.text),
                            onSubmitted: _passwordFocusNode.requestFocus,
                          ),
                          const SizedBox(height: 16),
                          MovieLogTextFormField(
                            fieldKey: passwordFieldKey,
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            label: '비밀번호',
                            hint: '대·소문자, 숫자, 특수문자 포함 8자 이상',
                            prefixIcon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            validator: _validatePassword,
                            // 로컬 validator가 통과한 뒤에도 서버가 거부한 값이면 계속 에러로 보인다.
                            errorText: viewModel.passwordErrorText,
                            onChanged: () {
                              viewModel.onPasswordChanged();
                              _updateFormState();
                            },
                            onSubmitted: canSubmit ? _submit : null,
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? '비밀번호 보기'
                                  : '비밀번호 숨기기',
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TermsAgreementTile(
                            value: _agreedToTerms,
                            checkboxKey: termsCheckboxKey,
                            onChanged: (value) {
                              setState(() => _agreedToTerms = value);
                            },
                          ),
                          const SizedBox(height: 20),
                          // Form 맨 아래는 화면 전체 너비를 쓴다(width: double.infinity).
                          // 제출 중에는 isLoading으로 인디케이터를 보이고 다시 누를 수 없다.
                          MovieLogButton(
                            key: signUpButtonKey,
                            label: '가입하기',
                            height: 56,
                            width: double.infinity,
                            isLoading: viewModel.isSubmitting,
                            onPressed: canSubmit ? _submit : null,
                          ),
                          const SizedBox(height: 36),
                          RatingPracticeCard(
                            rating: _rating,
                            onRatingChanged: (value) =>
                                setState(() => _rating = value),
                            onSave: _saveRating,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MovieLog',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 12),
        Text(
          '영화를 기록할\n계정을 만들어볼까요?',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 30,
            height: 1.22,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '입력값을 확인하면 가입 버튼이 활성화돼요.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 15),
        ),
      ],
    );
  }
}

String? _validateNickname(String? value) {
  final nickname = value?.trim() ?? '';
  if (nickname.isEmpty) return '닉네임을 입력해주세요.';
  // 백엔드 검증(2~12자)과 같은 규칙을 화면에서도 먼저 확인한다.
  if (nickname.length < 2 || nickname.length > 12) {
    return '닉네임은 2~12자로 입력해주세요.';
  }
  return null;
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return '이메일을 입력해주세요.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return '올바른 이메일 형식을 입력해주세요.';
  }
  return null;
}

/// 빠른 안내를 위한 로컬 규칙: 8자 이상, 소문자·대문자·숫자·특수문자를 각각 하나 이상.
/// 서버 검증을 대신하지 않는다. 서버가 더 엄격하게 거부하면(예: bcrypt 한계 72자 초과)
/// 그 문구가 [SignUpViewModel.passwordErrorText]로 같은 입력칸에 붙는다.
String? _validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return '비밀번호를 입력해주세요.';
  if (password.length < 8) return '비밀번호는 8자 이상 입력해주세요.';
  final hasLower = RegExp('[a-z]').hasMatch(password);
  final hasUpper = RegExp('[A-Z]').hasMatch(password);
  final hasDigit = RegExp(r'\d').hasMatch(password);
  final hasSpecial = RegExp(r'[^A-Za-z0-9\s]').hasMatch(password);
  if (!(hasLower && hasUpper && hasDigit && hasSpecial)) {
    return '대문자·소문자·숫자·특수문자를 모두 포함해 주세요.';
  }
  return null;
}
