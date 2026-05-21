import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

/// Второй шаг входа: ввод кода из письма.
class EmailTwoFaScreen extends StatefulWidget {
  const EmailTwoFaScreen({
    required this.email,
    required this.displayName,
    required this.isLoading,
    required this.errorMessage,
    required this.onVerify,
    required this.onResend,
    required this.onBackToLogin,
    this.hintMessage,
    super.key,
  });

  final String email;
  final String displayName;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function(String code) onVerify;
  final Future<void> Function() onResend;
  final VoidCallback onBackToLogin;
  final String? hintMessage;

  @override
  State<EmailTwoFaScreen> createState() => _EmailTwoFaScreenState();
}

class _EmailTwoFaScreenState extends State<EmailTwoFaScreen> {
  final _codeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown(seconds: 60);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startResendCooldown({required int seconds}) {
    _resendTimer?.cancel();
    setState(() {
      _resendSecondsLeft = seconds;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resendSecondsLeft -= 1;
      });
      if (_resendSecondsLeft <= 0) {
        t.cancel();
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await widget.onVerify(_codeCtrl.text.trim());
  }

  Future<void> _resend() async {
    if (_resendSecondsLeft > 0 || widget.isLoading) {
      return;
    }
    await widget.onResend();
    if (mounted) {
      _startResendCooldown(seconds: 60);
    }
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
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  "Код из письма",
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Мы отправили код на ${widget.email}",
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (widget.hintMessage != null &&
                    widget.hintMessage!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.hintMessage!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 22),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _codeCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(12),
                            ],
                            decoration: const InputDecoration(
                              labelText: "Код",
                              prefixIcon: Icon(Icons.pin_outlined),
                            ),
                            validator:
                                (value) =>
                                    (value == null || value.trim().length < 4)
                                        ? "Введите код из письма"
                                        : null,
                            onFieldSubmitted: (_) => unawaited(_submit()),
                            enabled: !widget.isLoading,
                          ),
                          if (widget.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              widget.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed:
                                widget.isLoading
                                    ? null
                                    : () => unawaited(_submit()),
                            child:
                                widget.isLoading
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text("Подтвердить"),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed:
                                (_resendSecondsLeft > 0 || widget.isLoading)
                                    ? null
                                    : () => unawaited(_resend()),
                            child: Text(
                              _resendSecondsLeft > 0
                                  ? "Отправить снова ($_resendSecondsLeft с)"
                                  : "Отправить код снова",
                            ),
                          ),
                          TextButton(
                            onPressed:
                                widget.isLoading ? null : widget.onBackToLogin,
                            child: const Text("Назад к логину"),
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
