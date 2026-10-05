import 'package:flutter/material.dart';
import 'package:dijital_dolap/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifications = true;
  bool _darkMode = false; // Şimdilik sadece görsel, tema geçişi sonra bağlanır.

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what yakında')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Kullanıcı kartı
          _Panel(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.thread,
                  child: Text(
                    'N',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nisa Nur',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'nisa@ornek.com',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _soon('Profil düzenleme'),
                  icon: const Icon(Icons.edit_outlined, color: AppColors.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // İstatistikler
          const Row(
            children: [
              Expanded(child: _Stat(value: '8', label: 'Parça')),
              SizedBox(width: 12),
              Expanded(child: _Stat(value: '3', label: 'Kombin')),
              SizedBox(width: 12),
              Expanded(child: _Stat(value: '1', label: 'Favori')),
            ],
          ),
          const SizedBox(height: 24),

          const _SectionTitle('Tercihler'),
          _Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: _notifications,
                  onChanged: (v) => setState(() => _notifications = v),
                  secondary: const Icon(
                    Icons.notifications_none,
                    color: AppColors.ink,
                  ),
                  title: const Text('Bildirimler'),
                ),
                const Divider(height: 1, color: AppColors.line),
                SwitchListTile(
                  value: _darkMode,
                  onChanged: (v) => setState(() => _darkMode = v),
                  secondary: const Icon(
                    Icons.dark_mode_outlined,
                    color: AppColors.ink,
                  ),
                  title: const Text('Karanlık tema'),
                ),
                const Divider(height: 1, color: AppColors.line),
                _NavTile(
                  icon: Icons.language,
                  title: 'Dil',
                  trailing: 'Türkçe',
                  onTap: () => _soon('Dil seçimi'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const _SectionTitle('Hesap'),
          _Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.lock_outline,
                  title: 'Şifre değiştir',
                  onTap: () => _soon('Şifre değiştirme'),
                ),
                const Divider(height: 1, color: AppColors.line),
                _NavTile(
                  icon: Icons.help_outline,
                  title: 'Yardım ve destek',
                  onTap: () => _soon('Yardım'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

                    OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Çıkış yap'),
                  content: const Text('Hesabından çıkmak istediğine emin misin?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Vazgeç'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      child: const Text('Çıkış yap'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await context.read<AuthProvider>().logout();
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış yap'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.slate,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.ink),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(trailing!, style: Theme.of(context).textTheme.bodyMedium),
          const Icon(Icons.chevron_right, color: AppColors.slate),
        ],
      ),
    );
  }
}
