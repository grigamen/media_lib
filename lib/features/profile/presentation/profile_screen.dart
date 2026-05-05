import "package:flutter/material.dart";

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.email,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.onLogout,
    super.key,
  });

  final String email;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeToggle;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Профиль", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text("Email"),
            subtitle: Text(email),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: isDarkMode,
          onChanged: onThemeToggle,
          title: const Text("Темная тема"),
          subtitle: const Text("Переключение между светлой и темной темами"),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text("Выйти"),
        ),
      ],
    );
  }
}
