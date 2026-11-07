# ARTA: контракт совместимости, matching и оптимизации (CON-03)

Статус: черновик спецификации v1 для утверждения оркестратором. Код не написан.
Владелец: optimization-engineer. Общие DTO живут в `backend/app/schemas/optimization.py` (файл принадлежит backend-engineer, изменения предлагает optimization-engineer).
Основание: `CLAUDE.md` §5, §7, §8; `docs/decisions.md` D-02 (SciPy `milp`), D-03 (расположение), D-04 (одна функция), D-05 (Decimal), D-10 (допущения).

Версии, которые фиксирует этот документ:

| Константа | Значение |
| --- | --- |
| `MATCH_RULES_VERSION` | `match-rules-v1` |
| `ALLOCATION_MODEL_VERSION` | `alloc-v1` |
| `BASELINE_VERSION` | `baseline-v1` |
| `SNAPSHOT_SCHEMA_VERSION` | `1` |

Любое изменение весов, порядка фильтров или модели увеличивает версию. Веса не меняются скрыто.

## 1. Модули и границы

- `backend/app/optimization/compatibility.py`: `is_compatible`, enum, типы фактов.
- `backend/app/optimization/matching.py`: `rank_requirements` (скоринг и сортировка).
- `backend/app/optimization/allocator.py`: сборка модели, `milp`, округление, проверки, baseline, fallback.
- Модуль чистый: без БД, без сети, без LLM, без чтения `backend/app/ai/`. Он не резервирует массу, не меняет статус партии и не создаёт заявки. План есть рекомендация.
- Входные факты о партии берутся только из подтверждённых человеком характеристик, не из сырого AI JSON.
- Все массы и деньги: `Decimal`; в JSON строки (D-05). Исключение: внутри вызова `scipy.optimize.milp` числа неизбежно `float`; результат пересчитывается в `Decimal` и проверяется (раздел 6).

## 2. Единая функция совместимости

### 2.1 Сигнатура

```python
def is_compatible(
    material: MaterialFacts,
    demand: DemandFacts,
    rules: RuleSet = RULES_V1,
) -> CompatibilityResult: ...
```

Функция чистая и детерминированная. Её вызывают и `matching.rank_requirements`, и `allocator` (при построении множества допустимых пар). Тест импортирует обе точки и проверяет, что они ссылаются на один и тот же объект функции, а на наборе пар дают одинаковые решения.

### 2.2 Входы

`MaterialFacts` (подтверждённые данные на конкретной `version`):

| Поле | Тип | Примечание |
| --- | --- | --- |
| `material_id` | UUID | |
| `version` | int | версия, на которой дано подтверждение |
| `confirmed` | bool | нет подтверждения на текущей version: исключение |
| `status` | enum статусов партии | допустимы только `available`, `partially_allocated` |
| `material_type` | enum или `None` | |
| `condition` | enum или `None` | |
| `applications` | `frozenset[ApplicationEnum]` | подтверждённые способы применения; пусто означает «неизвестно» |
| `city` | `str` или `None` | сравнение после нормализации (trim, casefold) |
| `available_kg` | Decimal | свободный остаток, ≥ 0 |
| `price_per_kg_kgs` | Decimal или `None` | `None` не равно нулю |

`DemandFacts` описывает потребность любого вида одним типом:

| Поле | Тип | Примечание |
| --- | --- | --- |
| `option_id` | str | для покупателя `req:<requirement_id>`, для внутреннего использования `int:<id>` |
| `kind` | `DirectionKind` | `sale`, `recycling`, `internal_use` |
| `requirement_id` | UUID или `None` | `None` только для `internal_use` |
| `organization_id` | UUID или `None` | |
| `accepted_types` | `frozenset[MaterialType]` | должно быть непусто |
| `accepted_conditions` | `frozenset[Condition]` | должно быть непусто |
| `applications` | `frozenset[ApplicationEnum]` | пусто означает отсутствие предпочтения |
| `city` | `str` или `None` | |
| `geo_restriction_cities` | `frozenset[str]` или `None` | явное ограничение; `None` означает ограничения нет |
| `remaining_demand_kg` | Decimal | для `internal_use` и переработчика без заявки это заданная ёмкость, ≥ 0 |
| `min_kg` | Decimal | ≥ 0, на пару партия–потребность |
| `max_kg` | Decimal или `None` | потолок на пару, если задан |
| `budget_per_kg_kgs` | Decimal или `None` | `None` означает цены ограничены только партией |
| `active` | bool | |

Внутреннее использование и ёмкость переработчика проходят через ту же функцию: владелец передаёт их в запросе на расчёт как `DemandFacts` с `kind=internal_use` и явной ёмкостью (см. допущения A-04, A-05). Так «совместимость и ёмкость» (CLAUDE.md §8) проверяются одним кодом.

`RuleSet`: неизменяемый объект с `version`, весами скоринга и порядком фильтров. `RULES_V1` задаёт значения раздела 3.

### 2.3 Выход

```python
class CompatibilityResult(BaseModel):
    compatible: bool
    reasons: list[ExclusionReason]       # пусто, если compatible
    feasible_kg: Decimal                 # 0.000, если не compatible
    upper_kg: Decimal                    # min(available, remaining_demand, max_kg)
    rules_version: str
```

`ExclusionReason` (StrEnum, значения стабильны и входят в OpenAPI):

| Код | Условие |
| --- | --- |
| `MATERIAL_NOT_CONFIRMED` | `confirmed = False` или подтверждение на другой version |
| `MATERIAL_NOT_AVAILABLE` | статус не `available`/`partially_allocated` или `available_kg = 0` |
| `DEMAND_INACTIVE` | `active = False` |
| `DEMAND_EXHAUSTED` | `remaining_demand_kg = 0` |
| `DEMAND_INCOMPLETE` | пустые `accepted_types`/`accepted_conditions` у потребности |
| `UNKNOWN_TYPE` | у партии тип неизвестен |
| `TYPE_MISMATCH` | тип известен и не входит в `accepted_types` |
| `UNKNOWN_CONDITION` | у партии состояние неизвестно |
| `CONDITION_MISMATCH` | состояние известно и не входит в `accepted_conditions` |
| `UNKNOWN_APPLICATION` | у потребности есть предпочтение по применению, у партии применения неизвестны |
| `APPLICATION_MISMATCH` | оба набора известны, пересечения нет |
| `MIN_LOT_IMPOSSIBLE` | `min_kg > upper_kg` |
| `PRICE_UNKNOWN` | для `sale`/`recycling` нет цены партии и нет помеченной оценки (A-03) |
| `PRICE_ABOVE_BUDGET` | цена за кг больше `budget_per_kg_kgs` |
| `GEO_RESTRICTED` | город партии не входит в `geo_restriction_cities` |
| `UNKNOWN_CITY_FOR_RESTRICTION` | ограничение задано, город партии неизвестен |

### 2.4 Hard-фильтры: порядок и правило для неизвестного

Фильтры вычисляются все, в этом фиксированном порядке; `reasons` перечисляет все сработавшие причины в этом же порядке (стабильный и воспроизводимый вывод для объяснений):

1. Состояние объектов: `MATERIAL_NOT_CONFIRMED`, `MATERIAL_NOT_AVAILABLE`, `DEMAND_INACTIVE`, `DEMAND_EXHAUSTED`, `DEMAND_INCOMPLETE`.
2. Тип: `UNKNOWN_TYPE` / `TYPE_MISMATCH`.
3. Состояние материала: `UNKNOWN_CONDITION` / `CONDITION_MISMATCH`.
4. Применение: `UNKNOWN_APPLICATION` / `APPLICATION_MISMATCH` (только если у потребности есть предпочтение).
5. Явные географические ограничения: `GEO_RESTRICTED` / `UNKNOWN_CITY_FOR_RESTRICTION`.
6. Невозможный минимальный объём: `MIN_LOT_IMPOSSIBLE`.
7. Цена: `PRICE_UNKNOWN`, `PRICE_ABOVE_BUDGET` (для `internal_use` проверка цены не применяется; значение берётся из A-05).

Правило неизвестного: неизвестная критичная характеристика (тип, состояние, применение при заданном предпочтении, город при явном ограничении, цена для продажи) никогда не считается совпадением и даёт исключение с причиной. Отсутствие предпочтения у потребности допустимо (фильтр 4 пропускается). Расстояние из названия города не выводится; город участвует только как равенство строк и как явный список ограничений.

Hard-фильтры сильнее score: исключённая пара не получает score и не может попасть в план.

`upper_kg = min(available_kg, remaining_demand_kg, max_kg если задан)`. `feasible_kg` равен `upper_kg`, если пара совместима.

Цены и расходы здесь не вычисляются; функция проверяет только наличие цены и бюджет. Чистая маржа считается в `allocator` (раздел 5.2). Отрицательная маржа не нарушает совместимость, но пара не входит в модель (5.3).

## 3. Скоринг matching, версия `match-rules-v1`

Вход: список `DemandFacts` для одной партии. Для каждой совместимой пары:

| Компонент | Макс. | Формула |
| --- | --- | --- |
| `city` | 30 | 30, если `normalize(material.city) == normalize(demand.city)` и оба известны; иначе 0 |
| `application` | 30 | 30, если у потребности нет предпочтения; 30, если есть пересечение; иначе пара уже исключена |
| `coverage` | 40 | 40, если `available_kg >= remaining_demand_kg`; иначе `40 × available_kg / remaining_demand_kg` |

`score = city + application + coverage`, диапазон 0–100. Вычисление в `Decimal`, итог квантуется до 0.01 (`ROUND_HALF_EVEN`), компоненты квантуются тем же способом, `score` равен сумме уже округлённых компонентов (чтобы сумма сходилась в UI).

Сортировка: `score` по убыванию, затем `requirement_id` по возрастанию (сравнение по 16-байтному значению UUID). Для `internal_use` без `requirement_id` ключом служит `option_id`. Входной порядок не влияет на результат.

Ответ matching (`MatchResponse`):

```
material_id, material_version, rules_version, generated_at (UTC),
matches: [ { requirement_id, organization_id, score, components{city, application, coverage},
             feasible_kg, reasons: [ReasonCode info-коды: CITY_MATCH, APPLICATION_MATCH,
             APPLICATION_NO_PREFERENCE, FULL_COVERAGE, PARTIAL_COVERAGE], min_kg } ],
excluded: [ { requirement_id, reasons: [ExclusionReason] } ]
```

Info-коды (`CITY_MATCH` и др.) отделены от `ExclusionReason`, чтобы не смешивать «почему подходит» и «почему исключено». Текст на русском формирует клиент по кодам, backend отдаёт коды и числа. Высокий score не даёт права нарушить спрос, бюджет или min_kg: matching всегда возвращает только пары, прошедшие фильтры.

В matching не выдумываются покупатели и вероятность продажи; поле «вероятность» отсутствует в контракте.

## 4. Вход солвера: snapshot

Тип `OptimizationInput` (передаётся в `allocator.run_allocation`). Backend собирает его из БД, модуль не обращается к БД.

```
snapshot_schema_version: 1
match_rules_version: "match-rules-v1"
allocation_model_version: "alloc-v1"
organization_id
requested_at (UTC)
parameters: { time_limit_seconds, mip_rel_gap, mass_step_kg="0.001", money_step_kgs="0.01",
              max_materials, max_options, max_pairs, random_seed: null }
materials:  [ { MaterialFacts, version, input_version_of_confirmation } ]       # sorted by material_id
directions: [ { DemandFacts } ]                                                # sorted by (kind order, requirement_id / option_id)
unit_values: [ { material_id, option_id, price_per_kg_kgs, price_origin } ]     # p[i,j]
unit_costs:  [ { material_id|null, option_id|null, variable_cost_per_kg_kgs, cost_origin } ]  # c[i,j]
default_variable_cost_per_kg_kgs: { value, origin } | null
assumptions: [ AssumptionRef ]            # см. раздел 11
```

Правила:

- Сортировка входов стабильная: материалы по `material_id`, направления по `(kind: sale < recycling < internal_use, requirement_id или option_id)`. Дубликаты ID отклоняются как ошибка валидации.
- `p[i,j]`: для `sale`/`recycling` равно цене партии (если она есть), либо помеченной оценке из `unit_values`; для `internal_use` это документированная оценка экономии, `value_kind = forecast_saving` (не денежная выручка). Значение «задаётся в данных»; в модуле нет числовых значений по умолчанию.
- `c[i,j]`: только переменные расходы на кг (delivery и т.п.), берутся из `unit_costs` (приоритет: пара, затем направление, затем партия) или из `default_variable_cost_per_kg_kgs`. Расход, не заданный ни в одном месте, не равен нулю: пара исключается причиной `COST_UNKNOWN` (расширение `ExclusionReason`, добавляется вместе с `PRICE_UNKNOWN`). Явный ноль допустим, если он указан во входе с `origin`.
- Каждое значение несёт `origin` (enum `ValueOrigin`): `owner_input`, `buyer_input`, `user_estimate`, `documented_assumption`. Значения `user_estimate` и `documented_assumption` в ответе помечаются как предположения.
- Фиксированные расходы за отправку в MVP не поддерживаются: поле отсутствует, модель использует только расходы на кг (решение зафиксировано здесь; расширение через бинарную переменную отгрузки возможно после MVP с новой версией модели). Это закрывает требование «фиксированные расходы нельзя умножать на кг».
- Расстояние не вычисляется; стоимость доставки приходит явным числом или помеченным допущением и применяется одинаково в оптимизированном и baseline-расчётах.
- `snapshot_hash` = SHA-256 от канонического JSON входа (ключи отсортированы, Decimal как строки). Хеш входит в результат.

## 5. Модель MILP

### 5.1 Множество пар

`E` = пары `(i, j)`, для которых одновременно:

1. `is_compatible(i, j).compatible`;
2. известны `p[i,j]` и `c[i,j]`;
3. маржа `m[i,j] = p[i,j] − c[i,j] > 0`.

Пары с `m ≤ 0` не входят в модель и попадают в `excluded_options` с кодом `NON_POSITIVE_MARGIN` (отрицательная чистая ценность не навязывается, нулевая исключена, чтобы не плодить равные оптимумы). Все остальные пары имеют `x = 0` (несовместимые пары просто не создают переменных, это эквивалентно ограничению `x = 0`).

### 5.2 Переменные и параметры

- `x[k] ≥ 0`: кг для пары `k = (i, j) ∈ E`, непрерывная.
- `y[k] ∈ {0,1}`: только для пар с `min_kg[k] > 0`.
- `A[i]`: свободный остаток партии `i`; `D[j]`: оставшийся спрос/ёмкость направления `j`.
- `U[k] = upper_kg(k)`; `L[k] = min_kg[k]`.

### 5.3 Модель

```
maximize   sum_k  x[k] * m[k]

s.t.  sum_{k: i(k)=i}  x[k]  <= A[i]          для каждой партии i       (баланс партии)
      sum_{k: j(k)=j}  x[k]  <= D[j]          для каждого направления j  (общий спрос по всем партиям)
      x[k] <= U[k]                             для пар без y
      L[k]*y[k] <= x[k] <= U[k]*y[k]           для пар с y                (минимальный заказ)
      x[k] >= 0, y[k] in {0,1}
```

`milp` минимизирует, поэтому вектор целевой функции `c = −m`. Остаток партии `R[i] = A[i] − sum x` возвращается явно и может быть положительным; обязательности направлять всю массу нет.

### 5.4 Детерминизм и вторичное правило

Два этапа на одном и том же порядке столбцов (столбцы строятся из отсортированного входа):

1. Решить основную задачу, получить `z*`.
2. Добавить ограничение `sum x*m >= z* − tol` (`tol` = 1e-6 от масштаба целевой, документируется в параметрах) и минимизировать вторичную цель: сначала число активных пар `sum y` (с весом 1 на y и 0 на пары без y), затем лексикографически тот же вторичный вектор плюс малый штраф по индексу пары `k` для фиксации выбора среди одинаковых решений. Если второй этап не успел за остаток лимита, используется решение первого этапа, это отражается в `tie_break_applied = false`.

Основная цель при этом не ухудшается сверх `tol`. Seed: `scipy.optimize.milp` не принимает seed; значение `random_seed` в snapshot остаётся `null` («не применяется»). Воспроизводимость обеспечивается детерминированным порядком столбцов и фиксированными параметрами; она проверяется тестом на demo fixture (два прогона дают одинаковое распределение и `snapshot_hash`). Если воспроизводимость между версиями SciPy/HiGHS не гарантирована, версии библиотек записываются в результат.

### 5.5 Статусы

`RunStatus`: `optimal`, `feasible`, `infeasible`, `timeout`, `error`, `heuristic`.

| Состояние `scipy.optimize.milp` | Статус результата |
| --- | --- |
| `status = 0`, решение найдено и доказано оптимальным (`mip_gap` ≤ параметра, по умолчанию 0) | `optimal` |
| лимит времени/итераций, решение есть (`x` не `None`), либо `mip_gap` > заданного | `feasible` (выдаётся `mip_gap`, если доступен) |
| лимит времени, решения нет | `timeout` (план пуст; можно запросить `heuristic`, см. 5.6) |
| `status = 2` (infeasible) | `infeasible` |
| `status = 3` (unbounded), `4` (прочее), исключение, нарушена проверка раздела 6 | `error` с безопасным `error_code` |

`feasible` никогда не называется `optimal` ни в API, ни в тексте объяснений, ни в UI. Поскольку `x = 0` всегда допустимо, `infeasible` при корректной модели означает ошибку построения и логируется как дефект.

### 5.6 Fallback `heuristic`

Greedy допустим только если солвер не вернул решение (`timeout`, `error` при исключении солвера). Правило: пары `E` по убыванию `m[k]`, при равенстве по `(material_id, option_id)`; для каждой назначается `min(R[i], D[j] остаток, U[k])`, пары с невозможным `min_kg` пропускаются. Итог получает статус `heuristic`, проходит ту же проверку раздела 6 и имеет метку «эвристика, без доказательства оптимальности». Если проверка не проходит, статус `error`.

### 5.7 Лимиты

| Параметр | Значение | Источник |
| --- | --- | --- |
| `max_materials` | 50 | допущение A-07 (совпадает с «десятки партий», D-02) |
| `max_options` (направления) | 200 | A-07 |
| `max_pairs` (число `|E|`) | 5000 | A-07 |
| `time_limit_seconds` | из `OPTIMIZATION_TIMEOUT_SECONDS`; значение по умолчанию задаётся в конфигурации backend (рекомендуется 10, A-08) | `CLAUDE.md` §13 |
| `mip_rel_gap` | 0 | желаем доказанный optimum на малых задачах |

Превышение размера возвращает ошибку валидации (HTTP 422 на уровне API), а не усечённый расчёт. Фактическое время и размер входа измеряются отдельно от API p95 и записываются в `solve_time_ms`, `n_pairs`; цель по времени не заявляется без замера.

## 6. Округление и проверки после округления

Шаг массы 0.001 кг, шаг денег 0.01 KGS (D-05).

1. `x_raw` (float) переводится в `Decimal` и округляется вниз: `x = floor(x_raw / 0.001) * 0.001`. Округление вниз гарантирует, что суммы по партиям и спросу не растут.
2. Пара с `y = 1`, у которой после округления `x < min_kg`, обнуляется (масса уходит в остаток), помечается `rounded_to_zero` в объяснении.
3. Пары с `x = 0` не попадают в `allocations`.
4. Все значения ценности пересчитываются в `Decimal` из округлённых `x`: `line_net = x * m`, квантуется до 0.01 (`ROUND_HALF_EVEN`); итог равен сумме квантованных строк. Выводимая «ожидаемая ценность» только эта пересчитанная.
5. Остаток `R[i] = A[i] − sum x[i,*]` считается в `Decimal`.

Проверки перед возвратом (общая функция `validate_plan`, применяется и к оптимизированному плану, и к baseline, и к heuristic):

- каждый `x ≥ 0`, шаг 0.001;
- `sum_j x[i,j] + R[i] = A[i]` точно, `R[i] ≥ 0`;
- `sum_i x[i,j] ≤ D[j]` для каждого направления;
- каждая строка `x ≤ U[k]`, и для `min_kg > 0`: `x = 0` либо `x ≥ min_kg`;
- каждая строка соответствует паре, для которой `is_compatible` возвращает `compatible` (повторный вызов той же функции);
- `p` и `c` известны, ни одно значение не подставлено по умолчанию без `origin`.

Нарушение даёт `error` (`PLAN_VALIDATION_FAILED`); план не возвращается как успешный. Тест OPT-03: случай, где округление «к ближайшему» превысило бы спрос на 0.001, должен давать нарушение до введения проверки и проходить после.

## 7. Baseline

`baseline-v1` строится на тех же входах (`snapshot_hash` совпадает), том же множестве пар `E` (одинаковые `p`, `c`, фильтры, исключение пар с неположительной маржой), без вызова солвера:

1. Материалы по возрастанию `material_id`.
2. Для материала направления из `E` в порядке matching (score по убыванию, затем `requirement_id`).
3. Назначается `min(R[i], остаток D[j], U[k])`, округлённо вниз до 0.001; если результат меньше `min_kg` пары, пара пропускается.
4. Остаток материала переходит дальше по списку, непроданное идёт в остаток.

Baseline проходит `validate_plan`. Если baseline недопустим, это `error`: сравнение не показывается.

Результат сравнения (`comparison`): `baseline_method`, `baseline_net_value_kgs`, `optimized_net_value_kgs`, `delta_kgs = optimized − baseline`, `baseline_remainder_kg`, `optimized_remainder_kg`, `same_inputs = true`. Разница может быть нулевой или отрицательной (для статусов `feasible`/`heuristic`); модуль не обещает улучшения на произвольных данных и не выводит процент без базы. Если `status = optimal`, то `delta ≥ 0` по построению (baseline допустим в той же модели); тест это проверяет.

## 8. Выход солвера

`OptimizationResult`:

```
run_id (присваивает backend при сохранении)
status: optimal | feasible | infeasible | timeout | error | heuristic
status_detail: { mip_gap | null, error_code | null, tie_break_applied, message_code }
method: "scipy.optimize.milp (HiGHS)" | "greedy-v1" ; solver_name, solver_version, numpy/scipy versions
model_versions: { match_rules, allocation_model, baseline, snapshot_schema }
snapshot_hash, parameters (эхо), random_seed: null
allocations: [ { material_id, option_id, kind, requirement_id | null, organization_id | null,
                 kg, unit_value_kgs, unit_cost_kgs, net_value_kgs, value_kind (cash_sale | forecast_saving),
                 value_origin, cost_origin, explanation: { codes[], numbers{} } } ]
remainders: [ { material_id, remainder_kg, reasons[] } ]      # явно, в т.ч. нулевой остаток
excluded_options: [ { material_id, option_id, reasons[] } ]    # в т.ч. NON_POSITIVE_MARGIN, PRICE_UNKNOWN, COST_UNKNOWN
totals: { allocated_kg, remainder_kg, expected_net_value_kgs,
          expected_cash_net_kgs, forecast_saving_net_kgs }       # saving отдельно от выручки
comparison: (раздел 7)
assumptions_used: [AssumptionRef]
solve_time_ms, n_materials, n_options, n_pairs
stale_hint: { material_versions: {...}, demand_versions: {...} }
generated_at (UTC)
label: "expected"   # результат всегда прогноз, не продажа и не передача
```

Объяснение строки строится из кодов и чисел (`MARGIN_POSITIVE`, `FILLED_DEMAND`, `LIMITED_BY_STOCK`, `LIMITED_BY_MIN_LOT`, `LIMITED_BY_MAX_KG`, `ROUNDED_TO_ZERO` и т.п.), русский текст формируется клиентом. Объяснение остатка: `NO_COMPATIBLE_DIRECTION`, `NON_POSITIVE_MARGIN_ONLY`, `DEMAND_EXHAUSTED_BY_OTHERS`, `MIN_LOT_NOT_REACHED`, `LEFT_BY_OPTIMUM`.

Прогнозная экономия внутреннего использования входит в целевую функцию как документированная оценка (CLAUDE.md §8), но в `totals` отделена от денежной части и никогда не суммируется с выручкой в аналитике.

Результат не меняет остатки и статусы. Применение плана выполняется только через защищённые операции резервирования backend, которые заново проверяют остаток и спрос. Сохранённый план помечается устаревшим, если `version` партии или ключевые данные потребности изменились (проверка backend по `stale_hint`); тогда предлагается пересчёт.

## 9. Точка вызова и работа вне event loop

- `allocator.run_allocation(input: OptimizationInput) -> OptimizationResult` и `matching.rank_requirements(...)` синхронные, чистые функции.
- Эндпоинт `POST /optimization/run` (backend-engineer) строит snapshot в сессии БД, затем закрывает/освобождает транзакцию и вызывает расчёт через `await asyncio.to_thread(run_allocation, snapshot)` (или `run_in_threadpool`). Внешние вызовы и расчёт не удерживают блокировки БД. Результат сохраняется отдельной короткой транзакцией.
- Параллельные расчёты ограничены семафором на процесс (рекомендация: 2) и лимитом запросов на пользователя; превышение даёт 429.
- Жёсткая остановка зависшего потока не гарантируется, поэтому защита от зависания обеспечивается параметром `time_limit` самого HiGHS; внешний `asyncio.wait_for` лишь освобождает HTTP-запрос и не заменяет лимит солвера.
- `POST /ai/match` вызывает `rank_requirements` из того же пакета; расчёт мал и может выполняться в threadpool тем же способом.

## 10. Тесты, привязанные к контракту (план для OPT-01..03)

В `backend/tests/optimization/`: известный оптимум, посчитанный вручную; общий спрос на несколько партий; несовместимые пары с проверкой причин; min-lot (0 или ≥ min); отрицательная и нулевая маржа; нулевой спрос и нулевой остаток; граничное округление; повторяемость на demo fixture (одинаковые `snapshot_hash` и распределение); `timeout` и `feasible` (мок результата `milp`/малый лимит); baseline допустим и использует те же входы; matching и allocator используют один объект `is_compatible`; `PRICE_UNKNOWN`/`COST_UNKNOWN` исключают, а не подставляют ноль.

## 11. Список допущений

Каждое допущение имеет `AssumptionRef` с id, меткой «допущение» и источником. Числовые значения цен и расходов в этот документ не заносятся: «задаётся в данных» (в snapshot с `origin`). Реестр цифр ведёт business-analyst (D-10).

| ID | Допущение | Метка | Источник |
| --- | --- | --- | --- |
| A-01 | Веса v1: город 30, применение 30, покрытие 40 | фиксировано | `CLAUDE.md` §7 |
| A-02 | `min_kg` задаётся на пару партия–потребность; `max_kg` трактуется как потолок на пару | допущение MVP | `CLAUDE.md` §8, модель `buyer_requirements` |
| A-03 | Цена продажи берётся из цены партии; при её отсутствии нужна явная оценка с `origin = user_estimate`, иначе `PRICE_UNKNOWN` | допущение | `CLAUDE.md` §8 (пропущенная цена не ноль) |
| A-04 | Ёмкость и параметры внутреннего использования владелец передаёт в запросе как `DemandFacts(kind=internal_use)`; в БД отдельной сущности нет | допущение, требует подтверждения backend | `CLAUDE.md` §5, §8 |
| A-05 | Ценность внутреннего использования есть оценка экономии (`value_kind = forecast_saving`), значение «задаётся в данных», источник указывает владелец | допущение | `CLAUDE.md` §8, D-10 |
| A-06 | Переработчик: цена в `unit_values`/цене партии, ёмкость в `remaining_demand_kg` его потребности; отдельного ценника переработки в модели нет | допущение | `CLAUDE.md` §4 |
| A-07 | Лимиты размера 50 / 200 / 5000 | допущение | «десятки×десятки», D-02 |
| A-08 | Лимит времени по умолчанию 10 с рекомендуется, итог задаёт `OPTIMIZATION_TIMEOUT_SECONDS`; значение подлежит замеру | допущение | `CLAUDE.md` §13 |
| A-09 | Расходы только переменные (за кг); фиксированные расходы за отправку вне MVP | решение MVP | `CLAUDE.md` §8, R-03 |
| A-10 | Стоимость доставки задаётся явно или как помеченное допущение, одинаково в baseline и оптимизации; расстояние из городов не выводится | допущение | `CLAUDE.md` §7, D-10 |
| A-11 | Явное географическое ограничение (`geo_restriction_cities`) требует соответствующего поля в `buyer_requirements`; до его появления фильтр 5 не срабатывает | зависит от backend | CON-01 |
| A-12 | Списки допустимых состояний и типов у потребности должны быть непусты; пустые значения считаются `DEMAND_INCOMPLETE` | допущение | `CLAUDE.md` §5 |
| A-13 | Нулевая маржа исключается из модели (вторичное правило) | решение | `CLAUDE.md` §8 |
| A-14 | Комиссия 5% в расчётах не участвует | фиксировано | `CLAUDE.md` §2, D-10 |
| A-15 | CO2 и экологические показатели в контракте отсутствуют | фиксировано | `CLAUDE.md` §10 |

## 12. Открытые вопросы к оркестратору

1. A-04 и A-11: нужны ли backend отдельные поля (ёмкость внутреннего использования, `geo_restriction_cities`) в `docs/api.md`/`buyer_requirements`; без них поведение описано как в таблице.
2. BLK-04: утверждение SciPy `milp` ожидается; контракт написан под него.
3. Для подтверждения: `ExclusionReason` и `RunStatus` как общие enum размещаются в `backend/app/schemas/optimization.py` (не дублируются в модулях).
