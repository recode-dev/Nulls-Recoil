# Cleanup Report — 2026-10-11

- Репозиторий: `recode-dev/Nulls-Recoil`
- База: `main` @ `504cec3e2fc107273fadc6c1c2f631697c1b9431`
- Ветка: `chore/cleanup-20261011`
- Стек: Theos tweak (Objective-C++), arm64, iOS 15.0+, 32 файла исходников, 12 178 строк

## Как проверялось

- Сборка локально по той же схеме, что в CI: Theos на Ubuntu 24.04, iOSToolchain x86_64,
  iPhoneOS16.5.sdk, `make -j5 ARCHS=arm64 DEBUG=0 FINALPACKAGE=1`. Прогон до правок и после
  каждого коммита — 5 сборок, 0 падений.
- Тестов в репозитории нет (CI-джоб только собирает пакет), поэтому критерий приёмки —
  успешная сборка плюс отсутствие изменений в поведении: все правки удаляют сущности,
  которые нигде не читаются, исполняемый код не меняется.
- Мёртвый код искался тремя независимыми способами: `clang -fsyntax-only -Wall -Wextra`
  (0 предупреждений до и после правок), анализатор объявлений/использований (322 функции,
  361 макрос, 64 static-переменные, 19 структур) и граф вызовов с достижимостью от
  `__attribute__((constructor)) start()` (src/core/scan.mm:2607).
- Include-ы проверялись по фактическому использованию символов. Тест «собралось без include»
  здесь непригоден: `-Wl,-undefined,dynamic_lookup` и транзитивные include от Foundation
  позволяют выкинуть даже нужный заголовок.

## Удалено

| Что | Где | Доказательство |
| --- | --- | --- |
| `#import <signal.h>` | src/recoil.h | В `src/` и в hook-библиотеке нет ни `signal()`, ни `sigaction()`, ни `SIG*` |
| `#import <unistd.h>` | src/recoil.h | Нет `usleep`, `sleep`, `getpid`, `ssize_t`, `read`/`write`/`close` |
| `#import <dlfcn.h>` | src/recoil.h | Нет `dlopen`, `dlsym`, `dlerror`, `RTLD_*` |
| `#import <UIKit/UIKit.h>` | src/recoil.h | Ни одного символа `UI[A-Z]*` во всём дереве; хуки ставятся через objc-runtime по строкам `"MetalView"`/`"NullView"` |
| `RCL_BDC_TURN_PANIC` = 1.60f | src/features/autododge.mm:85 | 0 ссылок, остаток от удалённой panic-ветки |
| `RCL_BDC_PANIC_MS` = 350.0f | src/features/autododge.mm:86 | 0 ссылок, остаток от удалённой panic-ветки |
| Параметр `verbose` у `rcl_probe` | src/core/scan.h:431, src/core/scan.mm:3956, вызов src/features/autododge.mm:1357 | `-Wunused-parameter`; в теле не читается, значение на месте вызова остаётся нужным для `rcl_discriminate` |
| Путь `-Iinclude` | Makefile:15, Makefile:18 | Каталога `include/` нет ни в репозитории, ни в клоне `Recoil`, ни в SDK; ни один `#include "include/..."` не встречается |

## Подозрительное (не тронул)

- `rcl_aim_ahead_t.flightMs` (src/helpers/aim_ahead.h:20) — поле заполняется в ~120 строках
  таблицы `rcl_aim_ahead_table`, но не читается нигде (значения = range/speed·1000, то есть
  производные). Удаление требует правки всех строк данных; выгода нулевая, шум в диффе большой.
- 6 недостижимых функций в соседнем репозитории `recode-dev/Recoil` (каталог `Recoil/recoil_hook/`,
  клонируется на этапе сборки): `hook_last_error`, `brk_remove`, `rcl_hooks_uninstall`,
  `rcl_objc_arg_types`, `rcl_objc_skip_compound`, `rcl_objc_strip_imp`. Это не файлы Nulls-Recoil,
  поэтому правки не делались — недостижимость подтверждена графом вызовов, чистить нужно в том репо.
- Makefile:21-22 (`-Wno-unused-function -Wno-unused-variable -Wno-unused-parameter -Wno-everything`)
  глушат все предупреждения. Сейчас код проходит `-Wall -Wextra` с нулём предупреждений,
  так что заглушки можно снимать, но это отдельное решение по процессу.
- `Recoil_FRAMEWORKS = Foundation UIKit` (Makefile:26) — UIKit после удаления импорта не
  используется ни одним символом. Линковку не менял: при `dynamic_lookup` эффект только
  на load-time, а проверки на устройстве у меня нет.
- 11 функций длиннее 100 строк (`rcl_discriminate` 228, `rcl_proj_scan` 216, `rcl_run_autoaim` 212,
  `rcl_ad_collect` 212, `rcl_resolve_own` 157, `rcl_autododge` 153, `rcl_roster` 146,
  `rcl_container_score` 139, `rcl_collect` 137, `rcl_state_tick` 127, `rcl_probe` 103).
  Разбиение — этап 4, без явного запроса не выполнялось.
- Имена projectile-ов дублируются в `aim_ahead.mm` (имя → индекс строки) и `dodge_kinds.mm`
  (имя + 9 полей). Схемы разные, объединение — архитектурное решение, а не уборка.

## Изменено

- `src/recoil.h` — удалены 4 неиспользуемых импорта (`b778cc1`).
- `src/features/autododge.mm` — удалены 2 неиспользуемые константы (`992b60c`).
- `src/core/scan.h`, `src/core/scan.mm`, `src/features/autododge.mm` — у `rcl_probe` убран
  неиспользуемый параметр (`7821a6b`).
- `Makefile` — убран висячий `-Iinclude`, чистая пересборка прошла (`e36f2a2`).

## Метрики

- Файлов удалено: 0
- Строк удалено: 11 (вставлено 4 — изменённые строки сигнатур/списка include)
- Неиспользуемых импортов убрано: 4; зависимостей пакетного менеджера: 0 (их нет в проекте)
- Размер: `src` 432 KB (без изменений), `.git` pack 3.61 MiB
- Проверок сборки: 5, падений 0; `clang -Wall -Wextra`: 0 предупреждений до и после
- Мусор: 0 — нет артефактов сборки в индексе, `.DS_Store`, `.idea/`, `.vscode/`, `*.swp`,
  `*.log`, `*.bak/*.old/*.orig`, `tmp_*`, пустых файлов и каталогов, файлов-дубликатов
- Комментарии: 0 закомментированного кода (нет ни строк с `//`, ни блоков `/* */`),
  TODO/FIXME/HACK/XXX: 0, `#if 0`: 0
- `.gitignore`: правок не требует — `.theos/`, `packages/`, `Recoil/`, `out/`, `*.dylib`, `*.deb`,
  `*.o`, `*.log` уже покрыты, после сборки `git status` чистый

## Следующие шаги (рекомендации)

1. Решить по `flightMs` и по 6 мёртвым функциям в `recode-dev/Recoil`.
2. Снять `-Wno-everything` и включить `-Wunused-function`/`-Wunused-variable` в CI — код это выдержит.
3. Проверить на устройстве, нужен ли UIKit в `Recoil_FRAMEWORKS`, и убрать, если нет.
4. Этап 4 (не выполнялся): разбиение 11 функций >100 строк, магические числа в таблицах `dodge_kinds`.
