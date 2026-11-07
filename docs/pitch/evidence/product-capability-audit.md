# Аудит возможностей рабочего MVP ARTA

Дата: 2026-11-08. Автор: qa-engineer. Код `backend/` и `frontend/` не менялся, в git ничего не добавлялось.

Метки:
- **VERIFIED** — есть автотест или воспроизведённый запуск; указано, какой.
- **PARTIAL** — работает с названным ограничением.
- **SIMULATED** — работает только в mock или демо-режиме.
- **PLANNED** — не реализовано (или есть только схема/документ).

## 1. Что запускалось в этой сессии

| Проверка | Команда | Результат |
|---|---|---|
| Backend | из `backend/`: `TEST_DATABASE_URL='postgresql+psycopg://arta@127.0.0.1:54329/arta_be_test' .venv/bin/python -m pytest -q -p no:cacheprovider` | `215 passed, 2 warnings in 79.24s` (БД `arta_be_test`; `arta_r1_device` не трогалась) |
| Flutter | из `frontend/`: `/Users/sm1le/develop/flutter/bin/flutter test` | `+235: All tests passed!` |

Итого 450 автотестов (215 + 235), по одному прогону. Предупреждения backend: устаревший `httpx` в starlette testclient и короткий HMAC-ключ в тестовом JWT (тестовая конфигурация).

Оговорка: тесты ниже названы по именам из файлов; отдельно по одному я их не запускал, они входят в общий зелёный прогон 215. `ruff`, `flutter analyze`, `dart format` не запускались. Измерения покрытия, нагрузки и p95 нет. Рабочее дерево не зафиксировано коммитом (см. `demo-traction-verification.md` §1). `adb` на этой машине не найден в PATH, поэтому прогоны на телефоне здесь не повторялись: пометки «на устройстве» взяты из отчётов `docs/qa/` от 2026-11-07 (Xiaomi Redmi Note 14S, debug-сборка).

## 2. Таблица возможностей

| № | Возможность | Метка | Основание и ограничение |
|---|---|---|---|
| **ИИ-анализ фото** | | | |
| 1 | Backend `POST /ai/analyze` (202) и `GET /ai/analyses/{id}` через mock-провайдер | SIMULATED | `test_ai_mock_confirmation_stale_and_isolation` (входит в 215). Mock отдаёт один и тот же файл `app/fixtures/demo-analysis.json` для любого фото и разрешён только при `DEMO_MODE=true` |
| 2 | Живой vision-провайдер | PLANNED | `VISION_PROVIDER=http_json` — договорной адаптер к шлюзу; шлюза, ключа и вендора нет (BLK-02). Живой вызов не выполнялся |
| 3 | Валидация ответа ИИ, запрет выдуманного состава, mock не включается молча | VERIFIED | `test_vision_forbids_inferred_composition_and_inconsistent_confidence`, `test_vision_configuration_cannot_silently_enable_mock` |
| 4 | Сбой/отключённый ИИ не блокирует ручное подтверждение | VERIFIED | `test_disabled_ai_fails_without_blocking_manual_confirmation`. Таймаут и недоступность реального провайдера не проверялись |
| 5 | Экран анализа в приложении | SIMULATED | В демо-режиме (`USE_DEMO_DATA=true`) результат строит клиент, плашка «Симуляция»; на устройстве AI-SIM-03 PASS. Состав всегда «Неизвестно» |
| **Подтверждение характеристик** | | | |
| 6 | Человек подтверждает характеристики; проверка `version`; изменение инвалидирует анализ | VERIFIED | `test_ai_mock_confirmation_stale_and_isolation`, `test_materials.py`; `VERSION_CONFLICT` 409 в `services/materials.py` |
| 7 | Подтверждение кнопкой с экрана анализа на телефоне | PARTIAL | Кнопка и код есть, на устройстве не проверялось (AI-SIM-06 NOT TESTED). Подтверждение на экране партии проверено (отчёт 2026-11-07) |
| **Matching** | | | |
| 8 | Детерминированные правила, оценка 0–100 (город 30, применение 30, покрытие спроса 40), коды исключения, объяснения | PARTIAL | `POST /ai/match`, `test_match_optimize_stale_and_permissions`, `test_unknown_cost_and_application_excluded`. Тесты не проверяют отдельно компоненты и порядок при равном score; причины совпадения статичны |
| 9 | Экран matching в приложении | PLANNED | В `frontend/lib/features` нет каталога matching; на телефоне не показывался |
| **Оптимизация распределения** | | | |
| 10 | MILP (SciPy `milp`, HiGHS) находит известный оптимум на малом наборе | VERIFIED | `test_shared_capacity_minimum_and_baseline` (оптимум 60, план `[0, 10, 10]`, `optimal`), `test_large_lots_do_not_hit_semi_integer_solver_cap`. Один маленький набор, не доказательство для произвольных данных |
| 11 | Статусы, которые реально возвращает код | PARTIAL | `optimizer.py` выдаёт только `optimal`, `feasible`, `heuristic`. `feasible` (лимит времени с найденным решением) отдельным тестом не покрыт |
| 12 | Резерв greedy (`greedy-v1`) с явным статусом `heuristic` и проверкой ограничений | VERIFIED | `test_timeout_without_incumbent_uses_feasible_baseline` (solver без решения -> `heuristic`, план = baseline), `test_fractional_mass_and_invalid_plan` |
| 13 | Воспроизводимость плана | PARTIAL | Сортировка стабильна, seed не нужен, но теста «два запуска дают одно и то же» нет |
| 14 | Статусы `infeasible`, `timeout`, `error` | PLANNED | Разрешены схемой, код их не выдаёт; таймаут без решения превращается в `heuristic` |
| 15 | Сравнение с baseline в каждом плане | PARTIAL | `delta_vs_baseline_kgs` считается; baseline — жадный алгоритм; улучшения на реальных данных не доказаны. Ценности внутреннего использования и переработки задаёт пользователь |
| 16 | Экран плана в приложении | PLANNED | Во Flutter нет экрана оптимизации |
| **Жизненный цикл резерва** | | | |
| 17 | pending -> confirmed -> transferred -> completed; отмена; удержание и возврат остатка | VERIFIED | `test_full_lifecycle_and_analytics`, `test_full_chain_catalog_to_transactions`, `test_cancel_confirmed_releases_stock_and_demand`, `test_permissions_and_invalid_transitions`, `test_buyer_reads_own_status_and_cancels_only_pending` |
| 18 | Конкурентность: заявки больше остатка | VERIFIED | `test_concurrent_reservations_cannot_oversell`, `test_concurrent_confirms_above_available_one_wins`, `test_shared_demand_is_locked_across_materials`, `test_concurrent_reuse_cannot_exceed_transfer`. Два потока, PostgreSQL; нагрузка и повторы N=20 не выполнялись (`backend/tests/race/` нет) |
| 19 | Идемпотентность | VERIFIED | `test_idempotent_replay_creates_one_transaction`, `test_idempotency_and_cancel`, `test_concurrent_same_key_creates_one_reservation`, `test_business_conflict_replayed_after_stock_changes` |
| 20 | Одна активная заявка покупателя на партию | VERIFIED | `test_one_active_reservation_per_buyer_and_material` |
| **Сценарий поставщика** | | | |
| 21 | Создать, изменить, подтвердить, опубликовать, архивировать партию | VERIFIED | `test_materials.py`, `test_internal_use_archive_and_validation`; на устройстве создание/подтверждение/публикация по отчёту 2026-11-07 |
| 22 | Загрузка фото | PARTIAL | Валидация формата, размера, чужой партии: `test_images.py`, `test_image_validation.py`. С телефона: в демо-режиме через пикер PASS; в API-режиме фото в прогоне загружено запросом API. Хранилище локальное, не Supabase |
| 23 | Подтвердить/отклонить резерв, передать | VERIFIED | Тесты п. 17; на устройстве диалог «Будет удержано 12,5 кг», статус «Передано» (отчёт). Отказ требует причину (диалог в `reservation_dialogs.dart`) |
| 24 | Внутреннее использование и подтверждение использования (`/materials/{id}/internal-use`, `/transactions/{id}/reuse-confirmation`) | PARTIAL | Backend VERIFIED (`test_internal_use_archive_and_validation`, `test_concurrent_reuse_cannot_exceed_transfer`); во Flutter экранов для этих действий нет |
| 25 | Экран истории сделок | PLANNED | Отсутствует. Есть `GET /transactions` на backend (VERIFIED в `test_full_chain_catalog_to_transactions`) и метод `transactions()` в репозитории Flutter, но ни один экран его не вызывает |
| **Сценарий покупателя** | | | |
| 26 | Каталог: поиск и фильтры | VERIFIED | `test_catalog_search_and_filters`, `test_catalog_aliases_and_missing_details`; фильтры в `buyer_catalog_filters.dart`, widget-тесты в 235; на устройстве поиск PASS |
| 27 | Карточка партии, количество, заявка | PARTIAL | Backend VERIFIED. В прогоне на устройстве заявка 12,5 кг помечена как созданная через API; кнопку на телефоне перед показом проверить |
| 28 | Статус заявки и подтверждение получения | VERIFIED | Тесты п. 17; на устройстве `completed`, `receipt_confirmed_at` заполнен (отчёт) |
| 29 | История сделок покупателя на экране | PLANNED | См. п. 25 |
| **Переработчик** | | | |
| 30 | Переработчик = организация `buyer` с видом деятельности `recycler`; те же экраны и права покупателя | PARTIAL | Вход на главный экран на устройстве (`live/07_recycler_home.png`); отдельного функционала нет |
| 31 | Специальное право `recycling.operate` | PLANNED | Определено в `core/permissions.py` (MANAGER), ни один маршрут его не требует (grep по `app/` находит только определение) |
| **Администратор** | | | |
| 32 | `/admin/api/*`: сводка, записи, доступ пользователей, проверка членств (activate/reject) | VERIFIED | `test_admin.py`, `test_pending_review.py` |
| 33 | Веб-страница `/admin` | PARTIAL | В `backend/app/admin_ui/` есть статическая страница (`index.html`, `admin.js`); экрана во Flutter нет; в браузере мной не открывалась |
| **Подтверждение email** | | | |
| 34 | Код `7777` в демо-режиме | SIMULATED | `test_demo_code_7777_only_in_demo_mode`, `test_startup_rejects_demo_with_production_signs` |
| 35 | Остальная логика кода (срок, 5 попыток, лимиты, нет утечки) | VERIFIED | `test_email_confirmation.py` (expired, five_wrong_attempts, resend_cooldown, new_code_invalidates) |
| 36 | Реальная отправка писем | PLANNED | Провайдера почты нет; без него доставка отвечает 503 (`test_delivery_unavailable_without_provider_is_503_for_any_email`) |
| **Аналитика** | | | |
| 37 | Сводка `GET /analytics/summary`: registered, available, distributed, internally used, confirmed reuse, revenue (только завершённые), allocation efficiency, отдельный блок `forecast` (label `expected`, не выручка) | VERIFIED | `test_full_lifecycle_and_analytics`. Покупателю: received, spent, active reservations. Конкретные суммы проверены на одном сценарии |
| 38 | Экран аналитики | PLANNED | Во Flutter нет; на телефоне не показывалась |
| 39 | CO2 и экологический эффект | PLANNED | Не вычисляется (нет методики) |
| **Инфраструктура** | | | |
| 40 | Supabase Storage, подписанные ссылки, облачный деплой | PLANNED | Используется локальное хранилище и сервер на `127.0.0.1` |

## 3. Подсчёт меток

Считалось по таблице §2 (40 строк).

| Метка | Строк |
|---|---|
| VERIFIED | 16 |
| PARTIAL | 10 |
| SIMULATED | 3 |
| PLANNED | 11 |

## 4. Расхождения с существующими файлами evidence

- Строка 12: `optimization-claims-verification.md` писал, что для ветки с отсутствием решения у solver есть только тест `x=None` -> `heuristic`. Сейчас в файле есть `test_timeout_without_incumbent_uses_feasible_baseline`, но он тоже ожидает `heuristic`, не `feasible`. Метка `feasible` остаётся PARTIAL (строка 11).
- Строка 33: `demo-traction-verification.md` §5 п. 9 говорит «нет экрана администратора» — это верно для Flutter, но в backend есть статическая страница `/admin`; помечено PARTIAL, а не PLANNED.
- Строка 24: внутреннее использование и подтверждение использования реализованы на backend и проверены тестами, но в UI отсутствуют. В питче нельзя показывать «подтверждённое использование» как экран.
- Строка 5 и 1 разделены: симуляция клиента (без вызова API) и backend mock — разные пути, оба SIMULATED.
- Остальные метки совпадают с `demo-traction-verification.md`, `ai-claims-verification.md`, `optimization-claims-verification.md`.

## 5. Что нельзя утверждать в питче по итогам аудита

- Живой ИИ, рекомендации по составу, письма с кодом, оптимизатор и matching «на экране», аналитика «на экране», история сделок на телефоне, CO2.
- Нагрузочная проверка и «проверено на парке устройств».
- Можно: «партия, подтверждение человеком, заявка, резерв, передача, получение работают на backend (215 тестов) и по отчёту проходили на одном телефоне; ИИ — симуляция; данные синтетические».
