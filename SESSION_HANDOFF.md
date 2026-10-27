# Khata App — Session Handoff

Written at the end of a multi-phase build session, for a fresh agent/session
to pick up with full context. Read this before touching anything.

**Not a git repo** (`git status` fails — no `.git` here). There is no commit
history to lean on; this document is the only record of what happened and why.

---

## 1. What this is

A Digital Khata (ledger) app for small businesses: track what clients owe
you / what you owe them, record business income & expenses, and see
profit/loss — separately from the client ledger. Flutter app, Supabase
backend (Postgres + Auth + Row Level Security). Multi-tenant: every user's
data is fully isolated via RLS, enforced at the database level, not just in
app code.

**Brand**: "HS Traders" / shown in-app as "Hussnain Traders" (the user
hand-edited this business name directly in a couple of screens outside of
my own edits — see §7). Visual identity: flat, neo-brutalist — 2px black
borders, zero border-radius, uppercase micro-labels, Archivo font at
weight 800 for headings, one accent color `#EC3013` (orange-red) used only
for debit/payable/danger states. The "ruled monogram" mark (black border,
red rule through "HS", ink-on-ground) is the app icon and splash brand.

---

## 2. Tech stack

- Flutter 3.47.2 / Dart 3.13.2 (`environment: sdk: ^3.13.2` in pubspec)
- State management: `flutter_riverpod` ^2.6.1
- Navigation: `go_router` ^15.1.2 (`StatefulShellRoute.indexedStack` for the
  5-tab bottom nav, so each tab's scroll/filter state survives switching)
- Backend: `supabase_flutter` ^2.9.1 — Postgres + Auth + RLS, no separate
  backend server
- Fonts: `google_fonts` ^6.2.1 (Archivo) — used for body text, **not** for
  the splash/icon monogram (see §6, deliberate)
- Dates/numbers: `intl` ^0.20.2
- Icon/splash generation (dev only): `flutter_launcher_icons` ^0.14.4,
  `flutter_native_splash` ^2.4.6
- No hardcoded credentials anywhere — Supabase URL/key come from
  `--dart-define-from-file=env/dev.json` (gitignored; see §4)

---

## 3. Architecture

Feature-first, under `lib/features/<feature>/{data,domain,presentation}`:

```
lib/
  main.dart                  — bootstraps Supabase, then runs the app
  app.dart                   — MaterialApp.router + theme
  core/
    config/                  — env vars (String.fromEnvironment), Supabase init
    theme/                   — AppColors, AppSpacing, AppTheme (design tokens)
    router/                  — GoRouter setup, the 5-tab AppShell, auth redirect
    domain/                  — DatePeriod (shared Today/Yesterday/Week/Month/Custom)
    utils/                   — Formatters (currency, date, time — Rs. X,XXX style)
    widgets/                 — KhataChip, EmptyState, ConfirmDeleteDialog, etc.
  features/
    auth/                    — login/signup, AuthRepository, riverpod providers
    clients/                 — list, detail, add/edit, the full client ledger
                                (credit/debit/receive/pay sheet, edit, soft-delete)
    dashboard/                — Home tab: net balance, receivable/payable,
                                period-filtered credit/debit/income/expense/P&L
    pnl/                     — Income/Expense entry + management, P&L tab
                                (categories, summaries, itemized entries)
    reports/                 — Reports tab: period summary + client-wise list
    more/                    — More tab (mostly still stub rows — see §8)
    splash/                  — RuledMonogram painter + SplashScreen widget
```

Each feature's `data/` layer has a `*Repository` class (all Supabase access
goes through these — screens never call `supabase.from(...)` directly) and
plain model classes with `fromJson`. `presentation/` has riverpod providers
(`*_providers.dart`) and screens/widgets. State that's genuinely
feature-crossing (e.g. saving a client transaction should refresh the
Dashboard's totals too) is handled by explicitly invalidating the other
feature's provider — see §6 for the pattern.

---

## 4. Supabase setup

**Project**: credentials live in `env/dev.json` (gitignored — copy from
`env/dev.json.example` if it's missing). This file already has the dev/test
project's real URL and anon/publishable key filled in from earlier in this
session — don't need to ask the user for them again unless that file is gone.

**Schema**: [`supabase/schema.sql`](supabase/schema.sql) — full, idempotent
schema. Run it in the Supabase SQL Editor. Tables:

- `profiles` — one row per user, seeded on signup
- `categories` — income/expense categories, seeded per-user on signup
  (Sales, Service income, Other income / Purchases, Rent, Salaries,
  Utilities, Transportation, Maintenance, Other) — **no UI to add custom
  categories yet**, only these seeded defaults are selectable
- `clients` — `opening_balance` (signed: +receivable/-payable), soft
  `is_active` flag (no UI exposes deactivating a client yet)
- `client_transactions` — credit/debit against a client. `type` is
  literally `'credit'`/`'debit'`. Soft-deleted via `is_deleted` +
  `deleted_at` + `deleted_by`, never hard-deleted (audit trail)
- `income_expenses` — business income/expense, `category_id` FK, entirely
  separate from client_transactions. Same soft-delete pattern.
- `reminders` — **table exists, zero app code uses it.** The More tab has a
  stub row referencing "Reminders" that just shows a snackbar.
- `client_balances` — a VIEW (`security_invoker = true`) computing
  `opening_balance + credit − debit` per client; used by the client list
  for efficiency instead of pulling every transaction per client

**RLS**: every table has `enable row level security` + a policy scoped to
`auth.uid()`. This is the actual security boundary — see the answer I gave
the user earlier in this session for the full explanation of why this means
two different logins never see each other's data, even with zero filtering
in the Dart code.

**Grants — non-obvious gotcha**: RLS alone wasn't enough. This project uses
Supabase's newer API key system (`sb_publishable_...` keys), which does NOT
auto-grant table-level access to `anon`/`authenticated` roles the way the
legacy JWT anon-key system did. Every table needed explicit
`grant select/insert/update/delete ... to anon, authenticated` statements
(included at the bottom of `schema.sql`) or every request 42501'd before RLS
was even evaluated. If you ever add a new table, remember the grants.

**Auth config on the Supabase dashboard** (as currently set, from this
session — you should know this before testing):
- Email provider: **enabled**
- "Confirm email": **disabled** (turned off mid-session for faster dev
  iteration — signup logs straight in, no confirmation email needed).
  **Re-enable before shipping to real users.**

**Reset script**: [`supabase/reset_test_data.sql`](supabase/reset_test_data.sql)
wipes `clients` (cascades to `client_transactions`), `income_expenses`, and
`reminders` for a fresh-testing slate. Keeps `profiles` and `categories`
(deleting those would break login / income-expense entry with no re-seed
path short of a brand new signup). Runs unscoped (all users in the
project) since this is a solo test project — has a comment explaining how
to scope it by `user_id` if that ever matters.

**Known test account**: `waqar.mustafa005+khatatest3@gmail.com` /
`TestPass123!` — created and used throughout this session for live testing
against the real Supabase project. May or may not currently have sample
clients/transactions in it depending on whether the reset script was run
since — check before assuming state.

---

## 5. How to run / build

```bash
# Run on a connected device/emulator or Chrome
flutter run --dart-define-from-file=env/dev.json

# Analyze + test (always run both before calling anything done)
flutter analyze
flutter test

# Release APK (signed with Flutter's default debug key — fine for
# sideloading, NOT for a Play Store submission; see android/app/build.gradle.kts)
flutter build apk --release --dart-define-from-file=env/dev.json
# → build/app/outputs/flutter-apk/app-release.apk

# Web build (used throughout this session for fast iteration via the
# Browser pane — .claude/launch.json has a "web-preview" config that
# serves build/web on a static server)
flutter build web --dart-define-from-file=env/dev.json --release
```

The app **will not start** without real Supabase credentials — no
hardcoded fallback exists by design (`EnvConfig.isConfigured` throws in
`bootstrapSupabase()` if missing).

---

## 6. What's built — phase by phase

Each phase was built, then verified **live against the real Supabase
project** (via the Browser pane, driving the actual web build against real
data) — not just compiled. Findings from that live testing are called out.

**Phase 1 — Scaffolding, auth, navigation shell**
Design-token theme (`AppColors`/`AppSpacing`/`AppTheme`), the 5-tab
`StatefulShellRoute` (Home/Clients/P&L/Reports/More), full email/password
auth (signup/login/logout) with session-gated `redirect` in the router.

**Phase 2 — Client Management**
List (search, status filter chips, cycling sort), add/edit form (phone
validation, duplicate-phone rejection via the DB unique constraint,
opening-balance sign picker), client profile/detail screen.

**Phase 3 — Client Ledger**
Add Credit / Add Debit / Receive Payment / Make Payment via one shared
bottom sheet (`transaction_sheet.dart`) — a 2-step flow: numeric keypad →
description/payment-method/date/time/reference. Edit and soft-delete via a
tap-to-open action menu + confirm dialog. Running balance computed and
displayed per ledger row.

*Bug found and fixed during this phase*: `postgrest-dart`'s `.order()`
defaults `ascending` to **`false`**, not `true` like SQL's own default
(confirmed by reading the package source). This silently broke the
client-ledger's running-balance calculation once a client had 2+
transactions — the query backing it returned newest-first instead of
oldest-first. Fixed with explicit `ascending: true` on every `.order()`
call across the codebase (`clients_repository.dart` ×2,
`pnl_repository.dart` categories fetch). Re-verified with a 2-transaction
scenario and cross-checked raw UTC timestamps directly in the database.

*Second bug, same phase*: `occurred_at` timestamps weren't converted
`.toLocal()` after fetch, so displayed/edited times were off by the local
UTC offset. Fixed in `ClientTransaction.fromJson`, `Client.fromJson`, and
the `client_balances` summary mapping — all timestamps are converted to
local time exactly once, at the point they're read from Supabase.

**Phase 4 — Dashboard (Home tab)**
Net balance, receivable/payable (never period-filtered — point-in-time
balances), and a single period-filtered section for credit/debit/income/
expense/net-profit-loss, with 5 period chips: Today/Yesterday/This
Week/This Month/Custom Range (`core/domain/date_period.dart` — shared with
P&L and Reports). Quick actions: Add Client (works), Add Credit/Add Debit
(route to the Clients tab rather than embedding a client-picker in the
sheet — deliberate, avoided extending an already-verified component),
Income/Expense (wired to the real entry sheet once Phase 5 landed).

**Phase 5 — Income & Expense management + P&L**
`income_expense_sheet.dart` — same 2-step UX as the client ledger sheet,
but writes to `income_expenses` with a category picker instead of a client
picker. P&L tab: result number (income − expense, **never** derived from
client credit/debit — this separation is enforced by construction:
`PnlSummary.fromEntries()` only ever sums `income_expenses` rows), category
breakdown, income-vs-expense bars, itemized editable/deletable entry list.

**Phase 6 — Reports**
Reuses the Dashboard's `periodTotalsProvider` and Clients'
`clientSummariesProvider` — no new queries. Period-filtered
income/expenses/P&L + a sortable client-wise list (Recent/Name/Highest),
tap a row to open that client's full profile.

**Phase 7 — Branding (app icon + splash)**
Decoded the user's brand design doc (same "Claude Design canvas" compressed
JSON format as the original UI design — see §9 if you need to decode
another one) and implemented variant **1B "Ruled monogram"**:
`RuledMonogram` `CustomPainter` (`lib/features/splash/presentation/widgets/`)
reused for both the generated app icon and the in-app `SplashScreen`.
`tool/icon_gen/generate_assets_test.dart` renders it to PNG via
`dart:ui`/`RepaintBoundary.toImage()` inside a `flutter_test` harness (no
image tools like ImageMagick/cairosvg were available on the machine).

*Two real gotchas hit while building the generator* (documented as comments
in the file — read them before touching it):
1. `toImage()`'s callback resolves on a real engine thread outside
   `flutter_test`'s FakeAsync zone — without wrapping in `tester.runAsync()`
   it hangs until the test timeout (learned this the hard way: first run
   hung the full 10 minutes).
2. `flutter_test` substitutes a glyph-less placeholder ("test font") for
   **all** text by design, regardless of requested font family — the "HS"
   text rendered as solid black rectangles until a real font
   (`/System/Library/Fonts/Supplemental/Arial Black.ttf`, loaded via
   `FontLoader`) was explicitly loaded first.

Applied via `dart run flutter_launcher_icons` (adaptive icon: background
`#F3F2F2`, foreground inset so the border survives circular/squircle
masking) and `dart run flutter_native_splash:create`. Only iOS/Android were
regenerated — web/desktop icons were left on Flutter defaults (not asked
for, app targets mobile).

**Unrelated but critical bug fix, discovered via real-device testing**:
`android/app/src/main/AndroidManifest.xml` was missing
`<uses-permission android:name="android.permission.INTERNET" />` entirely
— every network call failed on-device (`Failed host lookup`) while the web
build worked fine (browser networking isn't gated by Android app
permissions). This is almost certainly why *any* release APK built before
this fix would have been non-functional off a browser. Fixed; verified
present in the compiled APK via `aapt dump permissions`.

---

## 7. Things I did not touch, that changed on disk mid-session

The user directly hand-edited the business name string in
`lib/features/auth/presentation/login_screen.dart` and
`lib/features/dashboard/presentation/dashboard_screen.dart` — from "Rehman
Traders" (my original placeholder, matching the design mock's default) to
"Hussnain Traders". This was **not** my edit; it showed up via the
"file changed on disk" mechanism. It's a cosmetic string, does not affect
correctness, and I left it as-is. If you're grepping for the business name
elsewhere, note it's currently inconsistent with the brand doc's "HS
Traders" — that's the user's call to reconcile, not an error to fix
unprompted.

---

## 8. Scope decisions — deliberately not built

Called out explicitly so a fresh agent doesn't assume these are bugs or
oversights:

- **No standalone "Transactions" tab.** The original HTML design doesn't
  have one either — credit/debit entry happens via quick-actions on a
  client row/profile, not a dedicated tab. Confirmed as a deliberate
  fidelity choice to the design, not a missing feature.
- **No category management UI.** Only the seeded default categories are
  selectable when adding income/expense. No add/edit/delete-category
  screen exists.
- **No Reports export** (PDF/CSV). Explicitly deferred per the user's
  original spec ("prioritize the core application first").
- **More tab is still mostly a stub.** Reminders, Audit trail, Backup &
  restore, Currency — all just show a "coming soon" snackbar. Sign Out is
  the only real functionality there. The `reminders` table exists in the
  schema with zero app code using it.
- **No client archive/deactivate UI.** `clients.is_active` exists and is
  filtered on, but nothing in the app ever sets it to false.
- **Release APK is debug-signed** (Flutter template default). Fine for
  sideloading/testing; would need a real keystore + signing config before
  any Play Store submission.

---

## 9. If you need to decode another design file

Both the original UI design (`Khata App (offline).html`) and the brand doc
(`HS Traders Brand (offline).html`) the user supplied were **not** plain
HTML — they're "Claude Design canvas" exports: a huge (~1MB) file where the
actual design lives as a JSON-escaped string on one specific line (find it
via `awk '{ print length, NR }' file.html | sort -rn | head`), gzip+base64
compressed alongside a `<script>` payload. To decode: find the longest line
that starts with `"<!DOCTYPE html>...` after JSON-parsing, `json.loads()` it
in Python, write the result to a file, and read *that*. It'll contain a
mock-data JavaScript class (`class Component extends DCLogic`) with
placeholder state that's extremely useful for extracting exact business
logic, enum values, and default copy — read it, don't just skim the HTML.

---

## 10. Recommended next steps

Roughly in the order they'd likely come up:

1. **More tab real features** — Reminders (table already exists, needs a
   repository + UI), Currency setting, Audit trail (would need to surface
   the `deleted_at`/`deleted_by` soft-delete trail already being recorded).
2. **Category management** — add/edit/delete custom categories screen.
3. **Client archive** — wire `is_active` to an actual deactivate action.
4. **Reports export** (PDF/CSV).
5. **Re-enable "Confirm email"** on Supabase before any real user signs up.
6. **Real Android signing config** before a Play Store submission.
7. Consider reconciling the "Hussnain Traders" vs. "HS Traders" naming
   inconsistency (§7) with the user.

---

## 11. Quick command reference

```bash
flutter analyze                                    # must be clean before calling anything done
flutter test                                        # unit tests (Formatters, currently)
flutter build apk --release --dart-define-from-file=env/dev.json
flutter build web --dart-define-from-file=env/dev.json --release
flutter test tool/icon_gen/generate_assets_test.dart # regenerate icon/splash PNGs
dart run flutter_launcher_icons                      # apply assets/icon/icon*.png → native icons
dart run flutter_native_splash:create                # apply assets/icon/splash_logo.png → launch screen
```
