import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/app_router.dart';
import 'package:movielog/core/storage/email_preference.dart';
import 'package:movielog/core/theme/app_theme.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

const loginEmailFieldKey = Key('loginEmailField');
const loginPasswordFieldKey = Key('loginPasswordField');
const loginButtonKey = Key('loginButton');
const loginErrorKey = Key('loginError');
const rememberEmailKey = Key('rememberEmail');
const loginGoSignUpKey = Key('loginGoSignUp');

const sessionExpiredMessage = '로그인이 만료됐어요. 다시 로그인해 주세요.';

/// 로그인 화면. 버튼은 [AuthViewModel.login]만 부르고 직접 화면을 이동하지 않는다.
/// 상태가 signedIn이 되면 Router가 홈으로, signedOut이 되면 이 화면으로 보낸다.
///
/// - 이메일·비밀번호 오류(AUTH401_1), 통신 실패, 저장 실패를 같은 문구로 뭉치지 않는다.
/// - 세션이 **만료돼서** 이 화면으로 왔을 때만 Snackbar로 한 번 안내한다(직접 로그아웃·로그인 실패는 아님).
/// - "이메일 저장"은 이메일만 shared_preferences에 둔다. 비밀번호와 토큰은 저장하지 않는다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialEmail});

  /// 회원가입 직후 넘어왔을 때 미리 채울 이메일.
  final String? initialEmail;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final AuthViewModel _auth;
  late final EmailPreference _emailPreference;
  bool _rememberEmail = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthViewModel>();
    _emailPreference = context.read<EmailPreference>();
    _email.text = widget.initialEmail ?? '';
    _auth.addListener(_showSessionExpired);
    // 이미 만료된 상태로 이 화면이 처음 열리는 경우도 처리한다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionExpired());
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    String? saved;
    try {
      saved = await _emailPreference.read();
    } catch (_) {
      return; // 저장된 이메일을 못 읽어도 로그인은 할 수 있다.
    }
    if (!mounted || saved == null || saved.isEmpty) return;
    setState(() {
      _rememberEmail = true;
      // 가입 직후 넘어온 이메일이 있으면 그것이 우선이다.
      if (_email.text.isEmpty) _email.text = saved!;
    });
  }

  @override
  void didUpdateWidget(LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 로그인 화면 위에 회원가입을 push했다가 가입 뒤 go(login, extra: email)로 돌아오면
    // 같은 State가 재사용되어 initState가 다시 실행되지 않는다. 새로 넘어온 이메일은 여기서 채운다.
    final email = widget.initialEmail;
    if (email != null && email != oldWidget.initialEmail) {
      _email.text = email;
      _password.clear(); // 이전 시도의 비밀번호가 남아 있지 않게 한다.
    }
  }

  void _showSessionExpired() {
    if (!mounted || !_auth.sessionExpired) return;
    // 같은 Snackbar가 반복되지 않게 표시 전에 먼저 끈다.
    _auth.consumeSessionExpired();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(sessionExpiredMessage)));
  }

  @override
  void dispose() {
    _auth.removeListener(_showSessionExpired);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final remember = _rememberEmail;
    // 로그인에 성공하면 Router가 이 화면을 곧바로 치우므로, context 없이 쓸 것들을 미리 꺼내 둔다.
    final auth = _auth;
    final preference = _emailPreference;
    await auth.login(email, _password.text);
    if (!auth.isSignedIn) return;
    try {
      // 이메일만 저장한다. 체크를 풀고 로그인하면 저장해 둔 이메일도 지운다.
      if (remember) {
        await preference.save(email);
      } else {
        await preference.clear();
      }
    } catch (_) {
      // 이메일 저장 실패가 로그인을 막지는 않는다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final loading = auth.status == AuthStatus.authenticating;
    final enabled = !loading && !auth.storageCleanupInProgress;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('로그인'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Image.asset(
                      'assets/logos/movielog_logo.png',
                      width: 84,
                      height: 84,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'MovieLog에 로그인',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      key: loginEmailFieldKey,
                      controller: _email,
                      enabled: enabled,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: '이메일'),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? '이메일을 입력해 주세요.'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: loginPasswordFieldKey,
                      controller: _password,
                      enabled: enabled,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => enabled ? _submit() : null,
                      decoration: const InputDecoration(labelText: '비밀번호'),
                      validator: (value) =>
                          (value?.isEmpty ?? true) ? '비밀번호를 입력해 주세요.' : null,
                    ),
                    CheckboxListTile(
                      key: rememberEmailKey,
                      value: _rememberEmail,
                      onChanged: enabled
                          ? (value) =>
                                setState(() => _rememberEmail = value ?? false)
                          : null,
                      title: const Text('이메일 저장'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (auth.message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          auth.message!,
                          key: loginErrorKey,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    const SizedBox(height: 24),
                    MovieLogButton(
                      key: loginButtonKey,
                      label: '로그인',
                      width: double.infinity,
                      height: 52,
                      isLoading: loading,
                      onPressed: enabled ? _submit : null,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      key: loginGoSignUpKey,
                      onPressed: enabled
                          ? () => context.push(AppRoutes.signUp)
                          : null,
                      child: const Text('회원가입'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
