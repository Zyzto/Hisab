import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/connectivity_service.dart';

/// A banner that slides down when the app goes offline and shows a
/// brief "Back online!" confirmation when connectivity is restored.
class ConnectionBanner extends ConsumerStatefulWidget {
  const ConnectionBanner({super.key});

  @override
  ConsumerState<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends ConsumerState<ConnectionBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  Timer? _dismissTimer;

  /// Tracks banner display state.
  _BannerMode _mode = _BannerMode.hidden;

  /// Previous sync status to detect transitions.
  SyncStatus? _prevStatus;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  void _showBanner(_BannerMode mode) {
    _dismissTimer?.cancel();
    setState(() => _mode = mode);
    _slideController.forward();

    if (mode == _BannerMode.backOnline) {
      _dismissTimer = Timer(const Duration(seconds: 2), _hideBanner);
    }
  }

  void _hideBanner() {
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() => _mode = _BannerMode.hidden);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider);

    // Detect transitions.
    if (status != _prevStatus) {
      final prev = _prevStatus;
      _prevStatus = status;

      if (prev != null) {
        if (status == SyncStatus.offline) {
          // Went offline — show offline banner.
          _showBanner(_BannerMode.offline);
        } else if (prev == SyncStatus.offline &&
            (status == SyncStatus.connected || status == SyncStatus.syncing)) {
          // Came back online — show "Back online!" briefly.
          _showBanner(_BannerMode.backOnline);
        } else if (_mode != _BannerMode.hidden &&
            _mode != _BannerMode.backOnline) {
          // Some other transition while banner is showing — hide it.
          _hideBanner();
        }
      }
    }

    if (_mode == _BannerMode.hidden) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isOffline = _mode == _BannerMode.offline;

    final bgColor = isOffline
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer;
    final fgColor = isOffline
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimaryContainer;
    final icon = isOffline ? Icons.cloud_off_outlined : Icons.cloud_done_outlined;
    final text = isOffline
        ? 'sync_offline_banner'.tr()
        : 'sync_back_online'.tr();

    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        color: bgColor,
        elevation: 1,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: fgColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isOffline)
                  GestureDetector(
                    onTap: _hideBanner,
                    child: Icon(Icons.close, size: 18, color: fgColor),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _BannerMode {
  hidden,
  offline,
  backOnline,
}
