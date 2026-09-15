# MCQ Exam Portal

A full-stack MCQ Exam Portal: Flutter client (Admin + Student roles in one codebase), Node.js/Express REST API, Firebase (Auth + Firestore) for identity and data, and Cloudinary for all file storage.

## Status

All 8 core build phases are complete and verified running end-to-end against a live Firebase project (`mcq-flutter-app`) on web + Android, with Firestore security rules deployed. `flutterfire configure` for iOS/macOS wasn't run — this dev machine is missing the `xcodeproj` Ruby gem CocoaPods needs; re-run `flutterfire configure --platforms=ios,macos` on a machine with a working CocoaPods/Xcode setup to add those platforms. Phase 9 bonus features beyond dark mode (already included via the shared light/dark theme) are not implemented.

## Project structure

```
mcq-exam-portal/
├── flutter_app/          # Flutter client (Admin + Student)
├── backend/               # Node.js/Express API
├── firestore.rules        # Firestore security rules
├── firestore.indexes.json
└── firebase.json
```

## Prerequisites

- Flutter SDK (built against Flutter 3.47.2 / Dart 3.13.2)
- Node.js 18+ and npm
- A Firebase project (Auth + Firestore enabled)
- A Cloudinary account
- `firebase-tools` CLI and the `flutterfire_cli` pub package

## Firebase project setup

1. Create a project at console.firebase.google.com.
2. Enable **Authentication** → Sign-in methods: **Email/Password** and **Google**.
3. Enable **Firestore Database**: Build → Firestore Database → Create database. This is a separate, easy-to-miss step from creating the project itself — Firestore writes fail with `SERVICE_DISABLED` until this is done.
4. Generate a **service account key**: Project Settings → Service Accounts → Generate new private key. Save the JSON as `backend/src/config/serviceAccountKey.json` (gitignored).
5. From `flutter_app/`, run `firebase login` then `flutterfire configure` — this registers an app per platform automatically and generates `lib/firebase_options.dart` plus platform config files (all gitignored).
6. For Google Sign-In on Android, add your debug/release SHA-1 fingerprints under Project Settings → Your Android app.
7. Deploy the security rules once you have Firebase CLI access: `firebase deploy --only firestore:rules` from the repo root (uses `.firebaserc` / `firebase.json` already in this repo).

## Cloudinary setup

1. Create an account at cloudinary.com and note your **Cloud name**, **API key**, and **API secret**.
2. Create an **unsigned upload preset** (Settings → Upload → Upload presets, mode: Unsigned) — used for direct-from-Flutter profile picture uploads.
3. Excel sheets, result PDFs, and report exports go through the backend using signed uploads, so no extra preset is needed for those.

## Environment variables

Copy `backend/.env.example` → `backend/.env`:

```
PORT=5050
NODE_ENV=development
JWT_SECRET=...
FIREBASE_SERVICE_ACCOUNT_PATH=./src/config/serviceAccountKey.json
FIREBASE_PROJECT_ID=...
CLOUDINARY_CLOUD_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...
CLOUDINARY_UNSIGNED_UPLOAD_PRESET=...
```

(`PORT` defaults to 5050, not 5000 — 5000 is squatted by macOS AirPlay Receiver on many Macs.)

The Flutter app has no `.env` mechanism in the fixed dependency list. Its two non-secret values (API base URL, Cloudinary cloud name + unsigned preset) live in `flutter_app/lib/utils/app_config.dart` — update `cloudinaryCloudName`/`cloudinaryUnsignedPreset` there to match your Cloudinary account, and `apiBaseUrl` if running on a physical device (it defaults to `10.0.2.2` for the Android emulator and `localhost` elsewhere).

## Running the backend

```bash
cd backend
npm install
npm run dev
```

## Running the Flutter app

```bash
cd flutter_app
flutter pub get
flutter run
```

## Creating an admin account

There's no admin signup flow by design (per the spec, "Admin accounts are provisioned separately"). Sign up normally as a student, then in the Firebase Console → Firestore → `users/{uid}`, change `role` from `"student"` to `"admin"`. The Firestore rules make `role` immutable from the *client* SDK specifically to prevent self-promotion — editing it directly in the console (or via the Admin SDK) is unaffected by client-side rules.

## Grading logic

Per question: correct → `+marks`; wrong → `-negativeMarking * marks` (only if `negativeMarking > 0`); unattempted → `0`. `percentage = score / totalMarks * 100`. `status` is `PASS` if `percentage >= (passingMarks / totalMarks * 100)`, else `FAIL`. Grade banding (computed from percentage, not stored — see Deviations): A+ 90+, A 80-89, B 70-79, C 60-69, D 50-59, F below 50.

Per-question `marks` aren't part of the Excel column spec, so each question is weighted equally: `marks = totalMarks / totalQuestions`, computed once at publish time.

## Deviations / assumptions from the spec

All pinned versions installed cleanly, but one needed bumping once actually *run*: the spec's `firebase_auth: ^4.15.0` pulls in `firebase_auth_web` ~5.8.x, which calls `dart:js_util`'s `handleThenable` — removed from the current Dart SDK, so it fails to compile for web specifically (mobile/desktop targets don't hit that code path, so this only surfaced when building for web). Bumped to `firebase_core: ^3.0.0` / `firebase_auth: ^5.0.0` / `cloud_firestore: ^5.0.0` (resolving to `firebase_auth_web` 5.15.3, which doesn't have the issue) and left `google_sign_in` at `^6.1.5` — its 7.x line is a breaking API rewrite and wasn't implicated in the actual failure. Everything else below is a design decision made where the spec was silent or where two of its requirements pulled in different directions.

- **Excel upload is two backend calls, not one.** The spec names a single `POST /admin/upload-excel` endpoint but also requires a preview before publish confirmation. `POST /admin/upload-excel/preview` parses, validates, and uploads the sheet to Cloudinary without touching Firestore; the literal `POST /admin/upload-excel` endpoint is the publish step that does the Firestore writes.
- **Whole-file rejection on invalid rows.** If any row's `Correct Answer` isn't A/B/C/D (or a question/option is empty), the entire file is rejected with a full list of row errors, rather than silently dropping bad rows.
- **Profile pictures upload client-side.** The spec's Cloudinary rules say student profile pics "can use an unsigned preset," which only makes sense as a direct client → Cloudinary upload (Flutter owns `cloudinary_service.dart` for exactly this). The backend's `POST /student/upload-profile` then persists the resulting URL to Firestore server-side (rather than letting the client write its own `users/{uid}` doc for this field) and cleans up the previous Cloudinary asset.
- **Result PDFs and report exports generate server-side** (`pdfkit`/`exceljs`), since generation needs to end with a signed Cloudinary upload. Flutter's `pdf` package (in the fixed dependency list) isn't exercised by this design — the Flutter side instead downloads the generated PDF via `http` and saves it locally via `path_provider`.
- **One attempt per student per exam**, with resume support: if a student's app is killed mid-exam, starting the same exam again returns the same `attemptId` and a server-anchored `startedAt` rather than blocking them — the block only applies once the attempt is actually submitted. Answers are autosaved locally (`shared_preferences`, keyed by `attemptId`) since the schema doesn't sync in-progress answers to Firestore.
- **Server-side timer backup** (Phase 8 hardening): a submission arriving more than 2 minutes after `startedAt + duration` is forfeited (graded as 0/FAIL) rather than graded normally — the server can't reconstruct "answers as of the deadline" from a single final snapshot, so a submission that late is treated as a tampered/bypassed client rather than trusted.
- **`correctAnswer` and question-wise review**: never sent to the client while `status === 'IN_PROGRESS'`; revealed in both the submit response and `GET /student/result/:examId` once the attempt is graded, so the required "question-wise analysis" is possible without ever exposing answers during the exam.
- **Two fields added beyond the schema's literal list**: `users.photoPublicId` (so a replaced profile photo can be cleaned up from Cloudinary) and, only in API *responses* (never written to Firestore), a `questions` array attached to submit/result payloads for review. `grade` is deliberately **not** stored — it's a pure function of `percentage`, computed identically on both ends.
- **Report exports live under `mcq-portal/results/reports/`** — the spec's Cloudinary folder list doesn't include a reports folder, so this nests them under the closest sanctioned one.
- **No dedicated "students" screen file.** The spec's screen list has no file for the admin's "view all students" requirement, so it's a private widget inside `admin_dashboard.dart` rather than a new top-level screen.
- **Firestore security rules lock `exams`, `exams/*/questions`, and `attempts` to no direct client access at all** — every read/write for those collections goes through the backend's Admin SDK (which bypasses rules), so this is a hard backstop, not just the REST API being the "intended" path. Only `users/{uid}` has real client-facing rules: read own doc (or any doc, if admin), create with `role` forced to `'student'`, and `role` is immutable on update from the client SDK — self-promotion to admin is impossible without going through Firebase Console or the Admin SDK directly.
