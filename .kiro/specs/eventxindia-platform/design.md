# Design Document

## Overview

EventXIndia V1 is a single Flutter application that digitizes an offline event-staffing process for three roles — Student, Vendor, and Admin — using role-based navigation. The current backend is Firebase (Authentication with Phone OTP, Cloud Firestore, Firebase Storage, Cloud Messaging, and Cloud Functions for trusted server-side logic).

This design is structured around two strict architectural goals:

- **Goal 1 — Backend swappability.** The app is built so Firebase can later be replaced by a Node.js + REST/WebSocket backend **without touching the domain or presentation layers**. This is achieved with Clean Architecture: the domain layer defines abstract repository interfaces and pure entities that contain **no Firebase types**; the data layer holds the Firebase implementations of those interfaces plus DTOs and mappers that convert Firebase documents to/from pure domain entities. Swapping backends means writing new data-layer implementations (e.g., `RestEventRepositoryImpl`) and changing one dependency-injection binding — nothing in domain or presentation changes.
- **Goal 2 — Clean Architecture + BLoC.** A strict layered structure (presentation → domain ← data, with a shared core) using `flutter_bloc` for presentation state. BLoCs depend only on use cases; use cases depend only on abstract repository interfaces; repository implementations are the only place that knows about Firebase.

All 14 requirements are satisfied. The high-level mapping below now references the layer that owns each behavior (use cases in the domain layer carry the business logic; data-layer repositories carry persistence; BLoCs carry presentation state):

| Requirement | Area | Owning use cases / components |
|---|---|---|
| 1 | Student auth + profile | `RequestOtp`, `VerifyOtp`, `RegisterStudent`, `AuthRepository`, `ProfileRepository`, `StorageRepository` |
| 2 | Vendor auth + approval status | `RequestOtp`, `VerifyOtp`, `RegisterVendor`, `AuthRepository`, `ProfileRepository` |
| 3 | Role-based navigation | `WatchSession`, `ResolveStartDestination`, `Authorize`, `AuthBloc`, router |
| 4 | Student dashboard | `WatchActiveEvents`, `WatchStudentApplications`, `WatchAttendanceHistory`, `GetEarnings` |
| 5 | Vendor dashboard | `WatchVendorEvents`, `WatchEventApplications`, `DecideApplication`, `GenerateAttendanceCode` |
| 6 | Admin dashboard + vendor approval | `ApproveVendor`, `RejectVendor`, list use cases, `GetMetrics` |
| 7 | Event management | `CreateEvent`, `ChangeEventStatus`, `EventRepository` |
| 8 | Event discovery | `WatchActiveEvents`, `SearchActiveEvents`, `GetEvent` |
| 9 | Applications | `ApplyToEvent`, `DecideApplication`, `ApplicationRepository` |
| 10 | Attendance (codes + GPS) | `CheckIn`, `CheckOut`, `AttendanceRepository`, GPS/working-hours services |
| 11 | Estimated earnings | `GetEarnings` + `EarningsService` (backend trusted accrual) |
| 12 | Reports | `SubmitReport`, `ListReports`, `ReportRepository` |
| 13 | Push notifications | `NotificationService` (backend trusted dispatch) |
| 14 | Data persistence | Repository implementations + retry policy in data layer |

### Design Principles

- **Dependency rule.** Source-code dependencies always point inward: presentation → domain ← data. The domain layer depends on nothing external (pure Dart). Presentation and data depend on domain; they never depend on each other.
- **Backend independence.** No Firebase type (`DocumentSnapshot`, `Timestamp`, `GeoPoint`, `User`, etc.) ever crosses out of the data layer. Domain entities and use cases are expressed in pure Dart types.
- **Trust boundary as a capability, not a vendor.** Logic that must be computed exactly once or be tamper-proof (earnings accrual, notification dispatch/retry, scheduled reminders, metrics aggregation) is modeled as a **backend capability behind a service abstraction** (`EarningsService`, `NotificationService`, `MetricsService`). It is implemented today by Firebase Cloud Functions and can move to Node.js later with no change to the abstraction.
- **Business logic lives in the domain.** Validation, GPS haversine distance, working-hours calculation, search filtering, status-transition guards, exactly-once accrual logic, and retry logic are pure functions/use cases in the domain layer — backend-independent and property-testable.
- **Two-layer validation.** Use cases validate for correctness and fast feedback; the current backend re-validates server-side (Firestore Security Rules / Cloud Functions). A future Node.js backend enforces the equivalent invariants server-side.

## Architecture

### The Dependency Rule

```
        presentation  ───────▶  domain  ◀───────  data
     (Flutter + BLoC)         (pure Dart)      (Firebase today,
                                                REST/WS later)
                                  ▲
                                  │
                                core/shared
                       (Result/Either, Failure, DI, value objects)
```

- **Presentation** knows about **domain** (use cases, entities) only. It never imports a repository implementation or a Firebase package.
- **Data** knows about **domain** (it implements the abstract interfaces) only. It never imports presentation.
- **Domain** knows about nothing but itself and the shared core. It is the stable center.
- Concrete wiring happens once, at the composition root (DI container), which is the only place that knows all three layers.

### Layered Architecture and Backend-Swap Abstraction

```mermaid
graph TB
    subgraph Presentation["Presentation Layer (Flutter + flutter_bloc)"]
        W[Widgets / Screens<br/>student / vendor / admin / auth]
        B[BLoCs / Cubits<br/>AuthBloc, EventDiscoveryBloc, ApplicationBloc,<br/>AttendanceBloc, EarningsBloc, ReportBloc, AdminBloc]
    end

    subgraph Domain["Domain Layer (pure Dart — no external deps)"]
        UC[Use Cases / Interactors<br/>RequestOtp, VerifyOtp, RegisterStudent, CreateEvent,<br/>ApplyToEvent, DecideApplication, CheckIn, CheckOut,<br/>SubmitReport, ApproveVendor, GetEarnings, ...]
        ENT[Entities<br/>Student, Vendor, Event, Application,<br/>AttendanceRecord, Earnings, Report, ...]
        RI[Abstract Repository Interfaces<br/>AuthRepository, ProfileRepository, EventRepository,<br/>ApplicationRepository, AttendanceRepository,<br/>EarningsRepository, ReportRepository, AdminRepository]
        SI[Abstract Service Interfaces<br/>EarningsService, NotificationService, MetricsService]
        DL[Pure domain logic<br/>validators, haversine distance, workingHours,<br/>search filter, transition guards, accrual reducer, retry policy]
    end

    subgraph Data["Data Layer (swappable per backend)"]
        subgraph FB["Firebase implementation (current)"]
            FRI[FirebaseAuthRepositoryImpl<br/>FirestoreEventRepositoryImpl<br/>FirestoreApplicationRepositoryImpl<br/>FirestoreAttendanceRepositoryImpl<br/>FirestoreEarningsRepositoryImpl ...]
            FDS[Firebase data sources<br/>FirebaseAuthDataSource,<br/>FirestoreEventDataSource, StorageDataSource]
            DTO[DTOs + Mappers<br/>EventDto, ApplicationDto, ...<br/>toEntity() / fromEntity()]
        end
        subgraph REST["Node.js implementation (future)"]
            RRI[RestEventRepositoryImpl<br/>RestAuthRepositoryImpl ...]
            RDS[Remote data sources<br/>RestApiDataSource, WebSocketDataSource]
            RDTO[REST DTOs + Mappers]
        end
    end

    subgraph Core["Core / Shared"]
        RES[Result/Either, Failure/DomainError]
        DI[Dependency Injection<br/>get_it + injectable]
        VO[Value Objects]
    end

    W --> B
    B --> UC
    UC --> RI
    UC --> SI
    UC --> ENT
    UC --> DL
    FRI -.implements.-> RI
    RRI -.implements.-> RI
    FRI --> FDS --> DTO
    RRI --> RDS --> RDTO
    DI -. binds one impl .-> RI
    UC --> RES
    B --> RES
```

The dashed `implements` edges and the single DI binding are the entire backend-swap mechanism: today DI binds `EventRepository → FirestoreEventRepositoryImpl`; tomorrow it binds `EventRepository → RestEventRepositoryImpl`. No use case, BLoC, widget, or entity changes.

### Abstraction Boundary (the swap line)

The boundary is the set of **abstract repository interfaces and abstract service interfaces in the domain layer**. Everything above the line (domain + presentation) is backend-agnostic. Everything below the line (data layer) is backend-specific and replaceable.

**Repository interfaces (domain-owned, the swap line):**

| Interface | Responsibility | Current impl | Future impl |
|---|---|---|---|
| `AuthRepository` | OTP request/verify, session stream, sign-out | `FirebaseAuthRepositoryImpl` | `RestAuthRepositoryImpl` |
| `ProfileRepository` | Create/read student & vendor profiles | `FirestoreProfileRepositoryImpl` | `RestProfileRepositoryImpl` |
| `StorageRepository` | Upload/reference profile photos | `FirebaseStorageRepositoryImpl` | `S3RestStorageRepositoryImpl` |
| `EventRepository` | CRUD/query events, codes | `FirestoreEventRepositoryImpl` | `RestEventRepositoryImpl` |
| `ApplicationRepository` | Create/decide/list applications | `FirestoreApplicationRepositoryImpl` | `RestApplicationRepositoryImpl` |
| `AttendanceRepository` | Check-in/out records, codes | `FirestoreAttendanceRepositoryImpl` | `RestAttendanceRepositoryImpl` |
| `EarningsRepository` | Read earnings (read-only client) | `FirestoreEarningsRepositoryImpl` | `RestEarningsRepositoryImpl` |
| `ReportRepository` | Submit/list reports | `FirestoreReportRepositoryImpl` | `RestReportRepositoryImpl` |
| `AdminRepository` | Vendor approval, lists, device-token registration | `FirestoreAdminRepositoryImpl` | `RestAdminRepositoryImpl` |

**Service interfaces (domain-owned, for trusted server-side capabilities):**

| Interface | Capability | Current impl | Future impl |
|---|---|---|---|
| `EarningsService` | Exactly-once earnings accrual | Cloud Function `accrueEarnings` (triggered) | Node.js worker / endpoint |
| `NotificationService` | Push dispatch with retry/skip/failure | Cloud Functions + FCM | Node.js + push provider / WebSocket |
| `MetricsService` | Admin metric aggregation | Cloud Function `recomputeMetrics` | Node.js aggregation job |

> The client interacts with these capabilities only by writing the triggering data (e.g., an attendance record) and reading the result (e.g., earnings). The *trust* and *exactly-once* semantics live behind the service abstraction, so moving them from Cloud Functions to a Node.js backend is a data-layer/server change, invisible to domain and presentation.

### DTO / Mapper Pattern

Each backend implementation owns a DTO type per persisted shape and a mapper that converts between the wire/document format and the pure domain entity. Domain entities never carry backend types.

```
// data layer (Firebase)
class EventDto {
  // built from a Firestore document; uses Firebase types internally
  factory EventDto.fromFirestore(DocumentSnapshot doc) { ... }   // Timestamp, GeoPoint here
  Map<String, dynamic> toFirestore() { ... }
  Event toEntity() { ... }          // -> pure domain Event (DateTime, double, plain LatLng VO)
  factory EventDto.fromEntity(Event e) { ... }
}
```

- **Inbound**: data source returns a backend-native payload → DTO parses it → `toEntity()` yields a pure entity → repository returns the entity to the use case.
- **Outbound**: use case passes an entity to the repository → `EventDto.fromEntity(...)` → `toFirestore()` (or `toJson()` for REST) → data source persists it.
- A future `RestEventRepositoryImpl` provides its own `EventDto.fromJson` / `toJson` mappers producing the **same** domain `Event`. Use cases are unaffected because they only ever see `Event`.

This is the only place Firebase `Timestamp`/`GeoPoint`/`DocumentSnapshot` exist; mappers convert them to `DateTime`, a `GeoPoint` value object, and `decimal`/`double` for the domain.

### Proposed Folder Structure (feature-first with shared core)

```
lib/
├── core/                                   # cross-cutting, backend-agnostic
│   ├── result/result.dart                  # Result/Either<Failure, T>
│   ├── error/failure.dart                  # Failure / DomainError hierarchy
│   ├── value_objects/                      # PhoneNumber, GeoPoint, Money, ...
│   └── di/injection.dart                   # get_it + injectable composition root
│
├── features/
│   ├── auth/
│   │   ├── domain/
│   │   │   ├── entities/auth_user.dart, otp_session.dart, session_state.dart
│   │   │   ├── repositories/auth_repository.dart        # abstract
│   │   │   └── usecases/request_otp.dart, verify_otp.dart, watch_session.dart
│   │   ├── data/
│   │   │   ├── datasources/firebase_auth_data_source.dart
│   │   │   ├── dtos/auth_throttle_dto.dart
│   │   │   ├── mappers/auth_mapper.dart
│   │   │   └── repositories/firebase_auth_repository_impl.dart
│   │   └── presentation/
│   │       ├── bloc/auth_bloc.dart, auth_event.dart, auth_state.dart
│   │       └── screens/ ...
│   ├── profile/        (RegisterStudent, RegisterVendor, validators)
│   ├── events/         (CreateEvent, ChangeEventStatus, discovery, search)
│   ├── applications/   (ApplyToEvent, DecideApplication)
│   ├── attendance/     (CheckIn, CheckOut, GenerateAttendanceCode)
│   ├── earnings/       (GetEarnings + EarningsService abstraction)
│   ├── reports/        (SubmitReport, ListReports)
│   └── admin/          (ApproveVendor, RejectVendor, lists, GetMetrics)
│
├── routing/                                # role-based router + guards
└── main.dart                               # bootstraps DI, runs app
```

Each feature folder repeats the same `domain / data / presentation` triad, keeping the dependency rule visible and local. A `RestXxxRepositoryImpl` is added under the relevant feature's `data/` folder when the Node.js backend lands.

### Current Backend (Firebase) and Trusted Capabilities

The current data-layer implementation uses:

- **Firebase Authentication (Phone OTP)** for OTP generation, delivery, and verification. The 6-digit numeric OTP and native rate limiting are platform-provided; the application-specific attempt counting and lockout windows (R1.4, R2.4, R2.5) are domain logic backed by an `authThrottle` record in the data layer.
- **Cloud Firestore** as the system of record for all nine collections.
- **Firebase Storage** for profile photos, with the reference path stored on the profile entity.
- **Firebase Cloud Messaging** for notifications; device tokens stored on the user document.
- **Cloud Functions** implementing the trusted service capabilities behind the domain service interfaces:

| Function | Trigger | Capability (interface) | Requirements |
|---|---|---|---|
| `accrueEarnings` | Firestore `onWrite` of `attendance/{id}` | `EarningsService` — add `payPerHead` exactly once when a record becomes completed | 11.1, 11.2 |
| `onApplicationStatusChange` | Firestore `onUpdate` of `applications/{id}` | `NotificationService` — approved/rejected notice to applicant | 13.1, 13.2 |
| `onApplicationCreated` | Firestore `onCreate` of `applications/{id}` | `NotificationService` — notify owning vendor | 13.4 |
| `eventReminders` | Scheduled | `NotificationService` — 24h-before reminders to approved applicants | 13.3 |
| `deliverNotification` | Firestore `onCreate` of `notifications/{id}` | `NotificationService` — FCM dispatch with retry/skip/failure | 13.5–13.8 |
| `recomputeMetrics` | Firestore triggers + scheduled fallback | `MetricsService` — admin counters | 6.7 |

> **Node.js migration note.** Each row above is a server-side behavior behind a domain service interface. A Node.js backend would implement the same capability — accrual idempotency, notification retry/skip/failure, reminder selection, metric aggregation — as REST endpoints, queue workers, or scheduled jobs, and enforce the equivalent integrity rules server-side (see Security Rules Approach). The Flutter domain and presentation layers are unaffected because they depend only on `EarningsService`, `NotificationService`, and `MetricsService`, plus the read/write repository interfaces.

## Components and Interfaces

Contracts are expressed in pure Dart terms. Use cases return a `Result<T, Failure>` (success value or a typed `Failure` with a code, message, and optional field errors); errors are values, not thrown exceptions, so BLoCs can map them to states and preserve form input. BLoCs depend only on use cases. Use cases depend only on repository/service interfaces. Repository implementations are the only code that touches Firebase.

### Domain Layer — Use Cases (Interactors)

One use case per business action. Each takes its dependencies (repository/service interfaces) by constructor injection and exposes a single `call(...)`.

**Auth & session (R1, R2, R3.4)**
```
RequestOtp(input: PhoneNumber) -> Result<OtpSession, Failure>
  - validates phone format: country code + 10 national digits (R1.5);
    vendor path requires exactly 10 national digits (R2.2)
  - rejects when phone is locked (R1.4) or OTP attempts exhausted (R2.5)
  - asks AuthRepository to deliver a 6-digit OTP within the delivery window (R2.1)

VerifyOtp(session: OtpSession, code: String) -> Result<AuthUser, Failure>
  - accepts only if code matches and within 300s of delivery (R1.2, R2.3)
  - on mismatch/expiry: rejects, increments attempt counter (R1.3, R2.4)
  - 5 consecutive invalids -> lock phone 900s (student R1.4) /
    invalidate OTP, require new (vendor R2.5)

WatchSession() -> Stream<SessionState>
  - emits Unauthenticated | AuthenticatedNoRole | Authenticated(role) (R3.3, R3.4)
```

**Profile registration (R1.6–1.9, 2.6–2.9, 14.1–14.3)**
```
RegisterStudent(profile: StudentProfile, photo: PhotoRef) -> Result<Student, Failure>
  - validateStudentProfile + validatePhoto must pass (R1.6–1.9)
  - StorageRepository.upload(photo); ProfileRepository.createStudent(...) (R1.9, R14.1, R14.2)

RegisterVendor(profile: VendorProfile) -> Result<Vendor, Failure>
  - validateVendorProfile must pass; stores optional fields (R2.6–2.8)
  - ProfileRepository.createVendor(...) with approvalStatus=Pending (R2.9, R14.3)

// pure domain functions (property-tested)
validateStudentProfile(input) -> List<FieldError>
validateVendorProfile(input)  -> List<FieldError>
validatePhoto(meta)           -> Result<Unit, Failure>
```

**Navigation guards (R3)**
```
ResolveStartDestination(session) -> Destination     // R3.1, R3.3, R3.4
Authorize(role, feature) -> bool                     // pure, property-tested (R3.2)
```

**Events (R5.1–5.2, R7, R8)**
```
CreateEvent(vendor, input: EventInput) -> Result<Event, Failure>
  - requires vendor.approvalStatus == Approved (R2.10, R5.1)
  - validateEvent(input) must pass; on success status=Active, persist (R7.1–7.4, 7.6)

ChangeEventStatus(vendor, eventId, status) -> Result<Event, Failure>
  - status in {Active, Closed, Completed} else error (R7.5); vendor must own event (R5.9)

WatchActiveEvents() -> Stream<List<Event>>           // R4.1, R8.1, R8.2
WatchVendorEvents(vendorId) -> Stream<List<Event>>   // R5.2
SearchActiveEvents(query, events) -> List<Event>     // pure filter, property-tested (R8.3, R8.4)
GetEvent(eventId) -> Result<Event, Failure>          // R8.5

// pure
validateEvent(input) -> List<FieldError>             // R7.2, R7.3
```

**Applications (R5.3–5.5, 5.8, 8.6–8.7, 9)**
```
ApplyToEvent(student, eventId) -> Result<Application, Failure>
  - event must be Active else reject, no record (R8.7); reject duplicates (R9.2)
  - on success create status=Pending, persist (R8.6, R9.1, R9.6)

DecideApplication(vendor, applicationId, decision) -> Result<Application, Failure>
  - vendor must own the application's event (R5.9)
  - status must be Pending else error, unchanged (R5.8, R9.5)
  - set Approved/Rejected (R5.4, R5.5, R9.3, R9.4)

WatchEventApplications(vendor, eventId) -> Stream<List<Application>>   // R5.3, R5.9
WatchStudentApplications(studentId) -> Stream<List<Application>>       // R4.2, R4.3
```

**Attendance (R10)**
```
CheckIn(student, eventId, startCode, deviceLocation) -> Result<AttendanceRecord, Failure>
  - startCode == event.startCode else error (R10.2)
  - location obtained within 30s else "location unavailable" (R10.4)
  - distanceMeters(deviceLocation, event.location) <= 100 else "location failed" (R10.3)
  - if already checked in -> "already checked in", unchanged (R10.5)
  - on success record checkInTime; persist (R10.1, R10.10)

CheckOut(student, eventId, endCode) -> Result<AttendanceRecord, Failure>
  - endCode == event.endCode else error (R10.7); checkIn must exist else error (R10.8)
  - record checkOutTime; workingHours = round((out-in) hours, 2) (R10.6, R10.9); persist (R10.10)

GenerateAttendanceCode(vendor, eventId, kind) -> Result<String, Failure>  // R5.6, R5.9

// pure domain logic (property-tested)
distanceMeters(a: GeoPoint, b: GeoPoint) -> double          // haversine
workingHours(checkIn: DateTime, checkOut: DateTime) -> double
```

**Earnings (R11) — read-only client; accrual behind `EarningsService`**
```
GetEarnings(studentId) -> Stream<Earnings>           // R11.3, R11.4, R11.5
// accrual is performed by EarningsService (trusted backend capability), keyed for
// exactly-once semantics; the pure accrual reducer below is property-tested:
accrue(earnings, completedRecord) -> Earnings        // idempotent on (studentId, eventId) (R11.1, R11.2)
```

**Reports (R12)**
```
SubmitReport(user, category, description) -> Result<Report, Failure>
  - validateReport(role, category, description) must pass (R12.1–12.4)
  - persist submitterId, category, description, createdAt (R12.5)
ListReports() -> Stream<List<Report>>                // admin only (R6.8, R12.6)
validateReport(role, category, description) -> List<FieldError>   // pure
```

**Admin (R6)**
```
ApproveVendor(adminUid, vendorId) -> Result<Vendor, Failure>     // R6.1
RejectVendor(adminUid, vendorId)  -> Result<Vendor, Failure>     // R6.2
  - approvalStatus must be Pending else error, unchanged (R6.3)
ListStudents() / ListVendors() / ListEvents() / ListReports()    // R6.4–6.6, 6.8, 6.9
GetMetrics() -> Stream<Metrics>                                  // via MetricsService (R6.7)
```

### Presentation Layer — BLoCs (Events, States)

Each feature has a BLoC (or Cubit) built on `flutter_bloc`. BLoCs receive use cases via DI, translate UI intent (Events) into use-case calls, and emit States the widgets render. BLoCs never import a repository or Firebase package.

| BLoC | Key Events | Key States |
|---|---|---|
| `AuthBloc` | `OtpRequested`, `OtpSubmitted`, `SessionWatchStarted`, `SignedOut` | `AuthInitial`, `OtpSending`, `OtpSent`, `Verifying`, `Authenticated(role)`, `AuthFailure(message)`, `PhoneLocked(until)` |
| `RegistrationBloc` | `StudentFieldsChanged`, `StudentSubmitted`, `VendorSubmitted`, `PhotoPicked` | `RegistrationEditing(fieldErrors)`, `Submitting`, `Registered`, `RegistrationFailure` |
| `EventDiscoveryBloc` | `DiscoveryStarted`, `SearchQueryChanged(q)`, `EventSelected(id)` | `EventsLoading`, `EventsLoaded(list)`, `EventsEmpty`, `SearchNoResults`, `EventDetail(event)` |
| `EventManagementBloc` | `CreateRequested(input)`, `StatusChangeRequested(id,status)`, `VendorEventsWatchStarted` | `Editing(fieldErrors)`, `Creating`, `Created`, `VendorEventsLoaded`, `EventFailure` |
| `ApplicationBloc` | `ApplyRequested(eventId)`, `DecideRequested(appId,decision)`, `ApplicationsWatchStarted` | `Applying`, `Applied`, `DuplicateApplication`, `ApplicationsLoaded`, `ApplicationFailure` |
| `AttendanceBloc` | `CheckInRequested(code,loc)`, `CheckOutRequested(code)`, `HistoryWatchStarted` | `LocatingDevice`, `CheckingIn`, `CheckedIn`, `CheckedOut`, `AttendanceFailure(reason)`, `HistoryLoaded` |
| `EarningsBloc` | `EarningsWatchStarted` | `EarningsLoading`, `EarningsLoaded(total, perEvent)`, `EarningsEmpty` |
| `ReportBloc` | `ReportFieldsChanged`, `ReportSubmitted` | `ReportEditing(fieldErrors)`, `ReportSubmitting`, `ReportSubmitted`, `ReportFailure` |
| `AdminBloc` | `VendorApproveRequested(id)`, `VendorRejectRequested(id)`, `ListsWatchStarted`, `MetricsWatchStarted` | `ListsLoaded`, `MetricsLoaded`, `AdminActionFailure`, `EmptyState` |

The role-based router subscribes to `AuthBloc`'s session state to choose the start destination and to block cross-role navigation (R3.1–3.4), invoking `ResolveStartDestination` and `Authorize` use cases.

### Data Layer — Repository Implementations, Data Sources, DTOs, Mappers

For each domain repository interface there is a Firebase implementation that depends on one or more **data sources** (thin wrappers over `FirebaseAuth`, `FirebaseFirestore`, `FirebaseStorage`, `FirebaseMessaging`) and uses **DTOs/mappers** to convert documents to/from entities. The retry policy for writes (R14.6) lives here as a data-layer concern wrapping data-source calls.

```
FirestoreEventRepositoryImpl implements EventRepository {
  final FirestoreEventDataSource ds;                 // returns DocumentSnapshots
  Future<Result<Event, Failure>> create(Event e) =>
      withRetry(3, () => ds.set(EventDto.fromEntity(e).toFirestore()))   // R14.6
        .map((doc) => EventDto.fromFirestore(doc).toEntity());
  Stream<List<Event>> watchActive() =>
      ds.streamActive().map((docs) => docs.map((d) => EventDto.fromFirestore(d).toEntity()).toList());
}
```

A future REST implementation (`RestEventRepositoryImpl`) swaps the data source to a `RestApiDataSource`/`WebSocketDataSource` and the DTO mappers to JSON, returning the same `Event` entities. The `AuthRepository` impl additionally maintains the `authThrottle` record for application-level lockout counting (R1.4, R2.4, R2.5).

### Core / Shared

- **`Result<T, Failure>` (Either)** — railway-style error handling; all use cases and repositories return it. No exceptions cross layer boundaries.
- **`Failure` / `DomainError` hierarchy** — `ValidationFailure(fieldErrors)`, `AuthFailure`, `AuthorizationFailure`, `StateTransitionFailure`, `LocationFailure`, `PersistenceFailure`, `NotFoundFailure`, etc., each with a stable `code`.
- **Dependency injection** — `get_it` + `injectable`. The composition root binds each repository/service interface to one implementation. Backend swap = change these bindings only.
- **Value objects** — `PhoneNumber`, `Money` (fixed-precision decimal), `GeoPoint`, `EventStatus`, `ApplicationStatus`, `ApprovalStatus`, enforcing validity at construction.

## Data Models

Data models are expressed twice: as **pure domain entities** (what use cases and BLoCs consume — no backend types) and as **Firebase DTOs** (how the data layer persists/reads them in Firestore). Mappers (`toEntity`/`fromEntity`, `fromFirestore`/`toFirestore`) bridge them. A future REST backend provides alternative DTOs (`fromJson`/`toJson`) producing the **same** entities.

Domain entities use pure Dart types: `DateTime` (not Firestore `Timestamp`), a `GeoPoint` value object (not Firestore `GeoPoint`), and `Money`/`decimal` for currency. Firebase `Timestamp`/`GeoPoint`/`DocumentSnapshot` appear only inside DTOs/mappers in the data layer.

The field shapes below describe the persisted Firestore document (the DTO). The corresponding domain entity has the same fields with backend-neutral types.

### users/{uid}  →  `AuthUser` entity

```
{
  uid: string,
  role: "student" | "vendor" | "admin",
  phone: string,                 // E.164: country code + national number
  deviceTokens: string[],        // FCM tokens; empty allowed (R13.7)
  createdAt: Timestamp,          // -> DateTime in entity
  updatedAt: Timestamp
}
```

### students/{uid}  →  `Student` entity

```
{
  uid: string,
  fullName: string,              // 1..100
  phone: string,
  gender: "male" | "female" | "other",
  dateOfBirth: Timestamp,        // strictly in the past  (-> DateTime)
  city: string,                  // 1..100
  heightCm: number,              // 50..250
  profilePhotoPath: string,      // Storage reference (JPEG/PNG, <= 5MB)
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### vendors/{uid}  →  `Vendor` entity

```
{
  uid: string,
  fullName: string,              // 1..100
  agencyName: string,            // 1..150
  phone: string,                 // exactly 10 national digits
  city: string,                  // 1..100
  address: string,               // 1..250
  approvalStatus: "Pending" | "Approved" | "Rejected",   // default Pending
  aadhaarOrPan?: string,         // optional
  website?: string,              // optional
  socialLinks?: string[],        // optional
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### events/{eventId}  →  `Event` entity

```
{
  eventId: string,
  vendorId: string,              // owner
  title: string,                 // 1..100
  description: string,           // 1..2000
  date: Timestamp,               // today or future at creation (-> DateTime)
  startTime: Timestamp,
  endTime: Timestamp,            // > startTime
  location: { label: string,    // 1..200
              geo: GeoPoint },   // -> GeoPoint value object
  slots: number,                 // integer 1..10000
  payPerHead: decimal,           // 0.01..9999999.99 (-> Money)
  status: "Active" | "Closed" | "Completed",   // Active on creation
  startCode?: string,            // set when generated
  endCode?: string,              // set when generated
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### applications/{eventId}_{studentId}  →  `Application` entity

```
{
  applicationId: string,         // composite "{eventId}_{studentId}" (dedupe key)
  eventId: string,
  studentId: string,
  status: "Pending" | "Approved" | "Rejected",   // Pending on creation
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### attendance/{eventId}_{studentId}  →  `AttendanceRecord` entity

```
{
  attendanceId: string,          // composite "{eventId}_{studentId}"
  eventId: string,
  studentId: string,
  checkInTime?: Timestamp,
  checkInGeo?: GeoPoint,
  checkOutTime?: Timestamp,
  workingHours?: number,         // hours rounded to 2 dp, set at checkout
  accrued?: boolean,             // set true by EarningsService (idempotency)
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### earnings/{studentId}  →  `Earnings` entity

```
{
  studentId: string,
  total: decimal,                // sum of credited payPerHead, default 0 (-> Money)
  perEvent: { [eventId]: decimal },  // credited amount per completed event
  updatedAt: Timestamp
}
```

### reports/{reportId}  →  `Report` entity

```
{
  reportId: string,
  submitterId: string,
  submitterRole: "student" | "vendor",
  category: "FakeEvent" | "VendorIssue" | "NoShow" | "Misbehavior",
  description: string,           // 1..1000
  createdAt: Timestamp
}
```

### notifications/{notificationId}  →  `Notification` entity

```
{
  notificationId: string,
  recipientId: string,
  type: "ApplicationApproved" | "ApplicationRejected"
      | "EventReminder" | "NewApplication",
  payload: { eventId?: string, applicationId?: string, title: string, body: string },
  deliveryStatus: "Pending" | "Delivered" | "Skipped" | "Failed",
  attemptCount: number,          // 0..3
  lastAttemptAt?: Timestamp,
  createdAt: Timestamp
}
```

### authThrottle/{phone} (auth support, data-layer state)

```
{
  phone: string,
  otpIssuedAt?: Timestamp,
  attemptsForCurrentOtp: number,  // resets on new OTP (R2.5)
  failedCount: number,            // consecutive invalids (R1.4)
  lockedUntil?: Timestamp         // set when locked 900s (R1.4)
}
```

### metrics/global (admin counters, written by MetricsService)

```
{
  totalStudents: number,         // >= 0
  totalVendors: number,          // >= 0
  activeEvents: number,          // >= 0
  completedEvents: number,       // >= 0
  updatedAt: Timestamp
}
```

> Monetary values use a fixed-precision decimal representation (stored as integer paise or a string-decimal) so the `Money` value object treats `payPerHead` and earnings totals as exact decimals, avoiding floating-point drift across any backend.

## Backend Enforcement: Firestore Security Rules Approach (current backend)

Server-side enforcement is a **backend capability**, not a domain concern. The current backend enforces the trust boundary and role-based access with Firestore Security Rules, independently of the client. A future Node.js backend would enforce the **equivalent** invariants server-side (authorization middleware, ownership checks, status-transition guards, server-owned fields), so the guarantees the domain relies on are preserved regardless of backend.

The role is read from `users/{request.auth.uid}.role`.

- **users**: a user may read/write only their own document; `role` is set at registration and not client-mutable afterward (role change requires Admin / trusted backend). `deviceTokens` writable by the owner.
- **students / vendors**: owner may create and read own profile; `vendors.approvalStatus` is **not** client-writable (only Admin / trusted backend), preventing self-approval (R2.9, R6.1–6.3). Admin may read all (R6.4, R6.5).
- **events**: create/update allowed only when `auth.uid == vendorId` AND that vendor's `approvalStatus == Approved` (R5.1, R2.10); `startCode`/`endCode` writable only by the owning vendor; any authenticated user may read Active events (R8.1); Admin may read all (R6.6).
- **applications**: `create` allowed only by the owning student with doc ID `{eventId}_{studentId}` and only when the target event is Active; **create on an existing doc is denied**, enforcing no duplicates (R9.2). Status updates allowed only by the owning event's vendor and only Pending→Approved/Rejected (R5.4, R5.5, R9.3–9.5); students cannot change their own status.
- **attendance**: the owning student may create/update `checkInTime`, `checkInGeo`, `checkOutTime`, `workingHours`; `accrued` is **not** client-writable (trusted backend only), protecting exactly-once earnings.
- **earnings**: read by owning student and Admin; **no client writes** — written only by the trusted `EarningsService` (R11.1, R11.2).
- **reports**: create by Student or Vendor for their permitted categories; read by Admin only (R12.6).
- **notifications**: **no client writes** to delivery fields; created by triggers, delivered by `NotificationService`. Recipients may read their own.
- **metrics**: read by Admin only; written only by `MetricsService`.

Status-transition validity (only Pending applications may move to Approved/Rejected; only Pending vendors may be approved/rejected) is asserted in **both** the domain use cases (for fast, testable feedback) and the backend (Security Rules today, server middleware under Node.js) for defense in depth. Because the guards also live as pure domain logic, they remain backend-independent and property-testable.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

These properties are **backend-agnostic**: they constrain the pure domain logic (use cases, validators, reducers, guards) and therefore hold whether the data layer is backed by Firebase or a future Node.js backend. The following properties were derived from the acceptance criteria via the prework analysis. Redundant criteria were consolidated so each property below provides unique validation value. Criteria classified as INTEGRATION, SMOKE, or pure UI/rendering EXAMPLE/EDGE_CASE are covered by the Testing Strategy section rather than as properties.

### Property 1: OTP acceptance window

*For any* issued OTP with a delivery time and any submitted code at any time, verification succeeds if and only if the submitted code equals the issued code AND the submission occurs within 300 seconds of delivery; otherwise the attempt is rejected and the session remains unauthenticated.

**Validates: Requirements 1.1, 1.2, 1.3, 2.3**

### Property 2: OTP attempt counting and lockout

*For any* sequence of OTP submission attempts for a single phone number, after 5 consecutive invalid submissions the phone is locked (student: blocked for 900 seconds; vendor: current OTP invalidated and a new OTP required) and no further attempts against the invalidated OTP are accepted until the lock clears or a new OTP is issued.

**Validates: Requirements 1.4, 2.4, 2.5**

### Property 3: Phone number format validation

*For any* input string, phone validation accepts it if and only if it matches the required format — for the student path a country code followed by a 10-digit national number, and for the vendor path exactly 10 numeric digits — and rejects all other strings (including empty) without issuing an OTP.

**Validates: Requirements 1.5, 2.2**

### Property 4: Student profile validation completeness

*For any* student profile input, validation passes if and only if every required field is present and within bounds (Full Name 1–100 chars, Date of Birth strictly in the past, City 1–100 chars, Height 50–250 cm, Gender present, Profile Photo present); when it fails, the returned error list contains exactly the set of fields that are missing or out of bounds.

**Validates: Requirements 1.6, 1.7**

### Property 5: Profile photo validation

*For any* uploaded photo described by size and MIME type, validation accepts it if and only if the size is 5 MB or smaller AND the format is JPEG or PNG; otherwise it is rejected.

**Validates: Requirements 1.8**

### Property 6: Vendor profile validation completeness

*For any* vendor profile input, validation passes if and only if all required fields are present and within bounds (Full Name 1–100, Agency Name 1–150, Phone exactly 10 digits, City 1–100, Address 1–250); when it fails, the error list contains exactly the non-conforming fields, and any provided optional fields never cause rejection.

**Validates: Requirements 2.6, 2.7, 2.8**

### Property 7: Vendor event-creation authorization

*For any* vendor, the system permits event creation if and only if the vendor's approval status is Approved; Pending or Rejected vendors are prevented from creating events.

**Validates: Requirements 2.10, 5.1**

### Property 8: Role-based navigation visibility

*For any* assigned role value, the set of visible navigation destinations equals exactly that role's destinations and hides the destinations of the other two roles; for a missing or unrecognized role value, no role-specific destinations are shown.

**Validates: Requirements 3.1, 3.3**

### Property 9: Feature authorization

*For any* pair of (role, feature), access is granted if and only if the feature belongs to that role; otherwise the feature does not load and the user is returned to the role's default destination with the session unchanged.

**Validates: Requirements 3.2**

### Property 10: Owner-scoped and status-scoped list filtering

*For any* collection of events, applications, and attendance records, each list view returns exactly the records matching its filter: event discovery returns exactly the events with status Active (independent of remaining slots); a vendor's Manage Events returns exactly events owned by that vendor; an event's applicant list returns exactly applications for that event; an event's attendance view returns exactly attendance records for that event; and the student dashboard sublists return exactly the Active events, the events the student applied to, and the events whose application is Approved.

**Validates: Requirements 4.1, 4.2, 4.3, 4.4, 5.2, 5.3, 5.7, 8.1**

### Property 11: Vendor event-access ownership

*For any* vendor and event, access to the applicant list, attendance view, or attendance-code generation is permitted if and only if the event's vendorId equals the vendor; otherwise the action is denied.

**Validates: Requirements 5.9**

### Property 12: Event validation

*For any* event creation input, validation passes if and only if all required fields are present and non-empty AND the Date is the current or a future calendar date AND End Time is later than Start Time AND Slots is an integer in [1, 10000] AND Pay_Per_Head is in [0.01, 9999999.99]; when it fails, the error list contains exactly the missing or invalid fields, and a passing input yields an event with status Active.

**Validates: Requirements 7.1, 7.2, 7.3, 7.4**

### Property 13: Event status enum guard

*For any* requested status value, changing an event's status succeeds if and only if the value is exactly one of {Active, Closed, Completed}; any other value is rejected and the existing status is retained.

**Validates: Requirements 7.5**

### Property 14: Active-event search

*For any* search query of 1–100 characters and any collection of events, the search returns exactly the events with status Active whose Title or Location contains the query as a substring ignoring letter case.

**Validates: Requirements 8.3, 8.4**

### Property 15: Application creation and event-active guard

*For any* student and event with no existing application from that student for that event, applying succeeds if and only if the event status is Active, creating exactly one application linked to that student and event with status Pending; if the event is not Active, the application is rejected and no record is created.

**Validates: Requirements 8.6, 8.7, 9.1**

### Property 16: No duplicate applications

*For any* student and event, at most one application record exists; a second application attempt for the same student and event is rejected and leaves the existing application unchanged.

**Validates: Requirements 9.2**

### Property 17: Application status transition

*For any* application and any decide action by the owning event's vendor, the status changes from Pending to Approved or Pending to Rejected as chosen; if the application's status is not Pending, the action is rejected and the status is left unchanged.

**Validates: Requirements 5.4, 5.5, 5.8, 9.3, 9.4, 9.5**

### Property 18: Vendor approval status transition

*For any* vendor and any admin decision, the approval status changes from Pending to Approved or Pending to Rejected as chosen; if the status is not Pending, the action is rejected and the status is left unchanged.

**Validates: Requirements 6.1, 6.2, 6.3**

### Property 19: Admin metrics counting

*For any* collection of students, vendors, and events, the metrics equal the cardinalities of the matching subsets — Total Students = number of students, Total Vendors = number of vendors, Active Events = number of events with status Active, Completed Events = number of events with status Completed — and each count is an integer of 0 or greater.

**Validates: Requirements 6.7**

### Property 20: Attendance check-in decision

*For any* submitted Start_Code and device location for an event, check-in records a check-in timestamp if and only if the code matches the event's Start_Code AND the device location is obtained within 30 seconds AND the location is within 100 meters of the event location AND no check-in is already recorded; in every rejecting case (code mismatch, location too far, location unavailable, or already checked in) the existing attendance record is left unchanged.

**Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5**

### Property 21: Attendance check-out decision

*For any* submitted End_Code, check-out records a check-out timestamp if and only if the code matches the event's End_Code AND a check-in time is already recorded; otherwise the check-out is rejected and the existing record is left unchanged.

**Validates: Requirements 10.6, 10.7, 10.8**

### Property 22: Working-hours computation

*For any* attendance record with a check-in time no later than its check-out time, the stored working hours equal the difference between check-out and check-in expressed in hours rounded to 2 decimal places, and the value is non-negative.

**Validates: Requirements 10.9**

### Property 23: Exactly-once earnings accrual

*For any* attendance record that becomes completed (both check-in and check-out recorded), running accrual any number of times increases the student's Estimated_Earnings total by exactly the event's Pay_Per_Head once and no more.

**Validates: Requirements 11.1, 11.2**

### Property 24: Earnings total integrity

*For any* collection of a student's completed attendance records, the Estimated_Earnings total equals the sum of the per-event credited Pay_Per_Head amounts, and is 0 with an empty per-event list when there are no completed records.

**Validates: Requirements 11.4, 11.5**

### Property 25: Report validation

*For any* (submitting role, category, description), report submission succeeds if and only if the category is permitted for the role (Student → {FakeEvent, VendorIssue}; Vendor → {NoShow, Misbehavior}) AND the description length is in [1, 1000]; on success the stored report contains the submitter identity, category, description, and a creation timestamp, and on failure the error identifies the invalid category or description.

**Validates: Requirements 12.1, 12.2, 12.3, 12.4**

### Property 26: Notification creation on triggering events

*For any* application creation or status change, exactly one notification of the correct type is created for the correct recipient: creation → NewApplication to the owning vendor; transition to Approved → ApplicationApproved to the applicant; transition to Rejected → ApplicationRejected to the applicant.

**Validates: Requirements 13.1, 13.2, 13.4**

### Property 27: Event-reminder selection

*For any* collection of events with approved applications and any current time, the set of reminder recipients equals exactly the students with an Approved application for events whose start time falls within the 24-hour reminder window and for which a reminder has not already been sent.

**Validates: Requirements 13.3**

### Property 28: Notification delivery retry, skip, and failure

*For any* notification and any sequence of FCM delivery outcomes: if the recipient has no registered device token, delivery is skipped with no error and no retries; otherwise the number of delivery attempts never exceeds 3, successive attempts are spaced at least 60 seconds apart, and the status is recorded as Failed (with the triggering data preserved) only after all 3 attempts fail.

**Validates: Requirements 13.6, 13.7, 13.8**

### Property 29: Write retry atomicity

*For any* simulated sequence of write failures, the write wrapper retries at most 3 times; if all attempts fail it returns an error to the caller and commits no partial data, and if any attempt succeeds the data is committed exactly once.

**Validates: Requirements 14.6**

## Error Handling

The system uses a layered error strategy expressed through the shared `Result<T, Failure>` type. Every use case and repository returns either a value or a typed `Failure { code, message, fieldErrors? }`. BLoCs map failure codes to states/messages and preserve form input on validation failures. Because errors are values (not exceptions) and the `Failure` hierarchy lives in the backend-agnostic core, error handling is identical across backends.

### Error Categories and Handling

| Category | Examples | Handling | Owning layer |
|---|---|---|---|
| Validation | Invalid phone, missing profile/event fields, bad photo, bad report | Reject before any write; return per-field errors; retain entered values (R1.7, R2.8, R7.2, R12.3, R12.4) | Domain use case |
| Authentication | Wrong/expired OTP, locked phone | Return invalid/expired/locked error; keep unauthenticated state (R1.3, R1.4, R2.4, R2.5) | Domain use case |
| Authorization | Wrong-role feature, non-owner vendor action, unapproved vendor create | Deny, message, return to default destination; no data change (R3.2, R5.9, R2.10) | Domain use case + backend |
| State/transition | Approve non-Pending application/vendor, duplicate application, double check-in, check-out without check-in | Reject, leave record unchanged, return state-specific error (R5.8, R6.3, R9.2, R9.5, R10.5, R10.8) | Domain use case + backend |
| Location | GPS unavailable within 30s, out of range | Reject check-in with the specific reason; record unchanged (R10.3, R10.4) | Domain use case |
| Persistence | Backend write failure | Retry up to 3 times; on total failure return error and commit no partial data (R14.6) | Data layer (repository) |
| Read failure | Dashboard/list load failure | Show "could not load" message; leave stored data unchanged (R4.7) | Data layer → BLoC |
| Notification delivery | FCM failure, missing token | Retry up to 3 (≥60s apart), skip when no token, record Failed after exhaustion, preserve trigger data (R13.6–13.8) | `NotificationService` (backend) |

### Cross-cutting Rules

- **Atomicity**: Multi-document operations (e.g., create `users` + `students`/`vendors`, accrue earnings + mark `accrued`) run inside backend transactions/batches so no partial state is committed on failure (R14.6). Under Firebase these are Firestore transactions; under Node.js they are DB transactions exposed through the same repository contract.
- **Idempotency**: Trusted services use idempotency markers (`accrued` flag, notification `deliveryStatus`/`attemptCount`) so retried invocations do not duplicate effects (R11.2, R13.6). The pure accrual and retry reducers in the domain make this property-testable independent of backend.
- **Defense in depth**: State guards (status==Pending, ownership, vendor approved) are enforced in both the domain use cases and the backend (Security Rules today; server middleware under Node.js) so a compromised or buggy client cannot violate invariants.

## Testing Strategy

The system uses a dual approach: property-based tests for universal invariants in the **domain layer**, and example/bloc/integration/smoke tests for everything else. Clean Architecture makes this straightforward — pure domain logic is tested with no mocks, use cases and BLoCs are tested with mocked repositories, and the data layer is tested against the (replaceable) backend.

### Domain Property-Based Testing

PBT applies because the core logic — input validation, search filtering, working-hours and GPS-distance computation, status-transition guards, exactly-once accrual, counting, and retry state machines — consists of pure functions in the domain layer with large input spaces and well-defined input/output behavior. These tests are backend-independent and never touch Firebase or a future REST client.

- Use an established PBT library for Dart (a generator-based QuickCheck-style package); for any trusted-service logic implemented in TypeScript (current Cloud Functions / future Node.js), use `fast-check`. Do not implement PBT from scratch.
- Each correctness property (1–29) is implemented as a **single** property-based test.
- Each property test runs a **minimum of 100 iterations**.
- Each test is tagged with a comment referencing its design property in the format:
  **Feature: eventxindia-platform, Property {number}: {property_text}**
- Logic under test is structured as pure functions/use cases (validators, `distanceMeters`, `workingHours`, `SearchActiveEvents`, transition guards, accrual reducer, retry reducer), so generators exercise them in-memory.

Generators must cover edge cases identified in prework, including: empty and whitespace strings, boundary values for all numeric bounds (50/250 cm, 1/10000 slots, 0.01/9999999.99 pay, 1/1000 char descriptions), past/today/future dates, distances exactly at 100 m, equal check-in/check-out times, empty data sets (empty-state indications), invalid/unknown roles, missing device tokens, and non-ASCII/special characters in searchable fields.

### Use Case and BLoC Unit Tests (mocked repositories)

- **Use cases** are unit-tested with **mocked repository/service interfaces**, verifying orchestration: that the right repository methods are called, that failures map to the correct `Failure`, and that guards short-circuit before any persistence call. Because use cases depend only on abstract interfaces, these tests are fully backend-agnostic.
- **BLoCs** are tested with `bloc_test` using **mocked use cases**, asserting the Event→State sequences (e.g., `OtpSubmitted` → `[Verifying, Authenticated]` or `[Verifying, AuthFailure]`; duplicate apply → `[Applying, DuplicateApplication]`). This validates presentation behavior without any backend.

### Example-Based Unit Tests

For concrete behaviors that are not universal:
- Vendor created with approvalStatus = Pending (R2.9); optional vendor fields stored (R2.7).
- Unauthenticated session resolves to the auth screen (R3.4).
- Event detail and report detail views render all required fields (R8.5, R12.6).
- Earnings total renders as a monetary amount (R11.3).
- Read-failure path shows the error and mutates nothing (R4.7).

### Mapper / DTO Tests (round-trip)

- For each DTO, a round-trip test: `dto.toEntity()` then back to DTO preserves all domain fields; `fromFirestore`/`toFirestore` (and future `fromJson`/`toJson`) preserve data. This protects the abstraction boundary and is the contract a future `RestXxxRepositoryImpl` must also satisfy.

### Integration Tests (1–3 examples each)

For external-service wiring and persistence (behavior does not vary meaningfully with input):
- OTP request triggers Firebase Auth delivery (R2.1) and a valid profile photo is stored in Firebase Storage with a reference on the profile (R1.9).
- Writes land in the correct Firestore collections within the latency budget: `users`, `students`, `vendors`, `events`, `applications`, `attendance`, `earnings`, `reports`, `notifications` (R6.4–6.6, 6.8, 7.6, 9.6, 10.10, 12.5, 14.1–14.5).
- Notification dispatch calls FCM (R13.5) — verified with mocks for the retry logic and with a real/emulated channel for end-to-end.
- Security Rules tests (using the Firestore emulator) verifying: students cannot write `earnings` or `accrued`; vendors cannot set their own `approvalStatus`; a create on an existing application document is denied (dedupe); non-owner vendors cannot read another vendor's event applications. (When the Node.js backend replaces Firebase, these become server-side authorization/integration tests asserting the equivalent rules.)

### Smoke Tests

- The build excludes any wallet, withdrawal, or payment-processing surface (R11.6) — verified by absence checks / configuration review.

### Test Environment

Trusted-service logic (accrual, notification creation/delivery, reminders, metrics) is unit- and property-tested in isolation with mocked backends, and validated end-to-end against the Firebase Emulator Suite (Auth, Firestore, Functions) before deployment. Because this logic sits behind `EarningsService` / `NotificationService` / `MetricsService`, the same test suite carries over to a Node.js implementation by pointing the integration layer at the new backend.
