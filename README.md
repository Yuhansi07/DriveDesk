# DriveDesk Pro v2.8 — Modern Customer Portal

**New:** A role-scoped Flutter Customer Portal with Home, Explore cars, My rentals, Updates, and My profile. Booking cancellation, profile editing, own payment statement/history, customer notifications, and safe tracker status are connected to the existing Node.js/SQLite API. Interview-only demo payments can be enabled locally; **not a real payment gateway**.

**Get started:** Run `RUN_DRIVEDESK_WINDOWS.bat` in the inner `DriveDesk_Pro` directory, then open `http://localhost:8080` and log in as `customer@drivedesk.local` / `Customer@12345`. For all other roles, see `docs/USER_ROLES_AND_DEMO_LOGINS.md`.

**Read [Customer Portal v2.8 guide](docs/CUSTOMER_PORTAL_V28.md)** for actions, security, setup, demo script and limitations.

**Tested:** Node API tests: `npm test` (20/20). Flutter code was statically checked, but **could not be compiled in this environment**; validate with `cd flutter_app`, `flutter pub get`, `flutter analyze` and `flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://127.0.0.1:3000`.

---

# DriveDesk Pro v2.7 — Seven Role Workspaces

**Full account coverage:** Administrator, Operations Manager, Rental Agent, Fleet Officer, Finance Officer, Driver, and Customer. Includes 8 seeded local demonstration logins (legacy staff retained), Team & Access CRUD, role-specific Flutter navigation, driver-job assignments, and a scoped customer booking portal.

**[Read all demo login credentials and the full permissions matrix](docs/USER_ROLES_AND_DEMO_LOGINS.md)** before testing. Local demo passwords are **not safe for deployment**. Keep `SEED_DEMO=0` in production.

Run on Windows: `RUN_DRIVEDESK_WINDOWS.bat` from the `DriveDesk_Pro` root; or `npm start`, then Flutter web on port 8080. If a port is occupied use `CHECK_PORTS_WINDOWS.bat`. Backend tests: `npm test` (18 passed). Flutter compile is unverified in the packaging environment and should be checked locally with `flutter analyze` and `flutter test`.

---

# DriveDesk Pro 2.5 — Compact Tools UI

The original rental system is unchanged: this release simplifies **More tools**, where large text-heavy accordion panels made discovery difficult.

- **Bookings / Vehicles / Insights** are compact selectable tabs: just one category shown at a time.
- **Icon-first cards** have a one-line purpose. Click a card to open its real feature.
- On the Flutter frontend each card opens the existing tool screen; in the browser backup, a card unfolds the actual form.
- OCR requires a supported engine, damage detection requires a trained model, location demos are simulated; all remain clearly identified and do not fabricate results.
- Pricing and recommendations remain integrated in **New rental**. QR/inspection/payment processes and backend validation are preserved.
- Floating success/error feedback from v2.4 remains unchanged.

**Run:** Open inner `DriveDesk_Pro` folder; ensure no old process is using ports 3000/8080; run `RUN_DRIVEDESK_WINDOWS.bat` or use `npm start` plus Flutter from `flutter_app`:

```powershell
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Demo credentials: `admin@drivedesk.local` / `Demo@12345`. Backup UI: `http://127.0.0.1:3000/demo/`.

**Validation:** `npm test` passes. `node --check demo/app.js` passes. Flutter SDK is not installed in this environment: validate with `flutter analyze` and `flutter run` on your Windows machine. The compact browser layout has been previewed statically; not a claim of compiled Flutter output.

---

# DriveDesk Pro 2.4 — Guided Experience Edition

**Purpose:** Make the smart capabilities useful at the exact point of the rental journey, not as a wall of AI buttons. This is an enhancement to the **same DriveDesk project**, not an added application.

## User journey

1. **Dashboard:** Next-best-action guidance, upcoming rentals, quick access to trends/service reminders.
2. **New rental:** Select customer → vehicle + dates → optional automatic recommended matches → backend availability check → automatically calculated quote → staff chooses recommended/standard price → create booking.
3. **Rental desk:** Confirm → pickup inspection → QR handover → active rental → return inspection → outstanding payment → complete. Existing backend gates stay in place.
4. **Vehicles:** Maintenance/insurance rules are linked from fleet management.
5. **Customers:** Optional license OCR is offered during customer management, with a requirement to review extracted data.
6. **Bookings:** Unusual-pattern review is linked from the booking screen; flags are not fraud findings.
7. **Advanced utilities:** Moved to less-prominent **More tools** with grouped, expandable sections for optional standalone demonstrations.

## Feedback after actions

Floating green/red feedback gives a result **only after the API confirms success** (or an error after rejection). Booking creation, confirmation, inspection, handover, payment, completion, vehicle/customer saves, and reminder checks explain the **next action**. This is a UI notification, not a Windows desktop system notification.

## Honest AI boundaries

- Vehicle matching is content-based ranking; a quote may be trained regression **only when enough history exists**, otherwise a rules fallback. The user retains final price approval.
- Maintenance and risk flags are explainable business rules, not validated predictive failure/fraud models.
- OCR requires supported ML Kit/Tesseract setup; damage analysis requires separately trained YOLO weights; GPS hardware is not included. A simulated location is clearly marked simulated.
- The Q&A assistant is database-grounded rules, **not** a generative LLM.

## Run

1. Extract ZIP and open the nested `DriveDesk_Pro` folder (the one with `package.json`).
2. Close old backend / Flutter processes on ports 3000 and 8080.
3. Windows: double click `RUN_DRIVEDESK_WINDOWS.bat`, or run it from PowerShell: ` .\RUN_DRIVEDESK_WINDOWS.bat `.
4. Open `http://localhost:8080` once Flutter launches. Backend: `http://127.0.0.1:3000`.
5. Demo credentials: `admin@drivedesk.local` / `Demo@12345`.
6. Backend-only/browser backup: `npm start` and `http://127.0.0.1:3000/demo/`.

## Tests

Run `npm test` from `DriveDesk_Pro`. Node/API integration plus source-contract tests pass in the packaging environment. **Flutter SDK is not present in the packaging environment**, so run `cd flutter_app`, `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://127.0.0.1:3000` on Windows. Flutter rendering and device-dependent integrations are **not** claimed as compiled/validated here. Keep a backup of `data/drivedesk-pro.db` before changing versions.

---

# DriveDesk Pro 2.4 — Unified Fleet Management

**One application, one API, one rental database.** The original CarZone dark/teal styling was brought into **DriveDesk itself**. It is **not** a second standalone project. This is a demonstration/portfolio application, not an audited production rental platform.

## Quickest way to run on Windows

1. Extract the ZIP and open the **inner `DriveDesk_Pro` folder** in VS Code. You must see `package.json` in the Explorer.
2. Ensure Node.js (22.13 or newer) and Flutter are installed. To check: `node -v` and `flutter --version`.
3. Double-click **`RUN_DRIVEDESK_WINDOWS.bat`** from that folder. The script launches separate Node.js and Flutter terminals.
4. Keep both terminal windows open. Flutter's first build may take time. Navigate to **http://localhost:8080**.
5. Demo login: `admin@drivedesk.local` / `Demo@12345`.

If a port is occupied from an earlier DriveDesk launch, close the old server terminal (Ctrl+C) before starting this one. After an update, stop the old Flutter session and hard refresh Chrome with Ctrl+Shift+R.

### Manual launch (VS Code PowerShell)

Terminal 1 — in `DriveDesk_Pro` root:

```powershell
npm start
```

Terminal 2 — in the **same root**:

```powershell
.\RUN_FLUTTER_WINDOWS.bat
```

Or, to run Flutter manually:

```powershell
cd flutter_app
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

If you have not previously generated Flutter platform scaffolding, run this in `flutter_app` before `flutter pub get`:

```powershell
flutter create --project-name drivedesk_pro --platforms=windows,android,web .
```

**Browser-only fallback** (no Flutter required): run `npm start` and visit **http://127.0.0.1:3000/demo/**. Browser UI now uses a dark/teal stylesheet as well. This is a secondary interface to the **same** backend, not an unrelated application.

## Modules and actual workflow

- **Dashboard** — statistics, recent rental activity, shortcuts to New Rental/Fleet/Rental Desk.
- **New rental wizard** — customer → vehicle/dates/availability → suggested pricing → review → pending booking.
- **Rental desk** — confirm reservation → pickup inspection → QR handover → active rental → return inspection → payment settlement → complete. Back-end checks enforce prerequisites.
- **Explore fleet** — visually browse the same registered vehicles, view details, save favorites in the current UI session, submit a booking to the real Node API. Pictures are clearly labelled **illustrative** (the supplied reference files do not match the actual seeded fleet).
- **Vehicles / Customers / Bookings / Payments** — shared backend CRUD/transactions.
- **More tools** — advisory pricing/recommendations/anomalies, historical fallback demand forecast, rule-based Q&A, optional OCR/damage ML, consent-based GPS logging.
- **Alerts** — insurance, return, and service reminders.

## Architecture

```text
DriveDesk Flutter web / mobile / desktop (dark + teal UI)
     └── HTTP JSON REST API
          └── Node.js native HTTP backend (port 3000)
               ├── SQLite (demo database in data/)
               ├── Booking/payment/inspection/QR workflow
               ├── Smart pricing, recommendations, anomalies, reminders
               └── Optional OCR and trained YOLO inference services
```

Flutter web uses port 8080. PostgreSQL schema lives in `sql/postgres.sql`, but SQLite is the default and is what the demo runs. To use PostgreSQL in production requires setting up the DB and testing migrations/driver separately. WAMPServer is not needed.

## Design implementation

| File | Responsibility |
| --- | --- |
| `flutter_app/lib/drive_theme.dart` | Consistent Material dark colors, cards, fields, buttons and compact accessible date-range selection dialog |
| `flutter_app/lib/main.dart` | Unified authenticated navigation, responsive dark sidebar, login and dashboard shell |
| `flutter_app/lib/screens.dart` | Business dashboard, CRUD, smart tools with shared dark theme |
| `flutter_app/lib/rental_flow.dart` | Booking wizard and enforced rental workflow UI |
| `flutter_app/lib/carzone_ui.dart` | Fleet explorer component, backed by DriveDesk API and booking database |
| `demo/modern.css` | Matching browser demo styling without changing its API behavior |

The full-screen calendar shown in the previous screenshots has been replaced with a constrained dual-calendar dialog on wide screens and one-calendar-at-a-time view on narrow screens.

## Quality checks

```powershell
npm test
cd flutter_app
flutter pub get
flutter analyze
flutter test
```

**Verified here:** Node API/business logic and UI static contract tests **13/13 passed**. Dart delimiter structure was statically checked. **Not verified here:** Flutter/Dart compilation, on-device permissions, graphical layout on a real Flutter runtime, PostgreSQL migrations. The Flutter SDK was not available in the packaging environment. Please run `flutter analyze` and `flutter test` locally. Report exact compiler errors rather than claiming it was compiled.

## ML, location, and photo accuracy

- **Smart pricing** — regression where enough data exist; rule fallback is labelled.
- **Vehicle ranking** — explains matching rules; not a trained deep-learning recommender.
- **Anomalies** — rules/statistical review flags, not automatic fraud judgments.
- **Demand forecast** — labelled historical baseline when no robust model exists.
- **Fleet Q&A** — rule-based database-backed assistant, not an LLM.
- **Damage detection** — requires a separately trained YOLO model/weights; an offline status is expected otherwise.
- **License/plate OCR** — requires supported mobile ML Kit or optional installed backend Tesseract.
- **GPS** — mobile/browser device coordinates are not automatically the vehicle's location. Simulated points are explicitly marked; live fleet tracking needs hardware and consent.
- **Car photos** — sample reference photos are deliberately labelled ILLUSTRATIVE; they are not claims of the actual cars' appearance.

## Interview demonstration

1. Log in and open Dashboard.
2. Use New Rental to select a customer and vehicle, check dates, and review suggested price.
3. Confirm the booking in Rental Desk.
4. Complete pickup inspection; generate/verify QR; record vehicle handover.
5. Record return inspection and any remaining payment, then mark rental completed.
6. Explore Fleet and More tools as secondary capabilities. Describe optional integrations honestly.

See `docs/CARZONE_INTEGRATION.md` for design and data-link detail. Other API endpoints: `docs/API.md`.

## Data safety

This is a local demo. Do not put real customer/license info into seed data. Do not publish a real database file, `.env` secrets, or demo credentials as production passwords. Real deployments require secure authentication, image retention policy, proper backup and role enforcement, and validated integrations.

## v2.6 — Team accounts and access control

**Users** are members of the internal rental team; **Customers** are rental client records and do not receive staff login access. Navigate to **Team & access** (admin only) in Flutter, or **Team** in the browser fallback.

- **Admin:** can add staff/admin accounts, edit name/email/role, suspend/reactivate accounts, reset passwords, manage fleet/customer/bookings/payments, and review audit history.
- **Staff:** can sign in and operate the rental workflow, but the API denies team management, running administrative reminder checks, deleting customer/vehicle records, and reading audit history. Staff can change their own password from **My account**.
- **Suspended** accounts cannot log in. Suspending accounts or resetting passwords revokes their sessions. Changing a user's role revokes existing sessions.
- Cannot suspend or demote your own admin account; cannot remove the last active admin. Passwords are scrypt-hashed with per-password random salts. API never returns password hashes.
- SQLite startup automatically upgrades older v2.5 user tables by adding `is_active` and `last_login_at` columns without deleting business records. PostgreSQL requires the existing schema from `sql/postgres.sql` for first-time setup; subsequent startups add those user columns if missing.

### Demo team logins

| Role | Email | Password |
|---|---|---|
| Admin | `admin@drivedesk.local` | `Demo@12345` |
| Staff | `staff@drivedesk.local` | `Staff@12345` |

Demo accounts are seeded only for development when `SEED_DEMO=1`. For a real deployment, use HTTPS, rotate demo credentials, set `SEED_DEMO=0`, provision a secure initial administrator, and assess additional hardening (CSRF, rate-limit across multiple instances, HTTPS-only cookies/storage, secure audit retention and backups). Do not use the demo credentials in production.

**Start Windows:** Close old Node/Flutter terminals first, then run `RUN_DRIVEDESK_WINDOWS.bat` from the project's root. If port 3000/8080 is already occupied, run `CHECK_PORTS_WINDOWS.bat` to view owning process IDs instead of terminating unrelated processes.

**Test:** `npm test` (includes user creation, role authorization, deactivation, reset/password rotation, session invalidation and complete booking flow). Flutter source is included but Flutter SDK is not available in this build environment; run `flutter analyze` and `flutter run -d chrome` on Windows to validate Dart compilation. OCR/damage AI/tracker integrations still require real third-party/local models or hardware.
