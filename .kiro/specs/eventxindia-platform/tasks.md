# Implementation Plan: EventXIndia Platform

## Overview

This plan converts the EventXIndia V1 design into incremental, code-only steps that build the Flutter app bottom-up per Clean Architecture: core/shared scaffolding and DI first, then the pure Dart domain (entities, abstract interfaces, use cases, and property-tested pure logic), then the Firebase data layer (DTOs, mappers, data sources, repository implementations), then presentation (BLoCs and screens per feature), then the trusted Cloud Functions, and finally Firestore Security Rules plus integration wiring.

Each feature (auth, profile, events, applications, attendance, earnings, reports, admin, notifications) carries its own domain → data → presentation triad. Pure domain logic is exercised by one property-based test per correctness property (min 100 iterations, tagged `Feature: eventxindia-platform, Property {n}: {text}`). Use cases and BLoCs are tested with mocked dependencies, DTOs with round-trip tests, and the backend trust boundary with Firestore-emulator security-rules tests.

Conventions:
- App code is **Dart/Flutter**; trusted server logic is **TypeScript** (Cloud Functions). Dart PBT uses a generator-based QuickCheck-style package; TypeScript PBT uses `fast-check`.
- Domain layer is pure Dart — no Firebase types ever cross out of the data layer.
- Use cases and repositories return `Result<T, Failure>`.

## Tasks

- [x] 1. Project setup and core/shared scaffolding
  - [x] 1.1 Initialize Flutter project, dependencies, and folder structure
    - Create the `lib/core`, `lib/features/*` (domain/data/presentation triads), `lib/routing`, and `lib/main.dart` structure from the design
    - Add dependencies: `flutter_bloc`, `get_it`, `injectable`, Firebase packages, a generator-based PBT package, `bloc_test`, `mocktail`/`mockito`
    - Configure the `injectable` build pipeline and an empty composition root (`core/di/injection.dart`)
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_

  - [x] 1.2 Implement the Result/Either type and Failure hierarchy
    - Implement `Result<T, Failure>` with map/flatMap/fold and a typed `Failure { code, message, fieldErrors? }`
    - Add concrete failures: `ValidationFailure`, `AuthFailure`, `AuthorizationFailure`, `StateTransitionFailure`, `LocationFailure`, `PersistenceFailure`, `NotFoundFailure`
    - _Requirements: 1.7, 2.8, 3.2, 5.8, 10.3, 14.6_

  - [x] 1.3 Implement core value objects
    - Implement `PhoneNumber`, `Money` (fixed-precision decimal), `GeoPoint`, and the `EventStatus`/`ApplicationStatus`/`ApprovalStatus` enums, enforcing validity at construction
    - _Requirements: 7.1, 8.5, 10.1, 11.3_

  - [ ]* 1.4 Write unit tests for value objects
    - Test `Money` exact-decimal arithmetic, `GeoPoint` bounds, and enum parsing/rejection of unknown values
    - _Requirements: 7.5, 11.3_

- [x] 2. Auth domain (pure Dart)
  - [x] 2.1 Define auth entities and the AuthRepository interface
    - Create `AuthUser`, `OtpSession`, `SessionState` (Unauthenticated | AuthenticatedNoRole | Authenticated(role)) entities
    - Define the abstract `AuthRepository` (request/verify OTP, session stream, sign-out)
    - _Requirements: 1.1, 2.1, 3.3, 3.4_

  - [x] 2.2 Implement phone validation and the RequestOtp use case
    - Implement the pure phone-format validator (student: country code + 10 national digits; vendor: exactly 10 digits)
    - Implement `RequestOtp` to reject invalid/locked phones and ask the repository to deliver an OTP
    - _Requirements: 1.1, 1.5, 2.1, 2.2_

  - [x] 2.3 Implement VerifyOtp with the OTP window and attempt/lockout reducer
    - Implement the pure OTP-acceptance check (match AND within 300s) and the consecutive-invalid attempt counter/lockout reducer (student 900s block; vendor invalidate OTP after 5)
    - Implement `VerifyOtp` orchestrating these against the repository
    - _Requirements: 1.2, 1.3, 1.4, 2.3, 2.4, 2.5_

  - [x] 2.4 Implement the WatchSession use case
    - Emit `SessionState` transitions for unauthenticated, authenticated-no-role, and authenticated(role)
    - _Requirements: 3.3, 3.4_

  - [ ]* 2.5 Write property test for phone-format validation
    - **Property 3: Phone number format validation**
    - **Validates: Requirements 1.5, 2.2**

  - [ ]* 2.6 Write property test for the OTP acceptance window
    - **Property 1: OTP acceptance window**
    - **Validates: Requirements 1.1, 1.2, 1.3, 2.3**

  - [ ]* 2.7 Write property test for OTP attempt counting and lockout
    - **Property 2: OTP attempt counting and lockout**
    - **Validates: Requirements 1.4, 2.4, 2.5**

  - [ ]* 2.8 Write unit tests for auth use cases with mocked AuthRepository
    - Verify RequestOtp/VerifyOtp orchestration and failure mapping; guards short-circuit before repository calls
    - _Requirements: 1.3, 2.4_

- [x] 3. Profile domain (pure Dart)
  - [x] 3.1 Define profile entities and ProfileRepository/StorageRepository interfaces
    - Create `Student` and `Vendor` entities (Vendor defaults `approvalStatus = Pending`, holds optional fields)
    - Define abstract `ProfileRepository` (create/read student & vendor) and `StorageRepository` (upload/reference photo)
    - _Requirements: 1.6, 2.6, 2.7, 2.9, 14.2, 14.3_

  - [x] 3.2 Implement profile validators and the RegisterStudent/RegisterVendor use cases
    - Implement pure `validateStudentProfile`, `validatePhoto`, `validateVendorProfile` returning exact field-error sets
    - Implement `RegisterStudent` (upload photo then create) and `RegisterVendor` (create with Pending status, store optionals)
    - _Requirements: 1.6, 1.7, 1.8, 1.9, 2.6, 2.7, 2.8, 2.9_

  - [ ]* 3.3 Write property test for student profile validation completeness
    - **Property 4: Student profile validation completeness**
    - **Validates: Requirements 1.6, 1.7**

  - [ ]* 3.4 Write property test for profile photo validation
    - **Property 5: Profile photo validation**
    - **Validates: Requirements 1.8**

  - [ ]* 3.5 Write property test for vendor profile validation completeness
    - **Property 6: Vendor profile validation completeness**
    - **Validates: Requirements 2.6, 2.7, 2.8**

  - [ ]* 3.6 Write unit tests for registration use cases with mocked repositories
    - Verify photo upload precedes profile create; vendor created with Pending; optionals persisted (R2.7)
    - _Requirements: 1.9, 2.7, 2.9_

- [x] 4. Navigation/authorization domain (pure Dart)
  - [x] 4.1 Implement Destination model and the Authorize/ResolveStartDestination use cases
    - Define role→destinations map; implement pure `Authorize(role, feature)` and `ResolveStartDestination(session)` (unauthenticated → auth screen; no/unknown role → no role destinations)
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [ ]* 4.2 Write property test for role-based navigation visibility
    - **Property 8: Role-based navigation visibility**
    - **Validates: Requirements 3.1, 3.3**

  - [ ]* 4.3 Write property test for feature authorization
    - **Property 9: Feature authorization**
    - **Validates: Requirements 3.2**

- [x] 5. Events domain (pure Dart)
  - [x] 5.1 Define the Event entity and EventRepository interface
    - Create the `Event` entity (status, owner vendorId, location label+geo, codes) and the abstract `EventRepository` (CRUD/query, codes)
    - _Requirements: 7.1, 7.6, 8.5_

  - [x] 5.2 Implement event validation and the CreateEvent use case
    - Implement pure `validateEvent` (presence + date today/future + endTime > startTime + slots 1..10000 + payPerHead 0.01..9999999.99)
    - Implement `CreateEvent` requiring `approvalStatus == Approved`, setting status Active on success
    - _Requirements: 2.10, 5.1, 7.1, 7.2, 7.3, 7.4_

  - [x] 5.3 Implement status/ownership guards, queries, and search
    - Implement `ChangeEventStatus` (enum guard {Active,Closed,Completed} + owner check), `WatchActiveEvents`, `WatchVendorEvents`, `GetEvent`, the pure `SearchActiveEvents` filter, the pure ownership guard, and the dashboard/list filter selectors
    - _Requirements: 4.1, 5.2, 5.9, 7.5, 8.1, 8.3, 8.5_

  - [ ]* 5.4 Write property test for event validation
    - **Property 12: Event validation**
    - **Validates: Requirements 7.1, 7.2, 7.3, 7.4**

  - [ ]* 5.5 Write property test for the event status enum guard
    - **Property 13: Event status enum guard**
    - **Validates: Requirements 7.5**

  - [ ]* 5.6 Write property test for vendor event-creation authorization
    - **Property 7: Vendor event-creation authorization**
    - **Validates: Requirements 2.10, 5.1**

  - [ ]* 5.7 Write property test for active-event search
    - **Property 14: Active-event search**
    - **Validates: Requirements 8.3, 8.4**

  - [ ]* 5.8 Write property test for vendor event-access ownership
    - **Property 11: Vendor event-access ownership**
    - **Validates: Requirements 5.9**

  - [ ]* 5.9 Write property test for owner-scoped and status-scoped list filtering
    - **Property 10: Owner-scoped and status-scoped list filtering**
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 5.2, 5.3, 5.7, 8.1**

  - [ ]* 5.10 Write unit tests for event use cases with mocked EventRepository
    - Verify CreateEvent persists only on validation+approval; ChangeEventStatus rejects non-owners
    - _Requirements: 5.9, 7.6_

- [x] 6. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Applications domain (pure Dart)
  - [x] 7.1 Define the Application entity and ApplicationRepository interface
    - Create the `Application` entity (composite id `{eventId}_{studentId}`, Pending on creation) and the abstract `ApplicationRepository`
    - _Requirements: 9.1, 9.6_

  - [x] 7.2 Implement ApplyToEvent, DecideApplication, and watch use cases
    - Implement `ApplyToEvent` (event must be Active; reject duplicates; create Pending), `DecideApplication` (owner check + Pending→Approved/Rejected guard), `WatchEventApplications`, `WatchStudentApplications`
    - _Requirements: 4.2, 4.3, 5.3, 5.4, 5.5, 5.8, 8.6, 8.7, 9.1, 9.2, 9.3, 9.4, 9.5_

  - [ ]* 7.3 Write property test for application creation and event-active guard
    - **Property 15: Application creation and event-active guard**
    - **Validates: Requirements 8.6, 8.7, 9.1**

  - [ ]* 7.4 Write property test for no duplicate applications
    - **Property 16: No duplicate applications**
    - **Validates: Requirements 9.2**

  - [ ]* 7.5 Write property test for application status transition
    - **Property 17: Application status transition**
    - **Validates: Requirements 5.4, 5.5, 5.8, 9.3, 9.4, 9.5**

  - [ ]* 7.6 Write unit tests for application use cases with mocked repositories
    - Verify duplicate apply leaves existing record unchanged; decide rejects non-owner and non-Pending
    - _Requirements: 5.9, 9.2, 9.5_

- [x] 8. Attendance domain (pure Dart)
  - [x] 8.1 Define the AttendanceRecord entity and AttendanceRepository interface
    - Create the `AttendanceRecord` entity (check-in/out times, geo, workingHours, accrued flag) and the abstract `AttendanceRepository`
    - _Requirements: 10.1, 10.10_

  - [x] 8.2 Implement the haversine distance and working-hours pure functions
    - Implement `distanceMeters(a, b)` (haversine) and `workingHours(checkIn, checkOut)` (hours rounded to 2 dp, non-negative)
    - _Requirements: 10.3, 10.9_

  - [x] 8.3 Implement CheckIn, CheckOut, and GenerateAttendanceCode use cases
    - `CheckIn`: code match AND location within 30s AND within 100m AND not already checked in; reject leaves record unchanged. `CheckOut`: code match AND check-in exists; record checkout + workingHours. `GenerateAttendanceCode`: owner check + start/end kind
    - _Requirements: 5.6, 5.9, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 10.10_

  - [ ]* 8.4 Write property test for the attendance check-in decision
    - **Property 20: Attendance check-in decision**
    - **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5**

  - [ ]* 8.5 Write property test for the attendance check-out decision
    - **Property 21: Attendance check-out decision**
    - **Validates: Requirements 10.6, 10.7, 10.8**

  - [ ]* 8.6 Write property test for working-hours computation
    - **Property 22: Working-hours computation**
    - **Validates: Requirements 10.9**

  - [ ]* 8.7 Write unit tests for attendance use cases with mocked repositories
    - Verify each rejecting branch leaves the record unchanged and surfaces the specific failure
    - _Requirements: 10.2, 10.4, 10.5, 10.8_

- [x] 9. Earnings domain (pure Dart)
  - [x] 9.1 Define the Earnings entity and EarningsRepository/EarningsService interfaces
    - Create the `Earnings` entity (total + perEvent map, default 0), the read-only `EarningsRepository`, and the abstract `EarningsService` (trusted accrual)
    - _Requirements: 11.3, 11.4, 11.5_

  - [x] 9.2 Implement the accrual reducer and the GetEarnings use case
    - Implement the pure idempotent `accrue(earnings, completedRecord)` keyed on (studentId, eventId) and `GetEarnings` stream
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

  - [ ]* 9.3 Write property test for exactly-once earnings accrual
    - **Property 23: Exactly-once earnings accrual**
    - **Validates: Requirements 11.1, 11.2**

  - [ ]* 9.4 Write property test for earnings total integrity
    - **Property 24: Earnings total integrity**
    - **Validates: Requirements 11.4, 11.5**

  - [ ]* 9.5 Write unit tests for GetEarnings with a mocked repository
    - Verify empty earnings render total 0 with an empty per-event list
    - _Requirements: 11.5_

- [x] 10. Reports domain (pure Dart)
  - [x] 10.1 Define the Report entity and ReportRepository interface
    - Create the `Report` entity (submitterId, submitterRole, category, description, createdAt) and the abstract `ReportRepository`
    - _Requirements: 12.5_

  - [x] 10.2 Implement validateReport and the SubmitReport/ListReports use cases
    - Implement the pure `validateReport` (role-permitted category + description 1..1000) and `SubmitReport`/`ListReports`
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6_

  - [ ]* 10.3 Write property test for report validation
    - **Property 25: Report validation**
    - **Validates: Requirements 12.1, 12.2, 12.3, 12.4**

  - [ ]* 10.4 Write unit tests for report use cases with a mocked repository
    - Verify rejected categories/descriptions never persist; valid reports store identity/category/description/timestamp
    - _Requirements: 12.3, 12.4, 12.5_

- [x] 11. Admin domain (pure Dart)
  - [x] 11.1 Define the Metrics entity and AdminRepository/MetricsService interfaces
    - Create the `Metrics` entity (non-negative counts), the abstract `AdminRepository` (approval, lists, device-token registration), and the abstract `MetricsService`
    - _Requirements: 6.4, 6.5, 6.6, 6.7, 6.8_

  - [x] 11.2 Implement vendor-approval transition, list use cases, and metrics counting
    - Implement `ApproveVendor`/`RejectVendor` (Pending-only guard), `ListStudents`/`ListVendors`/`ListEvents`/`ListReports`, `GetMetrics`, and the pure metrics-counting function
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9_

  - [ ]* 11.3 Write property test for vendor approval status transition
    - **Property 18: Vendor approval status transition**
    - **Validates: Requirements 6.1, 6.2, 6.3**

  - [ ]* 11.4 Write property test for admin metrics counting
    - **Property 19: Admin metrics counting**
    - **Validates: Requirements 6.7**

  - [ ]* 11.5 Write unit tests for admin use cases with a mocked repository
    - Verify approve/reject on non-Pending vendors is rejected and leaves status unchanged
    - _Requirements: 6.3_

- [x] 12. Notifications domain (pure Dart)
  - [x] 12.1 Define the Notification entity and NotificationService interface
    - Create the `Notification` entity (type, payload, deliveryStatus, attemptCount) and the abstract `NotificationService` consumed by the client/read paths
    - _Requirements: 13.5, 13.7_

- [x] 13. Checkpoint - Domain layer complete, ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 14. Data layer infrastructure (Firebase)
  - [x] 14.1 Implement Firebase initialization, data-source base, and the write-retry policy
    - Initialize Firebase; add thin data-source wrappers over `FirebaseAuth`/`FirebaseFirestore`/`FirebaseStorage`/`FirebaseMessaging`; implement the pure `withRetry(3)` wrapper that returns an error and commits no partial data on total failure
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6_

  - [ ]* 14.2 Write property test for write retry atomicity
    - **Property 29: Write retry atomicity**
    - **Validates: Requirements 14.6**

- [x] 15. Auth & profile data layer (Firebase)
  - [x] 15.1 Implement auth data source, DTOs/mappers, and FirebaseAuthRepositoryImpl
    - Implement `FirebaseAuthDataSource`, the `authThrottle` DTO/mapper, and `FirebaseAuthRepositoryImpl` maintaining application-level attempt/lockout state
    - _Requirements: 1.4, 2.1, 2.4, 2.5, 14.1_

  - [x] 15.2 Implement profile data sources, DTOs/mappers, and repository impls
    - Implement `FirestoreProfileRepositoryImpl` (students/vendors DTOs + mappers) and `FirebaseStorageRepositoryImpl`; wrap writes in the retry policy
    - _Requirements: 1.9, 14.2, 14.3, 14.6_

  - [ ]* 15.3 Write DTO round-trip tests for auth and profile
    - Verify `toFirestore`/`fromFirestore` and `toEntity`/`fromEntity` preserve all domain fields
    - _Requirements: 14.2, 14.3_

- [x] 16. Events / applications / attendance data layer (Firebase)
  - [x] 16.1 Implement Event DTO/mapper, data source, and FirestoreEventRepositoryImpl
    - Map `Timestamp`/`GeoPoint`/`decimal` to/from pure types; implement create/query/code writes with the retry policy
    - _Requirements: 7.6, 8.1, 14.6_

  - [x] 16.2 Implement Application DTO/mapper, data source, and repository impl
    - Use composite doc id `{eventId}_{studentId}`; implement create/decide/list with the retry policy
    - _Requirements: 9.6, 14.6_

  - [x] 16.3 Implement Attendance DTO/mapper, data source, and repository impl
    - Map check-in/out times, geo, workingHours; never write `accrued` from the client; apply the retry policy
    - _Requirements: 10.10, 14.6_

  - [ ]* 16.4 Write DTO round-trip tests for event, application, and attendance
    - Verify mappers preserve all fields including geo and decimal money
    - _Requirements: 7.6, 9.6, 10.10_

- [x] 17. Earnings / reports / admin / notifications data layer (Firebase)
  - [x] 17.1 Implement Earnings DTO/mapper and the read-only repository impl
    - Implement `FirestoreEarningsRepositoryImpl` (read-only client); no client writes to earnings
    - _Requirements: 11.3, 11.4, 14.4_

  - [x] 17.2 Implement Report DTO/mapper and the repository impl
    - Implement `FirestoreReportRepositoryImpl` with the retry policy
    - _Requirements: 12.5, 14.6_

  - [x] 17.3 Implement Admin repository impl, device-token registration, and Notification data source
    - Implement `FirestoreAdminRepositoryImpl` (lists, approval reads, device-token write), the Notification DTO/mapper, and an FCM data source for reads/token registration
    - _Requirements: 6.4, 6.5, 6.6, 13.5, 13.7, 14.5_

  - [ ]* 17.4 Write DTO round-trip tests for earnings, reports, admin, and notifications
    - Verify mappers preserve totals/per-event maps and notification fields
    - _Requirements: 11.4, 12.5, 14.5_

- [x] 18. Checkpoint - Data layer complete, ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 19. Auth & registration presentation
  - [x] 19.1 Implement AuthBloc
    - Map `OtpRequested`/`OtpSubmitted`/`SessionWatchStarted`/`SignedOut` to use-case calls and states (`OtpSent`, `Authenticated(role)`, `AuthFailure`, `PhoneLocked`)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.3, 2.4, 3.4_

  - [x] 19.2 Implement RegistrationBloc
    - Map student/vendor field changes and submit events to validators + register use cases; preserve entered values and surface field errors
    - _Requirements: 1.6, 1.7, 2.6, 2.8_

  - [x] 19.3 Build auth and registration screens
    - Phone entry, OTP entry, student registration form (with photo picker), and vendor registration form wired to the BLoCs
    - _Requirements: 1.5, 1.7, 1.8, 2.2, 2.8_

  - [ ]* 19.4 Write bloc_test suites for AuthBloc and RegistrationBloc
    - Assert Event→State sequences (e.g., `OtpSubmitted` → `[Verifying, Authenticated]` / `[Verifying, AuthFailure]`)
    - _Requirements: 1.3, 1.4, 2.4_

- [x] 20. Role-based router
  - [x] 20.1 Implement the role-based router and navigation guards
    - Subscribe to `AuthBloc` session state; use `ResolveStartDestination` and `Authorize` to choose start destination, block cross-role navigation (return to default destination), and redirect unauthenticated users to auth
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [ ]* 20.2 Write widget tests for router guards
    - Verify each role sees only its destinations; unknown/no role shows none; unauthorized feature returns to default without altering session
    - _Requirements: 3.1, 3.2, 3.3_

- [x] 21. Student presentation
  - [x] 21.1 Implement EventDiscoveryBloc and discovery/detail/search screens
    - Map `DiscoveryStarted`/`SearchQueryChanged`/`EventSelected` to states (`EventsLoaded`, `EventsEmpty`, `SearchNoResults`, `EventDetail`)
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [x] 21.2 Build student dashboard screens
    - Active events list, applied events list, approved events list, attendance history, profile view, with empty-state and read-failure indications
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.6, 4.7_

  - [x] 21.3 Implement AttendanceBloc and check-in/check-out screens
    - Map `CheckInRequested`/`CheckOutRequested` to states (`LocatingDevice`, `CheckedIn`, `CheckedOut`, `AttendanceFailure(reason)`, `HistoryLoaded`)
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8_

  - [x] 21.4 Implement EarningsBloc and the earnings screen
    - Map `EarningsWatchStarted` to `EarningsLoaded(total, perEvent)` / `EarningsEmpty`; render monetary total and per-event credits
    - _Requirements: 4.5, 11.3, 11.4, 11.5_

  - [ ]* 21.5 Write bloc_test suites for discovery, attendance, and earnings BLoCs
    - Assert search no-results, each check-in/out failure reason, and empty-earnings sequences
    - _Requirements: 8.4, 10.3, 10.5, 11.5_

- [x] 22. Vendor presentation
  - [x] 22.1 Implement EventManagementBloc and manage/create-event screens
    - Map `CreateRequested`/`StatusChangeRequested`/`VendorEventsWatchStarted` to states; surface field errors and retain values; gate creation on Approved status
    - _Requirements: 5.1, 5.2, 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 22.2 Implement ApplicationBloc and applicant-list/decide/attendance screens
    - Applicant list, approve/reject actions, attendance-code generation, and attendance view; deny actions on non-owned events
    - _Requirements: 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 9.3, 9.4, 9.5_

  - [ ]* 22.3 Write bloc_test suites for EventManagementBloc and ApplicationBloc
    - Assert create-validation failures, status enum guard, and decide non-Pending/non-owner failures
    - _Requirements: 5.8, 5.9, 7.3, 7.5_

- [x] 23. Admin presentation
  - [x] 23.1 Implement AdminBloc and approval/lists/metrics screens
    - Map approve/reject and list/metrics watch events to states; render student/vendor/event lists with statuses, metrics counts, and empty-state indications
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.9_

  - [ ]* 23.2 Write bloc_test suite for AdminBloc
    - Assert non-Pending approval failure and metrics/list loaded/empty sequences
    - _Requirements: 6.3, 6.7, 6.9_

- [x] 24. Reports presentation
  - [x] 24.1 Implement ReportBloc and report-submission/admin-review screens
    - Student (FakeEvent/VendorIssue) and Vendor (NoShow/Misbehavior) submission forms; admin report detail view (category, description, submitter, timestamp)
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.6_

  - [ ]* 24.2 Write bloc_test suite for ReportBloc
    - Assert invalid category/description failures and successful submission sequences
    - _Requirements: 12.3, 12.4_

- [x] 25. Checkpoint - Presentation layer complete, ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 26. Cloud Functions setup (TypeScript)
  - [x] 26.1 Initialize the Cloud Functions project and test tooling
    - Set up the TypeScript functions package, Firebase Admin SDK, and `fast-check` for property tests; structure trusted logic as pure, testable functions
    - _Requirements: 11.1, 13.5_

- [x] 27. Earnings accrual Cloud Function
  - [x] 27.1 Implement the accrueEarnings function (idempotent)
    - On `attendance/{id}` onWrite, when a record becomes completed add `payPerHead` exactly once using the `accrued` idempotency marker inside a transaction
    - _Requirements: 11.1, 11.2_

  - [ ]* 27.2 Write fast-check property test for server-side accrual idempotency
    - **Property 23: Exactly-once earnings accrual**
    - **Validates: Requirements 11.1, 11.2**

- [x] 28. Notification Cloud Functions
  - [x] 28.1 Implement onApplicationCreated and onApplicationStatusChange
    - Create exactly one correctly-typed notification: creation → NewApplication to owning vendor; Approved/Rejected → notice to applicant
    - _Requirements: 13.1, 13.2, 13.4_

  - [x] 28.2 Implement the scheduled eventReminders function
    - Select students with an Approved application for events starting within the 24h window with no reminder already sent
    - _Requirements: 13.3_

  - [x] 28.3 Implement the deliverNotification function (retry/skip/failure)
    - Skip when no device token; otherwise dispatch via FCM with at most 3 attempts ≥60s apart; record Failed after exhaustion and preserve trigger data
    - _Requirements: 13.5, 13.6, 13.7, 13.8_

  - [ ]* 28.4 Write fast-check property test for notification creation on triggering events
    - **Property 26: Notification creation on triggering events**
    - **Validates: Requirements 13.1, 13.2, 13.4**

  - [ ]* 28.5 Write fast-check property test for event-reminder selection
    - **Property 27: Event-reminder selection**
    - **Validates: Requirements 13.3**

  - [ ]* 28.6 Write fast-check property test for notification delivery retry, skip, and failure
    - **Property 28: Notification delivery retry, skip, and failure**
    - **Validates: Requirements 13.6, 13.7, 13.8**

- [x] 29. Metrics Cloud Function
  - [x] 29.1 Implement the recomputeMetrics function
    - Recompute admin counters (total students/vendors, active/completed events) on Firestore triggers with a scheduled fallback, writing `metrics/global`
    - _Requirements: 6.7_

- [x] 30. Firestore Security Rules (backend enforcement)
  - [x] 30.1 Write Firestore Security Rules for all collections
    - Enforce per-doc ownership, non-client-writable `vendors.approvalStatus`/`attendance.accrued`/earnings/metrics/notification-delivery fields, event create/update gated on owner+Approved, and application create-on-existing-doc denial (dedupe) with Pending-only status transitions
    - _Requirements: 2.9, 2.10, 5.1, 5.9, 6.1, 6.2, 6.3, 9.2, 11.1, 11.2, 12.6_

  - [ ]* 30.2 Write Firestore-emulator security-rules tests
    - Assert students cannot write earnings/`accrued`; vendors cannot self-approve; create on an existing application doc is denied; non-owner vendors cannot read another vendor's event applications
    - _Requirements: 2.9, 5.9, 9.2, 11.2_

- [x] 31. Integration wiring and DI finalization
  - [x] 31.1 Finalize dependency-injection bindings
    - Bind every repository interface to its Firebase impl and every service interface (`EarningsService`/`NotificationService`/`MetricsService`) to its Cloud-Function-backed impl in the composition root
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_

  - [x] 31.2 Bootstrap the app and wire the router and FCM token registration
    - Wire `main.dart` to initialize DI/Firebase, register the device token via `AdminRepository`, and start the role-based router from `AuthBloc`
    - _Requirements: 3.1, 3.4, 13.7_

  - [ ]* 31.3 Write integration tests against the Firebase Emulator Suite
    - Verify writes land in `users`/`students`/`vendors`/`events`/`applications`/`attendance`/`earnings`/`reports`/`notifications` within budget, OTP request triggers Auth delivery, and a valid photo is stored with a reference on the profile
    - _Requirements: 1.9, 2.1, 6.4, 6.5, 6.6, 6.8, 7.6, 9.6, 10.10, 12.5, 13.5, 14.1, 14.2, 14.3, 14.4, 14.5_

- [x] 32. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test sub-tasks (property, unit, bloc, DTO round-trip, integration, security-rules) and can be skipped for a faster MVP, but each correctness property maps to exactly one property-based test.
- Property-based tests run a minimum of 100 iterations and are tagged `Feature: eventxindia-platform, Property {n}: {text}`. Dart domain logic uses a generator-based PBT package; TypeScript Cloud Function logic uses `fast-check`.
- All 29 correctness properties are covered: P1–P3 (auth), P4–P6 (profile), P7/P10–P14 (events), P8–P9 (navigation), P15–P17 (applications), P18–P19 (admin), P20–P22 (attendance), P23–P24 (earnings), P25 (reports), P26–P28 (notification Cloud Functions), P29 (data-layer write retry).
- The domain layer stays backend-agnostic; swapping Firebase for a Node.js/REST backend later means adding new data-layer impls and changing the DI bindings in task 31.1 only.
- Checkpoints (tasks 6, 13, 18, 25, 32) provide incremental validation at each layer boundary.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["1.4", "2.1", "3.1", "4.1", "5.1", "7.1", "8.1", "9.1", "10.1", "11.1", "12.1"] },
    { "id": 3, "tasks": ["2.2", "2.3", "2.4", "3.2", "5.2", "5.3", "7.2", "8.2", "8.3", "9.2", "10.2", "11.2"] },
    { "id": 4, "tasks": ["2.5", "2.6", "2.7", "2.8", "3.3", "3.4", "3.5", "3.6", "4.2", "4.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "5.10", "7.3", "7.4", "7.5", "7.6", "8.4", "8.5", "8.6", "8.7", "9.3", "9.4", "9.5", "10.3", "10.4", "11.3", "11.4", "11.5"] },
    { "id": 5, "tasks": ["14.1"] },
    { "id": 6, "tasks": ["14.2", "15.1", "15.2", "16.1", "16.2", "16.3", "17.1", "17.2", "17.3"] },
    { "id": 7, "tasks": ["15.3", "16.4", "17.4"] },
    { "id": 8, "tasks": ["19.1", "19.2", "21.1", "21.3", "21.4", "22.1", "22.2", "23.1", "24.1"] },
    { "id": 9, "tasks": ["19.3", "20.1", "21.2"] },
    { "id": 10, "tasks": ["19.4", "20.2", "21.5", "22.3", "23.2", "24.2"] },
    { "id": 11, "tasks": ["26.1"] },
    { "id": 12, "tasks": ["27.1", "28.1", "28.2", "28.3", "29.1"] },
    { "id": 13, "tasks": ["27.2", "28.4", "28.5", "28.6"] },
    { "id": 14, "tasks": ["30.1"] },
    { "id": 15, "tasks": ["30.2", "31.1"] },
    { "id": 16, "tasks": ["31.2"] },
    { "id": 17, "tasks": ["31.3"] }
  ]
}
```
