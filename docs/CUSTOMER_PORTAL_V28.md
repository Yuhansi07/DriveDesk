# DriveDesk Pro v2.8 — Customer Portal

## Customer account
`customer@drivedesk.local` / `Customer@12345` (local demo account only). Customer and the seven staff/driver roles all use **one Flutter application and one Node.js API/database**. The customer home is not a separate CarZone app.

## Customer journey

1. **Home / Explore** — browse available fleet cars (the bundled stock photos are **illustrative**, not guaranteed photos of the actual car), search categories and open vehicle details.
2. **Dates / Request** — choose start/end; server enforces rental date format, current/future start, licence expiry and booking overlap before saving a pending booking.
3. **My rentals** — see pending, confirmed, active, completed and cancelled requests; total, paid, and balance.
4. **Cancel request** — only `pending` or `confirmed`, before pickup date. Paid amounts are **not refunded by software automatically**; a `manual_review` refund record is created for staff review.
5. **Statement** — server generated statement with invoice-like reference, paid transactions and balance. **Not a tax invoice or payment gateway receipt.** Copy statement to clipboard.
6. **Demo payment** — optional local **simulation**, only with `ENABLE_DEMO_PAYMENTS=1`, SQLite and seeded development mode. This writes a clearly labelled `demo_gateway` payment record; **no real money is taken**. The Windows `RUN_DRIVEDESK_WINDOWS.bat` enables simulation for local interview demo only. Do not confuse with live credit-card support.
7. **Updates** — scoped booking status, handover and payment notifications; mark read.
8. **Tracking** — only latest, consent-authorized and recent (`<15 min`) **real tracker** location events for the customer's **active** booking. Demo/staff-entered GPS coordinates are never represented as live tracking. Without a tracker the screen says it is unavailable.
9. **My profile** — edit name, phone, email/login, licence ID and expiry. Changes are written to customer record and login name/email in one transaction. Staff still need to verify driving licence authenticity.

## Security and permissions

- All portal actions require a signed-in **customer** with an existing `customer_id` link.
- Customer ID is obtained **from the session**, never a POST body.
- `GET invoice/location`, cancellation, notifications, and profile edits use the signed-in customer's ID; other customers' records return 404 or 403.
- Staff users and drivers cannot access customer portal endpoints.
- Server-side checks prevent booking conflicts and cancellation after pickup.
- User actions are written to audit log; notification events are deduplicated by event key.

## Technical implementation

- Flutter file: `flutter_app/lib/customer_portal.dart` is loaded by `role_portal.dart` when the role is `customer`.
- APIs: `/api/portal/*` in `api/routes.js`, permissions in `api/access.js`.
- New database tables: `portal_notifications`, `cancellation_requests`; auto-created on SQLite startup. PostgreSQL fresh schema and startup migrations also included.
- Run backend tests: `npm test` (includes `tests/customer_portal_v28.test.js`).

## Important integration boundaries

**Real online payments:** Requires signing up with a PCI-compliant hosted provider, configuring verified webhook signatures, idempotent events, refund handling, and production credentials. None of that is included. The demo is *not* an online gateway integration.

**Live GPS:** Requires approved GPS hardware, authorized tracker data, consent and retention controls. Device integration is *not* included.

**Production readiness:** Demo passwords, local demo payment mode, SQLite, and unsupervised uploaded licences must not be used to accept production bookings or real payments without proper deployment hardening.

## Windows run

1. Extract and open inner `DriveDesk_Pro` folder (where `package.json` and `RUN_DRIVEDESK_WINDOWS.bat` reside).
2. Stop previous Node/Flutter terminals. If port 3000 or 8080 is busy, run `CHECK_PORTS_WINDOWS.bat` to identify the old process and stop it safely.
3. Double click `RUN_DRIVEDESK_WINDOWS.bat`.
4. Open `http://localhost:8080`, select **Customer** account at login.
5. Use **Explore cars → Choose dates → Request → My rentals → Demo payment → Statement → Updates**.

Manual terminals from project root:

```
# Terminal 1 — local demo payment simulator (strictly not real money)
set ENABLE_DEMO_PAYMENTS=1
npm start
```

```
# Terminal 2
cd flutter_app
flutter pub get
flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

On PowerShell use `$env:ENABLE_DEMO_PAYMENTS='1'` instead of `set ...`.

### Validation
Node API integration tests run in the packaging environment. **Flutter SDK is not available there**, so Flutter actual compilation must be validated on Windows with `flutter analyze` / `flutter run`. A lightweight delimiter check is not a substitute for the Flutter compiler.
