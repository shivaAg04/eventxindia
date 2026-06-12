import 'package:equatable/equatable.dart';

import '../error/failure.dart';

/// A railway-style result: either a success value of type [T] or a [Failure]
/// of type [F].
///
/// Errors are modelled as values rather than thrown exceptions. Use cases and
/// repositories return a `Result<T, Failure>`; callers compose them with
/// [map]/[flatMap] and collapse them with [fold], so the happy path and the
/// error path stay explicit and type-checked.
///
/// Use the [Ok] and [Err] variants (or the [Result.ok]/[Result.err] factories)
/// to construct values, and pattern-match or use [fold] to consume them.
sealed class Result<T, F extends Failure> extends Equatable {
  const Result();

  /// Creates a successful result wrapping [value].
  const factory Result.ok(T value) = Ok<T, F>;

  /// Creates a failed result wrapping [failure].
  const factory Result.err(F failure) = Err<T, F>;

  /// Whether this result represents success.
  bool get isOk => this is Ok<T, F>;

  /// Whether this result represents failure.
  bool get isErr => this is Err<T, F>;

  /// The success value, or `null` when this is an [Err].
  T? get valueOrNull => switch (this) {
        Ok<T, F>(:final T value) => value,
        Err<T, F>() => null,
      };

  /// The failure, or `null` when this is an [Ok].
  F? get failureOrNull => switch (this) {
        Ok<T, F>() => null,
        Err<T, F>(:final F failure) => failure,
      };

  /// Transforms the success value with [transform], leaving a failure untouched.
  ///
  /// This is the functor map: the error channel is preserved unchanged.
  Result<R, F> map<R>(R Function(T value) transform) => switch (this) {
        Ok<T, F>(:final T value) => Ok<R, F>(transform(value)),
        Err<T, F>(:final F failure) => Err<R, F>(failure),
      };

  /// Transforms the failure with [transform], leaving a success untouched.
  Result<T, G> mapError<G extends Failure>(G Function(F failure) transform) =>
      switch (this) {
        Ok<T, F>(:final T value) => Ok<T, G>(value),
        Err<T, F>(:final F failure) => Err<T, G>(transform(failure)),
      };

  /// Chains another result-producing step onto a success ("bind"/"andThen").
  ///
  /// If this result is a failure, [transform] is not called and the failure is
  /// propagated. This is what makes the railway short-circuit on the first
  /// error.
  Result<R, F> flatMap<R>(Result<R, F> Function(T value) transform) =>
      switch (this) {
        Ok<T, F>(:final T value) => transform(value),
        Err<T, F>(:final F failure) => Err<R, F>(failure),
      };

  /// Collapses both channels into a single value of type [R].
  ///
  /// Calls [onSuccess] for an [Ok] or [onFailure] for an [Err]. This is the
  /// primary way the presentation layer turns a result into a state.
  R fold<R>(
    R Function(T value) onSuccess,
    R Function(F failure) onFailure,
  ) =>
      switch (this) {
        Ok<T, F>(:final T value) => onSuccess(value),
        Err<T, F>(:final F failure) => onFailure(failure),
      };

  /// Returns the success value, or [fallback] when this is a failure.
  T getOrElse(T fallback) => switch (this) {
        Ok<T, F>(:final T value) => value,
        Err<T, F>() => fallback,
      };
}

/// The success variant of a [Result].
final class Ok<T, F extends Failure> extends Result<T, F> {
  const Ok(this.value);

  /// The wrapped success value.
  final T value;

  @override
  List<Object?> get props => <Object?>[value];

  @override
  String toString() => 'Ok($value)';
}

/// The failure variant of a [Result].
final class Err<T, F extends Failure> extends Result<T, F> {
  const Err(this.failure);

  /// The wrapped failure.
  final F failure;

  @override
  List<Object?> get props => <Object?>[failure];

  @override
  String toString() => 'Err($failure)';
}

/// A type with exactly one value, used as the success payload when an
/// operation succeeds but produces no meaningful value (e.g.
/// `Result<Unit, Failure>` for validators that only signal pass/fail).
class Unit extends Equatable {
  const Unit._();

  /// The single [Unit] value.
  static const Unit value = Unit._();

  @override
  List<Object?> get props => const <Object?>[];

  @override
  String toString() => 'Unit';
}

/// The canonical [Unit] instance.
const Unit unit = Unit.value;
