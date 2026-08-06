import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/navigation/route_transition_ready.dart';

void main() {
  testWidgets(
    'armWhenAnimationReady fires immediately when animation completed',
    (tester) async {
      var fired = 0;
      final animation = AlwaysStoppedAnimation<double>(1);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              armWhenAnimationReady(
                context: context,
                animation: animation,
                action: () => fired++,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(fired, 1);
    },
  );

  testWidgets('armWhenAnimationReady waits for forward animation to complete', (
    tester,
  ) async {
    var fired = 0;
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 100),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return const SizedBox();
          },
        ),
      ),
    );
    final context = tester.element(find.byType(SizedBox));
    armWhenAnimationReady(
      context: context,
      animation: controller,
      action: () => fired++,
    );
    expect(fired, 0);
    controller.forward();
    await tester.pumpAndSettle();
    expect(fired, 1);
  });

  testWidgets(
    'RouteTransitionReady sync-ready without setState on completed route',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _ReadyProbe()));
      await tester.pump();
      final state = tester.state<_ReadyProbeState>(find.byType(_ReadyProbe));
      expect(state.routeReady, isTrue);
      expect(find.text('ready'), findsOneWidget);
    },
  );

  testWidgets('RouteTransitionReady invokes late onReady after sync-ready', (
    tester,
  ) async {
    var fired = 0;
    await tester.pumpWidget(const MaterialApp(home: _ReadyProbe()));
    await tester.pump();
    final state = tester.state<_ReadyProbeState>(find.byType(_ReadyProbe));
    expect(state.routeReady, isTrue);

    state.ensureRouteReady(state.context, onReady: () => fired++);
    expect(fired, 1);
  });
}

class _ReadyProbe extends StatefulWidget {
  const _ReadyProbe();

  @override
  State<_ReadyProbe> createState() => _ReadyProbeState();
}

class _ReadyProbeState extends State<_ReadyProbe> with RouteTransitionReady {
  @override
  void dispose() {
    disposeRouteReady();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ensureRouteReady(context);
    return Text(routeReady ? 'ready' : 'waiting');
  }
}
