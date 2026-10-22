# Task-first UX design — v2.4

| Stage | User goal | Automatic guidance | Feedback after successful action |
| --- | --- | --- | --- |
| Dashboard | Know what needs attention | Start reservation / continue rental; trends and service shortcuts | Informational next-step tile |
| New rental - customer | Identify renter | Customer lookup, license details | Validation if none selected |
| New rental - vehicle | Pick suitable car | Ranked matches for seats/category/budget (can refresh), server availability check | Vehicle available; quote ready |
| New rental - quote | Understand the price | Smart suggestion with manual approval; technical method hidden in expandable section | Booking created; next = confirm |
| Rental desk - confirm | Approve the reservation | Workflow next-step explanation | Confirmed; next = pickup inspection |
| Rental desk - pickup | Record condition | Optional damage analysis link, manual capture always available | Inspection saved; next = handover QR |
| Rental desk - handover | Verify key transfer | QR is blocked until inspection is recorded | Active rental; next = payments/return |
| Rental desk - return | Close safely | Must inspect and collect full payment | Payment/inspection saved; rental can complete |
| Customers / Vehicles | Manage records | Contextual OCR and service status support | Success toast with usage hint |
| Bookings / Alerts | Review exceptions | Anomaly flags and maintenance reminders accessible in task | Error or completion alert as appropriate |

Design principle: never imply a configured trained vision model or GPS tracker when one is absent. Do not silently change prices or assert fraud. Advanced modules remain discoverable but do not block the normal workflow.
