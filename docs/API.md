# REST API quick reference

Base: `http://127.0.0.1:3000`; JSON; bearer token for everything except `/api/health`, `/api/features`, and `/api/auth/login`.

`POST /api/auth/login` {email,password} → token

`GET /api/dashboard` → stats and recent rentals

`GET /api/vehicles` · `POST /api/vehicles` · `PUT /api/vehicles/:id` · `DELETE /api/vehicles/:id` (admin deletes only)

`GET /api/customers` · `POST /api/customers` · `PUT /api/customers/:id` · `DELETE /api/customers/:id` (admin deletes only)

`GET /api/bookings` · `POST /api/bookings` with {vehicle_id,customer_id,pickup_date,return_date,use_suggested_price} · `GET /api/availability?vehicle_id=1&pickup_date=2026-11-10&return_date=2026-11-13`

`GET /api/bookings/:id/workflow` → booking, paid, balance, inspections, completion checklist, next_action

`PATCH /api/bookings/:id/status` {status:'confirmed'|'cancelled'|'completed'} · `POST /api/bookings/:id/qr` {} → one-time QR payload · `POST /api/bookings/:id/handover` {code} → active

`GET /api/payments` · `POST /api/payments` {booking_id,amount,method:'cash'|'card'|'transfer'|'other',note}

`GET /api/smart/pricing?vehicle_id=1&pickup_date=2026-11-10&return_date=2026-11-13`

`GET /api/smart/recommendations?budget=50000&seats=5&days=3&category=SUV`

`GET /api/smart/anomalies` · `GET /api/smart/forecast` · `POST /api/smart/assistant` {message}

`POST /api/smart/ocr/plate` or `/license` {image_base64} — only when optional Tesseract enabled.

`POST /api/smart/damage` {image_base64} — requires external trained model service.

`POST /api/locations` {vehicle_id,latitude,longitude,source:'simulated'|'staff_manual'|'tracker',consent_confirmed:true,geofence_center_lat,geofence_center_lng,geofence_radius_km}

`GET /api/locations?vehicle_id=1`

`POST /api/inspections` {booking_id,phase:'pickup'|'return',image_base64?,findings?,reviewer_note?}

`GET /api/inspections?booking_id=1` · `GET /api/inspections/:id/photo` (authenticated, private)

`GET /api/notifications` · `POST /api/notifications/run` (admin) · `PATCH /api/notifications/:id/read`

`GET /api/audit` (admin) · `POST /api/users` (admin)

**Response conventions:** success JSON; errors `{ "error": "Explanation" }`. HTTP 401 unauthorized, 403 forbidden, 409 booking conflict / policy conflict, 503 unavailable optional OCR/damage service. All monetary amounts in LKR.

**2.1 workflow gates:** `POST /api/bookings/:id/qr` requires a confirmed booking AND recorded pickup inspection. The one-time QR handover activates the rental. A return inspection and a zero outstanding balance are required before status `completed`. Missing steps return HTTP 409 with a user-readable message.
