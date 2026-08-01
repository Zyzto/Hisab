import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'celebration_controller.dart';
import 'celebration_game.dart';
import 'celebration_kind.dart' show CelebrationRequest;

/// App-level overlay that plays [CelebrationController] requests via Flame.
class CelebrationHost extends ConsumerStatefulWidget {
  const CelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CelebrationHost> createState() => _CelebrationHostState();
}

class _CelebrationHostState extends ConsumerState<CelebrationHost> {
  CelebrationRequest? _playing;
  CelebrationGame? _game;

  void _ensurePlaying(CelebrationRequest? active) {
    if (active == null) return;
    if (_playing != null) return;
    final request = active;
    _playing = request;
    _game = CelebrationGame(
      kind: request.kind,
      onComplete: () {
        if (!mounted) return;
        final done = _playing;
        setState(() {
          _playing = null;
          _game = null;
        });
        if (done != null) {
          ref.read(celebrationControllerProvider).complete(done);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bus = ref.watch(celebrationControllerProvider);

    return ListenableBuilder(
      listenable: bus,
      builder: (context, _) {
        final active = bus.active;
        if (active != null && _playing == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _ensurePlaying(active));
          });
        }

        final game = _game;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (game != null)
              IgnorePointer(
                child: GameWidget<CelebrationGame>(
                  game: game,
                  loadingBuilder: (_) => const SizedBox.shrink(),
                  errorBuilder: (_, error) => const SizedBox.shrink(),
                ),
              ),
          ],
        );
      },
    );
  }
}
