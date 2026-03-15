import "package:flutter/material.dart";

class AccountSettingsScreenArgs {
  AccountSettingsScreenArgs({required this.accessToken});

  final String accessToken;
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({
    super.key,
    required this.accessToken,
  });

  final String accessToken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17181C),
        foregroundColor: const Color(0xFFF2D05C),
        title: Text(
          "ACCOUNT SETTINGS",
          style: theme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFFF2D05C),
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsTile(
            icon: Icons.person_outline,
            label: "Edit Profile",
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            label: "Change Password",
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: "Notifications",
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.language,
            label: "Language",
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF17181C),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFF2D05C)),
        title: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFF0F0F0),
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}
