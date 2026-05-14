part of "profile_screen.dart";

// Модальные окна профиля: данные пользователя, пароль, пошаговое включение/выключение 2FA.

/// Диалоги, открываемые из [ProfileScreen] (редактирование, безопасность).
extension _ProfileScreenDialogs on ProfileScreen {

  /// Имя, email и при смене почты — текущий пароль; вызов [onUpdateProfile].
  Future<void> _openEditProfileDialog(BuildContext context) async {
    final nameCtrl = TextEditingController(text: displayName);
    final emailCtrl = TextEditingController(text: email);
    final passwordCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var busy = false;
        String? errorText;
        return StatefulBuilder(
          builder: (dialogInnerContext, setDialogState) {
            final emailChanged =
                emailCtrl.text.trim().toLowerCase() !=
                email.trim().toLowerCase();

            Future<void> submit() async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                setDialogState(() {
                  errorText = "Укажите имя";
                });
                return;
              }
              if (emailChanged && (passwordCtrl.text.isEmpty)) {
                setDialogState(() {
                  errorText = "Для смены email введите текущий пароль";
                });
                return;
              }
              setDialogState(() {
                busy = true;
                errorText = null;
              });
              try {
                await onUpdateProfile(
                  displayName: name,
                  newEmail: emailCtrl.text.trim(),
                  currentPasswordForEmail:
                      emailChanged ? passwordCtrl.text : null,
                );
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Данные сохранены")),
                  );
                }
              } on ApiException catch (e) {
                setDialogState(() {
                  busy = false;
                  errorText = e.message;
                });
              } catch (_) {
                setDialogState(() {
                  busy = false;
                  errorText = "Не удалось сохранить";
                });
              }
            }

            return AlertDialog(
              title: const Text("Редактировать профиль"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: "Отображаемое имя",
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      enabled: !busy,
                      decoration: const InputDecoration(labelText: "Email"),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (emailChanged) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: "Текущий пароль (для смены email)",
                        ),
                        obscureText: true,
                      ),
                    ],
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: Theme.of(dialogInnerContext).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      busy ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text("Отмена"),
                ),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child:
                      busy
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text("Сохранить"),
                ),
              ],
            );
          },
        );
      },
    );
    _scheduleDisposeTextControllers([nameCtrl, emailCtrl, passwordCtrl]);
  }

  /// Текущий и новый пароль с подтверждением; вызов [onChangePassword].
  Future<void> _openChangePasswordDialog(BuildContext context) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var busy = false;
        String? errorText;
        return StatefulBuilder(
          builder: (dialogInnerContext, setDialogState) {
            Future<void> submit() async {
              if (currentCtrl.text.length < 8 ||
                  newCtrl.text.length < 8 ||
                  confirmCtrl.text.length < 8) {
                setDialogState(() {
                  errorText = "Пароль не короче 8 символов";
                });
                return;
              }
              if (newCtrl.text != confirmCtrl.text) {
                setDialogState(() {
                  errorText = "Новый пароль и подтверждение не совпадают";
                });
                return;
              }
              if (currentCtrl.text == newCtrl.text) {
                setDialogState(() {
                  errorText = "Новый пароль должен отличаться от текущего";
                });
                return;
              }
              setDialogState(() {
                busy = true;
                errorText = null;
              });
              try {
                await onChangePassword(
                  currentPassword: currentCtrl.text,
                  newPassword: newCtrl.text,
                );
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Пароль изменён. При следующем входе используйте новый пароль.",
                      ),
                    ),
                  );
                }
              } on ApiException catch (e) {
                setDialogState(() {
                  busy = false;
                  errorText = e.message;
                });
              } catch (_) {
                setDialogState(() {
                  busy = false;
                  errorText = "Не удалось сменить пароль";
                });
              }
            }

            return AlertDialog(
              title: const Text("Смена пароля"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: currentCtrl,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: "Текущий пароль",
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newCtrl,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: "Новый пароль",
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmCtrl,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: "Повторите новый пароль",
                      ),
                      obscureText: true,
                      onSubmitted: (_) => unawaited(submit()),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: Theme.of(dialogInnerContext).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      busy ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text("Отмена"),
                ),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child:
                      busy
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text("Сменить пароль"),
                ),
              ],
            );
          },
        );
      },
    );
    _scheduleDisposeTextControllers([currentCtrl, newCtrl, confirmCtrl]);
  }

  /// Ввод текущего пароля перед шагами 2FA (минимальная длина проверяется локально).
  Future<String?> _promptTwoFaPasswordDialog(
    BuildContext context, {
    required String title,
  }) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Текущий пароль"),
            onSubmitted: (_) => Navigator.of(dialogContext).pop(ctrl.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Отмена"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(ctrl.text),
              child: const Text("Далее"),
            ),
          ],
        );
      },
    );
    _scheduleDisposeTextControllers([ctrl]);
    final t = result?.trim() ?? "";
    if (t.length < 8) {
      return null;
    }
    return t;
  }

  /// Диалог кода из письма на этапе включения 2FA.
  Future<String?> _promptTwoFaCodeDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Код из письма"),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Код",
              hintText: "Цифры из email",
            ),
            onSubmitted: (_) => Navigator.of(dialogContext).pop(ctrl.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Отмена"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(ctrl.text),
              child: const Text("Включить 2FA"),
            ),
          ],
        );
      },
    );
    _scheduleDisposeTextControllers([ctrl]);
    final t = result?.trim() ?? "";
    if (t.length < 4) {
      return null;
    }
    return t;
  }

  /// [true] если 2FA реально включена/выключена; [false] при отмене или ошибке.
  Future<bool> _handleTwoFaToggle(
    BuildContext context, {
    required bool enable,
    required Future<void> Function(String password) startTwoFaEnable,
    required Future<void> Function(String code) confirmTwoFaEnable,
    required Future<void> Function(String password) disableTwoFa,
  }) async {
    if (enable) {
      final pwd = await _promptTwoFaPasswordDialog(
        context,
        title: "Включить 2FA — введите пароль",
      );
      if (pwd == null) {
        return false;
      }
      await _afterDialogUiSettled();
      if (!context.mounted) {
        return false;
      }
      try {
        await startTwoFaEnable(pwd);
      } on ApiException catch (e) {
        if (context.mounted) {
          _postFrameSnackBar(context, e.message);
        }
        return false;
      } catch (_) {
        if (context.mounted) {
          _postFrameSnackBar(context, "Не удалось отправить код");
        }
        return false;
      }
      await _afterDialogUiSettled();
      if (!context.mounted) {
        return false;
      }
      final code = await _promptTwoFaCodeDialog(context);
      if (code == null) {
        return false;
      }
      try {
        await confirmTwoFaEnable(code);
      } on ApiException catch (e) {
        if (context.mounted) {
          _postFrameSnackBar(context, e.message);
        }
        return false;
      } catch (_) {
        if (context.mounted) {
          _postFrameSnackBar(context, "Неверный или просроченный код");
        }
        return false;
      }
      if (context.mounted) {
        _postFrameSnackBar(context, "Двухфакторная защита включена");
      }
      return true;
    }

    final pwd = await _promptTwoFaPasswordDialog(
      context,
      title: "Выключить 2FA — введите пароль",
    );
    if (pwd == null) {
      return false;
    }
    await _afterDialogUiSettled();
    if (!context.mounted) {
      return false;
    }
    try {
      await disableTwoFa(pwd);
    } on ApiException catch (e) {
      if (context.mounted) {
        _postFrameSnackBar(context, e.message);
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        _postFrameSnackBar(context, "Не удалось выключить 2FA");
      }
      return false;
    }
    if (context.mounted) {
      _postFrameSnackBar(context, "Двухфакторная защита выключена");
    }
    return true;
  }
}
