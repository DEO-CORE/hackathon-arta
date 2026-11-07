# ARTA client (Flutter)

Checks (run from `frontend/`):

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Demo mode

Enabled only by the build flag `--dart-define=USE_DEMO_DATA=true`. Without it the app talks to the API (`API_BASE_URL`); there is no silent switch to demo data.

- Demo data is synthetic and works fully offline. No deals, reservations or requests are created in demo.
- Storage: `<app documents>/demo_data/demo_materials.json` and `demo_data/demo_photos/` (photos are copied there under random names, never to the gallery). "Сбросить демо-данные" in the profile screen deletes the whole folder.
- AI analysis in demo shows a prepared example (`assets/demo/demo-analysis.json`, a copy of `docs/fixtures/demo-analysis.json`), labelled "Симуляция".

### Web limitations (secondary platform)

On web the demo keeps data in memory only: nothing survives a page reload, and picked photos are not displayed (there is no app folder). Persistence and photo preview work on Android and iOS builds.
