import 'package:flutter/material.dart';

import '../../core/services/training_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../core/i18n/l10n.dart';

class VoiceCadencePage extends StatefulWidget {
  const VoiceCadencePage({super.key});

  @override
  State<VoiceCadencePage> createState() => _VoiceCadencePageState();
}

class _VoiceCadencePageState extends State<VoiceCadencePage> {
  TrainingPreferences? _preferences;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await TrainingPreferences.load();
      if (mounted) setState(() => _preferences = value);
    } catch (_) {
      if (mounted) setState(() => _preferences = const TrainingPreferences());
    }
  }

  Future<void> _select(RepSpeechCadence cadence) async {
    final current = _preferences;
    if (current == null || _busy || current.repSpeechCadence == cadence) {
      return;
    }
    setState(() => _busy = true);
    try {
      final updated = await current.update(repSpeechCadence: cadence);
      if (mounted) setState(() => _preferences = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.legacyVoiceCadenceCouldNotSaveRep),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final preferences = _preferences;
    return Scaffold(
      body: SafeArea(
        child: preferences == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  TextButton.icon(
                    style:
                        TextButton.styleFrom(alignment: Alignment.centerLeft),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left),
                    label: Text(context.l10n.commonSettings),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.legacyVoiceCadenceRepSpeech,
                    style: AppTypography.display40,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.legacyVoiceCadenceChooseHowOftenVoice,
                    style: AppTypography.body16.copyWith(color: p.text2),
                  ),
                  const SizedBox(height: 34),
                  _ChoiceRow(
                    key: const Key('cadence-every-rep'),
                    selected:
                        preferences.repSpeechCadence == RepSpeechCadence.everyRep,
                    title: context.l10n.legacyVoiceCadenceEveryRep,
                    subtitle: context.l10n.legacyVoiceCadenceSpeakAfterEveryCounted,
                    onTap: _busy
                        ? null
                        : () => _select(RepSpeechCadence.everyRep),
                  ),
                  const SizedBox(height: 16),
                  _ChoiceRow(
                    key: const Key('cadence-every-5'),
                    selected: preferences.repSpeechCadence ==
                        RepSpeechCadence.every5Reps,
                    title: context.l10n.legacyVoiceCadenceEveryReps,
                    subtitle: context.l10n.legacyVoiceCadenceSpeak,
                    onTap: _busy
                        ? null
                        : () => _select(RepSpeechCadence.every5Reps),
                  ),
                  const SizedBox(height: 16),
                  _ChoiceRow(
                    key: const Key('cadence-milestones'),
                    selected: preferences.repSpeechCadence ==
                        RepSpeechCadence.milestonesOnly,
                    title: context.l10n.legacyVoiceCadenceMilestonesOnly,
                    subtitle: context.l10n.legacyVoiceCadenceGoalsSetsChallengeMilestones,
                    onTap: _busy
                        ? null
                        : () => _select(RepSpeechCadence.milestonesOnly),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: p.border),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.legacyVoiceCadenceRelatedSettings,
                    style: AppTypography.caption12.copyWith(color: p.text2),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: p.borderStrong),
                    ),
                    child: Column(
                      children: [
                        _RelatedRow(
                          label: 'Voice Coach',
                          value: preferences.voice,
                        ),
                        _RelatedRow(
                          label: context.l10n.legacyVoiceCadencePostureReminders,
                          value: preferences.cues,
                        ),
                        _RelatedRow(
                          label: context.l10n.legacyVoiceCadenceSetSounds,
                          value: preferences.sound,
                        ),
                        _RelatedRow(
                          label: context.l10n.legacyVoiceCadenceHaptics,
                          value: preferences.haptics,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? p.accent : p.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? p.accent : p.text3,
                              width: selected ? 2 : 1,
                            ),
                          ),
                        ),
                        if (selected)
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: p.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              size: 14,
                              color: p.accentInk,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: AppTypography.body16.copyWith(
                            color: selected ? p.accent : p.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppTypography.caption12.copyWith(
                            color: p.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RelatedRow extends StatelessWidget {
  const _RelatedRow({
    required this.label,
    required this.value,
  });

  final String label;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTypography.body14),
          ),
          const SizedBox(width: 12),
          Text(
            value
                ? context.l10n.legacyVoiceCadenceText
                : context.l10n.legacyVoiceCadenceOff,
            style: AppTypography.body14.copyWith(
              color: value ? p.accent : p.text3,
            ),
          ),
        ],
      ),
    );
  }
}
