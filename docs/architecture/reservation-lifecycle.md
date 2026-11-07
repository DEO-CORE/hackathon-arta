# Жизненный цикл заявки (reservation)

## Состояния и склад

| Статус | Что происходит с массой партии |
| --- | --- |
| `pending` | Ничего не удерживается. |
| `confirmed` | `available_kg -= q`, `held_kg += q`; у потребности `remaining_demand_kg -= q`. |
| `transferred` | `held_kg -= q`; `transferred_kg += actual`; разница `q - actual` возвращается в `available_kg` и в спрос. Создаётся `transaction`. |
| `completed` | Масса не меняется; `receipt_confirmed_at` фиксируется покупателем. |
| `cancelled` | Из `confirmed`: удержание и спрос возвращаются. Из `pending`: ничего не менялось. |

Баланс: `total = available + held + transferred + internally_used`, все части >= 0.

## Действия по ролям

| Действие | Кто | Из | В |
| --- | --- | --- | --- |
| create | покупатель (`reservation.create`) | - | `pending` |
| confirm | продавец (`reservation.approve`) | `pending` | `confirmed` |
| transfer | продавец | `confirmed` | `transferred` |
| complete | покупатель (`reservation.receive`) | `transferred` | `completed` |
| cancel | продавец (причина обязательна) | `pending`, `confirmed` | `cancelled` |
| cancel | покупатель (причина необязательна) | только `pending` | `cancelled` |

Чужая заявка - 404 (до проверки прав). Недопустимый переход - 409 `INVALID_TRANSITION`. Повтор действия, уже приведшего в целевой статус, - 200 без побочных эффектов. Одна активная заявка (`pending`/`confirmed`) на пару покупатель-партия: 409 `ACTIVE_RESERVATION_EXISTS`.

Порядок блокировок: партия -> потребность -> заявка -> транзакция. Доступность и спрос перепроверяются внутри транзакции БД; конфликт - 409.

## Аудит

`audit_log`: `reservation.created`, `.confirmed`, `.cancelled`, `.transferred`, `.completed`; `actor_user_id`, `organization_id`, `target_id` = id заявки, `details` = `material_id`, `quantity_kg`, `from` (и `transferred_kg` при передаче). Контакты и тексты причин не пишутся. Запись делается в той же транзакции, что и изменение; повтор без перехода записи не создаёт.

## Неизменяемость completed

После `completed` ни одно действие не меняет заявку или сделку (кроме отдельного подтверждения использования `reuse-confirmation`, которое добавляет факт, а не правит сделку). Явный процесс исправления (корректировка сделки с аудитом) **отложен** и не реализован.
