# IronRank API reference

Base URL: `http://<host>:<PORT>/api/v1` (default port `4000`). On the Android emulator, use `http://10.0.2.2:4000/api/v1`.

## Conventions

| Topic | Rule |
|---|---|
| Auth | Every endpoint except `/auth/*` requires `Authorization: Bearer <accessToken>` |
| Content type | `application/json` |
| Units | All weights are **kilograms**. The `unit` field on the user is a display preference only |
| Dates | Instants are ISO-8601 strings. Calendar days are `YYYY-MM-DD` in the user's local time zone |
| Time zone | Endpoints that group by day accept `tz` (IANA name such as `Europe/Paris`; default `UTC`) |
| Ids | 24-character hex strings. Every resource is returned with an `id` field |

### Pagination

Every list endpoint takes `?page=1&limit=20`. `limit` can be at most 100. Lists return this shape:

```json
{ "data": [ ... ], "page": 1, "limit": 20, "total": 57, "totalPages": 3 }
```

### Errors

Every error uses this shape:

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Request validation failed", "details": [{ "path": "body.email", "message": "Invalid email" }] } }
```

| Status | Typical codes |
|---|---|
| 400 | `BAD_REQUEST` (malformed JSON, bad id cast) |
| 401 | `UNAUTHORIZED`, `INVALID_TOKEN`, `TOKEN_EXPIRED`, `INVALID_CREDENTIALS`, `INVALID_REFRESH_TOKEN`, `REFRESH_TOKEN_REUSED` |
| 403 | `FORBIDDEN` (for example, editing a built-in exercise or template) |
| 404 | `NOT_FOUND`, `ROUTE_NOT_FOUND` |
| 409 | `EMAIL_TAKEN`, `ALREADY_COMPLETED`, `DUPLICATE_KEY` |
| 422 | `VALIDATION_ERROR`, `UNKNOWN_EXERCISE`, `INVALID_WEIGHT`, `PROFILE_INCOMPLETE` |
| 429 | `RATE_LIMITED` |
| 500 | `INTERNAL_ERROR` |

When the app receives `TOKEN_EXPIRED`, it should call `/auth/refresh` and retry the request once.

---

## Health

`GET /health` (outside `/api/v1`) returns `{ "status": "ok", "db": "up" | "down" }`.

---

## Auth

Rate limits are per IP:
- register, login and forgot-password: 20 requests per 15 minutes
- refresh: 120 requests per 15 minutes

### `POST /auth/register`

```json
{ "email": "a@b.dev", "password": "min 8 chars", "username": "2-32 chars" }
```

Returns **201** with:

```json
{ "user": { ... }, "tokens": { "accessToken": "...", "refreshToken": "...", "tokenType": "Bearer" } }
```

### `POST /auth/login`

Request body: `{ email, password }`. Returns **200** with the same shape as register. A wrong email and a wrong password both return `401 INVALID_CREDENTIALS`.

### `POST /auth/refresh`

Request body: `{ "refreshToken": "..." }`. Returns **200** with a new user and token pair.

- The presented token is revoked (rotation). Store the new refresh token.
- Re-using a rotated token returns `401 REFRESH_TOKEN_REUSED` and revokes every session of that login family.

### `POST /auth/logout`

Request body: `{ "refreshToken"?: "...", "allDevices"?: false }`. Returns **204**.

- By default it revokes the given refresh token.
- `allDevices: true` together with a valid bearer token revokes all of the user's refresh tokens.

### `POST /auth/forgot-password`

Request body: `{ email }`. Always returns **202** with `{ "message": "If an account exists..." }`. This is a stub: no email is sent.

Access tokens expire after **15 minutes** and refresh tokens after **30 days**.

---

## Users

### `GET /users/me`

Returns `{ user }`. User fields:

```json
{
  "id": "...", "email": "...", "username": "...", "avatarUrl": null,
  "sex": "male|female|null", "birthDate": "ISO|null", "heightCm": 180, "bodyweightKg": 80,
  "unit": "kg|lb", "activityLevel": "sedentary|light|moderate|active|very_active",
  "goal": "cut|maintain|bulk", "restTimerDefaultSec": 90, "onboardingComplete": true,
  "calorieTargetKcal": null, "createdAt": "...", "updatedAt": "..."
}
```

### `PATCH /users/me`

Takes any subset of: `username`, `avatarUrl`, `sex`, `birthDate`, `heightCm`, `bodyweightKg`, `unit`, `activityLevel`, `goal`, `restTimerDefaultSec`, `onboardingComplete`. Unknown fields are rejected. Changing `bodyweightKg` also appends a history entry.

### `GET /users/me/bodyweight`

Paginated, newest first. Optional `from` and `to` filters. Each item is `{ id, kg, date }`.

### `POST /users/me/bodyweight`

Request body: `{ kg, date? }`. Returns **201** with `{ entry, user }`. `bodyweightKg` always follows the newest entry.

### `DELETE /users/me/bodyweight/:entryId`

Returns **204**.

---

## Exercises

### `GET /exercises`

Paginated and sorted by name. Query parameters:

| Param | Example | Notes |
|---|---|---|
| `q` | `bench` | Case-insensitive substring match on the name |
| `muscle` | `chest,lats` or repeated | Matches primary or secondary muscles |
| `equipment` | `barbell,dumbbell` | |
| `category` | `strength` | One of `strength`, `cardio`, `stretching` |
| `level` | `beginner` | |
| `scope` | `all` / `global` / `custom` | Defaults to `all` (library plus your own custom exercises) |

Exercise shape:

```json
{
  "id": "...", "name": "Barbell Squat", "slug": "barbell-squat",
  "primaryMuscles": ["quadriceps"], "secondaryMuscles": ["glutes", "hamstrings"],
  "equipment": "barbell", "category": "strength", "sourceCategory": "strength",
  "force": "push", "mechanic": "compound", "level": "beginner",
  "instructions": ["..."], "images": ["https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Squat/0.jpg"],
  "metValue": 6, "isBodyweight": false, "liftKey": "squat",
  "isCustom": false, "createdBy": null, "sourceId": "Barbell_Squat"
}
```

- `liftKey` is set when the exercise counts toward a strength rank.
- `isBodyweight: true` means a set's `weight` is *added* load, and a negative value means assistance.

### Other exercise endpoints

- **`GET /exercises/filters`** returns `{ muscles, equipment, categories, levels }`.
- **`GET /exercises/:id`** returns `{ exercise }`.
- **`POST /exercises`** creates a custom exercise and returns **201** with `{ exercise }`.
  - Body: `{ name, primaryMuscles[≥1], secondaryMuscles?, equipment?, category?, level?, instructions?, images?, metValue?, isBodyweight? }`.
- **`PATCH /exercises/:id`** updates your own custom exercise. Library exercises return **403**.
- **`DELETE /exercises/:id`** deletes your own custom exercise and returns **204**.

---

## Programs

Program shape. `exercise` is an inlined summary of the referenced exercise:

```json
{
  "id": "...", "userId": null, "name": "5x5 Strength", "description": "...", "weeks": 12,
  "isTemplate": true, "templateKey": "strength-5x5", "sourceTemplateId": null,
  "isActive": false, "activatedAt": null,
  "days": [{
    "id": "...", "name": "Workout A",
    "exercises": [{
      "id": "...", "exerciseId": "...", "sets": 5, "repRange": { "min": 5, "max": 5 },
      "targetRPE": null, "restSeconds": 180, "notes": "",
      "exercise": { "id": "...", "name": "Barbell Squat", "image": "https://...", "primaryMuscles": ["quadriceps"], "equipment": "barbell", "category": "strength", "isBodyweight": false }
    }]
  }]
}
```

The built-in templates are `ppl`, `upper-lower`, `full-body-3x` and `strength-5x5`.

| Method | Path | Description |
|---|---|---|
| GET | `/programs?scope=all\|mine\|templates` | Paginated. Active program first |
| POST | `/programs` | Create. Body: `{ name, description?, weeks?, days: [{ name, exercises: [{ exerciseId, sets?, repRange?, targetRPE?, restSeconds?, notes? }] }] }`. Returns **201** |
| GET | `/programs/:id` | Returns a template or one of your own programs |
| PATCH | `/programs/:id` | Partial update. Send the full `days` array to reorder or edit. Templates return **403** |
| DELETE | `/programs/:id` | Returns **204** |
| POST | `/programs/:id/clone` | Copies into your programs and returns **201** `{ program }` |
| POST | `/programs/:id/activate` | Makes it your only active program. A template is cloned first, and the clone is returned |
| GET | `/programs/active` | Returns `{ program, nextDay: { index, id, name, exercises }, lastSession }`. All values are `null` when nothing is active |
| DELETE | `/programs/active` | Deactivates the current program and returns **204** |

`nextDay` rotates through the days in order. It continues after the most recent completed workout whose `programId` is the active program.

---

## Workouts

Session shape:

```json
{
  "id": "...", "clientId": "uuid-from-device", "status": "completed", "name": "Workout A",
  "programId": null, "dayId": null,
  "startedAt": "...", "endedAt": "...", "durationSec": 3600, "activeDurationSec": 3000,
  "exercises": [{
    "_id": "...", "exerciseId": "...", "exerciseName": "Barbell Squat", "restSeconds": 180, "notes": "",
    "sets": [{ "_id": "...", "weight": 100, "reps": 5, "rpe": 8, "type": "warmup|working|dropset|failure", "completed": true, "restTaken": 175, "completedAt": "..." }]
  }],
  "notes": "", "totalVolume": 2500, "caloriesBurned": 410, "bodyweightKg": 82, "prCount": 3
}
```

- `totalVolume` is the sum of weight × reps over completed sets, excluding warm-ups.
- `caloriesBurned` is an estimate: MET × bodyweight × active hours.

### `POST /workouts`

Saves a finished workout. Body fields:

| Field | Required | Notes |
|---|---|---|
| `clientId` | yes | Generated on the device |
| `startedAt` | yes | |
| `endedAt` | no | Defaults to now |
| `activeDurationSec` | no | |
| `name` | no | |
| `programId` | no | |
| `dayId` | no | |
| `notes` | no | |
| `exercises` | no | `[{ exerciseId, restSeconds?, notes?, sets: [{ weight, reps, rpe?, type?, completed?, restTaken?, completedAt? }] }]` |

Returns **201**, or **200** when the same `clientId` was already saved (this makes retries safe):

```json
{
  "session": { ... },
  "newPRs": [{ "exerciseId": "...", "exerciseName": "Barbell Squat", "exerciseImage": "https://...", "type": "e1rm", "value": 116.7, "previousValue": 110, "weight": 100, "reps": 5, "achievedAt": "..." }],
  "rankChanges": [{ "key": "squat", "name": "Squat", "from": "Silver", "to": "Gold", "direction": "up" }],
  "calories": { "kcal": 410, "isEstimate": true, "usedDefaultBodyweight": false }
}
```

- `newPRs` only lists improvements over earlier history. The first value ever logged is stored as a baseline and is not celebrated.
- Saving a workout discards any in-progress draft.

### Other workout endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/workouts?from=&to=` | Completed workouts, newest first, paginated |
| GET | `/workouts/:id` | Returns `{ session }` |
| PATCH | `/workouts/:id` | Body: any of `{ name, notes, startedAt, endedAt, activeDurationSec, exercises }`. Recomputes totals, PRs and ranks, and returns `{ session, rankChanges }` |
| DELETE | `/workouts/:id` | Recomputes PRs and ranks. Returns **204** |
| GET | `/workouts/active` | Returns `{ session \| null }`, the server copy of the in-progress workout |
| PUT | `/workouts/active` | Creates or replaces the draft. Body is the same as `POST /workouts` without `endedAt`. Returns **409 `ALREADY_COMPLETED`** if this `clientId` was already saved |
| DELETE | `/workouts/active` | Discards the draft. Returns **204** |
| GET | `/workouts/previous?exerciseIds=a,b` | Returns `{ previous: { [exerciseId]: { sessionId, date, sets: [{ weight, reps, rpe, type }] } \| null } }`, the sets from the last session for ghost text |

---

## Personal records

PR types:

| Type | `value` unit | Meaning |
|---|---|---|
| `maxWeight` | kg | Heaviest weight lifted |
| `maxRepsAtWeight` | reps | Most reps at a given `weight` |
| `e1rm` | kg | Best estimated one-rep max (Epley formula, sets of 12 reps or fewer) |
| `maxVolumeSet` | kg × reps | Highest weight × reps in a single set |

Only completed `working` and `failure` sets count.

### `GET /prs`

Paginated, newest first.
- Optional `type` filter.
- `includeBaselines=true` also returns first-time values.

Each item includes `exercise: { id, name, image }`.

### `GET /prs/:exerciseId`

Takes `?page&limit`. Returns:

```json
{
  "current": {
    "maxWeight": { "value": 105, "weight": 105, "reps": 3, "achievedAt": "...", "sessionId": "..." },
    "e1rm": { ... }, "maxVolumeSet": { ... },
    "repsAtWeight": [{ "weight": 100, "reps": 8 }]
  },
  "history": { "data": [ ...records incl. baselines ], "page": 1, "limit": 20, "total": 9, "totalPages": 1 }
}
```

---

## Ranks

### `GET /ranks`

```json
{
  "sex": "male", "assumedSex": false,
  "tiers": ["Bronze", "Silver", "Gold", "Platinum", "Diamond", "Elite", "Legend"],
  "overall": { "ranked": true, "liftsRanked": 3, "tierIndex": 3, "tier": "Platinum", "nextTier": "Diamond", "progress": 15, "score": 3.15 },
  "lifts": [{
    "key": "bench_press", "name": "Bench Press", "ranked": true,
    "ratio": 1.21, "e1rm": 99.2, "bodyweightKg": 82, "achievedAt": "...", "exerciseId": "...",
    "tierIndex": 3, "tier": "Platinum", "nextTier": "Diamond", "progress": 44,
    "nextThreshold": 1.35, "nextTierE1rm": 110.7, "thresholds": [0, 0.6, 0.85, 1.1, 1.35, 1.6, 2.0], "score": 3.44
  }, { "key": "dips", "name": "Dips", "ranked": false, "thresholds": [ ... ] }],
  "muscleGroups": [{ "group": "chest", "ranked": true, "tier": "Platinum", "progress": 44, ... }, { "group": "core", "ranked": false }]
}
```

- **Ratio:** the best e1RM ÷ bodyweight over the last 365 days.
- **Pull-ups and dips:** the e1RM includes bodyweight.
- **Muscle groups:** chest, back, shoulders, arms, legs and core. Each is a weighted average of the lifts that train it.
- **Overall:** a weighted average across lifts. The weights are in `src/config/strengthStandards.json`.
- **`assumedSex`:** when the profile has no sex, male standards are used and this field is `true`.

---

## Stats

### `GET /stats/overview?weeks=12&tz=Europe/Paris`

```json
{
  "range": { "from": "2026-07-20", "to": "2026-10-13", "weeks": 12, "tz": "Europe/Paris" },
  "totals": { "sessions": 30, "volume": 152000, "durationSec": 108000, "calories": 12000, "prs": 14, "avgSessionsPerWeek": 2.5 },
  "streak": { "days": 1, "weeks": 6 },
  "weekly": [{ "weekStart": "2026-07-20", "sessions": 3, "volume": 14000, "durationSec": 10800 }],
  "muscleDistribution": [{ "group": "chest", "sets": 42, "percent": 18.3 }],
  "heatmap": [{ "date": "2026-10-13", "sessions": 1, "volume": 6000 }],
  "lastWorkoutAt": "...", "daysSinceLastWorkout": 0
}
```

- Weeks start on Monday.
- A streak isn't broken until the current day or week has ended.
- In the muscle distribution, a primary muscle earns 1 per set and a secondary muscle 0.5.

### `GET /stats/exercise/:exerciseId?page=1&limit=50`

Returns the e1RM history, newest first:

```json
{
  "exercise": { "id": "...", "name": "...", "image": "..." },
  "bests": { "e1rm": { "value": 126.7, ... }, "maxWeight": { ... }, "maxVolumeSet": { ... } },
  "data": [{ "sessionId": "...", "date": "...", "bestE1rm": 126.7, "topSet": { "weight": 100, "reps": 8 }, "sets": 2, "volume": 1600 }],
  "page": 1, "limit": 50, "total": 2, "totalPages": 1
}
```

---

## Calories

### `GET /calories`

- `?date=YYYY-MM-DD&tz=` returns one day. It defaults to today in `tz`:

```json
{
  "date": "2026-10-13",
  "entries": [{ "id": "...", "name": "Oats", "kcal": 400, "protein": 15, "carbs": 60, "fat": 8, "loggedAt": "..." }],
  "consumed": { "kcal": 650, "protein": 55, "carbs": 60, "fat": 8 },
  "targetKcal": 2204,
  "burned": { "kcal": 480, "workouts": [{ "id": "...", "name": "Workout A", "kcal": 480, "durationSec": 3600 }] },
  "remainingKcal": 2034
}
```

- `?from=&to=&page=&limit=` returns a paginated list of days: `{ date, targetKcal, consumed, entryCount }`.

### Other calorie endpoints

- **`POST /calories/entries`** adds an entry and returns **201** with the day view.
  - Body: `{ date, tz?, name, kcal, protein?, carbs?, fat? }`.
- **`DELETE /calories/entries/:entryId`** returns **204**.

### `GET /calories/target`

```json
{
  "customTargetKcal": null, "effectiveTargetKcal": 2204, "goal": "cut",
  "tdee": {
    "age": 32, "bmr": 1777, "activityFactor": 1.55, "tdee": 2755, "goal": "cut",
    "targets": { "cut": { "kcal": 2204, "macros": { "proteinG": 180, "fatG": 61, "carbsG": 233 } }, "maintain": { ... }, "bulk": { ... } },
    "recommendedKcal": 2204
  },
  "profileIncomplete": false, "missing": []
}
```

- The calculation uses Mifflin-St Jeor × activity factor.
- A cut is −20% (never below 1500 kcal for men or 1200 kcal for women).
- A bulk is +10%.
- When the profile is missing data, `tdee` is `null` and `missing` lists the fields that are needed.

### `PUT /calories/target`

Body: `{ targetKcal?: number|null, goal?: "cut|maintain|bulk", date? }`.
- `null` clears a manual target and goes back to the TDEE recommendation.
- `date` also updates that day's stored target.

Returns the same shape as `GET /calories/target`.
