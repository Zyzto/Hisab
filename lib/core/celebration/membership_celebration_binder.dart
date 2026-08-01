import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import '../../features/groups/providers/groups_provider.dart';
import 'celebration_controller.dart';
import 'celebration_dedupe.dart';
import 'celebration_kind.dart';

/// Watches participants for [groupId] and fires join/leave celebrations once
/// per person. Seeds the first snapshot so cold sync never fireworks.
///
/// After seeding, IDs that appear from sync but are not recent (by
/// [Participant.createdAt] / [Participant.leftAt]) are claimed silently so an
/// incomplete first snapshot cannot celebrate long-standing members as new.
class MembershipCelebrationBinder extends ConsumerStatefulWidget {
  const MembershipCelebrationBinder({
    super.key,
    required this.groupId,
    this.child = const SizedBox.shrink(),
  });

  final String groupId;
  final Widget child;

  /// How fresh a join/leave must be to celebrate (vs silent seed).
  static const recentWindow = Duration(minutes: 3);

  @override
  ConsumerState<MembershipCelebrationBinder> createState() =>
      _MembershipCelebrationBinderState();
}

class _MembershipCelebrationBinderState
    extends ConsumerState<MembershipCelebrationBinder> {
  var _seeded = false;
  Set<String> _activeIds = {};
  Set<String> _leftIds = {};

  @override
  void didUpdateWidget(covariant MembershipCelebrationBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      _seeded = false;
      _activeIds = {};
      _leftIds = {};
    }
  }

  bool _isRecent(DateTime? at) {
    if (at == null) return false;
    return DateTime.now().toUtc().difference(at.toUtc()) <=
        MembershipCelebrationBinder.recentWindow;
  }

  void _onParticipants(List<Participant> participants) {
    final byId = {for (final p in participants) p.id: p};
    final active = <String>{};
    final left = <String>{};
    for (final p in participants) {
      if (p.leftAt == null) {
        active.add(p.id);
      } else {
        left.add(p.id);
      }
    }

    if (!_seeded) {
      _seeded = true;
      _activeIds = active;
      _leftIds = left;
      unawaited(
        CelebrationDedupe.instance.seed([
          for (final id in active)
            CelebrationKeys.personJoined(widget.groupId, id),
          for (final id in left)
            CelebrationKeys.personLeft(widget.groupId, id),
        ]),
      );
      return;
    }

    final joined = active.difference(_activeIds);
    final newlyLeft = left.difference(_leftIds);
    final leftFromActive = _activeIds.difference(active);

    _activeIds = active;
    _leftIds = left;

    for (final id in joined) {
      final key = CelebrationKeys.personJoined(widget.groupId, id);
      final createdAt = byId[id]?.createdAt;
      if (_isRecent(createdAt)) {
        unawaited(
          fireCelebration(
            ref,
            CelebrationKind.personJoined,
            dedupeKey: key,
          ),
        );
      } else {
        // Late sync of an existing member — mark seen, do not celebrate.
        unawaited(CelebrationDedupe.instance.seed([key]));
      }
    }
    for (final id in {...newlyLeft, ...leftFromActive.where(left.contains)}) {
      final key = CelebrationKeys.personLeft(widget.groupId, id);
      final leftAt = byId[id]?.leftAt;
      if (_isRecent(leftAt)) {
        unawaited(
          fireCelebration(
            ref,
            CelebrationKind.personLeft,
            dedupeKey: key,
          ),
        );
      } else {
        unawaited(CelebrationDedupe.instance.seed([key]));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Participant>>>(
      participantsByGroupProvider(widget.groupId),
      (prev, next) {
        final list = next.asData?.value;
        if (list == null) return;
        _onParticipants(list);
      },
    );

    final current = ref.watch(participantsByGroupProvider(widget.groupId));
    final list = current.asData?.value;
    if (list != null && !_seeded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _seeded) return;
        _onParticipants(list);
      });
    }

    return widget.child;
  }
}
