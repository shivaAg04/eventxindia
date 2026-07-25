# EventXIndia — Feature Guide

A plain-language guide to what the app does, organised by user role, plus pointers
to where each feature lives in the code. This is a functional overview — for the
architecture and the authoritative spec see [CLAUDE.md](CLAUDE.md) and
`.kiro/specs/eventxindia-platform/`.

---

## Roles at a glance

The app digitises an offline event-staffing process for three roles. After phone
OTP sign-in, a user is routed to their role's home screen.

| Role | Home | What they do |
|------|------|--------------|
| **Student** | Student dashboard | Discover events, apply, and record attendance (check in / out) |
| **Vendor** | Manage events | Create events, approve applicants, generate attendance codes, watch attendance |
| **Admin** | Admin dashboard | Approve vendors, browse users/events, view metrics |

Role-based navigation lives in [lib/routing/app_destination_screen_factory.dart](lib/routing/app_destination_screen_factory.dart).

---

## The event lifecycle (how a shift actually flows)

```
Vendor creates event ──► Student applies ──► Vendor approves ──►
Vendor shares check-in code ──► Student checks in (enters code) ──►
Vendor shares check-out code ──► Student checks out (enters code) ──►
Working hours computed ──► Earnings accrued (trusted backend)
```

Each step maps to a feature below.

---

## Student features

The student dashboard has **three** bottom-nav destinations:
**Active**, **My events**, and **Profile**.
Code: [student_dashboard_screen.dart](lib/features/events/presentation/screens/student_dashboard_screen.dart)

### 1. Active — discover & apply

- Streams the set of currently-active events; past-dated events are hidden.
- Search by title/location, sort (date / pay), and filter by date range.
- Each event shows as a card with seats-left and pay. If the student has
  **already applied**, the card shows a green **"Applied"** badge (a persistent
  check, not just a reaction to tapping).
- Tapping a card opens the **event detail**; the "Apply to join" button becomes a
  disabled **"Applied"** state if they've already applied or the event is full.

Code: [student_active_events_screen.dart](lib/features/events/presentation/screens/student_active_events_screen.dart),
[event_card.dart](lib/features/events/presentation/widgets/event_card.dart),
[event_detail_screen.dart](lib/features/events/presentation/screens/event_detail_screen.dart)

### 2. My events — applications + attendance in one place

This is the merged view. **One card per event the student applied to**, combining
the application status *and* the attendance actions.

- **Two combinable filters** at the top:
  - **Status**: All / Pending / Approved / Rejected
  - **Event**: All / Active / Inactive (past-dated events are "Inactive")
- **Each card** shows:
  - Event title + detail (location · pay · date)
  - **Application status badge** — amber *Pending*, green *Approved*, red *Rejected*
  - For **approved** events: **Check-in** and **Check-out** status lines (time once
    done, otherwise "Pending"), plus **Check in** / **Check out** buttons.
    - *Check out* is disabled until the student has checked in.
    - A **working-hours pill** appears once the shift is completed.
  - For non-approved events: a short "awaiting approval / not approved" note (no
    attendance actions).

Code: [student_events_screen.dart](lib/features/events/presentation/screens/student_events_screen.dart)

### 3. Attendance — the code-based check-in / check-out

Attendance is **code-driven**: the vendor generates a code and shares it; the
student types it in.

- **Check in**: enter the vendor's **start code**. *(Location/GPS verification is
  currently disabled — see "Configuration notes".)*
- **Check out**: enter the vendor's **end code**. Requires a prior check-in.
- On check-out the **working hours** are computed and stored.

Code: [check_in_screen.dart](lib/features/attendance/presentation/screens/check_in_screen.dart),
[check_out_screen.dart](lib/features/attendance/presentation/screens/check_out_screen.dart),
use cases [check_in.dart](lib/features/attendance/domain/usecases/check_in.dart) /
[check_out.dart](lib/features/attendance/domain/usecases/check_out.dart)

### 4. Profile

The student's profile data. Code: [student_profile_screen.dart](lib/features/profile/presentation/screens/student_profile_screen.dart)

---

## Vendor features

### Manage events (home)

- Two tabs: **Active** and **Closed / Completed** (an active event whose date has
  passed is shown as completed automatically).
- Each event row → open the **applicant list** to approve/reject, or the
  **attendance** screen; a menu changes the event's status. A FAB creates a new event.

Code: [manage_events_screen.dart](lib/features/events/presentation/screens/manage_events_screen.dart)

### Create event

A sectioned form — **Event details**, **Schedule**, **Location**, **Capacity & pay**:
title, description, date, start/end time, venue label, slots, pay-per-head.
*(Latitude/longitude inputs were removed since GPS attendance is disabled; a
placeholder coordinate is stored.)*

Code: [create_event_screen.dart](lib/features/events/presentation/screens/create_event_screen.dart)

### Approve applicants

Per-event list of student applications; approve or reject each (only while Pending).
Approving fills a seat and counts toward capacity.

Code: [applicant_list_screen.dart](lib/features/applications/presentation/screens/applicant_list_screen.dart),
use case [decide_application.dart](lib/features/applications/domain/usecases/decide_application.dart)

### Attendance (codes + live roster)

- **Generate codes**: a **Start code** (check-in) and an **End code** (check-out),
  shown in separate, labelled slots so the vendor always knows which to share.
- **Two tabs — Check-in / Check-out** — each listing every **enrolled (approved)
  student**, joined with their attendance records, so the vendor sees who has
  checked in / out and when. A per-tab filter narrows to **All / Done / Pending**.

Code: [vendor_attendance_screen.dart](lib/features/applications/presentation/screens/vendor_attendance_screen.dart),
use case [generate_attendance_code.dart](lib/features/attendance/domain/usecases/generate_attendance_code.dart)

---

## Admin features

- Approve/reject vendors; browse students, vendors, and events; view aggregate metrics.

Code: [admin_lists_screen.dart](lib/features/admin/presentation/screens/admin_lists_screen.dart),
[admin_metrics_screen.dart](lib/features/admin/presentation/screens/admin_metrics_screen.dart)

---

## Earnings (trusted backend)

When an attendance record is completed (both check-in and check-out present), a
Cloud Function credits the student's earnings exactly once and marks the record
`accrued`. The client never writes earnings or the `accrued` flag.

Code: `functions/src/earnings/accrueEarnings.ts`

---

## Configuration notes

- **Attendance location check is disabled.** The GPS-presence and 100 m radius
  guards on check-in are gated behind a single toggle:
  `kAttendanceLocationCheckEnabled` in
  [check_in.dart](lib/features/attendance/domain/usecases/check_in.dart). Set it to
  `true` to re-enable location enforcement (the student check-in screen will then
  acquire GPS, and the create-event form should collect real coordinates again).

---

## Where the data lives

- **Applications**: `applications/{eventId}_{studentId}` — status + snapshot of the
  applicant's profile and the event's display fields.
- **Attendance**: `attendance/{eventId}_{studentId}` — check-in/out times, working
  hours, and the backend-owned `accrued` flag.
- **Events**: `events/{eventId}` — includes `startCode` / `endCode` for attendance.

Firestore security rules: [firestore.rules](firestore.rules).
