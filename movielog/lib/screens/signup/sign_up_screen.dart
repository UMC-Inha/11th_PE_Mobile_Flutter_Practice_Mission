import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common_app_bar.dart';
import 'widgets/movie_log_text_form_field.dart';
import 'widgets/sign_up_footer.dart';
import 'widgets/sign_up_header.dart';
import 'widgets/sign_up_submit_button.dart';
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

  bool get _canSubmit =>
      _validateNickname(_nicknameController.text) == null &&
      _validateEmail(_emailController.text) == null &&
      _validatePassword(_passwordController.text) == null &&
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

  String? _validateNickname(String? value) {
    final nickname = value?.trim() ?? '';

    if (nickname.isEmpty) {
      return '닉네임을 입력해주세요.';
    }
    if (nickname.length < 2) {
      return '닉네임은 두 글자 이상 입력해주세요.';
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
    if (password.length < 8) {
      return '비밀번호는 8자 이상 입력해주세요.';
    }
    return null;
  }

  Widget? _validationIcon(String currentValue, String? Function(String?) validator) {
    if (currentValue.trim().isEmpty) {
      return null;
    }
    return validator(currentValue) == null
        ? const Icon(Icons.check_circle_outline, color: AppColors.violet)
        : const Icon(Icons.error_outline, color: AppColors.error);
  }

  void _handleSubmit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }
    FocusScope.of(context).unfocus();
    // 가입 완료 후에는 회원가입 화면으로 돌아올 수 없도록 go로 홈 위치로 교체합니다.
    Router.neglect(context, () => context.go('/home'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 회원가입 화면에서는 뒤로 가기가 동작하지 않도록 뒤로가기 버튼을 두지 않습니다.
      appBar: const CommonAppBar(
        title: '회원가입',
        centerTitle: true,
      ),
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
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
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
                          suffixIcon: _validationIcon(_nicknameController.text, _validateNickname),
                          validator: _validateNickname,
                          onChanged: (_) => setState(() {}),
                          onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                        ),
                        const SizedBox(height: 16),
                        MovieLogTextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          labelText: '이메일',
                          hintText: '이메일 주소를 입력해주세요',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          suffixIcon: _validationIcon(_emailController.text, _validateEmail),
                          validator: _validateEmail,
                          onChanged: (_) => setState(() {}),
                          onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
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
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColors.gray,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: _validatePassword,
                          onChanged: (_) => setState(() {}),
                          onFieldSubmitted: (_) => _handleSubmit(),
                        ),
                        const SizedBox(height: 16),
                        TermsAgreementCheckbox(
                          value: _agreedToTerms,
                          onChanged: (value) => setState(() => _agreedToTerms = value),
                        ),
                        const SizedBox(height: 8),
                        SignUpSubmitButton(
                          enabled: _canSubmit,
                          onPressed: _handleSubmit,
                        ),
                        const SizedBox(height: 16),
                        const SignUpFooter(),
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
