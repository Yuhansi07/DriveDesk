# DriveDesk v2.7 – Complete user roles and login guide

## Seven business roles, with real server-enforced permissions

| Role | Main workspace | Allowed | Restricted |
|---|---|---|---|
| Administrator | Full management, Team & Access | Add/suspend accounts, reset passwords, all rental and fleet operations | Cannot demote or suspend own admin account; cannot disable last active admin |
| Operations Manager | Business operations | Manage rental, customer, vehicle, inspection and payment operations | Manage accounts / view audit trail |
| Rental Agent | Reception / bookings | Customer registration, vehicle selection, reservations, QR, handover, payment records | Users, fleet editing, finance analytics, GPS monitoring |
| Fleet Officer | Vehicles and maintenance | Vehicle catalog, inspection, permitted location logging, service/insurance checks | Payments, customer list, booking creation, Team & Access |
| Finance Officer | Payments and reports | Booking list, revenue dashboard, payments, business forecast | Customer directory, vehicle edits, handover, account administration |
| Driver | Assigned trips | View ONLY assigned jobs; record condition note for assigned pickup/return stages | Full booking list, other drivers’ jobs, customer database, payment data |
| Customer | Customer portal | View ONLY linked profile and bookings; see public available fleet; request booking | Staff dashboard, other customer profiles, team administration, payments API |

The demo *rental_agent* also includes the older `staff@drivedesk.local` account so existing v2.6 installations continue working.

## Demo credentials (LOCAL DEVELOPMENT ONLY)

| Role | Email | Password |
|---|---|---|
| Admin | `admin@drivedesk.local` | `Demo@12345` |
| Operations Manager | `manager@drivedesk.local` | `Manager@12345` |
| Rental Agent | `booking@drivedesk.local` | `Booking@12345` |
| Fleet Officer | `fleet@drivedesk.local` | `Fleet@12345` |
| Finance Officer | `finance@drivedesk.local` | `Finance@12345` |
| Driver | `driver@drivedesk.local` | `Driver@12345` |
| Customer | `customer@drivedesk.local` | `Customer@12345` |
| Legacy Rental Staff | `staff@drivedesk.local` | `Staff@12345` |

There are **seven role types**, and **eight demo login accounts** (two Rental Agent logins) to preserve backward compatibility. On the Flutter login screen, the **Try a demo role** dropdown fills the correct example email/password. Do NOT use these passwords or enable `SEED_DEMO` in production. Replace all demo credentials before deploying.

## Typical interview flow

1. Log in as Admin and go to **Team & access**. Observe seven role options. Create a new Rental Agent, suspend it, reactivate it, and change its password.
2. Log in as Rental Agent, create a customer profile and a reservation.
3. In **Rental desk**, assign a Driver. Complete pickup inspection, confirm and hand over using QR; record return inspection and payment. The actual backend enforces these steps.
4. Log in as Driver. Only assigned jobs appear, with a condition-report action for relevant booking states.
5. Log in as Customer. The portal shows a separate synthetic customer profile and only the associated booking history. Click **New request** to submit a pending booking.
6. Log in as Finance Officer. View payment functions while Team & Access and vehicle editing are hidden; direct unauthorized API calls return 403.
7. Log in as Fleet Officer. Browse vehicles and maintenance, but cannot access payments or private customer directory.
8. Log in as Manager to supervise operations without access to user account administration.

## Database migration and privacy

- The **existing SQLite database is upgraded automatically**, adding `users.access_role`, `users.customer_id`, and `bookings.assigned_driver_id` only if absent. Historical vehicle, customer, booking, and payment records are retained.
- Existing `staff` accounts are migrated to the `rental_agent` effective role. The legacy database role column stays unchanged for compatibility.
- Demo Customer is attached to a **new synthetic `Demo Portal Customer` record**, never silently assigned to an existing real customer.
- Every API request checks the current account and its permissions, including direct requests outside the Flutter user interface. Changing or suspending an account revokes existing sessions.
- Driver trips are visible only if that driver's account is assigned to the booking. The selected booking shows an **Assigned driver** field in the Rental Desk for authorized staff.
- This is a **local interview demonstration**, not a security certification or a live production service.

## Run / validate

1. Stop old DriveDesk servers. Run `CHECK_PORTS_WINDOWS.bat` if ports 3000 or 8080 are occupied.
2. Extract the project and open the `DriveDesk_Pro` directory containing `package.json`.
3. Double-click `RUN_DRIVEDESK_WINDOWS.bat`, or start backend `npm start` and Flutter frontend from `flutter_app` using:

```powershell
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

4. Open `http://localhost:8080`.
5. Backend tests: `npm test`. Flutter checks on machine with SDK: `cd flutter_app; flutter analyze; flutter test`.

**Test status:** All 18 automated Node/backend tests passed in the packaging environment. Flutter compilation has not been verified in that environment because Flutter SDK was unavailable. This package includes source code for the Flutter features; test it locally before an interview.
