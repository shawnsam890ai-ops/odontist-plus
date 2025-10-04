# Dental Clinic App (Prototype)

This Flutter application is a prototype for a dental clinic management system featuring:

- Splash (Loading) Page
- Login Page
- Dashboard with statistics (Patients, Revenue)
- Patient List & Add Patient pages
- Patient Detail with dynamic form sections for treatment session creation:
  - General
  - Orthodontic
  - Root Canal
  - Lab Work (placeholder mention)
- Repositories with local persistence using `shared_preferences`
- Reindexing of patient display numbers after deletion

## Architecture Overview

```
lib/
  core/            # enums, constants, routing
  models/          # data models (Patient, TreatmentSession, LabWork, RevenueEntry)
  repositories/    # persistence & business logic (local storage)
  providers/       # ChangeNotifiers bridging UI and repositories
  ui/pages/        # Screens
  ui/widgets/      # Reusable widgets
```

### Patient ID Strategy
- `id`: internal UUID (never shown/editable)
- `displayNumber`: sequential number (1..N) recalculated on delete
- `customNumber`: manually editable backend field (not yet surfaced in UI editing form)

### Treatment Sessions
Currently minimal fields are implemented for the dynamic forms; prescription, follow-up chaining, media attachments, consent uploads, and payment tracking are prepared structurally but not fully implemented in UI yet.

## Missing / Next Planned Enhancements
1. Advanced validation & error states
2. WhatsApp integration (launch URL) for patient phone
3. Editable custom patient ID field in an admin/back-office panel
4. Deletion & editing of sessions
5. Orthodontic payment schedule & balance calculation UI
6. Root canal and orthodontic procedure step logging with per-step payments auto-posting to revenue
7. Lab work creation & linking from patient detail (currently only model & repo exist)
8. Media (x-ray images) picker & storage (need file picker implementation & permission handling)
9. Consent form PDF/image upload & persistent linking
10. Prescription builder (serial auto-increment + medicine dropdown + timing pattern input)
11. Follow-up session creation (template copy minus chief complaint / oral findings per requirements)
12. Export / backup (JSON export) functionality
13. Authentication (currently mock login form only)
14. Theming polish and responsive layout improvements

## Running
Install Flutter SDK, then:
```
flutter pub get
flutter run
```

## Disclaimer
This is a prototype scaffold focusing on structure. Many requested detailed behaviors (conditional forms, payment balance logic, follow-ups, dynamic backend option management) still need implementation.
