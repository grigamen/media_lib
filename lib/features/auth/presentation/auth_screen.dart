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
  final Future<void> Function(String email, String password, String displayName) onRegister;
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
    await widget.onRegister(email, password, _displayNameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MediaLib Auth")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isLoginMode ? "Вход" : "Регистрация",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: "Email"),
                    validator: (value) => (value == null || !value.contains("@")) ? "Введите корректный email" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Пароль"),
                    validator: (value) => (value == null || value.length < 8) ? "Минимум 8 символов" : null,
                  ),
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(labelText: "Имя профиля"),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? "Укажите имя профиля" : null,
                    ),
                  ],
                  if (widget.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.isLoading ? null : _submit,
                      child: widget.isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isLoginMode ? "Войти" : "Зарегистрироваться"),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.isLoading
                        ? null
                        : () {
                            setState(() {
                              _isLoginMode = !_isLoginMode;
                            });
                          },
                    child: Text(
                      _isLoginMode ? "Нет аккаунта? Регистрация" : "Уже есть аккаунт? Войти",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
