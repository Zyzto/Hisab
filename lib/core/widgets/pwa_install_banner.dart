import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pwa/pwa_capabilities.dart';
import 'pwa_install_guide_sheet.dart';

/// Dismissible banner prompting mobile web users to install the app as a PWA.
///
/// Visible when:
/// - Running on web (`kIsWeb`)
/// - Device looks mobile
/// - App is not already standalone
/// - User has not dismissed the banner
///
/// Uses the native install prompt when available (Chromium Android); otherwise
/// opens step-by-step Add to Home Screen instructions (iOS + other browsers).
class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  static const dismissedKey = 'pwa_install_dismissed';

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  bool _dismissed = false;
  PwaInstallMode _mode = PwaInstallMode.unsupported;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    if (kIsWeb) {
      addPwaCapabilityListener(_onCapabilityChanged);
      _checkShouldShow();
    }
  }

  void _onCapabilityChanged() {
    if (!mounted) return;
    final mode = pwaInstallMode;
    if (mode == PwaInstallMode.alreadyInstalled ||
        mode == PwaInstallMode.unsupported) {
      if (_visible) {
        _animController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _visible = false;
              _mode = mode;
            });
          }
        });
      } else {
        setState(() => _mode = mode);
      }
      return;
    }
    if (_dismissed) return;
    setState(() {
      _mode = mode;
      if (!_visible) {
        _visible = true;
        _animController.forward();
      }
    });
  }

  Future<void> _checkShouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final wasDismissed =
        prefs.getBool(PwaInstallBanner.dismissedKey) ?? false;

    if (!mounted) return;

    if (wasDismissed) {
      setState(() {
        _dismissed = true;
        _visible = false;
      });
      return;
    }

    final mode = pwaInstallMode;
    final shouldShow = mode == PwaInstallMode.nativePrompt ||
        mode == PwaInstallMode.manualIos ||
        mode == PwaInstallMode.manualAndroid;

    if (shouldShow && mounted) {
      setState(() {
        _mode = mode;
        _visible = true;
      });
      _animController.forward();
    } else if (mounted) {
      setState(() => _mode = mode);
    }
  }

  Future<void> _dismiss() async {
    await _animController.reverse();
    if (!mounted) return;
    setState(() {
      _dismissed = true;
      _visible = false;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PwaInstallBanner.dismissedKey, true);
  }

  Future<void> _primaryAction() async {
    if (_mode == PwaInstallMode.nativePrompt) {
      final accepted = await promptPwaInstall();
      if (accepted && mounted) {
        await _dismiss();
      }
      return;
    }
    if (!mounted) return;
    await showPwaInstallGuide(context);
  }

  @override
  void dispose() {
    if (kIsWeb) {
      removePwaCapabilityListener(_onCapabilityChanged);
    }
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _dismissed || !_visible) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final useNative = _mode == PwaInstallMode.nativePrompt;
    final actionLabel =
        useNative ? 'install_app'.tr() : 'install_app_how_to'.tr();
    final description = useNative
        ? 'install_app_description'.tr()
        : (_mode == PwaInstallMode.manualIos
              ? 'install_app_description_ios'.tr()
              : 'install_app_description_android'.tr());

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Card(
          elevation: 4,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.install_mobile_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'install_app'.tr(),
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _primaryAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _dismiss,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
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
