# MediScan — Build Guide

What you're building: a Flutter app that photographs a medicine pack, reads the
printed name with on-device OCR, looks it up (local DB → AI fallback), shows a
bilingual (English/Urdu) info card, reads it aloud with TTS, and offers an
"Ask AI" follow-up chat — matching the mockup screenshots.

**Architecture**
```
Flutter app (camera + OCR on-device)
   │  sends extracted TEXT only
   ▼
Flask API  ──►  PostgreSQL (medicine DB)
   │
   └──►  Anthropic API (fallback ID + chat)
```
Two folders in this project: `backend/` (Flask) and `flutter_app/` (Flutter).

---

## Part A — Backend (do this first, it's faster to verify)

### 1. Install and run locally
```bash
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...        # console.anthropic.com
python app.py                              # runs on http://localhost:8080, sqlite by default
python seed.py                             # adds Panadol/Brufen/Augmentin sample data
```

### 2. Verify it works
```bash
curl "http://localhost:8080/api/medicines/search?q=panadol"
# → {"found": true, "brand_name": "Panadol", ...}

curl "http://localhost:8080/api/medicines/search?q=totallyunknownbrand"
# → {"found": false, ...}

curl -X POST http://localhost:8080/api/medicines/ai-lookup \
  -H "Content-Type: application/json" \
  -d '{"query": "Disprin"}'
# → AI-generated bilingual entry, now cached in the DB too
```
If these three work, the backend is 100% functional — the Flutter app just
consumes this API.

### 3. Move to PostgreSQL (skip for now if just testing)
Create a Postgres DB (Fly Postgres, Supabase, or local), then:
```bash
export DATABASE_URL=postgresql://user:pass@host:5432/mediscan
python -c "from app import app, db; app.app_context().push(); db.create_all()"
python seed.py
```

### 4. Deploy to Fly.io (matches your existing workflow)
```bash
cd backend
fly launch --no-deploy          # uses the fly.toml already in this folder
fly secrets set ANTHROPIC_API_KEY=sk-ant-...
fly secrets set DATABASE_URL=postgresql://...   # if using Fly Postgres, `fly postgres create` first
fly deploy
```
Note the URL it gives you, e.g. `https://mediscan-api.fly.dev` — you'll need
it in Part B, step 4.

---

## Part B — Flutter app

### 1. Scaffold the project
The `flutter_app/` folder here has `lib/`, `pubspec.yaml`, and permission
snippets, but not the generated `android/`/`ios/` platform folders (those are
machine-specific). Generate them:
```bash
cd flutter_app
flutter create --org com.yourcompany --project-name mediscan .
```
This won't overwrite the `lib/` files already here — it fills in `android/`,
`ios/`, etc. around them.

### 2. Install packages
```bash
flutter pub get
```

### 3. Apply platform permissions
- Open `android/app/src/main/AndroidManifest.xml`, copy in the two
  `<uses-permission>` lines and the `<meta-data>` block from
  `android_config/AndroidManifest_additions.xml`.
- Open `ios/Runner/Info.plist`, copy in the two keys from
  `ios_config/Info_plist_additions.xml`.

### 4. Point the app at your backend
While the Flask server runs locally, the default (`10.0.2.2:8080`, Android
emulator's alias for your host machine) just works. For a real device or
production, pass the URL at build/run time:
```bash
flutter run --dart-define=MEDISCAN_API_BASE=https://mediscan-api.fly.dev
```

### 5. Add the Urdu font (so Urdu always renders, even on devices without a
   system Urdu font)
Download **Noto Nastaliq Urdu** (free, Google Fonts) and place it at:
```
flutter_app/assets/fonts/NotoNastaliqUrdu-Regular.ttf
```
The `pubspec.yaml` already registers this font family.

### 6. Run it
```bash
flutter run
```
Flow to test: Gallery/Camera → pick a clear photo of a medicine pack →
"Identify Medicine" → OCR extracts the name → app queries `/api/medicines/search`
→ card appears → tap play to hear it → toggle English/اردو → tap "Ask AI" and
ask a follow-up question.

### 7. Handle the "not found" path
Photograph something not in your seed data (or type a fake name into your own
test) — you should see the "Couldn't confirm this from our database" card with
a "Try AI identification" button. Tapping it calls `/api/medicines/ai-lookup`,
which the backend also **saves to the DB**, so scanning the same medicine
again next time is instant and no longer needs the AI call.

### 8. Build a release APK/IPA
```bash
flutter build apk --release --dart-define=MEDISCAN_API_BASE=https://mediscan-api.fly.dev
# or
flutter build ipa --release --dart-define=MEDISCAN_API_BASE=https://mediscan-api.fly.dev
```

---

## Why OCR happens on-device, not on the server
`google_mlkit_text_recognition` runs locally on the phone (Google Play
Services on Android, Vision framework on iOS) — no image upload needed, it's
instant, it works offline for the scan step, and it avoids sending a photo of
someone's medicine to a server. Only the extracted *text* (e.g. "Panadol") is
sent to your API. This is also why OCR is Latin-script only in this setup —
printed Urdu on packaging is rare (brand names are almost always in Roman
letters), so this covers the real-world case in the mockup.

## Growing the medicine database
`seed.py` has 3 examples. Realistically you want this DB to have the ~200-500
most common Pakistani-market medicines pre-loaded so the AI fallback is rarely
needed. Two ways to grow it fast:
1. Manually add `Medicine` rows for brands you know (copy the `seed.py`
   pattern) — most reliable, no hallucination risk.
2. Let the AI fallback run in production for a while; every new lookup gets
   cached with `source="ai_generated"`. Periodically query
   `Medicine.query.filter_by(source="ai_generated")` and have a pharmacist
   spot-check them, then flip `source` to `"verified"`.

## Known trade-offs / what "100% working" assumes
- **Urdu TTS**: whether a phone has an Urdu voice installed depends on the
  device (Android's Google TTS engine supports Urdu on most modern phones;
  many iPhones do not have an Urdu voice at all). The "voice not installed"
  label in the mockup is handled by `TtsService.isUrduAvailable()` — this is
  a real device limitation, not something fixable in-app; the best you can do
  is detect it and fall back gracefully, which this code does.
- **OCR accuracy** depends on photo quality/lighting/glare on foil blister
  packs — the `_looksLikeBrandName` heuristic in `ocr_service.dart` picks the
  largest clean text line, which works well for most Pakistani packaging but
  isn't perfect; the AI fallback path is what saves you when OCR guesses
  wrong (send the OCR raw text, not just the guess, if you want to make this
  more robust later).
