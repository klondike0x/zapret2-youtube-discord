# zapret2-youtube-discord v1.0.0

Первый публичный релиз portable-набора для Windows на базе настоящего Zapret2.

## Что добавлено

- Официальный `winws2.exe` v1.0.3 с совместимыми Lua-библиотеками (`lua_compat_ver 6`).
- Portable runtime с `cygwin1.dll`, WinDivert DLL и драйвером.
- Ручной запуск профилей через отдельное минимизированное окно в стиле Flowseal.
- Поддержка автоматического запуска выбранной стратегии как службы Windows.
- Профили для общего трафика, YouTube и Discord.
- Порт стратегии Flowseal `general (ALT)` на Lua-архитектуру Zapret2.
- Пять дополнительных вариантов для разных типов DPI:
  - Simple Fake;
  - Multisplit;
  - Fake + Multisplit;
  - HostFakeSplit;
  - Fake TLS Auto + Multidisorder.
- Hostlist и ipset для общих доменов, Google, YouTube, Discord и IP fallback.
- Пользовательские include/exclude-списки.
- QUIC, Discord Voice/STUN и игровые UDP payload-файлы.
- Проверки структуры проекта, CRLF, зависимостей и parser dry-run настоящим `winws2.exe`.
- SHA-256 манифест состава проекта.

## Проверка подлинности

Релиз содержит:

- ZIP-архив portable-сборки;
- файл `SHA256SUMS.txt` с SHA-256 хешами release assets;
- отсоединённую GPG-подпись `SHA256SUMS.txt.asc`;
- публичный ключ `release-signing-key.asc`.

Проверка подписи:

```bash
gpg --import release-signing-key.asc
gpg --verify SHA256SUMS.txt.asc SHA256SUMS.txt
```

После успешной проверки подписи сравните SHA-256 архива со значением в `SHA256SUMS.txt`.

> GPG-подпись подтверждает, что файл выпущен владельцем ключа и не менялся после подписания. Она не заменяет проверку антивирусом. WinDivert может определяться защитными программами как RiskTool/PUA, поскольку перехватывает сетевой трафик.

## Примечания

- Запуск требует прав администратора.
- Одновременно должен работать только один экземпляр `winws2.exe`.
- Эффективность стратегий зависит от провайдера и конфигурации DPI.
- Игровые профили в готовых вариантах отключены безопасным портом-заглушкой `12`.
