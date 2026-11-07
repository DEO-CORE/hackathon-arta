# ARTA — тест-план жизненного цикла партии (мобильный клиент, приоритет 3)

Статус: ПЛАН. Все кейсы имеют статус «план». Ни один кейс не запускался. Тестовый код в `frontend/test/` и `frontend/integration_test/` не написан: flutter-developer ещё меняет `lib/` и тесты материалов; QA начинает после его сигнала. Этот документ не содержит кода тестов.

Дата составления: 2026-11-07. Проверяемые версии кода: не фиксируются (репозиторий не git, проверка кода не выполнялась).

Источники: `docs/api.md` 8.7, 8.8, 18 (18.1, 18.2, 18.6, 18.8, 18.9), `docs/decisions.md` D-08, D-11, D-12, `docs/qa/mobile-test-plan.md`, `race-cases.md`, `authorization-matrix.md`.

Раздел 19 `docs/api.md` (19.1–19.8, A19-1…A19-14) записан и приоритетнее 8.7, 8.8, 18.8; план обновлён по нему (редакция 2). Раздел 19 помечен как предварительная заморозка, **не реализовано**.

**Состояние backend:** маршруты материалов не реализованы (BE-01, BE-03 в статусе todo), поэтому серверные ожидания ниже — контракт, а не поведение работающего кода. Идентификатор «BE-07» в `api.md` не определён; блокером интеграции считается **BE-03** (материалы, publish; archive — там же), как в `api.md`. Кроме того нужны BE-04 (фото) и BE-02 (login).

Обозначения. Ур.: W — widget (fake-репозиторий, метка `FAKE`), I — integration против живого backend (`LIVE-API`), M — ручной. Префикс ID: `LC-`. Прогон на fake/demo не закрывает кейсы, требующие кода ответа от настоящего сервера.

## 1. Переходы состояний

Статусы вычисляет только сервер (18.8, 19.5). Клиент не вычисляет статус из остатков, не отправляет `status`. Переходы `reserved`, `partially_allocated`, `completed` — побочные эффекты резервов/передачи/внутреннего использования; здесь проверяется, что клиент их корректно отображает, и (в I) что сервер их выставляет. Основание ожиданий — 19.2–19.5.

| ID | Ур. | Из состояния | Действие | Ожидаемый результат | Код при запрете |
|---|---|---|---|---|---|
| LC-01 | W/I | draft (все условия выполнены) | publish с актуальной `version` | 200, `status = available`, `version` НЕ изменилась (A19-3), `confirmed_at/by`, `balance` не изменились; клиент заменяет карточку ответом | — |
| LC-02 | I | available | confirm резерва на часть массы | `partially_allocated`, `available_kg` уменьшен, `held_kg` увеличен | — |
| LC-03 | I | available | confirm резерва на всю массу | `reserved`, `available_kg = 0`, `held_kg > 0` | — |
| LC-04 | I | partially_allocated | confirm резерва на весь остаток | `reserved` | — |
| LC-05 | I | reserved | cancel резерва | возврат `available`/`partially_allocated` по остаткам; `held_kg` уменьшен | — |
| LC-06 | I | reserved / partially_allocated | transfer всей массы и завершение | `completed` при `transferred_kg + internally_used_kg = total_kg`, `held_kg = 0` | — |
| LC-07 | I | available (`held_kg = 0`) | archive с актуальной `version` | 200, `archived`, `version` +1 (A19-8), `confirmed_at/by` сохранены; из каталога владельца по умолчанию исчезает (A18-8) | — |
| LC-08 | I | partially_allocated, `held_kg = 0`, `transferred_kg > 0` или `internally_used_kg > 0` | archive | 200 `archived`; `balance` (transferred, used) не изменён, impact-записи и аналитика прежние (A19-6) | — |
| LC-09 | W/I | available | publish с той же `version` | 200 без изменений: ничего не записано, `updated_at` и `version` те же (A19-4, 19.3); клиент молча показывает карточку, без ошибки | — |
| LC-10 | I | reserved | publish с той же `version` | 200 без изменений, статус `reserved` | — |
| LC-11 | I | completed | publish с той же `version` | 200 без изменений | — |
| LC-12 | I | archived | publish | 409 `INVALID_TRANSITION`, `details = {"from": "archived", "action": "publish"}`; клиент ветвится по `details`, не по тексту | 409 `INVALID_TRANSITION` |
| LC-13 | I | reserved (`held_kg > 0`) | archive | 409 `ACTIVE_OBLIGATIONS`, `details.held_kg` (decimal-строка) и `details.reason = "HELD_RESERVATIONS"` (A19-5); НЕ `INVALID_TRANSITION`; партия не изменена | 409 `ACTIVE_OBLIGATIONS` |
| LC-14 | I | partially_allocated, `held_kg > 0` | archive | 409 `ACTIVE_OBLIGATIONS` (как LC-13); после cancel подтверждённых резервов archive проходит | 409 `ACTIVE_OBLIGATIONS` |
| LC-15 | I | draft | archive | 200 `archived` (допустимо, 19.4/19.5); `version` +1 | — |
| LC-16 | I | completed (`held_kg = 0`) | archive | 200 `archived` | — |
| LC-17 | I | archived | archive повторно | с актуальной `version` — 200 без изменений; со старой — 409 `VERSION_CONFLICT` (A19-9); `INVALID_TRANSITION` для archive не возвращается | 409 `VERSION_CONFLICT` |
| LC-18 | I | любое | PATCH с полем `status` | 422 `VALIDATION_ERROR`, `errors[].code = extra_forbidden`, `field = "status"`; статус не изменён | 422 |
| LC-19 | W/I | available, `held_kg = 0` и `transferred_kg = 0` | PATCH `condition`/`city`/`material_type`/`total_kg` или загрузка фото | возврат в `draft` (системный переход), `version` +1, подтверждение сброшено; клиент показывает статус из ответа и чек-лист «что осталось». При `held_kg > 0` или `transferred_kg > 0` — 409 `ACTIVE_OBLIGATIONS` и статус прежний | 409 `ACTIVE_OBLIGATIONS` |
| LC-20 | W | любой | ответ с неизвестным значением `status` | нейтральная подпись, нет падения, кнопки действий скрыты | — |
| LC-21 | W | каждый из 6 статусов | отрисовка карточки (S05) | подпись по 18.8; «Опубликовать» только у draft; «Архивировать» у draft, available, partially_allocated, completed (при `held_kg = 0`); у archived нет ни publish, ни archive | — |
| LC-22 | W | reserved / `held_kg > 0` | карточка | «Архивировать» отключена или скрыта с причиной «есть активные заявки»; сервер всё равно проверяет (LC-13/14) | — |
| LC-23 | I | любое | publish/archive без `version` или не int | 422 `VALIDATION_ERROR`, `field = "version"`, `required` / `invalid_type`; лишнее поле — `extra_forbidden` | 422 |
| LC-24 | I | draft | publish: `version` до и после | равны (A19-3); клиент всё равно берёт версию из последнего ответа | — |
| LC-25 | I | available + pending-резервы (не удерживают запас) | archive (`held_kg = 0`) | 200; pending-резервы в той же транзакции стали `cancelled`, `cancel_reason = "MATERIAL_ARCHIVED"` (A19-7); у buyer в `GET /reservations` видны отменёнными | — |
| LC-26 | I | archived | PATCH, confirm, загрузка фото, internal-use | каждая операция: 409 `INVALID_TRANSITION`, `details = {"from": "archived", "action": "patch|confirm|images|internal-use"}` (A19-11); данные не изменены | 409 `INVALID_TRANSITION` |
| LC-27 | I | партия с сохранённым планом оптимизации | archive | план помечен `is_stale = true` (A19-8); при чтении плана клиент показывает «устарел» | — |
| LC-28 | I | available / partially_allocated / reserved / completed | PATCH `total_kg = "0.000"` | 422 `VALIDATION_ERROR`, `field = "total_kg"`, `code = out_of_range` (A19-12); у draft то же значение допустимо | 422 |

Итого раздел 1: 28.

## 2. Валидация публикации

Правило сервера (19.2): 422 `PUBLISH_REQUIREMENTS_NOT_MET`; `details.missing` — полный список невыполненных из `material_type`, `total_kg`, `condition`, `city`, `images`, `confirmation` в порядке таблицы 19.2; `details.errors[]` согласован с ним (`field` = элемент `missing`, `code = required`). Отдельного кода `CHARACTERISTICS_NOT_CONFIRMED` нет (A19-13). Масса: 0 допустим только у `draft`, публикация требует `> 0` строго (19.6); клиент по массе кнопку локально НЕ блокирует — источник истины ответ сервера. Клиентская проверка нужна для удобства (чек-лист «Что осталось» на S05), но не заменяет серверную: серверные кейсы выполняются прямым вызовом API / fake, отдающим этот ответ.

Таблица «правило — клиент — сервер»:

| Правило | Клиентская проверка (W) | Серверная проверка (I) |
|---|---|---|
| Масса строго > 0 | LC-30 | LC-31 |
| Тип | LC-32 | LC-33 |
| Состояние | LC-34 | LC-35 |
| Город | LC-36 | LC-37 |
| Подтверждение текущей версии | LC-38 | LC-39 |
| Минимум одно фото | LC-40 | LC-41 |

| ID | Ур. | Предусловие | Действие | Ожидаемый результат |
|---|---|---|---|---|
| LC-30 | W | форма черновика, `total_kg` пусто или `0` / `0,000` | Сохранить как черновик | Сохраняется (201/200), 0 допустим у черновика (18.4); значение показано как `0.000`, не ошибка |
| LC-31 | I | черновик с `total_kg = "0.000"`, прочее заполнено | publish | 422 `PUBLISH_REQUIREMENTS_NOT_MET`, `missing` содержит `total_kg`; статус остаётся draft |
| LC-32 | W | у партии нет `material_type` | карточка S05 | в чек-листе «Тип материала»; допустима либо отключённая кнопка, либо отправка с отображением ответа сервера; решение дизайна зафиксировать и тестировать однозначно |
| LC-33 | I | `material_type = null`, остальное готово | publish | 422, `missing` содержит `material_type` |
| LC-34 | W | нет `condition` | S05 | как LC-32 для «Состояние» |
| LC-35 | I | `condition = null` | publish | 422, `missing` содержит `condition` |
| LC-36 | W | `city` пуст | S05 | как LC-32 для «Город» |
| LC-37 | I | `city = null` | publish | 422, `missing` содержит `city` |
| LC-38 | W | `is_confirmation_current = false` | S05 | «Опубликовать» отключена, пункт «Подтвердить характеристики»; кнопка ведёт на подтверждение; клиент не подтверждает автоматически и не подставляет AI-значения |
| LC-39 | I | характеристики изменены после confirm (`is_confirmation_current = false`) | publish | 422, `missing` содержит `confirmation` (не 409, не `PRECONDITION_FAILED`) |
| LC-40 | W | `images = []` | S05 | как LC-32 для «Фото» |
| LC-41 | I | нет фото, остальное готово | publish | 422, `missing` содержит `images` |
| LC-42 | I | не выполнены несколько условий (масса 0, нет фото, нет подтверждения) | publish | 422, `missing` содержит все три; клиент показывает все пункты, а не первый |
| LC-43 | I | подтверждено, затем загружено новое фото (версия +1 сбрасывает подтверждение, 18.7) | publish | 422 `missing = ["confirmation"]`; клиент заранее показывает пункт подтверждения после загрузки (по `is_confirmation_current` из ответа) |
| LC-44 | I | подтверждено, затем PATCH `city` | publish | 422 `confirmation`; (если PATCH вернул партию в draft, см. LC-19) |
| LC-45 | W | сервер возвращает `missing` с неизвестным значением | S05 | неизвестный пункт показан общей строкой, приложение не падает |
| LC-46 | W | ответ 422 `PUBLISH_REQUIREMENTS_NOT_MET` с `missing` и `errors[]` (`field` = элемент missing) | S05 | чек-лист строится по `details.missing`; `errors[].message` допустим как подпись; расхождение missing и errors не ломает UI; `request_id` не показан |
| LC-47 | W | масса `0.000` у черновика, остальное готово | S05 | «Опубликовать» не блокируется локально по массе (19.6); нажатие отправляет запрос, ответ 422 `missing = [total_kg]` превращается в пункт чек-листа «Укажите массу больше нуля»; масса `0.001` проходит клиентскую проверку |
| LC-48 | W | все 6 условий выполнены | S05 | кнопка «Опубликовать» активна, чек-лист пуст или «Готово к публикации»; после нажатия до ответа кнопка отключена |
| LC-49 | I | все условия выполнены, `version` актуальна | publish | 200, `available` (дублирует LC-01 из точки валидации — выполнить один раз) |

Итого раздел 2: 20.

## 3. Ошибки

Порядок проверок (19.1, A19-14): 401 -> 429 -> 403 (роль, раньше владения) -> 404 -> 422 (тело) -> блокировка строки -> 409 `VERSION_CONFLICT` -> повтор/переход -> предусловия.

| ID | Ур. | Сценарий | Ожидаемый результат клиента | Код |
|---|---|---|---|---|
| LC-60 | W/I | buyer вызывает publish (кнопки нет; прямой вызов API) | I: 403 `FORBIDDEN`, партия не изменена. W: панель «Этот раздел недоступен для вашей роли.» | 403 |
| LC-61 | W/I | buyer вызывает archive | то же | 403 |
| LC-62 | W/I | enterprise B публикует партию enterprise A | 404 `NOT_FOUND` (не 403); «Объект не найден или недоступен.»; нет намёка на существование | 404 |
| LC-63 | I | enterprise A архивирует партию B | 404 | 404 |
| LC-64 | W/I | publish/archive несуществующего или невалидного UUID (enterprise) | 404 (A18-5), не 422 | 404 |
| LC-65 | W/I | publish со старой `version` (владелец изменил партию в другой сессии) | 409 `VERSION_CONFLICT`, `details.current_version`; баннер «Обновить данные»; кнопка перечитывает карточку; автоповтора нет. Верно и для уже опубликованной партии (19.3: сначала версия) | 409 |
| LC-66 | W/I | archive со старой `version` | 409 `VERSION_CONFLICT`; клиент перечитывает карточку и сверяет: если она уже `archived`, показывает успех (A19-9), иначе баннер обновления | 409 |
| LC-67 | W/I | archive при активном резерве | 409 `ACTIVE_OBLIGATIONS`, `details.held_kg`, `reason = HELD_RESERVATIONS`; «Нельзя архивировать: есть активные заявки.» (формулировку согласует дизайн); карточка прежняя | 409 |
| LC-68 | W/I | 429 `RATE_LIMITED` на publish/archive (A19-2) | заголовок `Retry-After` целое >= 1 и `details.retry_after_seconds`; клиент берёт поле, иначе заголовок, иначе 30 с; кнопка отключена, обратный отсчёт; автоповтор запрещён; 429 приходит раньше 403/404 (порядок 19.1) | 429 |
| LC-69 | W | быстрые повторные нажатия «Опубликовать» во время запроса и в паузе после 429 | в репозиторий ушёл ровно один вызов; в паузе 0 | — |
| LC-70 | W | 5xx на publish | «Что-то пошло не так. Повторите позже.», «Код обращения: …» (request_id только для 5xx), «Повторить»; статус партии в UI прежний | 5xx |
| LC-71 | W | повтор publish после 5xx/сетевой ошибки | один новый вызов с той же `version` безопасен (повтор идемпотентен, 200 без побочных эффектов, 19.3); повтор archive после ошибки — через перечитывание карточки, т.к. `version` растёт | — |
| LC-72 | W | сеть/таймаут на publish или archive | «Не удалось загрузить данные…» + «Повторить»; для archive перед повтором карточка перечитывается | — |
| LC-73 | W | неверный формат тела ошибки (HTML/пусто) | общий безопасный текст, нет падения | — |
| LC-74 | W | 401 `UNAUTHENTICATED` на publish/archive | сессия очищена, переход на вход «Сессия истекла. Войдите снова.» | 401 |
| LC-75 | I | buyer вызывает publish/archive на ЧУЖУЮ или скрытую (draft) партию | 403 `FORBIDDEN`, не 404: роль проверяется раньше владения (19.1); ответ не раскрывает состояние партии | 403 |

Итого раздел 3: 16.

## 4. Конкурентность

Строка партии блокируется `SELECT ... FOR UPDATE` (19.1); publish не меняет `version`, archive увеличивает на 1. Кейсы выполняются как I с двумя независимыми клиентами/сессиями одного владельца и барьером синхронизации (`race-cases.md`, раздел 1).

| ID | Ур. | Сценарий | Ожидаемый результат | Инвариант |
|---|---|---|---|---|
| LC-90 | I | Два устройства одновременно publish одной партии с одной `version` | Оба 200 `MaterialOut` (второй после блокировки видит `available` и возвращает состояние без изменений, A19-4); недопустимы 500 и 409 `INVALID_TRANSITION` | статус `available`, одно изменение в БД, `version` не изменилась |
| LC-91 | W/I | Второе устройство получило 200 на уже опубликованную | показывает `available`, без баннера ошибки, без «Опубликовать» | клиент берёт состояние из ответа |
| LC-92 | I | publish и archive одновременно на draft, одна `version` | Допустимы два исхода: (publish, archive) — оба 200, итог `archived`; (archive, publish) — archive 200, publish 409 `VERSION_CONFLICT` (версия выросла). Итог всегда `archived`, никогда `available` у архивной | единый статус |
| LC-93 | I | publish конкурирует с PATCH характеристик | PATCH увеличивает `version`: либо publish 409 `VERSION_CONFLICT`, либо publish 200 и затем PATCH возвращает партию в `draft` (при `held = transferred = 0`) | опубликованная партия на момент публикации имела `is_confirmation_current = true`; конечное состояние согласовано (draft + сброшенное подтверждение либо available + подтверждение актуально) |
| LC-94 | I | archive конкурирует с confirm резерва (см. RC-09) | один успех: либо archive 200 и confirm не создаёт held (409/404), либо confirm первым и archive 409 `ACTIVE_OBLIGATIONS` | у archived нет confirmed-резерва, `held_kg = 0` |
| LC-95 | I | publish конкурирует с загрузкой фото (версия +1, сброс подтверждения) | либо publish 409 `VERSION_CONFLICT`/422 `confirmation`, либо фото принято после публикации и партия возвращается в `draft` | нет публикации с неактуальным подтверждением |
| LC-96 | W | Нажатие «Опубликовать» на двух экранах/вкладках | клиент не отправляет повторно сам; второе нажатие — идемпотентный 200 | — |
| LC-97 | I | Два одновременных archive с одной `version` | первый 200 (`version`+1, `archived`), второй 409 `VERSION_CONFLICT` (A19-9); клиент второго перечитывает и видит `archived`; `version` выросла ровно на 1, pending-резервы отменены один раз | один переход, нет двойной отмены |

Итого раздел 4: 8.

## 5. Видимость для покупателя

| ID | Ур. | Сценарий | Ожидаемый результат |
|---|---|---|---|
| LC-100 | I | Партия draft (без публикации) | В `GET /materials` buyer её нет; `GET /materials/{id}` buyer -> 404 |
| LC-101 | I | Партия опубликована (`available`) | Есть в каталоге buyer, поля `MaterialPublicOut`: нет `held_kg`, `transferred_kg`, `internally_used_kg`, `confirmed_by`, контактов, object key |
| LC-102 | I | `partially_allocated` | Есть в каталоге только при `available_kg > 0` (условие выдачи 19.7: `status IN (available, partially_allocated) AND available_kg > 0`), показывается только `available_kg` |
| LC-103 | I | `reserved` / `completed` | Нет в каталоге (A17-8); прямой GET -> 404 |
| LC-104 | I | После archive | Нет в каталоге buyer; прямой GET -> 404; у владельца скрыта по умолчанию, видна по `status=archived`; buyer, у которого была заявка, видит её (отменённую, `MATERIAL_ARCHIVED`) через `GET /reservations`, а не через каталог |
| LC-105 | W | Интерфейс buyer на карточке партии | Нет кнопок «Опубликовать», «Архивировать», «Редактировать», «Подтвердить характеристики»; нет статусов `draft`/`archived` в фильтре |
| LC-106 | I | Партия возвращена в draft после изменения характеристик (LC-19) | Исчезает из каталога buyer сразу (видимость вычисляется на каждом запросе, без кэша); открытая у buyer карточка при обновлении -> 404 «Партия больше недоступна» |
| LC-107 | W | Buyer держит открытый список, партию архивируют | После pull-to-refresh партии нет; открытие устаревшей карточки даёт 404 и текст «Партия больше недоступна» с возвратом к каталогу, без падения (19.7) |
| LC-108 | I | Фото опубликованной партии у buyer | подписанная ссылка выдаётся; для draft/archived — 404 |

Итого раздел 5: 9.

## 6. Идемпотентность

| ID | Ур. | Сценарий | Ожидаемый результат |
|---|---|---|---|
| LC-120 | I | Повторный publish опубликованной партии (последовательно, с той же `version`) | 200 `MaterialOut` без изменений: `version`, `updated_at`, статус те же, записей нет (A19-4); со старой `version` — 409 `VERSION_CONFLICT` |
| LC-121 | W | Клиент не получил ответ publish (таймаут) и повторяет | повтор того же запроса безопасен и даёт 200; UI не показывает ошибку и не создаёт двойного эффекта |
| LC-122 | I | Повторный archive архивированной | с актуальной `version` — 200 без изменений; с версией до архивации — 409 `VERSION_CONFLICT`; клиент перечитывает и показывает `archived`; `version`, остатки, impact не меняются |
| LC-123 | I | Повторная загрузка того же файла фото | ОТКРЫТО: дедупликация в контракте (в т.ч. разделе 19) не описана. Пока ожидаем второй `MaterialImageOut` (201), `version` +1, счёт до лимита 5; UI показывает число фото с сервера. Если backend добавит дедупликацию, обновить кейс |
| LC-124 | W | Повторный выбор того же файла во время загрузки | Выбор заблокирован; вызов репозитория один (MP-18/MP-24) |
| LC-125 | W | Обрыв сети во время загрузки, затем повтор | Перед повтором клиент запрашивает карточку и показывает фактическое число фото; нет «призрачной» плитки (MP-24) |
| LC-126 | I | Повтор загрузки доводит число фото до 6 | 409 `IMAGE_LIMIT_REACHED`, `details.max_images = 5`; лишний файл в Storage не остаётся (проверка вручную, если есть доступ) |

Итого раздел 6: 7.

## 7. Регрессия Фаз 1–2

Все существующие тесты должны проходить без изменений после доработок lifecycle. Файлы на момент составления: `demo_isolation_test.dart`, `login_screen_test.dart`, `material_catalog_test.dart`, `material_create_photo_test.dart`, `material_edit_test.dart`, `material_form_validation_test.dart`, `material_navigation_test.dart`, `material_repository_contract_test.dart`, `material_repository_test.dart`, `material_rules_test.dart`, `material_screens_test.dart`, `router_guard_test.dart`. Фактическое число тестов не посчитано.

| ID | Ур. | Что проверяет | Ожидаемый результат |
|---|---|---|---|
| LC-140 | W | Все тесты `frontend/test/` целиком (`flutter test`) | 0 упавших; число прошедших не меньше значения до изменений (записать при первом прогоне) |
| LC-141 | W | Login и guard (MA-01..MA-26 в части, покрытой `login_screen_test.dart`, `router_guard_test.dart`) | зелёные; редиректы не зависят от новых маршрутов publish/archive |
| LC-142 | W | Материалы: каталог, создание, фото, правка, формы (MP-10..MP-24 в покрытой части) | зелёные; новый `MaterialRepository`-метод publish/archive не ломает `material_repository_contract_test.dart` (fake и live-реализация обязаны вести себя одинаково) |
| LC-143 | W | Демо-изоляция | `demo_isolation_test.dart` зелёный; в Demo publish/archive помечены «демо» и не обращаются к сети |
| LC-144 | W | `flutter analyze`, `dart format` | без замечаний (раздел 9) |

Итого раздел 7: 5.

## 8. Интеграционные тесты против реального backend

Статус всех: **не запущено, блокер BE-03 (материалы, publish, archive — как в `api.md`); дополнительно BE-04 (фото) и BE-02 (login)**. BE-07 в `api.md` не определён и не используется. В `api.md` 18 и 19: не реализовано. До снятия блокера кейсы раздела 8 не засчитываются, а прогон на fake помечается `FAKE`.

Общие предусловия: свежая мигрированная отдельная PostgreSQL; backend запущен с `DEMO_MODE` по решению (mock AI допустим, режим указывать в отчёте); Supabase Storage недоступен — нужен тестовый bucket или backend-fake storage; синтетические пользователи: E1 (enterprise), E2 (enterprise другой организации), B1 (buyer).

| ID | Эндпоинты | Предусловия | Проверка |
|---|---|---|---|
| LC-160 | `POST /auth/register`, `POST /auth/login` | свежая БД | E1, E2, B1 созданы и вошли; токены получены |
| LC-161 | `POST /materials` | токен E1 | 201, `draft`, `version = 1`, `Location` |
| LC-162 | `POST /materials/{id}/images` | draft E1, JPEG тестовый | 201, `material_version` +1, подтверждение сброшено |
| LC-163 | `POST /materials/{id}/confirm` | draft с типом, состоянием, городом, массой > 0 | 200, `is_confirmation_current = true` |
| LC-164 | `POST /materials/{id}/publish` | LC-161..163 | 200, `available`; затем публикация без фото / без подтверждения / с массой 0 -> 422 с нужным `missing` (LC-31, 33, 35, 37, 39, 41, 42) |
| LC-165 | `GET /materials` под B1 | до и после publish | отсутствует до, присутствует после; публичные поля (LC-100, 101) |
| LC-166 | `POST /materials/{id}/publish` под B1 и E2 | партия E1 | 403 и 404 соответственно (LC-60, 62); buyer на чужую/скрытую — 403 (LC-75) |
| LC-167 | `POST /materials/{id}/publish` повтор и с устаревшей `version` | опубликованная партия | 200 без изменений при той же `version`; 409 `VERSION_CONFLICT` со старой, `details.current_version` (LC-09, 65, 120) |
| LC-168 | `POST /reservations`, `PATCH /reservations/{id}` (confirm) под B1 и E1 | `available` партия | `partially_allocated` / `reserved` (LC-02, 03); нужен buyer requirement (`POST /buyer-requirements`) при проверке спроса |
| LC-169 | `POST /materials/{id}/archive` | `reserved`, затем после cancel `available` | 409 `ACTIVE_OBLIGATIONS` (`held_kg`, `reason`), затем 200, `version` +1 (LC-13, 07); партия исчезает из каталога B1 (LC-104); повтор archive со старой `version` — 409 `VERSION_CONFLICT` (LC-17) |
| LC-170 | `PATCH /materials/{id}` | `available` без обязательств | возврат в `draft`, версия +1, подтверждение сброшено (LC-19) |
| LC-171 | `GET /materials?status=archived` под E1 | архивная партия | видна только по фильтру (A18-8) |
| LC-172 | Конкурентные publish/publish, publish/archive, archive/archive (два клиента) | `draft`/`available` | исход по LC-90, 92, 97 |
| LC-173 | Rate limit (429) на publish/archive | лимит достигнут | `Retry-After` и `retry_after_seconds` (LC-68) |
| LC-174 | `POST /materials/{id}/archive`, `GET /reservations` | партия с pending-заявкой B1 | 200; заявка `cancelled`, `cancel_reason = MATERIAL_ARCHIVED`; PATCH/confirm/images/internal-use над архивной -> 409 `INVALID_TRANSITION` (LC-25, 26) |

Итого раздел 8: 15.

Дополнительно, не запущено: единый сквозной сценарий Flutter -> FastAPI (регистрация, партия, фото, подтверждение, публикация, видимость для buyer, архивация) для `integration_test/`; платформа integration_test (Chrome или эмулятор) не настроена и не проверена.

## 9. Команды проверки

Не запускались. Выполнять из `/Users/sm1le/Desktop/ARTA/frontend`, после сигнала flutter-developer.

```sh
cd /Users/sm1le/Desktop/ARTA/frontend
/Users/sm1le/develop/flutter/bin/dart format --output=none --set-exit-if-changed lib test
/Users/sm1le/develop/flutter/bin/flutter analyze
/Users/sm1le/develop/flutter/bin/flutter test
```

Integration (только после настройки платформы и запуска backend, отдельным решением):
`/Users/sm1le/develop/flutter/bin/flutter test integration_test --dart-define=API_BASE_URL=http://127.0.0.1:8000`. Эта команда не проверена: каталога `integration_test` с тестами нет.

Отчёт о прогоне обязан содержать: версию/состояние кода, дату, команду, число прошедших/упавших, метку источника (`FAKE`, `LIVE-API`, `DEMO-REPO`), режим AI.

## 10. Открытые вопросы и закрытые вопросы

Закрыты разделом 19 (ожидания в разделах 1–8 приведены в соответствие; backend ещё не реализован, поэтому «закрыто» = зафиксирован контракт, не поведение кода):

| Бывший вопрос | Решение раздела 19 |
|---|---|
| Q1 archive при `transferred_kg > 0` | разрешён при `held_kg = 0` (A19-6) |
| Q2 возврат из архива | нет (A19-10); publish из archived — 409 `INVALID_TRANSITION` |
| Q3, Q4 archive из draft, completed | разрешён (19.4) |
| Q5 повторный archive | 200 при актуальной `version`, 409 `VERSION_CONFLICT` при старой (A19-9) |
| Q6 `version` при publish | не меняется (A19-3); archive увеличивает на 1 (A19-8) |
| Q7 429 на publish/archive | есть, `Retry-After` и `retry_after_seconds` (A19-2) |
| Q8 повторный и конкурентный publish | 200 без побочных эффектов (A19-4, 19.3) |
| Q10 порядок проверок | 19.1, A19-14: 401, 429, 403, 404, 422, блокировка, 409 версия, переход, предусловия |
| Подтверждение при publish | элемент `confirmation` в `details.missing` 422 (A19-13) |
| Масса 0 | только у draft; publish требует > 0; PATCH 0 вне draft — 422 `out_of_range` (A19-12) |

Остаётся открытым (раздел 19 не покрывает):
- Дедупликация одинаковых фото (LC-123): не описана.
- Q11 (остаток): BE-07 не определён в `api.md`; используется BE-03.
- Проверить по факту реализации: что 403 для buyer на чужую партию действительно приходит раньше 404 (LC-75) — противоречит «согласованному 404» из `CLAUDE.md` §9 для buyer; зафиксировать результат прогона.

## 11. Сводка

| Раздел | Кейсов |
|---|---|
| 1. Переходы состояний | 28 |
| 2. Валидация публикации | 20 |
| 3. Ошибки | 16 |
| 4. Конкурентность | 8 |
| 5. Видимость для покупателя | 9 |
| 6. Идемпотентность | 7 |
| 7. Регрессия Фаз 1–2 | 5 |
| 8. Интеграция с backend | 15 |
| Итого | 108 |

Все 108 кейсов: статус «план», не запущено.
