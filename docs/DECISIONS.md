# Design decisions

Choices made where the brief was ambiguous or left room. Newest sections are appended per phase.

## Backend

- **Express 5.** Async handlers can throw or reject and the error reaches the central handler without a wrapper.
- **API prefix.** All routes are mounted under `/api/v1` so the API can be versioned later. `/health` is unversioned.
- **Validation.** zod schemas are declared next to each route. Parsed and coerced values live on `req.valid.{body,query,params}`, because Express 5 makes `req.query` read-only.
- **Error shape.** Every error is `{ error: { code, message, details? } }`. Validation errors use status 422 with `details: [{ path, message }]`.
- **Units.** All weights are stored and computed in **kg**. The user's `unit` preference is display-only and conversion happens in the app.
- **Refresh tokens.**
  - Each one is a JWT (signed with `JWT_REFRESH_SECRET`) with a random `jti` and a `fam` (family) claim. Only its SHA-256 hash is stored.
  - Each `/auth/refresh` revokes the presented token and issues a new one in the same family.
  - Presenting a token that was already rotated revokes the whole family (theft detection). A TTL index removes expired tokens.
- **Logout.** By default it revokes the presented refresh token. `allDevices: true` together with a valid access token revokes every session of the user.
- **Forgot password.** This is a stub. It always returns 202 with the same message, so it can't be used to check whether an email has an account. No email is sent.
- **Rate limits.** login/register/forgot-password allow 20 requests per 15 minutes per IP. refresh allows 120 per 15 minutes, because the app calls it silently.
- **Bodyweight history.** It is embedded in the User document as the brief requires. It is served paginated from `GET /users/me/bodyweight` and is left out of the user JSON. The newest entry always sets `bodyweightKg`.
- **Pagination.** Offset-based with `?page=&limit=` (max 100). Every list response is `{ data, page, limit, total, totalPages }`.

## Local development

- Docker and MongoDB are optional for running tests: Jest starts `mongodb-memory-server`, and each test file gets its own database.
- `npm run dev:memory` runs the API against a throwaway in-memory database and seeds it, which is useful without Docker or Atlas.

## Exercise library (Phase 2)

- **Source.** The source is free-exercise-db `dist/exercises.json`, which has 876 exercises (not ~800 as the brief estimated). Images point at `raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/<path>`, so they are never copied into our storage.
- **Categories.** The dataset's seven categories are collapsed into the brief's three:
  - powerlifting, olympic weightlifting and strongman become **strength**
  - plyometrics becomes **cardio**
  - the original value is kept in `sourceCategory`
- **Equipment.** A `null` equipment becomes `none`, and unknown values become `other`.
- **Seeding.** The seed is idempotent: it upserts by `(slug, createdBy: null)`, so re-running it never breaks references from workouts and never touches custom exercises. `--file` seeds from a local copy for offline use.
- **MET values** (`src/config/metTable.js`):
  - The non-generic dataset category is checked first: stretching 2.3, plyometrics 8, strongman 7, olympic/powerlifting 6, cardio 7.
  - Otherwise the value comes from equipment: barbell 6, dumbbell 5, machine/cable 4, bodyweight 4.5, and so on.
  - Custom exercises use the same table unless the user overrides it.
- **Bodyweight exercises.** Exercises with equipment `body only` get `isBodyweight: true`, and a set's `weight` is then the *added* load. Effective load (bodyweight + added) is used for e1RM and ranks. Volume uses only the logged weight, so it matches what the user typed.
- **Ranked lifts** (`src/config/lifts.js`). Specific library exercises are tagged with a `liftKey`:
  - bench: medium-grip and powerlifting bench
  - squat: back squat and full squat
  - deadlift: conventional and sumo
  - overhead press: standing military press
  - row: bent-over barbell row
  - pull-up: pull-ups and weighted pull-ups
  - dips: chest, triceps and parallel-bar dips
  - Variations such as incline bench or front squat don't count toward ranks.
- **Custom exercises.** They are visible only to their creator. Library exercises are read-only, and editing one returns 403. Another user's custom exercise returns 404, so its existence isn't revealed.
- **Search.** Search is a case-insensitive substring match on the name, with regex characters escaped. A text index was not used because it can't match partial words like "ben" in "bench".

## Training logic (Phase 3)

### e1RM and PRs

- **e1RM.** Epley for 1–12 reps. **A single rep returns the weight itself** instead of weight × 1.033, so a true 1RM isn't inflated. Sets above 12 reps are ignored.
- **Which sets count for PRs.** Only completed sets of type `working` or `failure`. Warm-ups and drop sets never set records.
- **Baselines.** The first value ever logged for a record type is stored as a *baseline* (`isBaseline: true`) and is not celebrated. Otherwise every first session would trigger a dozen PRs. The same applies to the first time a user lifts a particular weight (`maxRepsAtWeight`).
- **Precision.** `maxRepsAtWeight` matches weights at 0.01 kg precision, so lb→kg conversions line up.
- **One record per type per session.** Each record type counts once per session, using the session's best set. If an exercise appears twice in a session, its sets are merged.
- **Rebuilding records.** Editing or deleting a workout, or saving a backdated one, triggers a **rebuild**: the user's completed sessions for the affected exercises are replayed in date order. A normal save (the newest session) is checked incrementally against the stored bests.

### Calories

- **Formula.** Session calories = MET × bodyweight × active hours.
- **Active time.** It comes from the app's `activeDurationSec` (session timer without pauses), or wall-clock time if that is missing.
- **Mixing exercises.** The MET is a set-weighted average across exercises.
- **Missing bodyweight.** A default of 75 kg is used and the response is flagged.
- **Labelling.** Calories are always labelled as an estimate.

### TDEE

- Mifflin-St Jeor × activity factor (1.2 / 1.375 / 1.55 / 1.725 / 1.9).
- Cut −20%, maintain, bulk +10%.
- Cuts never go below 1500 kcal for men or 1200 kcal for women.
- Macros:
  - protein 1.8 g/kg (2.2 g/kg on a cut)
  - fat 25% of kcal
  - carbs make up the rest
- A user can override with a manual target, and `null` restores the automatic one.

### Calorie logs

- One document per local calendar day (`YYYY-MM-DD` sent by the app).
- The day's target is saved when the day is first logged, so past days keep the target that applied then.

### Ranks

- **Thresholds.** They live in `src/config/strengthStandards.json`. They are approximations tuned from common public strength standards (beginner→elite ratios), stretched across seven tiers.
- **Time window.** A rank uses the best ratio from the **last 365 days**, so ranks reflect current strength and can drop after a long break. Each session stores the user's bodyweight at that time.
- **Bodyweight lifts.** Pull-ups and dips are ranked on (bodyweight + added) e1RM, so 1.0 ≈ one strict rep.
- **Score.** Each lift gets a continuous score of tier index + progress, from 0 to 6.
- **Muscle groups.** A group's rank is a weighted average of the lifts that train it (weights in `src/config/lifts.js`).
- **Overall rank.** A weighted average: squat, bench and deadlift 20% each, OHP 15%, row 10%, pull-up 10%, dips 5%. Lifts without data are left out and the remaining weights are re-normalised.
- **Unknown sex.** Male standards are used and the response sets `assumedSex: true`.
- **Level-ups.** The last-seen tiers are stored on the user (`rankTiers`). Saving, editing or deleting a workout returns `rankChanges` so the app can play the level-up animation.

### Workouts and programs

- **Active workout.** It is a `WorkoutSession` with `status: 'active'`, and each user can have at most one (partial unique index). Finishing converts it in place and deletes any other draft.
- **Sync.** Sessions are matched on `(userId, clientId)`, so offline retries can't create duplicates.
- **Negative weight.** It is allowed only on bodyweight exercises, where it means assisted reps.
- **Templates.** Built-in templates are Program documents with `userId: null` and `isTemplate: true`. They are read-only. Activating one clones it into the user's programs first, so the user can edit their copy.
- **Next day.** Days rotate in order and continue after the last completed session of the active program.
- **Streaks.** Both a day streak and a week streak are returned. Weeks start on Monday in the user's time zone. A streak is not broken until the current day or week has ended. The dashboard shows the week streak, because rest days are normal in strength training.

## Flutter app foundation (Phase 4)

### Packages

- **Versions.** All packages are at their latest stable versions at build time: Riverpod 3.4, go_router 18, dio 5, flutter_local_notifications 22, google_fonts 9 and hive_ce 2.
- **No code generation.** Riverpod is used without codegen (`Notifier` / `FutureProvider`), and models have hand-written `fromJson`. There is no `build_runner` step.
- **Local storage.** `hive_ce` is used, the maintained Hive fork, instead of Isar, which is unmaintained. Values are stored as JSON strings, so no type adapters are needed.

### Fonts

- **Bundled.** The Inter Tight and Space Grotesk TTFs are bundled under `assets/fonts`, and `GoogleFonts.config.allowRuntimeFetching = false`. The app still uses `google_fonts`, but it renders correctly offline on first launch and in widget tests.
- **License.** The fonts are SIL OFL licensed. Their license texts are bundled and registered with `LicenseRegistry`.
- **TextTheme.** It is built style-by-style with `GoogleFonts.interTight(...)`. google_fonts 9 returns `TextTheme` from the new `material_ui` package, which isn't the same type as Flutter's.

### API URL

- It comes from `assets/config/app_config.json` (default `http://10.0.2.2:4000/api/v1` for the Android emulator).
- It can be overridden with `--dart-define=API_BASE_URL=...`.
- Android allows cleartext HTTP, and iOS sets `NSAllowsLocalNetworking`, so the local dev server is reachable. Use HTTPS in production.

### Auth

- **Token refresh.** It is a dio `QueuedInterceptor`, so concurrent 401s trigger a single refresh. A second refresh would trip the backend's reuse detection and log the user out.
- **Ending the session.** Only an explicit 401 from `/auth/refresh` signs the user out. Network failures keep the session alive.
- **Offline start.** If the server can't be reached on launch, the app signs in with the last cached profile, so it can be used offline (for example, mid-workout at the gym).

### Navigation and design tokens

- **Navigation.** There are five bottom tabs: Home · Exercises · Workout (raised centre action) · Progress · Profile. Programs, Ranks and Calories are pushed screens reached from Home and Progress.
- **One transition.** A single page transition, fade plus a slight slide, is defined in `core/router/transitions.dart`. Tabs cross-fade.
- **Tokens.** All durations, curves, springs and motion scales are in `lib/core/theme/motion.dart`. Colours, spacing, radii, sizes and opacities are in the theme folder. Widgets reference only these tokens.

### Tests

- Widget tests render every screen at phone size, and any layout overflow fails the test.
- Golden snapshots are opt-in with `--dart-define=GOLDENS=true`, because pixel-exact goldens differ between operating systems.

## Active workout (Phase 6)

### Persistence and sync

- **Local first.** Every edit to the in-progress workout is written to Hive immediately. Killing the app, losing signal or rebooting never loses a set, and the workout (including a running rest timer) is restored on launch.
- **Server draft.** The server copy (`PUT /workouts/active`) is pushed 4 s after the last change, best-effort. The local copy is always the source of truth.
- **Offline finish.** Finishing offline queues the workout in Hive. The summary shows locally computed duration and volume, and says calories, PRs and ranks will update once it syncs.
  - Queued workouts upload automatically when the Workout tab opens, on pull-to-refresh, or with the "Retry" banner.
  - The server de-duplicates on `clientId`, so a retry can't double-save.
  - A queued workout the server *rejects* (for example, a deleted custom exercise) is dropped, so the queue can't get stuck.
- **What's saved.** Only completed sets are sent, and exercises with no completed sets are dropped. Finishing with zero completed sets offers to discard instead.

### Logging sets

- **Empty fields.** Ticking a set with empty fields fills them from the previous session's values (the ghost text). If there's nothing to fill from, the row shakes and nothing is logged.
- **Rest after warm-ups.** It is half the exercise's rest. No rest timer starts after the final set of the workout.
- **Rest taken.** `restTaken` is recorded on a set when the *next* set is completed: the time between their completion timestamps, capped at 2 h.
- **Set types.** Tapping the set badge cycles working → warm-up → drop set → failure. Warm-ups don't get a number, so working sets are numbered 1, 2, 3.
- **Bodyweight exercises.** The weight column reads "+KG", meaning added load, and an empty weight logs as bodyweight only.

### Timers

- **Rest timer.** It is stored as an absolute `endsAt`, never as a countdown, so it stays correct across backgrounding and restarts.
  - A scheduled local notification fires at `endsAt`, with sound and vibration. It uses an exact alarm when Android grants it and an inexact one otherwise.
  - In the foreground the app also plays haptics and a system alert sound.
  - ±15 s and Skip reschedule or cancel the notification.
- **Session timer.** It can be paused. Paused time is excluded from `activeDurationSec`, which the server uses for calories.
- **Permissions.** Notification permission is requested when the first workout starts, not on app launch.

### Celebration

- **PR celebration.** It plays a hand-authored Lottie burst (`assets/lottie/pr_burst.json`, generated by `tool/gen_pr_burst.mjs`) together with the `confetti` package.
- **Rank-ups.** They appear on the workout summary with the tier badge. The dedicated level-up animation lives on the Ranks screen (Phase 7).

### Code structure

- **Refreshing derived data.** Data derived from workout history (stats, PRs, ranks) refreshes through a `workoutRevisionProvider` counter, which is bumped on finish, sync and delete. This avoids hand-maintained invalidation lists.

## Dashboard, ranks, progress, calories, profile (Phase 7)

### Dashboard

- **Streak.** The dashboard shows the **week** streak, with the day streak as a caption. Rest days shouldn't "break" a lifter's streak.
- **Calories card.** Today's calorie ring measures food eaten against target + workout calories, which is the day's total budget.

### Ranks screen

- **Level-ups.** Celebrated on the next visit to Ranks after a tier rises. The last-seen tiers live in the per-user cache, so they're cleared on logout and another account on the same device starts fresh.
  - The very first visit only records a baseline.
  - The workout summary already shows rank-ups right after a session.
  - The overlay flips the old badge into the new one with the Lottie burst and haptics.
  - When several tiers rose at once, the most important one is shown (overall first) with a "+N more" note.

### Progress screen

- **Periods.** 4, 12 or 26 weeks.
- **e1RM chips.** They come from the ranked lifts that have data. "Other" charts any exercise via the picker.
- **Muscle distribution.** A donut chart of sets (secondary muscles count half, computed server-side).
- **Training calendar.** A GitHub-style heatmap. Cells grow to fill the card for short periods and scroll for long ones.

### Calories screen

- **Remaining.** Calculated as target − eaten + burned, with burned calories labelled as an estimate everywhere.
- **Quick-add presets.** Common foods with standard macro values. A custom entry can leave kcal blank and have it computed from macros (4/4/9 kcal per gram).
- **Changing the goal.** The goal can be changed from the Calories target sheet or from Edit profile. Both update the profile, because the goal lives on the user.

### Offline and data refresh

- **Offline dashboard.** The last overview, ranks and PR responses are cached, so the dashboard and Progress tab render offline.
- **Revision counters.** Bodyweight and calorie entries use their own revision counters, the same pattern as workouts, so dependent views refresh by themselves.

### Testing infrastructure

- `LocalStore` has an in-memory backend for tests, because Hive file I/O never completes inside widget tests' fake-async zone. One test still round-trips the real Hive backend.
- `GlassCard` and `AppBackground` add a transparent `Material` layer so ink splashes from list tiles and buttons on them stay visible.

## Polish (Phase 8)

### Accessibility

- **Contrast.** It is enforced by `test/contrast_test.dart`, which computes WCAG ratios in both themes:
  - primary text ≥ 7:1
  - secondary and muted text ≥ 4.5:1 on the page, card and sheet backgrounds
  - status colours ≥ 3:1

  The test caught muted text at about 3.2:1, which was fixed by brightening it in dark mode and darkening it in light mode.
- **Bold button labels.** White labels on the orange→magenta gradient are held to 3:1. Reaching 4.5:1 with white text would need a muddy brown-orange that defeats the "electric" brand gradient, so this is a deliberate trade-off. To help, the dark-theme orange was deepened slightly (#F25C05).
- **Text scaling.** Every main screen is rendered at 160% text size in `test/screens/text_scale_test.dart`, and any overflow fails the build. This test led to `StatGrid` (rows sized to their content) replacing fixed-ratio grids, and to the workout timer header scaling down instead of clipping.
- **Screen readers.** Interactive custom widgets carry Semantics labels and values (set rows, steppers, badges, rings, timers). Live regions announce the rest countdown.

### Tokens and app polish

- **Tokens.** A final sweep moved the remaining literals into tokens:
  - `AppMotion.tick`, `holdRepeat`, `dragLiftScale` and `panelSlide`
  - `ConfettiTuning`
  - `AppOpacity.overlay`
  - `TierColors` badge shading

  CustomPainters keep their geometric proportions as named constants.
- **Launcher icon.** It is rendered from the theme's gradient and the bolt glyph by `tool/render_icon_test.dart`, then generated for every platform with `flutter_launcher_icons`. The Android adaptive icon uses separate gradient and foreground layers.
- **Native launch screen.** It is near-black on Android and iOS, so there's no white flash on a cold start.
