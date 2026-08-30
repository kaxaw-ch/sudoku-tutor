/// 轻量 `Ok` / `Err` 返回封装。
///
/// 用于不希望以异常表达的可预期失败（如导入校验、唯一解校验）。
library;

import 'core_error.dart';

/// 结果容器：要么是 [Ok]，要么是 [Err]。
sealed class Result<T> {
  /// 常量构造。
  const Result();

  /// 构造成功结果。
  const factory Result.ok(T value) = Ok<T>;

  /// 构造失败结果。
  const factory Result.err(CoreErrorCode code, [String? detail]) = Err<T>;

  /// 是否成功。
  bool get isOk => this is Ok<T>;

  /// 是否失败。
  bool get isErr => this is Err<T>;

  /// 成功时返回值，失败时返回 `null`。
  T? get valueOrNull {
    final Result<T> self = this;
    return self is Ok<T> ? self.value : null;
  }

  /// 失败时返回错误码，成功时返回 `null`。
  CoreErrorCode? get errorOrNull {
    final Result<T> self = this;
    return self is Err<T> ? self.code : null;
  }

  /// 成功时返回值；失败时抛出 [CoreException]。
  T unwrap() {
    final Result<T> self = this;
    if (self is Ok<T>) {
      return self.value;
    }
    final Err<T> err = self as Err<T>;
    throw CoreException(err.code, err.detail);
  }

  /// 成功时返回值；失败时返回 [fallback]。
  T unwrapOr(T fallback) => valueOrNull ?? fallback;
}

/// 成功结果。
final class Ok<T> extends Result<T> {
  /// 构造成功结果。
  const Ok(this.value);

  /// 承载的值。
  final T value;

  @override
  String toString() => 'Ok($value)';
}

/// 失败结果。
final class Err<T> extends Result<T> {
  /// 构造失败结果。
  const Err(this.code, [this.detail]);

  /// 错误码。
  final CoreErrorCode code;

  /// 附加上下文，可为空。
  final String? detail;

  @override
  String toString() => 'Err(${code.code}${detail == null ? '' : ': $detail'})';
}
