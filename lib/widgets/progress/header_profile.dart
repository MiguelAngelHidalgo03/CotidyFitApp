import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/user_profile.dart';
import 'progress_section_card.dart';

class HeaderProfile extends StatelessWidget {
  const HeaderProfile({
    super.key,
    required this.profile,
    required this.onOpenProfile,
    required this.onOpenSuggestions,
  });

  final UserProfile? profile;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSuggestions;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      backgroundColor: context.cfSoftSurface,
      borderColor: context.cfBorder,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;

          ButtonStyle actionStyle() {
            return TextButton.styleFrom(
              foregroundColor: context.cfPrimary,
              backgroundColor: context.cfPrimaryTint,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                side: BorderSide(color: context.cfPrimaryTintStrong),
              ),
              textStyle: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onOpenSuggestions,
                  icon: const Icon(Icons.feedback_outlined, size: 18),
                  label: Text(compact ? 'Sugerencias' : 'Sugerencias'),
                  style: actionStyle(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  onPressed: onOpenProfile,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: Text(compact ? 'Opciones' : 'Opciones'),
                  style: actionStyle(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
