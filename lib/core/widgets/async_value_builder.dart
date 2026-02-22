import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncValueBuilder<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) data;
  final Widget Function(BuildContext context, Object error, StackTrace stack)?
  error;
  final Widget Function(BuildContext context)? loading;
  final Widget Function(BuildContext context)? empty;

  const AsyncValueBuilder({
    super.key,
    required this.value,
    required this.data,
    this.error,
    this.loading,
    this.empty,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (data) {
        if (data == null && empty != null) {
          return empty!(context);
        }
        return this.data(context, data);
      },
      loading: () =>
          loading?.call(context) ??
          const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          this.error?.call(context, error, stack) ??
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'generic_error'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
    );
  }
}
