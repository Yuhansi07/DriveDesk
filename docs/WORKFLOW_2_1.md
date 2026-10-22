# DriveDesk Pro 2.1 — linked workflow (interview implementation)

## Why
The first project had separate buttons for booking, AI matching, pricing, payments and inspections. Version 2.1 joins them into one user flow. Screenshots of the wizard and rental desk are at `demo/new-rental-preview.png` and `demo/rental-desk-preview.png`.

## Browser workflow
1. Login; **New rental** → select a known customer (use Customers menu to add one first).
2. Select pickup and return dates, budget, category and seats. Optionally run recommendation ranking. Vehicle and dates are checked with `/api/availability`.
3. Get `/api/smart/pricing`, compare base rate vs recommendation, explicitly choose recommended rate (off by default).
4. Review → `POST /api/bookings` (pending), immediately navigate to **Rental desk** at booking ID.
5. Confirm pending booking; save pickup inspection note/photo (`POST /api/inspections` phase `pickup`).
6. Generate pickup token and verify it (`POST /api/bookings/:id/qr`, then `/handover`) to activate.
7. Save return inspection note/photo (phase `return`).
8. Collect payment (`POST /api/payments`) and verify remaining balance via `GET /api/bookings/:id/workflow`.
9. Complete (`PATCH /api/bookings/:id/status`, status `completed`) once full balance is settled.

## Server rules (not only UI validation)
- A vehicle is not double-booked for overlapping half-open date ranges.
- An expired customer license blocks booking.
- Pickup QR issuance requires a pickup inspection. Handover requires confirmed status, valid one-time QR code AND pickup inspection.
- Return inspection requires active status.
- Completion requires return inspection AND outstanding balance <= LKR 0.009.
- One-time QR code hash and expiration are stored server-side.
- Payment cannot exceed the booking contract value.
- `GET /api/bookings/:id/workflow` returns data needed for status checklist and next permitted action.

## Scope / limitations
- This is an interview-grade source project, **not** a certified production rental system.
- The browser uses a secure QR token fallback; an actual QR graphic is rendered in Flutter.
- OCR, GPS tracker integration and trained YOLO damage detection require external services/models/hardware.
- Historical demo data is synthetic; predictions are illustrative, not validated business models.
- Flutter SDK and PostgreSQL services were unavailable for compile/integration verification here.
- **Browser UI QA screenshots** were captured using a scripted fixture API; Node REST/API logic was tested separately end-to-end.
