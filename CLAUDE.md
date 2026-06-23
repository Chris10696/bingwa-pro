# CLAUDE.md — Bingwa Nexus (project memory)

> Place this file at the repository root (`C:\bingwa_pro\CLAUDE.md`). Claude Code reads it
> automatically at the start of every session. Keep it updated as the project evolves.
> The backend is a **separate** repo — give it its own CLAUDE.md.

## What this project is

**Bingwa Nexus** (rebrand of "Bingwa Pro" — same project) is a platform for Kenyan
Safaricom reseller agents who sell airtime / data / SMS bundles and run their own
subscription.

- **App** (this repo): Flutter, package `com.example.bingwa_pro`. Path `C:\bingwa_pro`.
- **Backend** (separate repo `bingwa-pro-backend`): NestJS, deployed on Railway at
  `https://bingwa-pro-backend-production.up.railway.app`.
- **Reference app**: "Bingwa Hybrid" — a working native-Kotlin app that is the
  **behavioral spec**. The app is being rebuilt wave-by-wave to match it.

### GOLDEN RULE
**Match Bingwa Hybrid's behavior unless a divergence has been explicitly agreed.** When in
doubt about how something should behave, the answer is "however Hybrid does it." Several
Kotlin classes are *verbatim ports* of Hybrid logic and are marked as such — do not
"improve", reword, or regex-ify those strings; retry/branch decisions (and how much real
airtime is spent) depend on matching Safaricom's wording exactly.

## Working method

- Development is **wave-based** (W1 data model, W2 commerce loop, W3 USSD pipeline, …) with
  **locked decisions** recorded in the wave primers. Don't silently revisit a locked decision.
- **Propose before large edits.** For anything non-trivial, explain the plan and show a diff
  before applying. Review diffs; commit to git before/after meaningful changes.
- Prefer **surgical, low-risk** fixes over broad rewrites.

## Test environment

- Physical device: **Samsung SM-A245F (Galaxy A24)**, Android 14, over **USB** (USB
  debugging on). Backend reached over Wi-Fi.
- Test agent: phone `0794180735`, `agentId c7308f84-534f-48bd-afa9-e367097b8d13`.
  (JWT payload uses `sub`, not `id`.)
- App owner's Sambaza collection ("admin") number: `0118531095`.

## Architecture map

### Android native (`android/app/src/main/kotlin/com/example/bingwa_pro/`)
- `MainActivity.kt` — Flutter MethodChannels: `bingwa_pro/ussd`, `/airtime`, `/service`,
  `/scheduler`, `/session` (hosts `enqueueQuickDial`, `getSimInfo`, SIM setters,
  accessibility gate), `/test` (dev only — remove before Play release).
- `UssdEngine.kt` — `formatUssdCode` (BH/BN→phone, AMT→amount), `dialExpressCapturing`
  (Express, `TelephonyManager.sendUssdRequest`, single round-trip, captures response),
  `dialAdvancedCapturing` (Advanced, accessibility-driven multi-step).
- `UssdExecutionService.kt` — foreground-service serial queue dialer; `processOne` pipeline:
  PreDial → dial → classify → SUCCESS / FAILED_ALREADY_RECOMMENDED / timeout / retry. Money-
  safety: each request dialed at most once; status PATCHed best-effort.
- `UssdResponseClassifier.kt` — verbatim Hybrid response classifiers (DO NOT reword) +
  `isSambazaFailure` (added this session, additive — safe to extend).
- `SessionBridge.kt` — SharedPreferences mirror of session (token/baseUrl/agentId),
  processing mode, app state, process-mpesa flag, and SIM-routing booleans.
- `SimSubscriptionResolver.kt` — resolves configured SIM slot → subId / PhoneAccountHandle.
- `AirtimeChecker.kt` — `*144#` balance via the Express capture (regex "Airtime Bal: <n>KSH").
- `DialRequest.kt`, `BootReceiver.kt`, `WorkScheduler` (scheduling), `AutoReplySender`.

### Dart (`lib/`)
- `shared/repositories/transaction_repository.dart`, `wallet_repository.dart`.
- `shared/models/transaction_model.dart` — **freezed** models (TransactionResponse,
  TransactionDetails, enums TransactionType/TransactionStatus, etc.).
- `core/services/session_bridge_service.dart` — Dart side of the `/session` channel.
- `features/wallet/presentation/widgets/pay_with_airtime_sheet.dart` — pay-with-airtime flow.

### USSD modes
- **Express** = single `sendUssdRequest` round-trip; captures the response text. Used for
  single-step codes (Sambaza, `*144#`). SUBSCRIPTION_RENEWAL and AIRTIME_BALANCE_CHECK are
  always forced Express.
- **Advanced** = ACTION_CALL + `UssdAccessibilityService` typing menu steps; for multi-step
  menu navigation. Requires the accessibility service to be enabled.

## Pay-with-airtime (Sambaza) flow — how it works
1. `POST /transactions/airtime-subscription` → backend builds a `SUBSCRIPTION_RENEWAL`
   transaction whose `ussdCode` is the Sambaza transfer `*140*<price>*0118531095#` (no debit).
2. App calls `enqueueQuickDial(... customerPhone: '')` → native pipeline dials it (Express).
   Blank `customerPhone` is a deliberate sentinel: self-contained code, suppress auto-reply.
3. App polls `GET /transactions/:id/status` until terminal.
4. On SUCCESS → `POST /wallet/purchase-subscription-airtime` grants the plan and writes a
   row to the purchases ledger (`GET /wallet/purchases`).

A purchase is recorded in **two** places: the transactions table (Transaction History,
`GET /transactions`) AND the subscription-purchases ledger (`GET /wallet/purchases`).

## Build & run

- Run on device: `flutter run` (from repo root, device connected).
- Static analysis: `flutter analyze`.
- **Kotlin changes need a FULL rebuild** — hot reload/restart will NOT pick them up. Stop the
  app and `flutter run` again (`flutter clean` first if Gradle caches misbehave).
- **freezed/json models** (`*.g.dart`, `*.freezed.dart`): after editing a `@freezed` class,
  regenerate with `dart run build_runner build --delete-conflicting-outputs`.
- adb is in the Android SDK platform-tools (e.g. `%LOCALAPPDATA%\Android\Sdk\platform-tools`).
  Useful logcat (clean run): `adb logcat -c` → reproduce → filter by app PID:
  `adb logcat --pid (adb shell pidof com.example.bingwa_pro) -v color`.
  Tag filter alternative: `adb logcat -s UssdService UssdEngine AirtimeChecker SessionBridge BingwaPro`.

## Gotchas / conventions
- `GET /transactions/:id/status` returns a **SLIM** payload
  (`{id, status, reference, errorMessage, ussdResponse}`), NOT a full transaction. Do NOT
  parse it with `TransactionResponse.fromJson` — that throws
  `type 'Null' is not a subtype of type 'String'`. Use
  `TransactionRepository.getTransactionStatusLite` and compare the status STRING.
- Backend timestamps (`createdAt`, etc.) are **UTC** (trailing `Z`). `DateTime.parse` keeps
  them UTC; **always `.toLocal()` before display** (device is EAT / UTC+3). A UTC-rendered
  time looks 3 hours behind the real local time.
- Don't reword the verbatim Hybrid classifier strings in `UssdResponseClassifier.kt`.
- Native Windows only — do NOT develop this in WSL2 (Android toolchain + USB device live on
  Windows).

## Recent fixes (this session)
- `MainActivity.enqueueQuickDial`: made `customerPhone` optional (blank is a valid sentinel),
  so pay-with-airtime can enqueue. Guard now requires only transactionId + ussdCode.
- `UssdExecutionService.processOne`: added **SambazaFailureGuard** — demotes a `success=true`
  whose captured text is a low-balance failure ("insufficient … balance", "too low",
  "recharge your account") to FAILED *before* any grant, so a transfer that didn't move
  airtime never grants a free plan.
- `UssdResponseClassifier.isSambazaFailure` added (additive; verbatim ports untouched).
- `transaction_repository.dart`: added `getTransactionStatusLite` (tolerant of the slim
  /status payload).
- `pay_with_airtime_sheet.dart`: poll switched to `getTransactionStatusLite` + string-based
  terminal-status set; insufficient-balance wording extended ("too low", "recharge your
  account"). This fixed the sheet hanging on "Sending airtime…" and the no-grant-after-success.

## Pending / next work
1. **Timezone display fix (app-wide):** backend UTC timestamps render 3 hours behind. Apply
   `.toLocal()` at the display layer — Transaction History screen, the Subscription screen's
   Purchase History widget, and any shared date-format helper (likely in `core/utils`).
   Centralize if a shared formatter exists.
2. **Quick Dial poll fix:** the Quick Dial provider/sheet polls `GET /transactions/:id/status`
   and will hit the same slim-payload crash the airtime sheet did. Point it at
   `getTransactionStatusLite` and compare status strings.
3. **USSD engine testing roadmap** (Express + the pipeline are proven; these are not yet):
   Quick Dial (real offer to a real customer, token economics) → a multi-step offer →
   Advanced mode (accessibility) → the full SMS-triggered auto-sale loop (M-Pesa SMS → parse →
   match → dial → customer auto-reply).
