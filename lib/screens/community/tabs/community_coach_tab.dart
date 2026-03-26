import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/user_profile.dart';
import '../../../screens/profile/premium_screen.dart';
import '../../../services/chat_service.dart';
import '../../../services/contacts_local_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/social_firestore_service.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../chat_screen.dart';

class CommunityCoachTab extends StatefulWidget {
  const CommunityCoachTab({super.key});

  @override
  State<CommunityCoachTab> createState() => _CommunityCoachTabState();
}

class _CommunityCoachTabState extends State<CommunityCoachTab>
    with AutomaticKeepAliveClientMixin {
  final ProfileService _profiles = ProfileService();
  final ChatService _chatService = ChatService();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  UserProfile? _profile;
  bool _loading = true;
  bool _openingLiveChat = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await _profiles.getOrCreateProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openLocalCoach() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen.privateContact(contactId: ContactsLocalService.coach.id),
      ),
    );
  }

  Future<String> _myDisplayName(User user) async {
    final authName = (user.displayName ?? '').trim();
    if (authName.isNotEmpty) return authName;

    final localName = (_profile?.name ?? '').trim();
    if (localName.isNotEmpty && localName != 'CotidyFit') return localName;

    final email = (user.email ?? '').trim();
    if (email.contains('@')) return email.split('@').first.trim();

    return 'Usuario';
  }

  Future<String> _myUniqueTag(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data() ?? const <String, dynamic>{};
      final uniqueTag = (data['uniqueTag'] as String?)?.trim() ?? '';
      if (uniqueTag.isNotEmpty) return uniqueTag;

      final username = (data['username'] as String?)?.trim() ?? '';
      final tag = (data['tag'] as String?)?.trim() ?? '';
      if (username.isNotEmpty && tag.isNotEmpty) return '$username#$tag';
    } catch (_) {
      // Best-effort only.
    }
    return '';
  }

  Future<void> _ensureCoachDm({required _CoachConfig coach}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('no-auth');

    final myUid = user.uid.trim();
    final coachUid = coach.uid.trim();
    if (coachUid.isEmpty || myUid.isEmpty || coachUid == myUid) {
      throw StateError('invalid-coach');
    }

    final chatId = SocialFirestoreService.pairIdFor(myUid, coachUid);
    final friendshipRef = _db.collection('friendships').doc(chatId);
    final friendshipSnap = await friendshipRef.get();

    if (!friendshipSnap.exists) {
      final members = <String>[myUid, coachUid]..sort();
      final aUid = members.first;
      final bUid = members.last;

      final myName = await _myDisplayName(user);
      final myTag = await _myUniqueTag(myUid);

      final aName = aUid == myUid ? myName : coach.name;
      final bName = bUid == myUid ? myName : coach.name;
      final aTag = aUid == myUid ? myTag : coach.tag;
      final bTag = bUid == myUid ? myTag : coach.tag;

      await friendshipRef.set({
        'uids': members,
        'aUid': aUid,
        'bUid': bUid,
        'aName': aName,
        'bName': bName,
        'aUniqueTag': aTag,
        'bUniqueTag': bTag,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await _chatService.ensureDmChatFromFriendship(chatId: chatId);
  }

  Future<void> _openLiveCoach({required _CoachConfig coach}) async {
    if (_openingLiveChat) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Inicia sesión para hablar con tu coach.');
      return;
    }

    final chatId = SocialFirestoreService.pairIdFor(user.uid, coach.uid);

    setState(() => _openingLiveChat = true);
    try {
      await _ensureCoachDm(coach: coach);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ChatScreen.dm(chatId: chatId)));
    } catch (_) {
      if (!mounted) return;
      _snack('No se pudo abrir el chat del coach.');
    } finally {
      if (mounted) {
        setState(() => _openingLiveChat = false);
      }
    }
  }

  Widget _heroCard({required bool isPremium}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? const <Color>[Color(0xFF1F3C67), Color(0xFF446A9B)]
              : const <Color>[Color(0xFF6C707B), Color(0xFF8A8E98)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: Text(
              isPremium ? 'Coach Premium' : 'Coach bloqueado',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Habla con un profesional desde la app.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isPremium
                ? 'El acceso premium abre un chat dedicado con tu coach para seguimiento real y directo.'
                : 'El chat directo con el coach queda reservado para usuarios premium.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitsRow() {
    const benefits = <_CoachBenefit>[
      _CoachBenefit(icon: Icons.bolt_outlined, label: 'Directo'),
      _CoachBenefit(icon: Icons.lock_outline, label: 'Privado'),
      _CoachBenefit(icon: Icons.workspace_premium_outlined, label: 'Premium'),
    ];

    return Row(
      children: [
        for (var index = 0; index < benefits.length; index++) ...[
          Expanded(
            child: ProgressSectionCard(
              backgroundColor: context.cfSoftSurface,
              borderColor: context.cfBorder,
              child: Column(
                children: [
                  Icon(benefits[index].icon, color: context.cfPrimary),
                  const SizedBox(height: 8),
                  Text(
                    benefits[index].label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.cfTextPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (index != benefits.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _lockedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(isPremium: false),
        const SizedBox(height: 16),
        _benefitsRow(),
        const SizedBox(height: 16),
        ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Qué desbloqueas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                'Consulta dudas, comparte contexto y mantén un hilo continuo con tu profesional desde Comunidad.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  );
                },
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Ver Premium'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _liveCoachCard(_CoachConfig coach) {
    final canUseLiveChat = coach.uid.trim().isNotEmpty;

    return ProgressSectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: context.cfPrimaryTint,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  border: Border.all(color: context.cfPrimaryTintStrong),
                ),
                child: Icon(
                  Icons.support_agent_outlined,
                  color: context.cfPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coach.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (coach.tag.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        coach.tag,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.cfPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      coach.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _CoachPill(label: 'Chat directo'),
              _CoachPill(label: 'Seguimiento personal'),
              _CoachPill(label: 'Dentro de Comunidad'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            canUseLiveChat
                ? 'El chat se abrirá sobre la mensajería real de Comunidad para mantener la conversación en un solo hilo.'
                : 'Falta configurar el UID del coach en app_config/community para activar el chat en directo.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: !canUseLiveChat || _openingLiveChat
                      ? null
                      : () => _openLiveCoach(coach: coach),
                  icon: _openingLiveChat
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    _openingLiveChat ? 'Abriendo…' : 'Abrir chat en directo',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _openLocalCoach,
                icon: const Icon(Icons.offline_bolt_outlined),
                label: const Text('Fallback local'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final profile = _profile;
    if (profile == null) {
      return const Center(child: Text('No se pudo cargar el perfil.'));
    }

    final firebaseReady = Firebase.apps.isNotEmpty;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (!profile.isPremium) ...[
            _lockedState(),
          ] else ...[
            _heroCard(isPremium: true),
            const SizedBox(height: 16),
            _benefitsRow(),
            const SizedBox(height: 16),
            if (!firebaseReady || user == null)
              ProgressSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modo local',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay sesión Firebase activa. Puedes seguir usando el chat local del coach mientras tanto.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _openLocalCoach,
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Abrir coach local'),
                    ),
                  ],
                ),
              )
            else
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _db
                    .collection('app_config')
                    .doc('community')
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final coach = _CoachConfig.fromMap(data);
                  return _liveCoachCard(coach);
                },
              ),
          ],
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _CoachConfig {
  const _CoachConfig({
    required this.uid,
    required this.name,
    required this.tag,
    required this.subtitle,
  });

  final String uid;
  final String name;
  final String tag;
  final String subtitle;

  static _CoachConfig fromMap(Map<String, dynamic>? data) {
    final coachRaw = data?['coach'];
    final map = coachRaw is Map
        ? coachRaw.map((k, v) => MapEntry(k.toString(), v))
        : const <String, Object?>{};

    String read(String key, String fallback) {
      final value = (map[key] as String?)?.trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    return _CoachConfig(
      uid: (map['uid'] as String?)?.trim() ?? '',
      name: read('name', ContactsLocalService.coach.name),
      tag: read('tag', ContactsLocalService.coach.tag),
      subtitle: read(
        'subtitle',
        'Coach personal disponible para seguimiento y respuesta directa.',
      ),
    );
  }
}

class _CoachBenefit {
  const _CoachBenefit({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _CoachPill extends StatelessWidget {
  const _CoachPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.cfPrimaryTint,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: context.cfPrimaryTintStrong),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.cfPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
