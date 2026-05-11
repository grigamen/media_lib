import "package:flutter/material.dart";

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.email,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.onDeleteAllWorks,
    required this.onOpenAddWork,
    required this.onLogout,
    this.onOpenAdminMedia,
    super.key,
  });

  final String email;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeToggle;
  final Future<void> Function() onDeleteAllWorks;
  final VoidCallback onOpenAddWork;
  final VoidCallback onLogout;
  final VoidCallback? onOpenAdminMedia;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                          "Иван Иванов",
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
              const SizedBox(height: 20),
              Text("Общие", style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              _SettingsSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: "Темная тема",
                value: isDarkMode,
                onChanged: onThemeToggle,
              ),
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
              _ActionTile(
                icon: Icons.lock_outline,
                title: "Двухфакторная\nаутентификация",
                onTap: () {},
              ),
              _ActionTile(
                icon: Icons.password,
                title: "Изменить пароль",
                onTap: () {},
              ),
              _ActionTile(
                icon: Icons.add_box_outlined,
                title: "Добавить произведение",
                onTap: onOpenAddWork,
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                            title: const Text("Удалить созданные произведения"),
                            content: const Text(
                              "Это удалит только произведения, созданные вашим аккаунтом. Действие необратимо.",
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    () =>
                                        Navigator.of(dialogContext).pop(false),
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
