import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'tabs/community_chats_tab.dart';
import 'tabs/community_communities_tab.dart';
import 'tabs/community_contacts_tab.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: TabBar(
            labelColor: CFColors.primary,
            unselectedLabelColor: CFColors.textSecondary,
            indicatorColor: CFColors.primary,
            labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
            tabs: const [
              Tab(text: 'Chats'),
              Tab(text: 'Contactos'),
              Tab(text: 'Comunidades'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CommunityChatsTab(),
            CommunityContactsTab(),
            CommunityCommunitiesTab(),
          ],
        ),
      ),
    );
  }
}
