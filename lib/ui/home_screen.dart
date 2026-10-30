import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/theory.dart';
import '../model/trainer.dart';
import 'palette.dart';
import 'settings_sheet.dart';

/// X position (from the left) of the selected level number and the
/// vertical hairline that drops from it.
const double _anchorLeft = 28;
const double _bigNumberWidth = 46;
const double _stripHeight = 52;

class HomeScreen extends StatelessWidget {
  final Trainer trainer;
  const HomeScreen({super.key, required this.trainer});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: trainer,
          builder: (context, _) => Column(
            children: [
              const SizedBox(height: 12),
              Expanded(child: _Stage(trainer: trainer)),
              _StatusRow(trainer: trainer),
              const SizedBox(height: 20),
              _AnswerGrid(trainer: trainer),
              _SettingsHandle(
                onTap: () => showSettingsSheet(context, trainer),
                color: p.fg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Level strip + info line + vertical hairline + circle.
class _Stage extends StatelessWidget {
  final Trainer trainer;
  const _Stage({required this.trainer});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final lineX = _anchorLeft + _bigNumberWidth * 0.72;
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _stripHeight,
              child: _LevelStrip(trainer: trainer),
            ),
            Positioned.fill(
              top: _stripHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: lineX + 14, right: 16),
                    child: _InfoLine(trainer: trainer),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, area) {
                        final orbSize = math
                            .min(area.maxWidth * 0.72, area.maxHeight - 24)
                            .clamp(100.0, 340.0);
                        return Center(
                          child: _Orb(trainer: trainer, size: orbSize),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // The hairline is drawn above the circle, like a cut through it.
            Positioned(
              top: _stripHeight - 6,
              bottom: 8,
              left: lineX,
              child: IgnorePointer(
                child: Container(width: 1, color: p.fg.withValues(alpha: 0.18)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LevelStrip extends StatelessWidget {
  final Trainer trainer;
  const _LevelStrip({required this.trainer});

  double _xFor(int i, int sel) {
    if (i == sel) return _anchorLeft;
    if (i < sel) return _anchorLeft - (sel - i) * 30 - 4;
    return _anchorLeft + _bigNumberWidth + 8 + (i - sel - 1) * 32;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final sel = trainer.level;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -150) trainer.setLevel(sel + 1);
        if (v > 150) trainer.setLevel(sel - 1);
      },
      child: ClipRect(
        child: Stack(
          children: [
            for (var i = 0; i < levels.length; i++)
              AnimatedPositioned(
                key: ValueKey(i),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                left: _xFor(i, sel),
                top: i == sel ? 6 : 18,
                child: GestureDetector(
                  onTap: () => trainer.setLevel(i),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutCubic,
                    style: i == sel
                        ? p.thin(30)
                        : p.thin(
                            14,
                            color: p.muted.withValues(
                              alpha: i <= trainer.unlockedLevel ? 1 : 0.35,
                            ),
                          ),
                    child: Text((i + 1).toString().padLeft(2, '0')),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final Trainer trainer;
  const _InfoLine({required this.trainer});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final names = trainer.degrees.map((d) => romanNames[d]).join(' · ');
    final atFrontier =
        trainer.level == trainer.unlockedLevel &&
        trainer.level < levels.length - 1;
    final streak = atFrontier
        ? 'streak ${trainer.streak}/$unlockStreak'
        : 'streak ${trainer.streak}';
    final acc = trainer.total == 0 ? '' : '  ·  ${trainer.accuracy}%';
    final text = p.fg.withValues(alpha: 0.85);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${trainer.key.display()} (${trainer.key.relativeMinor()})',
          style: p.body(22, color: text),
        ),
        Text(names, style: p.body(22, color: text)),
        Text('$streak$acc', style: p.body(22, color: text)),
      ],
    );
  }
}

/// The big accent circle: tap to start / replay. Shows the answer when solved.
class _Orb extends StatelessWidget {
  final Trainer trainer;
  final double size;
  const _Orb({required this.trainer, required this.size});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final solved = trainer.phase == Phase.correct;
    final c = trainer.caption;
    final Widget label = trainer.phase == Phase.idle
        ? Text('S T A R T', style: p.body(15, color: p.onAccent, spacing: 2))
        : c == null
        ? const SizedBox.shrink()
        // The note or chord sounding right now; the sub line is its degree.
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c.text, style: p.thin(size * 0.3, color: p.onAccent)),
              Text(
                c.sub ?? '',
                style: p.body(
                  16,
                  color: p.onAccent.withValues(alpha: 0.75),
                  spacing: 2,
                ),
              ),
            ],
          );

    return GestureDetector(
      onTap: trainer.tapCircle,
      // Re-keyed per question / wrong try so the pop or shake replays.
      child: TweenAnimationBuilder<double>(
        key: ValueKey('${trainer.questionsAsked}-${trainer.wrongTries.length}'),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(
          milliseconds: trainer.phase == Phase.wrong ? 420 : 520,
        ),
        curve: Curves.easeOut,
        builder: (context, t, child) {
          if (trainer.phase == Phase.wrong) {
            final dx = math.sin(t * math.pi * 5) * 10 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          }
          final s = 0.9 + 0.1 * Curves.easeOutBack.transform(t);
          return Transform.scale(scale: s, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: trainer.phase == Phase.wrong
                ? p.accent.withValues(alpha: 0.82)
                : p.accent,
            boxShadow: [
              // Lifts the disc off the background.
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              if (solved)
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: CustomPaint(
            // Shading goes over the swirl so both read as one surface.
            foregroundPainter: const _OrbSurfacePainter(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ink-swirl texture, barely darker than the disc.
                ClipOval(
                  child: Image.asset(
                    'assets/textures/swirl.png',
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.13),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 120),
                    child: KeyedSubtree(
                      key: ValueKey(
                        '${trainer.phase == Phase.idle}-${trainer.captionTick}',
                      ),
                      child: label,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft top-left lighting and a lit rim, so the flat disc reads like a
/// pressed, slightly domed paper stamp.
class _OrbSurfacePainter extends CustomPainter {
  const _OrbSurfacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    // Light from the top-left, shade towards the bottom-right.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.5),
          radius: 1.1,
          colors: [
            Colors.white.withValues(alpha: 0.2),
            Colors.white.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.22),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );

    // Thin bright rim on the lit edge.
    canvas.drawCircle(
      c,
      r - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbSurfacePainter oldDelegate) => false;
}

class _StatusRow extends StatelessWidget {
  final Trainer trainer;
  const _StatusRow({required this.trainer});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final text = switch (trainer.phase) {
      Phase.idle => 'Tap the circle',
      Phase.listening => 'Listen',
      Phase.wrong => 'Try again',
      Phase.correct =>
        trainer.justUnlocked
            ? 'Level ${(trainer.unlockedLevel + 1).toString().padLeft(2, '0')} unlocked'
            : 'Correct',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: trainer.phase == Phase.wrong ? p.muted : p.accent,
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              layoutBuilder: (cur, prev) => Stack(
                alignment: Alignment.centerLeft,
                children: [...prev, ?cur],
              ),
              child: Text(
                text,
                key: ValueKey(text),
                style: p.body(20, spacing: 6),
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Answer buttons: full-width hairline grid with heavy condensed labels.
class _AnswerGrid extends StatelessWidget {
  final Trainer trainer;
  const _AnswerGrid({required this.trainer});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final ds = trainer.degrees;
    final cols = switch (ds.length) {
      <= 3 => ds.length,
      4 => 2,
      <= 6 => 3,
      _ => 4,
    };
    final rows = <List<int>>[
      for (var i = 0; i < ds.length; i += cols)
        ds.sublist(i, math.min(i + cols, ds.length)),
    ];
    final border = BorderSide(color: p.hair, width: 0.8);

    return Column(
      children: [
        for (final row in rows)
          Container(
            height: rows.length > 1 ? 78 : 104,
            decoration: BoxDecoration(border: Border(top: border)),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: i == 0 ? null : Border(left: border),
                      ),
                      child: _AnswerCell(trainer: trainer, degree: row[i]),
                    ),
                  ),
              ],
            ),
          ),
        Container(height: 0.8, color: p.hair),
      ],
    );
  }
}

class _AnswerCell extends StatelessWidget {
  final Trainer trainer;
  final int degree;
  const _AnswerCell({required this.trainer, required this.degree});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final isRight = trainer.phase == Phase.correct && trainer.degree == degree;
    final isWrong = trainer.wrongTries.contains(degree);
    final enabled =
        trainer.phase == Phase.listening ||
        (trainer.phase == Phase.wrong && !isWrong);

    final fg = isRight
        ? p.onAccent
        : isWrong
        ? p.muted
        : p.fg;

    final sub = isRight ? p.onAccent.withValues(alpha: 0.8) : p.muted;

    return Material(
      color: isRight ? p.accent : Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => trainer.answer(degree) : null,
        splashColor: p.accent.withValues(alpha: 0.18),
        highlightColor: p.fg.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Letter name with the scale degree beside it, solfège below.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      trainer.key.letterOf(degree),
                      style: p
                          .heavy(30, color: fg)
                          .copyWith(
                            decoration: isWrong
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: p.accent,
                            decorationThickness: 2,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(romanNames[degree], style: p.body(15, color: sub)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(solfegeNames[degree], style: p.body(13, color: sub)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsHandle extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  const _SettingsHandle({required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -100) onTap();
      },
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: Icon(
          Icons.keyboard_arrow_up_rounded,
          size: 28,
          color: color.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
