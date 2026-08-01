import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_content.dart';

class AsyncValueBuilder<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) data;
  final Widget Function(BuildContext context, Object error, StackTrace stack)?
  error;
  final Widget Function(BuildContext context)? loading;
  final Widget Function(BuildContext context)? empty;

  /// When true, keep showing the previous [data] while a reload is in flight
  /// instead of swapping to [loading] (avoids disposing child [State]).
  final bool skipLoadingOnReload;

  const AsyncValueBuilder({
    super.key,
    required this.value,
    required this.data,
    this.error,
    this.loading,
    this.empty,
    this.skipLoadingOnReload = false,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: skipLoadingOnReload,
      data: (data) {
        if (data == null && empty != null) {
          return empty!(context);
        }
        return this.data(context, data);
      },
      loading: () => loading?.call(context) ?? LoadingContent,
      error: (error, stack) =>
          this.error?.call(context, error, stack) ??
          ErrorContentWidget(
            message: error.toString(),
            details: error.toString(),
            stackTrace: stack,
          ),
    );
  }
}
