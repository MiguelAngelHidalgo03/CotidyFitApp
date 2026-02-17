import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/chat_model.dart';
import '../../models/contact_model.dart';
import '../../models/message_model.dart';
import '../../models/user_profile.dart';
import '../../services/community_chat_local_service.dart';
import '../../services/chat_repository.dart';
import '../../services/contacts_local_service.dart';
import '../../services/private_chat_local_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/community/message_bubble.dart';
import '../../widgets/progress/progress_section_card.dart';

enum _ChatScope { privateChat, privateContact, community }

class ChatScreen extends StatefulWidget {
  const ChatScreen._({
    required this.scope,
    this.chatId,
    this.contactId,
  });

  factory ChatScreen.private({required String chatId}) {
    return ChatScreen._(scope: _ChatScope.privateChat, chatId: chatId);
  }

  factory ChatScreen.privateContact({required String contactId}) {
    return ChatScreen._(scope: _ChatScope.privateContact, contactId: contactId);
  }

  factory ChatScreen.community({required String chatId}) {
    return ChatScreen._(scope: _ChatScope.community, chatId: chatId);
  }

  final _ChatScope scope;
  final String? chatId;
  final String? contactId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatRepository _communityRepo = CommunityChatLocalService();
  final _privateRepo = PrivateChatLocalService();
  final _profileService = ProfileService();
  final _contacts = ContactsLocalService();

  final _textCtrl = TextEditingController();

  ChatModel? _chat;
  ContactModel? _contact;
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final profile = await _profileService.getOrCreateProfile();

    ChatModel? chat;
    ContactModel? contact;

    if (widget.scope == _ChatScope.community) {
      await _communityRepo.seedIfEmpty();
      chat = await _communityRepo.getChatById(widget.chatId!);
    } else if (widget.scope == _ChatScope.privateChat) {
      chat = await _privateRepo.getChatById(widget.chatId!);
    } else {
      contact = await _contacts.getContactById(widget.contactId!);
      if (contact != null) {
        chat = await _privateRepo.getChatForContact(contact.id);
      }
    }

    if (!mounted) return;

    setState(() {
      _chat = chat;
      _contact = contact;
      _profile = profile;
      _loading = false;
    });

    if (chat != null) {
      if (widget.scope == _ChatScope.community) {
        await _communityRepo.markChatRead(chat.id);
        chat = await _communityRepo.getChatById(chat.id);
      } else {
        await _privateRepo.markChatRead(chat.id);
        chat = await _privateRepo.getChatById(chat.id);
      }
      if (!mounted) return;
      setState(() => _chat = chat);
    }
  }

  bool get _isProfessionalLocked {
    final profile = _profile;
    final contact = _contact;
    if (profile == null) return false;
    if (widget.scope == _ChatScope.privateContact && contact != null) {
      return contact.requiresPremium && !profile.isPremium;
    }
    if (widget.scope == _ChatScope.privateChat) {
      final chat = _chat;
      if (chat == null) return false;
      return chat.type == ChatType.profesional && !profile.isPremium;
    }
    return false;
  }

  Future<void> _send(MessageType type, String text) async {
    if (text.trim().isEmpty) return;

    if (_isProfessionalLocked) return;

    final chat = _chat;
    if (widget.scope == _ChatScope.community) {
      if (chat == null) return;
      if (chat.readOnly) return;
      await _communityRepo.sendMessage(chatId: chat.id, type: type, text: text);
    } else if (widget.scope == _ChatScope.privateChat) {
      if (chat == null) return;
      await _privateRepo.sendMessageToChat(chatId: chat.id, type: type, text: text);
    } else {
      final contact = _contact;
      if (contact == null) return;
      await _privateRepo.sendMessageToContact(contact: contact, type: type, text: text);
    }

    _textCtrl.clear();
    await _load();
  }

  Future<void> _openPlusMenu() async {
    final picked = await showModalBottomSheet<MessageType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        final maxHeight = MediaQuery.sizeOf(context).height * 0.70;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ProgressSectionCard(
                padding: const EdgeInsets.all(6),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    _PlusItem(
                      icon: Icons.fitness_center_outlined,
                      title: 'Rutina',
                      subtitle: 'Comparte una rutina',
                      onTap: () => Navigator.of(context).pop(MessageType.routine),
                    ),
                    const Divider(height: 1),
                    _PlusItem(
                      icon: Icons.emoji_events_outlined,
                      title: 'Logro',
                      subtitle: 'Comparte un logro',
                      onTap: () => Navigator.of(context).pop(MessageType.achievement),
                    ),
                    const Divider(height: 1),
                    _PlusItem(
                      icon: Icons.today_outlined,
                      title: 'Resumen del día',
                      subtitle: 'Comparte tu día',
                      onTap: () => Navigator.of(context).pop(MessageType.daySummary),
                    ),
                    const Divider(height: 1),
                    _PlusItem(
                      icon: Icons.restaurant_outlined,
                      title: 'Dieta',
                      subtitle: 'Comparte tu dieta',
                      onTap: () => Navigator.of(context).pop(MessageType.diet),
                    ),
                    const Divider(height: 1),
                    _PlusItem(
                      icon: Icons.local_fire_department_outlined,
                      title: 'Rachas',
                      subtitle: 'Comparte tus rachas',
                      onTap: () => Navigator.of(context).pop(MessageType.streaks),
                    ),
                    const Divider(height: 1),
                    _PlusItem(
                      icon: Icons.chat_bubble_outline,
                      title: 'Mensaje normal',
                      subtitle: 'Escribir',
                      onTap: () => Navigator.of(context).pop(MessageType.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (picked == null) return;

    final payload = switch (picked) {
      MessageType.text => null,
      MessageType.routine => 'Full body 20 min · Casa',
      MessageType.achievement => 'Racha 7 días · CF +20',
      MessageType.daySummary => 'CF 78 · Entreno completado · Agua 2L',
      MessageType.diet => 'Hoy: proteína alta · 2L agua · sin ultraprocesados',
      MessageType.streaks => 'Racha actual: 3 días · Racha máx: 7 días',
    };

    if (picked == MessageType.text) {
      if (mounted) FocusScope.of(context).requestFocus();
      return;
    }

    await _send(picked, payload ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final chat = _chat;
    final contact = _contact;

    final title = chat?.title ?? contact?.name ?? 'Chat';
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (chat != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: Text(
                  chat.type.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: CFColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isProfessionalLocked
            ? _PremiumLockedChat(title: title)
            : Column(
                children: [
                  if (chat != null && chat.readOnly)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: ProgressSectionCard(
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline, color: CFColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Chat solo lectura',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      reverse: true,
                      itemCount: chat?.messages.length ?? 0,
                      itemBuilder: (context, index) {
                        final messages = chat?.messages ?? const <MessageModel>[];
                        final m = messages[messages.length - 1 - index];
                        return MessageBubble(message: m);
                      },
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _isProfessionalLocked
          ? null
          : SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: viewInsetsBottom),
                child: _Composer(
                  enabled: chat == null ? true : !chat.readOnly,
                  controller: _textCtrl,
                  onPlus: _openPlusMenu,
                  onSend: () => _send(MessageType.text, _textCtrl.text),
                ),
              ),
            ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.enabled,
    required this.controller,
    required this.onPlus,
    required this.onSend,
  });

  final bool enabled;
  final TextEditingController controller;
  final VoidCallback onPlus;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: CFColors.background,
        border: Border(top: BorderSide(color: CFColors.softGray.withValues(alpha: 0.9))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Más',
            onPressed: enabled ? onPlus : null,
            icon: const Icon(Icons.add_circle_outline, color: CFColors.primary),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => enabled ? onSend() : null,
              decoration: InputDecoration(
                hintText: enabled ? 'Escribe un mensaje…' : 'Solo lectura',
                filled: true,
                fillColor: CFColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                  borderSide: BorderSide(color: CFColors.softGray),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                  borderSide: BorderSide(color: CFColors.softGray),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Enviar',
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send, color: CFColors.primary),
          ),
        ],
      ),
    );
  }
}

class _PlusItem extends StatelessWidget {
  const _PlusItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: CFColors.primary.withValues(alpha: 0.10),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: CFColors.softGray),
        ),
        child: Icon(icon, color: CFColors.primary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _PremiumLockedChat extends StatelessWidget {
  const _PremiumLockedChat({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ProgressSectionCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: CFColors.primary.withValues(alpha: 0.10),
                      borderRadius: const BorderRadius.all(Radius.circular(18)),
                      border: Border.all(color: CFColors.softGray),
                    ),
                    child: const Icon(Icons.workspace_premium_outlined, color: CFColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chat profesional',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Este chat con $title está bloqueado. Activa Premium para hablar con profesionales.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Premium: próximamente')),
                    );
                  },
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('Desbloquear Premium'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
