import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/contact_model.dart';
import '../../../models/user_profile.dart';
import '../../../services/contacts_local_service.dart';
import '../../../services/profile_service.dart';
import '../../../widgets/community/community_avatar.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../chat_screen.dart';

class CommunityContactsTab extends StatefulWidget {
  const CommunityContactsTab({super.key});

  @override
  State<CommunityContactsTab> createState() => _CommunityContactsTabState();
}

class _CommunityContactsTabState extends State<CommunityContactsTab> {
  final _contacts = ContactsLocalService();
  final _profileService = ProfileService();

  UserProfile? _profile;
  List<ContactModel> _all = const [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await _profileService.getOrCreateProfile();
    final contacts = await _contacts.getContacts();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _all = contacts;
      _loading = false;
    });
  }

  List<ContactModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((c) {
      return c.name.toLowerCase().contains(q) || c.tag.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _addFriend() async {
    final nameCtrl = TextEditingController();
    final tagCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir amigo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tagCtrl,
                decoration: const InputDecoration(labelText: 'Tag único', hintText: '@usuario123'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || tagCtrl.text.trim().isEmpty) return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    try {
      await _contacts.addFriendMock(name: nameCtrl.text, tag: tagCtrl.text);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud enviada (mock).')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo añadir: $e')));
    }
  }

  Future<void> _openContact(ContactModel c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen.privateContact(contactId: c.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    if (_loading || profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _CoachCard(
            isPremium: profile.isPremium,
            onOpen: () => _openContact(ContactsLocalService.coach),
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre o tag…',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Text('Amigos', style: Theme.of(context).textTheme.titleLarge)),
              FilledButton.icon(
                onPressed: _addFriend,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Añadir'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final c in _filtered) ...[
            _ContactRow(contact: c, onTap: () => _openContact(c)),
            const SizedBox(height: 10),
          ],
          if (_filtered.isEmpty)
            ProgressSectionCard(
              child: Text('Sin resultados.', style: Theme.of(context).textTheme.bodyMedium),
            ),
        ],
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.isPremium, required this.onOpen});

  final bool isPremium;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: CFColors.primary.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              border: Border.all(color: CFColors.softGray),
            ),
            child: const Icon(Icons.workspace_premium_outlined, color: CFColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Coach CotidyFit',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPremium ? CFColors.primary.withValues(alpha: 0.12) : CFColors.softGray,
                        borderRadius: const BorderRadius.all(Radius.circular(999)),
                        border: Border.all(color: isPremium ? CFColors.primary : CFColors.softGray),
                      ),
                      child: Text(
                        'Premium',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isPremium ? CFColors.primary : CFColors.textSecondary,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Chat 1:1 con un profesional (mock).',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onOpen,
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.onTap});

  final ContactModel contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pending = contact.status == ContactStatus.pending;

    return ProgressSectionCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CommunityAvatar(keySeed: contact.avatarKey, label: contact.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(contact.tag, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              if (pending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: CFColors.primary.withValues(alpha: 0.10),
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border: Border.all(color: CFColors.primary.withValues(alpha: 0.22)),
                  ),
                  child: Text(
                    'Pendiente',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CFColors.primary, fontWeight: FontWeight.w900),
                  ),
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
