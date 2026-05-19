import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";

import "../../../../core/network/api_client.dart";

part "profile_screen_dialog_helpers.dart";
part "profile_screen_dialogs.dart";
part "profile_screen_widgets.dart";

// Вкладка «Профиль»: аккаунт, безопасность (2FA, пароль), тема, работы и выход.

/// Список настроек и действий профиля; бизнес-логика передаётся колбэками из родителя.
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
    this.onOpenShelves,
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
  final VoidCallback? onOpenShelves;
  final VoidCallback? onOpenAdminMedia;

  /// Разметка списка секций профиля и обработчики навигации/диалогов.
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
                if (onOpenShelves != null) ...[
                  _ActionTile(
                    icon: Icons.bookmarks_outlined,
                    title: "Мои полки",
                    subtitle:
                        "Личные подборки произведений — видите только вы",
                    onTap: onOpenShelves!,
                  ),
                ],
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
