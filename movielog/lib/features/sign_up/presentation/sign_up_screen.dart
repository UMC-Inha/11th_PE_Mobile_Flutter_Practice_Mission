import 'package:flutter/material.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/features/rating/presentation/widgets/rating_practice_card.dart';
import 'package:movielog/features/sign_up/presentation/widgets/movie_log_text_form_field.dart';
import 'package:movielog/features/sign_up/presentation/widgets/terms_agreement_tile.dart';

const nicknameFieldKey = Key('nicknameField');
const emailFieldKey = Key('emailField');
const passwordFieldKey = Key('passwordField');
const termsCheckboxKey = Key('termsCheckbox');
const signUpButtonKey = Key('signUpButton');

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

  bool get _canSubmit {
    // 버튼 활성화 조건과 최종 검증 규칙이 어긋나지 않도록 validator를 재사용한다.
    return _validateNickname(_nicknameController.text) == null &&
        _validateEmail(_emailController.text) == null &&
        _validatePassword(_passwordController.text) == null &&
        _agreedToTerms;
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

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_nicknameController.text.trim()}님, 입력을 확인했어요.'),
      ),
    );
  }

  void _saveRating() {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$_rating점 평점을 저장했어요.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        MovieLogTextFormField(
                          fieldKey: nicknameFieldKey,
                          controller: _nicknameController,
                          label: '닉네임',
                          hint: '두 글자 이상 입력',
                          prefixIcon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          validator: _validateNickname,
                          onChanged: _updateFormState,
                          onSubmitted: _emailFocusNode.requestFocus,
                        ),
                        const SizedBox(height: 16),
                        MovieLogTextFormField(
                          fieldKey: emailFieldKey,
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          label: '이메일',
                          hint: 'movielog@example.com',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: _validateEmail,
                          onChanged: _updateFormState,
                          onSubmitted: _passwordFocusNode.requestFocus,
                        ),
                        const SizedBox(height: 16),
                        MovieLogTextFormField(
                          fieldKey: passwordFieldKey,
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          label: '비밀번호',
                          hint: '8자 이상 입력',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          validator: _validatePassword,
                          onChanged: _updateFormState,
                          onSubmitted: _canSubmit ? _submit : null,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? '비밀번호 보기' : '비밀번호 숨기기',
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
                        FilledButton(
                          key: signUpButtonKey,
                          onPressed: _canSubmit ? _submit : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('가입하기'),
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
  if (nickname.length < 2) return '닉네임은 두 글자 이상 입력해주세요.';
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

String? _validatePassword(String? value) {
  if ((value ?? '').isEmpty) return '비밀번호를 입력해주세요.';
  if (value!.length < 8) return '비밀번호는 8자 이상 입력해주세요.';
  return null;
}
