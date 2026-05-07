import "package:flutter/material.dart";

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.onLogin,
    required this.onRegister,
    required this.isLoading,
    required this.errorMessage,
    super.key,
  });

  final Future<void> Function(String email, String password) onLogin;
  final Future<void> Function(String email, String password, String displayName)
  onRegister;
  final bool isLoading;
  final String? errorMessage;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController(text: "Media User");
  final _formKey = GlobalKey<FormState>();

  bool _isLoginMode = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_isLoginMode) {
      await widget.onLogin(email, password);
      return;
    }
    await widget.onRegister(
      email,
      password,
      _displayNameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 28, 18, 22),
              children: [
                const _LogoHeader(),
                const SizedBox(height: 26),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isLoginMode ? "Вход" : "Регистрация",
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 14),
                          if (!_isLoginMode) ...[
                            TextFormField(
                              controller: _displayNameController,
                              decoration: const InputDecoration(
                                hintText: "Имя пользователя",
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator:
                                  (value) =>
                                      (value == null || value.trim().isEmpty)
                                          ? "Укажите имя"
                                          : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: "Email",
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator:
                                (value) =>
                                    (value == null || !value.contains("@"))
                                        ? "Введите корректный email"
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: "Пароль",
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator:
                                (value) =>
                                    (value == null || value.length < 8)
                                        ? "Минимум 8 символов"
                                        : null,
                          ),
                          if (widget.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              widget.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: widget.isLoading ? null : _submit,
                              child:
                                  widget.isLoading
                                      ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Text(
                                        _isLoginMode
                                            ? "Войти"
                                            : "Зарегистрироваться",
                                      ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed:
                                widget.isLoading
                                    ? null
                                    : () {
                                      setState(() {
                                        _isLoginMode = !_isLoginMode;
                                      });
                                    },
                            child: Text(
                              _isLoginMode
                                  ? "Создать аккаунт"
                                  : "Уже есть аккаунт?",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.shield_outlined,
            size: 34,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text("MediaLib", style: Theme.of(context).textTheme.headlineMedium),
        Text(
          "Ваша персональная медиатека",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
