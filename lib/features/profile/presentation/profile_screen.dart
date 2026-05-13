import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";

import "../../../core/network/api_client.dart";

/// После закрытия диалога и анимации клавиатуры, чтобы не ловить кадр с
/// полуснятым деревом при notifyListeners с других подписчиков AppState.
Future<void> _afterDialogUiSettled() async {
  await SchedulerBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(milliseconds: 80));
}

/// `showDialog` completes when [Navigator.pop] runs, but the route can still
/// rebuild [TextField]s during the pop transition; disposing the controller
/// immediately triggers "used after being disposed".
void _scheduleDisposeTextControllers(List<TextEditingController> controllers) {
  Future<void>.delayed(const Duration(milliseconds: 400), () {
    for (final c in controllers) {
      c.dispose();
    }
  });
}

void _postFrameSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  final text = message;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    messenger.showSnackBar(SnackBar(content: Text(text)));
  });
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.email,
    required this.displayName,
    required this.twofaEnabled,
    required this.onStartTwoFaEnable,
    required this.onConfirmTwoFaEnable,
    required this.onDisableTwoFa,
    required this.isDarkMode,
    required this.hasOwnedWorks,
    required this.onThemeToggle,
    required this.onDeleteAllWorks,
    required this.onOpenAddWork,
    required this.onLogout,
    required this.onUpdateProfile,
    required this.onChangePassword,
    this.onOpenMyWorks,
    this.onOpenAdminMedia,
    super.key,
  });

  final String email;
  final String displayName;
  final bool twofaEnabled;
  final Future<void> Function(String currentPassword) onStartTwoFaEnable;
  final Future<void> Function(String code) onConfirmTwoFaEnable;
  final Future<void> Function(String currentPassword) onDisableTwoFa;
  final bool isDarkMode;
  final bool hasOwnedWorks;
  final ValueChanged<bool> onThemeToggle;
  final Future<void> Function() onDeleteAllWorks;
  final VoidCallback onOpenAddWork;
  final VoidCallback onLogout;
  final Future<void> Function({
    required String displayName,
    String? newEmail,
    String? currentPasswordForEmail,
  })
  onUpdateProfile;
  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
  })
  onChangePassword;
  final VoidCallback? onOpenMyWorks;
  final VoidCallback? onOpenAdminMedia;

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              children: [
                Text(
                  "Профиль",
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.28),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 34,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.isNotEmpty
                                ? displayName
                                : "Пользователь",
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(email),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: "Выйти",
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openEditProfileDialog(context),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      label: const Text("Имя и email"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text("Общие", style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                _SettingsSwitchTile(
                  icon: Icons.dark_mode_outlined,
                  title: "Темная тема",
                  value: isDarkMode,
                  onChanged: onThemeToggle,
                ),
                if (hasOwnedWorks && onOpenMyWorks != null) ...[
                  _ActionTile(
                    icon: Icons.collections_bookmark_outlined,
                    title: "Мои произведения",
                    subtitle:
                        "Все записи, добавленные с этого аккаунта (включая на модерации)",
                    onTap: onOpenMyWorks!,
                  ),
                ],
                if (onOpenAdminMedia != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    "Администрирование",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  _ActionTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: "Панель администратора",
                    subtitle: "Вкладки: подтверждение и удаление произведений",
                    onTap: onOpenAdminMedia!,
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  "Безопасность",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                _EmailTwoFaSwitchTile(
                  twofaEnabled: twofaEnabled,
                  icon: Icons.mark_email_unread_outlined,
                  title: "Код на email после пароля",
                  subtitle:
                      "Письмо с одноразовым кодом при входе (мягкая 2FA)",
                  onToggle:
                      (ctx, enable) => _handleTwoFaToggle(
                        ctx,
                        enable: enable,
                        startTwoFaEnable: onStartTwoFaEnable,
                        confirmTwoFaEnable: onConfirmTwoFaEnable,
                        disableTwoFa: onDisableTwoFa,
                      ),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.password,
                  title: "Изменить пароль",
                  onTap: () => _openChangePasswordDialog(context),
                ),
                _ActionTile(
                  icon: Icons.add_box_outlined,
                  title: "Добавить произведение",
                  onTap: onOpenAddWork,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder:
                            (dialogContext) => AlertDialog(
                              title: const Text(
                                "Удалить созданные произведения",
                              ),
                              content: const Text(
                                "Это удалит только произведения, созданные вашим аккаунтом. Действие необратимо.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(
                                        dialogContext,
                                      ).pop(false),
                                  child: const Text("Отмена"),
                                ),
                                FilledButton(
                                  onPressed:
                                      () =>
                                          Navigator.of(dialogContext).pop(true),
                                  child: const Text("Удалить"),
                                ),
                              ],
                            ),
                      );
                      if (confirmed != true) {
                        return;
                      }
                      await onDeleteAllWorks();
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Ваши произведения удалены"),
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text("Удалить созданные произведения"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Отдельное состояние позиции переключателя: иначе [Switch] с [value] только с
/// сервера кратко расходится с внутренним состоянием Material и в debug даёт
/// assert / красный экран при отмене или неверном пароле.
class _EmailTwoFaSwitchTile extends StatefulWidget {
  const _EmailTwoFaSwitchTile({
    required this.twofaEnabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onToggle,
  });

  final bool twofaEnabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<bool> Function(BuildContext context, bool enable) onToggle;

  @override
  State<_EmailTwoFaSwitchTile> createState() => _EmailTwoFaSwitchTileState();
}

class _EmailTwoFaSwitchTileState extends State<_EmailTwoFaSwitchTile> {
  late bool _value;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _value = widget.twofaEnabled;
  }

  @override
  void didUpdateWidget(covariant _EmailTwoFaSwitchTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.twofaEnabled != oldWidget.twofaEnabled) {
      _value = widget.twofaEnabled;
    }
  }

  Future<void> _onChanged(bool next) async {
    if (_busy || next == _value) {
      return;
    }
    _busy = true;
    final previous = _value;
    setState(() => _value = next);
    final ok = await widget.onToggle(context, next);
    if (!mounted) {
      return;
    }
    _busy = false;
    if (!ok) {
      setState(() => _value = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.24),
        child: Icon(widget.icon),
      ),
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
      isThreeLine: true,
      trailing: Switch(
        value: _value,
        onChanged: _busy ? null : (n) => unawaited(_onChanged(n)),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.24),
        child: Icon(icon),
      ),
      title: Text(title),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.24),
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      isThreeLine: subtitle != null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
