# Клиент ARTA (Flutter)

## Запуск в Firefox или другом браузере без Chrome

Сначала запустите API на порту 8000. В `backend/.env` укажите
`CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000`.
Затем из каталога `frontend/` выполните:

```sh
flutter pub get
flutter run -d web-server --web-hostname localhost --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8000
```

Откройте `http://localhost:3000` вручную в Firefox. Команда `-d chrome` требует
установленного Chrome; для web-server он не нужен. Уведомления о новых версиях
пакетов не являются ошибкой запуска. Обновлять зависимости для запуска не требуется.

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
