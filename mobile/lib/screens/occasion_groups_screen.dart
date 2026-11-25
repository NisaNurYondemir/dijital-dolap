import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/models/occasion_group.dart';
import 'package:dijital_dolap/providers/occasion_provider.dart';
import 'package:dijital_dolap/theme/app_theme.dart';
import 'package:dijital_dolap/widgets/occasion_group_dialog.dart';

class OccasionGroupsScreen extends StatefulWidget {
  const OccasionGroupsScreen({super.key});

  @override
  State<OccasionGroupsScreen> createState() => _OccasionGroupsScreenState();
}

class _OccasionGroupsScreenState extends State<OccasionGroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<OccasionProvider>();
      if (provider.groups.isEmpty) provider.load();
    });
  }

  Future<void> _delete(OccasionGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Grup silinsin mi?'),
        content: Text(
          '"${group.name}" grubu kombinlerden ve giyim geçmişi '
          'bağlantılarından kaldırılacak. Geçmişteki amaç metni korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<OccasionProvider>();
    final ok = await provider.delete(group.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Grup silindi' : (provider.error ?? 'Grup silinemedi'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OccasionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Amaç Grupları')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showOccasionGroupDialog(context),
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni grup'),
      ),
      body: provider.loading && provider.groups.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && provider.groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(provider.error!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: provider.load,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 16),
                      child: Text(
                        'Kombinlerini okul, iş, arkadaş, romantik, özel gün '
                        'gibi amaçlara göre grupla. Her grubun bir etkinlik '
                        'tipi var; öneri motoru parçaları bu tipe göre seçer. '
                        'Kendi gruplarını da ekleyebilirsin.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.slate,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (provider.groups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Henüz amaç grubu yok. Sağ alttaki düğmeyle '
                          'ilk grubunu oluştur.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.slate),
                        ),
                      ),
                    for (final group in provider.groups) ...[
                      _GroupTile(
                        group: group,
                        onEdit: () => showOccasionGroupDialog(
                          context,
                          group: group,
                        ),
                        onDelete: () => _delete(group),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.onEdit,
    required this.onDelete,
  });

  final OccasionGroup group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: group.color.withValues(alpha: 0.18),
          child: Text(
            (group.emoji?.trim().isNotEmpty ?? false) ? group.emoji! : '🏷️',
            style: const TextStyle(fontSize: 18),
          ),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Row(
          children: [
            if (group.isDefault) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x33F2B84B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Varsayılan',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                group.typeLabel,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Düzenle',
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
              icon: const Icon(
                Icons.edit_outlined,
                size: 20,
                color: AppColors.slate,
              ),
            ),
            IconButton(
              tooltip: 'Sil',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
