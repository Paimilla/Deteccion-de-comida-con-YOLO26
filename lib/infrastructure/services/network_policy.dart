import 'dart:async';

import 'package:http/http.dart' as http;

Future<T> runWithRetry<T>({
  required Future<T> Function() operation,
  int maxAttempts = 2,
  Duration initialDelay = const Duration(milliseconds: 250),
  bool Function(Object error)? retryOn,
}) async {
  Object? lastError;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      final shouldRetry = attempt < maxAttempts &&
          (retryOn?.call(error) ?? _defaultRetryPolicy(error));
      if (!shouldRetry) {
        rethrow;
      }

      final backoff = Duration(
        milliseconds: initialDelay.inMilliseconds * (1 << (attempt - 1)),
      );
      await Future<void>.delayed(backoff);
    }
  }

  throw lastError ?? StateError('runWithRetry failed without captured error');
}

bool _defaultRetryPolicy(Object error) {
  return error is TimeoutException || error is http.ClientException;
}
