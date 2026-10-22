# Interview demonstration: 7–10 minute flow

**30-second introduction:** “DriveDesk is a Flutter and Node.js rental management system. I prioritized booking correctness, secure handovers, payment controls and transparent decision support. I provide both a zero-install Node/SQLite demo and a PostgreSQL schema with a database-enforced non-overlap constraint.”

**Live steps**

1. Sign in, open Overview: fleet and payment figures are read from SQL, not hard-coded dashboard numbers.
2. More tools: recommend an SUV within budget. Explain this is a content-based ranking algorithm, not a neural net.
3. Price: compare base vs recommended rate. Explain the `ridge_linear_regression` vs `transparent_rule_fallback` label and how synthetic training data limits evaluation.
4. Open **New rental** wizard: select a customer → choose vehicle and dates → ask recommendations → check availability → review smart pricing → create the pending booking. Test a duplicate booking in the same dates (409).  Try duplicate on the same car; see conflict 409. Explain `[pickup,return)` interval semantics, transaction, and Postgres `EXCLUDE` constraints.
5. Open **Rental desk** for the new booking, confirm it, **record pickup inspection**, issue QR payload, enter it to approve handover. Talk through random 256-bit bearer secret, stored SHA-256 digest, one-time use, 24-hour expiration and authenticated request.
6. Record a **return inspection**, collect partial payment, then show completion is blocked by the outstanding balance (409). Settle the remaining amount, complete the rental, and demonstrate its completed state. An overpayment is rejected.
7. Open More tools anomaly and demand dashboards; differentiate statistical review flags and validated ML. Show rule-based Q&A.
8. Locations: check consent, record a point explicitly marked `simulated`. Describe future authenticated GPS tracker webhook integration.
9. Reminders: run insurance/service checks with idempotent notification keys; no email/SMS integrations claimed.
10. Show the Flutter source/project and optional_ai folder. Say trained visual damage model is **not** included and would require labelled data, precision/recall validation, bias/privacy controls and testing.

**Expected interview questions**

- *Why PostgreSQL?* Multi-user concurrency, transactions and exclusion constraint; SQLite suitable for local demo and single-process usage.
- *Why Node?* Express route layer; REST JSON clients; shared Node service code allows testing independent of transport.
- *What is truly ML?* Pricing ridge regression when enough data; demand linear trend; others are explainable rules. Computer vision inference is optional, and the prototype does not claim trained model accuracy.
- *How avoid same vehicle booked twice?* Atomic DB check in SQLite, database exclusion in PostgreSQL.
- *Is GPS live?* No tracker bundled. Staff app obtains its own phone location and the demo can store simulated coordinates. Authorized tracker integration is future work.
- *Security?* Scrypt, hashed expiring sessions, one-time QR, RBAC for limited admin actions, private inspection photo endpoint, validation. More production security is required.


**What not to overstate:** The web flow uses a one-time pickup token rather than an independently generated QR image; Flutter can render the QR. Pickup/return condition notes are manually reviewed. External damage AI requires trained weights. Pricing regressions and forecasting use synthetic demo history and must not be described as validated production predictions.
