import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/profile_service.dart';
import 'main_navigation.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _goals = <String>[
    'Perder grasa',
    'Ganar masa muscular',
    'Mantener peso',
    'Mejorar hábitos',
  ];

  final _service = ProfileService();
  String? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final goal = await _service.getGoal();
    if (!mounted) return;
    setState(() {
      _selected = goal;
    });
  }

  Future<void> _save() async {
    final goal = _selected;
    if (goal == null) return;

    setState(() => _saving = true);
    await _service.setGoal(goal);
    if (!mounted) return;

    if (widget.isEditing) {
      Navigator.of(context).pop(true);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Cambiar objetivo' : 'Bienvenido a CotidyFit';

    return Scaffold(
      appBar: widget.isEditing
          ? AppBar(title: Text(title))
          : const PreferredSize(
              preferredSize: Size.fromHeight(0),
              child: SizedBox.shrink(),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isEditing) ...[
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
              ],
              Text(
                'Elige tu objetivo principal',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: _goals.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final goal = _goals[index];
                    final selected = _selected == goal;
                    return Card(
                      child: InkWell(
                        borderRadius: const BorderRadius.all(Radius.circular(18)),
                        onTap: _saving
                            ? null
                            : () => setState(() => _selected = goal),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: selected
                                    ? CFColors.primary
                                    : CFColors.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  goal,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: CFColors.textPrimary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_selected == null || _saving) ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.isEditing ? 'Guardar' : 'Continuar'),
                ),
              ),
              if (!widget.isEditing) ...[
                const SizedBox(height: 8),
                Text(
                  'Podrás cambiar tu objetivo más adelante en Perfil.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
