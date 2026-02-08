mixin BaseDaoMixin {
  Future<T> executeWithErrorHandling<T>({
    required String operationName,
    required Future<T> Function() operation,
    T Function()? onError,
  }) async {
    try {
      return await operation();
    } catch (e, _) {
      if (onError != null) return onError();
      rethrow;
    }
  }
}
