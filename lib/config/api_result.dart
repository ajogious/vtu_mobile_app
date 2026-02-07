class ApiResult<T> {
  final bool success;
  final String message;
  final T? data;
  final String? error;

  ApiResult._({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  // Success factory
  factory ApiResult.success(T data, {String message = 'Success'}) {
    return ApiResult._(
      success: true,
      message: message,
      data: data,
      error: null,
    );
  }

  // Failure factory
  factory ApiResult.failure(String error, {String message = 'Failed'}) {
    return ApiResult._(
      success: false,
      message: message,
      data: null,
      error: error,
    );
  }

  // Check if result has data
  bool get hasData => data != null;

  // Get data or throw
  T get dataOrThrow {
    if (data == null) {
      throw Exception(error ?? 'No data available');
    }
    return data!;
  }
}
