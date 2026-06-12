# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

EventXIndia V1 — a Flutter app that digitizes an offline event-staffing process for three roles (Student, Vendor, Admin) with role-based navigation. The current backend is Firebase (Phone-OTP Auth, Firestore, Storage, Cloud Messaging, and Cloud Functions for trusted server-side logic). It is built so Firebase can later be swapped for a Node.js + REST/WS backend **without touching the domain or presentation layers**.

The authoritative spec lives in `.kiro/specs/eventxindia-platform/` (`requirements.md`, `design.md`, `tasks.md`). `tasks.md` is the implementation checklist and tracks what is built; `design.md` is the canonical architecture reference. Requirement IDs like `R7.2` and `Property 29` in code/test comments and doc-comments point back to these files — keep them when editing and cite them in new code.

## Commands

```bash
flutter pub get                                   # install deps
dart run build_runner build --delete-conflicting-outputs   # regenerate injectable DI (injection.config.dart)
flutter analyze                                   # static analysis / lint (flutter_lints)
flutter test                                      # run all tests
flutter test test/path/to/foo_test.dart           # run a single test file
flutter test --name "substring of test name"      # run tests matching a name
flutter run                                        # run the app
```

Re-run `build_runner` after adding or changing any `@injectable` / `@LazySingleton` / `@module` annotation — `lib/core/di/injection.config.dart` is generated and must not be hand-edited.

## Architecture

Strict Clean Architecture with the dependency rule **presentation → domain ← data**, plus a shared `core`. Source dependencies always point inward; the domain layer is pure Dart and depends on nothing external.

- `lib/core/` — shared infrastructure: `result/` (`Result<T, Failure>`), `error/` (`Failure` hierarchy), `value_objects/`, `di/` (composition root), `data/` (Firebase base classes + `withRetry`).
- `lib/features/<feature>/` — each feature is a `domain/ data/ presentation/` triad. Features: auth, profile, events, applications, attendance, earnings, reports, admin, notifications, navigation.
  - `domain/` — pure Dart: `entities/`, `repositories/` (abstract interfaces), `usecases/`, `validators/`, `services/`, and free-standing pure logic (e.g. `geo_distance.dart`, `event_filters.dart`, `otp_policy.dart`).
  - `data/` — Firebase implementations: `datasources/`, `dtos/`, `mappers/`, `repositories/` (concrete `*Impl`).
  - `presentation/` — `bloc/` (flutter_bloc) and `screens/`.

### Non-negotiable rules

- **No Firebase type ever crosses out of the data layer.** `DocumentSnapshot`, `Timestamp`, Firebase `User`, etc. stay inside `data/`; DTOs + mappers convert them to/from pure domain entities. Domain and presentation never import a Firebase package or a repository `*Impl`.
- **Use cases and repositories return `Result<T, Failure>`** (or a `Stream` of domain entities for watches). Errors are modeled as values, never thrown across layers. Compose with `map`/`flatMap`/`fold`; use `Unit`/`unit` as the success payload when there is no value. Failures are a sealed hierarchy with a machine-readable `code`; `ValidationFailure` carries `FieldError`s so forms can highlight fields.
- **The backend-swap line is the abstract repository/service interfaces in `domain/`.** Swapping backends = new data-layer `*Impl` + one DI binding change. Nothing in domain or presentation changes.
- **Trusted logic is a service abstraction, not a vendor.** Compute-once / tamper-proof logic (earnings accrual, notification dispatch, metrics aggregation) sits behind `EarningsService` / `NotificationService` / `MetricsService`, implemented today by Cloud Functions.
- **Business logic lives in the domain as pure functions** (validators, haversine distance, working-hours, search filters, status-transition guards, accrual reducer, retry policy) — backend-independent and property-testable.
- **Dependency injection** uses `get_it` + `injectable`. The only place that wires concrete impls to interfaces is the generated config; annotate data-layer impls (`@LazySingleton(as: SomeRepository)`, `@injectable`) rather than constructing them directly.
- **All persisted writes go through `withRetry` (`core/data/write_retry.dart`)** — a pure, backend-agnostic retry policy (default 3 attempts) that maps exhausted/failed writes to a `PersistenceFailure` and commits a success exactly once.
- **Value objects enforce validity at construction** (e.g. `Money` stores integer minor units to avoid float error; `PhoneNumber` E.164). Construct through their factories rather than passing raw primitives around.

## Testing conventions

- **Pure domain logic** is exercised by property-based tests using `glados` (QuickCheck-style, min 100 iterations), tagged `Feature: eventxindia-platform, Property {n}: {text}`.
- **Use cases** are tested with hand-written in-memory fakes (see `test/features/*/domain/fakes.dart`) or `mocktail` mocks of the abstract repositories.
- **BLoCs** are tested with `bloc_test` + `mocktail`-mocked use cases.
- **DTOs/mappers** use round-trip tests; **data-layer / repository** tests use `fake_cloud_firestore` (a real in-memory Firestore, not mocks).
