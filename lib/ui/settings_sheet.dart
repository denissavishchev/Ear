import 'package:flutter/material.dart';

import '../model/theory.dart';
import '../model/trainer.dart';
import 'palette.dart';

void showSettingsSheet(BuildContext context, Trainer trainer) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _SettingsSheet(trainer: trainer),
  );
}

class _SettingsSheet extends StatelessWidget {
  final Trainer trainer;
  const _SettingsSheet({required this.trainer});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: trainer,
      builder: (context, _) {
        final p = Palette.of(context);
        return Container(
          decoration: BoxDecoration(
            color: p.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 120,
                        height: 4,
                        decoration: BoxDecoration(
                          color: p.fg.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    _Section(
                      title: 'KEY',
                      first: true,
                      child: _Options<int>(
                        values: [for (var i = 0; i < allKeys.length; i++) i],
                        selected: trainer.keyIndex,
                        label: (i) => allKeys[i].display(),
                        onSelect: trainer.setKey,
                      ),
                    ),
                    _Section(
                      title: 'CADENCE',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'The chords played before the note, '
                            'so your ear knows where "Do" is.',
                            style: p.body(15, color: p.muted),
                          ),
                          const SizedBox(height: 14),
                          _Options<bool>(
                            values: const [true, false],
                            selected: trainer.cadenceEveryTime,
                            label: (v) =>
                                v ? 'before every note' : 'every 5 questions',
                            onSelect: trainer.setCadenceEveryTime,
                          ),
                        ],
                      ),
                    ),
                    _Section(
                      title: 'STYLE',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Which chord progressions the cadence uses. '
                            'Each question picks one at random.',
                            style: p.body(15, color: p.muted),
                          ),
                          const SizedBox(height: 14),
                          _Options<CadenceStyle>(
                            values: CadenceStyle.values,
                            selected: trainer.cadenceStyle,
                            label: (s) => s.name,
                            onSelect: trainer.setCadenceStyle,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _styleExample(trainer),
                            style: p.body(15, color: p.fg),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Big bold heading row separated by hairlines, like a weekly planner.
class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final bool first;
  const _Section({
    required this.title,
    required this.child,
    this.first = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: p.hair, width: 0.8)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: p.heavy(34)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Plain text options; the selected one is drawn as a checked box.
class _Options<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelect;

  const _Options({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Wrap(
      spacing: 18,
      runSpacing: 12,
      children: [
        for (final v in values)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(v),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CheckBox(checked: v == selected),
                const SizedBox(width: 8),
                Text(
                  label(v),
                  style: p.body(17, color: v == selected ? p.fg : p.muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CheckBox extends StatelessWidget {
  final bool checked;
  const _CheckBox({required this.checked});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: checked ? p.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: checked ? p.accent : p.muted, width: 1.2),
      ),
      child: checked
          ? Icon(Icons.check_rounded, size: 14, color: p.onAccent)
          : null,
    );
  }
}

/// The selected style's progressions spelled in the current key.
String _styleExample(Trainer trainer) {
  if (trainer.cadenceStyle == CadenceStyle.mix) {
    return 'All styles mixed together.';
  }
  return [
    for (final prog in progressions[trainer.cadenceStyle]!)
      prog.map(trainer.key.chordName).join(' · '),
  ].join('   /   ');
}
