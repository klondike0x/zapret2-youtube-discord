# zapret2-youtube-discord

Portable-набор для Windows с готовыми BAT-профилями на базе настоящего Zapret2. Внутри используется официальный `winws2.exe` и Lua-стратегии Zapret2, а не `winws.exe` от Zapret1.

[Скачать последнюю версию](https://github.com/klondike0x/zapret2-youtube-discord/releases/latest)

GPG fingerprint релизов: `4001 5491 B3A6 3D77 7855 FEC0 8DA8 2B54 BDED 31AE`. Публичный ключ находится в [`release-signing-key.asc`](release-signing-key.asc).

Проект сделан в привычном стиле Flowseal: пользователь запускает нужный BAT-файл, подтверждает UAC и получает отдельное минимизированное окно с работающим профилем.

> Результат зависит от провайдера, региона и настроек DPI. Наличие рабочего движка и корректного профиля не гарантирует, что одна стратегия будет работать во всех сетях.

## Требования

- Windows x64;
- права администратора для загрузки WinDivert;
- запущенная служба Base Filtering Engine (BFE);
- отсутствие другого активного экземпляра `winws2.exe` и конфликтующих программ на WinDivert.

Антивирус может определить WinDivert как RiskTool или PUA. Это драйвер перехвата трафика, необходимый для работы Zapret2.

## Быстрый запуск

1. Распакуйте проект в обычный каталог с правом запуска программ.
2. Запустите один из BAT-файлов:
   - `general.bat` — основной общий профиль;
   - `general (ALT).bat` — перенос стратегии `general (ALT)` из Flowseal на Zapret2;
   - `general (YouTube).bat` — профиль для YouTube;
   - `general (Discord).bat` — профиль для Discord.
   - `general (SIMPLE FAKE).bat` — минимальная TCP-стратегия только с fake;
   - `general (MULTISPLIT).bat` — TCP-сегментация с overlap без предварительного fake;
   - `general (FAKE MULTISPLIT).bat` — усиленный вариант fake + multisplit;
   - `general (HOSTFAKESPLIT).bat` — подмена только области имени хоста/SNI;
   - `general (FAKE TLS AUTO).bat` — динамический TLS fake и multidisorder.
3. Подтвердите запрос UAC.
4. `winws2` откроется в отдельном минимизированном окне. Разверните его через панель задач, если нужен журнал работы.

Успешный запуск заканчивается сообщением:

```text
windivert initialized. capture is started.
```

Чтобы остановить ручной режим, закройте окно профиля. Одновременно должен работать только один экземпляр `winws2.exe`. Если он уже запущен, новый профиль попросит сначала закрыть текущее окно.

Если запуск завершится ошибкой, окно останется открытым и покажет код завершения.

## Профиль General ALT

`general (ALT).bat` запускает `profiles/general-alt.txt`. Профиль сохраняет структуру исходной стратегии Flowseal, но использует синтаксис и Lua-функции Zapret2:

- QUIC на UDP 443 по общим hostlist;
- Discord Voice и STUN;
- отдельную обработку `discord.media`;
- отдельный профиль Google;
- общие HTTP/TLS hostlist;
- резервные правила по `ipset-all.txt`;
- ограниченные профили для игрового TCP и UDP.

Для переноса `--dpi-desync-fooling=ts` задано явное смещение `tcp_ts=-600000`. Запись `tcp_ts` без числа в Zapret2 недопустима и вызывает Lua-ошибку во время обработки трафика.

Игровые порты в текущей версии профиля отключены безопасным портом-заглушкой `12`. Это соответствует выключенному Game Filter в исходном Flowseal. Для включения игрового диапазона профиль нужно отредактировать осознанно.

## Дополнительные стратегии

Flowseal содержит много `ALT`, `SIMPLE FAKE` и `FAKE TLS AUTO` файлов. Большая часть различается только числом повторов, split-позицией или видом fooling. В этой сборке оставлены пять вариантов с действительно разной механикой:

| BAT-файл | TCP-механика | Когда пробовать |
| --- | --- | --- |
| `general (SIMPLE FAKE).bat` | `fake` с `tcp_ts=-600000` | Когда нужен наиболее простой и лёгкий вариант |
| `general (MULTISPLIT).bat` | `multisplit` с `seqovl` | Когда fake-пакеты фильтруются или мешают соединению |
| `general (FAKE MULTISPLIT).bat` | `fake` + `multisplit` | Более агрессивный вариант для сложного DPI |
| `general (HOSTFAKESPLIT).bat` | `hostfakesplit` | Когда DPI принимает решение по HTTP Host или TLS SNI |
| `general (FAKE TLS AUTO).bat` | динамический TLS fake + `multidisorder` | Для TLS-фильтрации, где полезна рандомизация ClientHello |

QUIC, Discord/STUN, списки и IP fallback во всех вариантах сохранены от основного General ALT. Игровые профили остаются отключены портом `12`.

`FAKE TLS AUTO` использует `tls_mod=rnd,dupsid,sni=www.google.com`. Для HTTP применяется отдельный статический blob, поскольку TLS-модификаторы нельзя применять к произвольному HTTP payload.

Не стоит переносить все Flowseal BAT-файлы один к одному. Варианты `ALT2`, `ALT6`, `ALT7` и часть `EXP` отличаются главным образом размером overlap или split-маркерами; их лучше подбирать после `blockcheck2`, а не хранить как десятки почти одинаковых профилей.

## Пользовательские списки

Профиль General ALT использует каталог `lists/`:

- `lists/list-general.txt` — основные домены для обхода;
- `lists/list-general-user.txt` — пользовательские домены;
- `lists/list-google.txt` — отдельный список Google;
- `lists/list-exclude.txt` — исключённые домены;
- `lists/list-exclude-user.txt` — пользовательские исключения;
- `lists/ipset-all.txt` — общий список IP и подсетей;
- `lists/ipset-exclude.txt` — IP-исключения;
- `lists/ipset-exclude-user.txt` — пользовательские IP-исключения.

Добавляйте по одному домену, IP или CIDR на строку. Не удаляйте пользовательские файлы и не оставляйте их полностью пустыми. Поддомены записанных доменов учитываются автоматически.

Каталог `files/` содержит компактные списки и payload-файлы других профилей. Не смешивайте пути `files/` и `lists/`: каждый профиль ссылается на свой набор данных.

## Запуск как службы

Откройте `service.bat` от имени администратора. Меню позволяет:

- установить один из пяти пользовательских профилей как автоматическую службу;
- запустить или остановить службу;
- проверить её статус и выбранный профиль;
- удалить службу;
- принудительно остановить вручную запущенный `winws2.exe`.

Имя службы:

```text
zapret2-youtube-discord
```

Перед ручным запуском остановите службу. Перед установкой службы закройте вручную запущенный профиль.

## Структура проекта

```text
zapret2-youtube-discord/
├── bin/                  winws2.exe, cygwin1.dll, WinDivert и payload-файлы
├── lua/                  Lua-библиотеки и дополнительные функции Zapret2
├── profiles/             конфигурации фильтров и Lua-стратегий
├── lists/                основные hostlist и ipset
├── files/                компактные списки и QUIC payload для отдельных профилей
├── windivert.filter/     частичные фильтры WinDivert
├── tools/                подготовка профиля и мост запуска winws2
├── tests/                структурные проверки и parser dry-run
├── general*.bat          ручной запуск выбранной стратегии
├── launcher.bat          общий запуск с UAC и отдельным окном
└── service.bat           установка и управление службой
```

Стратегии находятся в `profiles/*.txt`. Основные параметры Zapret2:

- `--lua-init` загружает Lua-библиотеки;
- `--lua-desync` задаёт действия над пакетами;
- `--filter-*`, `--payload`, `--hostlist` и `--ipset` выбирают трафик;
- `--new` начинает следующий профиль обработки.

`launcher.bat` копирует выбранную конфигурацию в `tools/preset-active.txt`, после чего запускает её через отдельное минимизированное CMD-окно. PowerShell-мост нужен из-за особенностей передачи `@config` в Cygwin-сборку `winws2.exe`.

## Проверка проекта

Выполняйте команды из корня проекта:

```cmd
bin\winws2.exe --version
python tests\validate_project.py
python tests\validate_flowseal_alt_port.py
python tests\validate_strategy_variants.py
python tests\dry_run_profiles.py
```

`validate_project.py` проверяет состав проекта, BAT-launcher, службу и версию движка.

`validate_flowseal_alt_port.py` проверяет портированный профиль General ALT, его зависимости, CRLF и параметры `tcp_ts`, затем запускает parser dry-run.

`validate_strategy_variants.py` проверяет пять дополнительных стратегий, их BAT-файлы, регистрацию в службе и реальный parser dry-run.

`dry_run_profiles.py` создаёт временную копию каждого профиля с `--dry-run` внутри конфигурации и передаёт её реальному `winws2.exe`. Этот тест проверяет синтаксис, загрузку файлов и Lua-инициализацию, но не подтверждает работу обхода у конкретного провайдера.

Перед parser dry-run закройте ручной профиль и остановите службу. Иначе `winws2` может сообщить:

```text
A copy of winws2 is already running with the same filter
```

Включённый бинарник сообщает:

```text
github version v1.0.3 (b78b52c4cd7f843da3ff0848a3430afbd401bdf2) lua_compat_ver 6
```

Не смешивайте `winws2.exe` и Lua-файлы из разных выпусков. `zapret-lib.lua` проверяет версию API через `NFQWS2_COMPAT_VER`.

## Возможные проблемы

### Профиль не открывается

Проверьте, не работает ли уже `winws2.exe` или служба `zapret2-youtube-discord`. Закройте окно активного профиля либо остановите процесс через пункт 6 в `service.bat`.

### Окно сразу закрывается

Запустите BAT ещё раз и посмотрите сообщение в отдельном окне. Ошибки подготовки профиля остаются в исходном CMD, а ошибки `winws2.exe` — в окне профиля.

### Ошибка `failed to split command line options`

Не запускайте `winws2.exe` вручную с абсолютным `@config`. Используйте готовые BAT-файлы. Профили должны сохранять CRLF и передаваться через предусмотренный PowerShell-мост.

### Ошибка Lua о `tcp_ts`

Параметр должен содержать число, например `tcp_ts=-600000`. Голый `tcp_ts` проходит часть статических проверок, но завершается ошибкой при обработке TCP-пакета.

### Нет доступа к нужному сайту

Строка `capture is started` подтверждает только запуск WinDivert. Она не доказывает, что стратегия подходит вашему провайдеру. Проверьте DNS, списки доменов и IP, затем попробуйте другой профиль.

## Источники

- [bol-van/zapret2](https://github.com/bol-van/zapret2)
- [bol-van/zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle)
- [basil00/WinDivert](https://github.com/basil00/WinDivert)
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) — идея простого выбора BAT-профилей

Этот проект не является официальной сборкой Flowseal. Стратегия General ALT была перенесена на архитектуру Zapret2 отдельно.

## Лицензия

Оболочка проекта распространяется по MIT License. Сторонние бинарники и библиотеки сохраняют собственные лицензии и авторские права.
