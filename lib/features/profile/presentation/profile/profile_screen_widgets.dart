part of "profile_screen.dart";

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
