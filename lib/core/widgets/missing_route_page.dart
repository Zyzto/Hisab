import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/content_aligned_app_bar.dart';
import '../layout/constrained_content.dart';
import '../navigation/route_paths.dart';
import 'error_content.dart';

/// "Not found" UI for deleted/missing deep links, then navigates away.
///
/// Use [asBody] when already inside a [Scaffold] (e.g. expense detail shell).
class MissingRoutePage extends StatefulWidget {
  const MissingRoutePage({
    super.key,
    required this.titleKey,
    this.messageKey,
    this.fallbackPath = RoutePaths.home,
    this.autoNavigateAfter = const Duration(seconds: 3),
    this.asBody = false,
  });

  /// Translation key for the title (e.g. [group_not_found]).
  final String titleKey;

  /// Optional translation key for a short supporting message.
  final String? messageKey;

  /// Where "Go home" / auto-navigation lands.
  final String fallbackPath;

  /// Delay before automatic navigation. Use [Duration.zero] to skip.
  final Duration autoNavigateAfter;

  /// When true, render only the body content (no nested [Scaffold]).
  final bool asBody;

  @override
  State<MissingRoutePage> createState() => _MissingRoutePageState();
}

class _MissingRoutePageState extends State<MissingRoutePage> {
  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoNavigateAfter > Duration.zero) {
      _timer = Timer(widget.autoNavigateAfter, _navigateAway);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _navigateAway() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _timer?.cancel();
    context.go(widget.fallbackPath);
  }

  Widget _buildContent() {
    return Center(
      child: ErrorContentWidget(
        titleKey: widget.titleKey,
        message: widget.messageKey?.tr(),
        onGoHome: _navigateAway,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asBody) return _buildContent();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: ContentAlignedAppBar(
            contentAreaWidth: constraints.maxWidth,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _navigateAway,
            ),
            title: Text(widget.titleKey.tr()),
          ),
          body: ConstrainedContent(child: _buildContent()),
        );
      },
    );
  }
}
