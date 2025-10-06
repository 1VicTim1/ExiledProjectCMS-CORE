# ExiledProjectCMS — Основной API для Minecraft CMS

[![.NET](https://img.shields.io/badge/.NET-8.0-512BD4?logo=dotnet&logoColor=white)](https://dotnet.microsoft.com/)
[![ASP.NET Core](https://img.shields.io/badge/ASP.NET%20Core-Minimal%20API-512BD4)](https://learn.microsoft.com/aspnet/core)
[![MySQL](https://img.shields.io/badge/DB-MySQL-4479A1?logo=mysql&logoColor=white)](https://www.mysql.com/)
[![PostgreSQL](https://img.shields.io/badge/DB-PostgreSQL-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Docker Compose](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![Prometheus](https://img.shields.io/badge/Monitoring-Prometheus-E6522C?logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Monitoring-Grafana-F46800?logo=grafana&logoColor=white)](https://grafana.com/)
![Status](https://img.shields.io/badge/Status-WIP-yellow)

Основной API на C# для будущей CMS Minecraft с интеграцией GML Launcher.

Документация GML: https://gml-launcher.github.io/Gml.Docs/home.html

---

## Содержание
- Введение
- Состав репозитория
- Возможности
- Дорожная карта
- Требования
- Быстрый старт
    - Вариант A — без БД (in-memory)
    - Вариант B — локально с MySQL/PostgreSQL
    - Вариант C — Docker Compose (API + БД + Prometheus + Grafana)
- Конфигурация (.env)
- Сид‑данные
- Эндпоинты
- Мониторинг
- Проверка скриптами
- FAQ
- Лицензия

---

## Введение
ExiledProjectCMS — минимально жизнеспособный бэкенд, который уже умеет:
- авторизовывать пользователей в формате, ожидаемом GML Launcher;
- отдавать ленту новостей для импорта в лаунчер;
- работать как с реальной БД (MySQL/PostgreSQL через EF Core), так и в in‑memory режиме;
- отдавать метрики Prometheus и смотреть их в Grafana;
- запускаться локально и через Docker Compose.

Мини‑схема стека:
```
[ GML Launcher ] → [ Main API (.NET 8) ] ↔ [ MySQL | PostgreSQL ]
                                 ↘
                                  → [/metrics → Prometheus] → [Grafana]
```

## Состав репозитория
- src\MainApi — ASP.NET Core 8 Minimal API
- monitoring\prometheus — конфигурация Prometheus
- monitoring\grafana\provisioning — авто‑подключение источника данных Prometheus в Grafana
- tests\check_api.ps1 — PowerShell‑скрипт для проверки API
- tests\check_api.sh — Bash‑скрипт для проверки API
- docker-compose.yml — общий стек (API + БД + Prometheus + Grafana)
- .env.example — пример конфигурации окружения

## Возможности
- ASP.NET Core 8 Minimal API.
- Интеграция для GML:
    - POST /api/v1/integrations/auth/signin — кастомный вход (см. Эндпоинты).
    - GET /api/news — список новостей (limit, offset).
- Здоровье сервиса: GET /health.
- Метрики Prometheus: /metrics (prometheus-net.AspNetCore).
- База данных (EF Core): MySQL (Pomelo) и PostgreSQL (Npgsql).
    - Конфигурация через .env, автоматическое создание БД и сиды через EnsureCreated (миграций пока нет).
    - Если БД не сконфигурирована — прозрачный fallback на in-memory репозитории с теми же сид‑данными.
- Docker Compose стек: Main API + MySQL/PostgreSQL (по профилям) + Prometheus + Grafana.
    - Grafana берёт логин/пароль из .env и автоматически получает datasource Prometheus.
    - Prometheus можно защитить базовой авторизацией (см. .env).
- Тестовые скрипты (PowerShell и Bash) для проверки основных сценариев.

## Дорожная карта
- Полноценная 2FA: приём и проверка TOTP‑кода (сейчас только подсказка в 401).
- Токены (JWT/refresh), защищённые эндпоинты и права доступа.
- Роли, права и админ‑панель (RBAC, доступ к страницам/элементам/формам).
- Почтовый сервис (Go) и его настройка из админ‑панели.
- Платёжный сервис (Go) и интеграции с провайдерами.
- Кеширование (Redis) и его использование на стороне API.
- Сервис скинов (Go) и интеграция по документации GML.
- Интеграции новостей с лаунчером и в Discord (вебхуки/бот).
- EF Core миграции (сейчас EnsureCreated).
- Дополнительный мониторинг, готовые дашборды Grafana, алерты.
- CI/CD, контейнеризация и запуск сопутствующих сервисов (Go) в общем стеке.
- Улучшения безопасности: rate limiting, аудит логов, CSP и т.п.

## Требования
- .NET 8 SDK — https://dotnet.microsoft.com/download
- Docker + Docker Compose plugin (для варианта с контейнерами)
- MySQL 8+ или PostgreSQL 13+ (если без Docker Compose и с реальной БД)

## Быстрый старт
### Вариант A — без БД (in‑memory)
1) Скопируйте .env.example в .env
- Windows (PowerShell):
```powershell
Copy-Item .env.example .env
```
- Linux/macOS:
```bash
cp .env.example .env
```
2) (Необязательно) Отредактируйте ADMIN_LOGIN/ADMIN_PASSWORD для первоначального администратора.
3) Запустите API на фиксированном порту (совместимо с тест‑скриптами):
```powershell
dotnet run --project src\MainApi\MainApi.csproj --urls http://localhost:5190
```
4) Проверьте: http://localhost:5190/health
5) Запустите тесты (по желанию):
```powershell
./tests/check_api.ps1 -BaseUrl http://localhost:5190
```
или
```bash
./tests/check_api.sh http://localhost:5190
```

### Вариант B — локально с MySQL/PostgreSQL (без Docker Compose)
1) Поднимите свою БД и создайте пользователя с правами на создание БД/таблиц.
2) Скопируйте .env.example в .env и заполните настройки БД, например для MySQL:
```env
DB_PROVIDER=mysql
DB_HOST=localhost
DB_PORT=3306
DB_NAME=exiledcms
DB_USER=root
DB_PASSWORD=yourpassword
```
Для PostgreSQL используйте DB_PROVIDER=postgresql и соответствующие значения; при необходимости укажите DB_SSLMODE.
3) Запустите API (лучше указать URL):
```powershell
dotnet run --project src\MainApi\MainApi.csproj --urls http://localhost:5190
```
4) На старте БД будет создана (EnsureCreated) и при пустых таблицах добавятся сид‑данные.

### Вариант C — Docker Compose (API + БД + Prometheus + Grafana)
1) Скопируйте .env.example в .env и отредактируйте:
- Выберите провайдера и хост БД внутри Compose:
    - MySQL: DB_PROVIDER=mysql, DB_HOST=mysql
    - PostgreSQL: DB_PROVIDER=postgresql, DB_HOST=postgres
- Порты (при необходимости): API_PORT, PROMETHEUS_PORT, GRAFANA_PORT
- Данные администратора Grafana: GRAFANA_ADMIN_USER, GRAFANA_ADMIN_PASSWORD
- (Опционально) базовая авторизация UI Prometheus: PROMETHEUS_WEB_USER и PROMETHEUS_WEB_PASSWORD_BCRYPT (bcrypt‑хеш)
- (Опционально) включить Swagger UI в контейнере: ASPNETCORE_ENVIRONMENT=Development
2) Поднимите стек, выбрав профиль БД:
```bash
docker compose --profile mysql up -d
# или
docker compose --profile postgresql up -d
```
3) Проверьте доступность:
- API:        http://localhost:${API_PORT:-5190}/health
- Метрики:    http://localhost:${API_PORT:-5190}/metrics
- Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}
- Grafana:    http://localhost:${GRAFANA_PORT:-3000}
4) Запустите тесты при необходимости:
```powershell
./tests/check_api.ps1 -BaseUrl http://localhost:${API_PORT:-5190}
```
или
```bash
./tests/check_api.sh http://localhost:${API_PORT:-5190}
```

## Конфигурация (.env)
Минимальные примеры

— MySQL:
```env
DB_PROVIDER=mysql
DB_HOST=localhost
DB_PORT=3306
DB_NAME=exiledcms
DB_USER=root
DB_PASSWORD=yourpassword
```

— PostgreSQL:
```env
DB_PROVIDER=postgresql
DB_HOST=localhost
DB_PORT=5432
DB_NAME=exiledcms
DB_USER=postgres
DB_PASSWORD=yourpassword
# (Опционально) DB_SSLMODE=Disable|Require|VerifyCA|VerifyFull (по умолчанию Disable)
```

Доп. переменные
- ADMIN_LOGIN, ADMIN_PASSWORD, ADMIN_REQUIRE2FA, ADMIN_IS_BANNED, ADMIN_BAN_REASON — параметры сид‑админа.
  Важно: сид‑пользователь добавляется только если таблица пользователей пуста (или в in‑memory режиме при старте).
- API_PORT, PROMETHEUS_PORT, GRAFANA_PORT — проброс портов в Docker Compose.
- GRAFANA_ADMIN_USER, GRAFANA_ADMIN_PASSWORD — креды Grafana.
- PROMETHEUS_WEB_USER, PROMЕТHEУС_WEB_PASSWORD_BCRYPT — включает базовую авторизацию UI Prometheus (опционально).
- MYSQL_ROOT_PASSWORD — пароль root для контейнера MySQL (Compose, профиль mysql).
- ASPNETCORE_ENVIRONMENT=Development — включает Swagger UI (локально или в контейнере, если прокинуть в сервис).

## Сид‑данные
Пользователи:
- admin / admin123 — успешная авторизация (если не меняли в .env)
- tester / test123 — требуется 2FA (вернётся 401 с подсказкой)
- banned / banned123 — заблокирован (403 с причиной)

Новости: 3 демо‑записи.

## Эндпоинты
- GET /health — проверка здоровья
  Ответ: `{ "status": "ok" }`

- POST /api/v1/integrations/auth/signin — авторизация для GML
  Запрос JSON: `{ "Login": "admin", "Password": "admin123" }`
  Возможные ответы:
    - 200 OK: `{ "Login": "admin", "UserUuid": "...", "Message": "Успешная авторизация" }`
    - 401 Unauthorized (неверные данные): `{ "Message": "Неверный логин или пароль" }`
    - 401 Unauthorized (требуется 2FA): `{ "Message": "Введите проверочный код 2FA" }`
    - 403 Forbidden (бан): `{ "Message": "Пользователь заблокирован. Причина: ..." }`
    - 404 Not Found (нет такого пользователя): `{ "Message": "Пользователь не найден" }`

Примеры curl:
```bash
# Успех
echo '{"Login":"admin","Password":"admin123"}' | \
  curl -s -H "Content-Type: application/json" -d @- http://localhost:5190/api/v1/integrations/auth/signin

# Требуется 2FA
echo '{"Login":"tester","Password":"test123"}' | \
  curl -s -H "Content-Type: application/json" -d @- http://localhost:5190/api/v1/integrations/auth/signin
```

- GET /api/news?limit=10&offset=0 — список новостей
  Ответ: массив объектов `{ id, title, description, createdAt }` (ISO‑8601, UTC)

- GET /metrics — метрики Prometheus

## Мониторинг
- Prometheus заранее сконфигурирован собирать метрики с API и самого себя (см. monitoring/prometheus/prometheus.yml).
- Grafana автоматически получает datasource Prometheus. Вход: GRAFANA_ADMIN_USER/GRAFANA_ADMIN_PASSWORD из .env.
- Если включите базовую авторизацию в Prometheus UI, вам может понадобиться вручную обновить datasource в Grafana или
  скорректировать provisioning.

## Проверка скриптами
- PowerShell (Windows):
```powershell
./tests/check_api.ps1 -BaseUrl http://localhost:5190
```
- Bash (Linux/macOS):
```bash
./tests/check_api.sh http://localhost:5190
```
Можно также задать BASE_URL переменной окружения.

## FAQ
- Swagger UI не видно — включите окружение Development (ASPNETCORE_ENVIRONMENT=Development).
- Не коннектится к БД — проверьте DB_HOST/PORT/USER/PASSWORD. В Docker Compose используйте имена сервисов (mysql или
  postgres).
- Порты заняты — измените API_PORT/GRAFANA_PORT/PROMETHEUS_PORT в .env и перезапустите.
- Сид‑админ не меняется — сид‑пользователь создаётся только если таблица users была пустой на старте. Очистите таблицу
  или базу и перезапустите.
- BCrypt‑хеш для Prometheus — сгенерируйте через `htpasswd -nB -C 10 <user>` (Linux/macOS) или в WSL/контейнере.

## Лицензия
Пока не задана. Добавьте файл LICENSE при необходимости.

## Swagger / OpenAPI

Swagger (OpenAPI) подключён и работает. По умолчанию он автоматически включается в окружении Development. Дополнительно
можно включить его в Production через переменную окружения.

- Эндпоинты:
    - UI: http(s)://<host>/swagger
    - JSON: http(s)://<host>/swagger/v1/swagger.json

- Как включить в Production:
    1) В файле .env задайте:
       SWAGGER_ENABLED=true
    2) Перезапустите сервис (локально или через Docker Compose).

- Метаданные:
    - Title: ExiledProject CMS API
    - Version: v1

Примечания:

- В docker-compose по умолчанию ASPNETCORE_ENVIRONMENT=Development, поэтому Swagger уже доступен по /swagger.
- Если вы меняете окружение на Production, включайте Swagger только при необходимости (например, на стендах), выставив
  SWAGGER_ENABLED=true.

---

## Что нового (последние изменения)

- Мини‑фронтенд страницы логина: доступно по /login. Используется для первичной привязки 2FA администратором.
- Реализован web‑флоу 2FA (TOTP) с QR‑кодом: новые эндпоинты /api/web/login, /api/web/2fa/start, /api/web/2fa/verify.
    - Первый админ теперь создаётся без включённой 2FA, но с флагом MustSetup2FA=true — вход в аккаунт блокируется, пока
      2FA не будет привязана.
- Docker Compose: опциональный phpMyAdmin, включается профилем pma вместе с mysql. Порт задаётся PHPMYADMIN_PORT.
- Prometheus: переезд на entrypoint‑скрипт, стабильный запуск и опциональная базовая авторизация.
- MySQL: если DB_USER=root в .env, API автоматически использует MYSQL_ROOT_PASSWORD для подключения.
- Добавлены переменные окружения: SWAGGER_ENABLED (включение Swagger вне Development), HTTPS_REDIRECT_ENABLED (
  непринудительное перенаправление на HTTPS в контейнерах по умолчанию выключено).
- Добавлен SQL‑скрипт для очистки тестовых данных: tests/cleanup_db_mysql.sql.

---

## Мини‑фронтенд (страница логина)

**Внимание!**  
Мини-фронтенд на чистом HTML удалён. Теперь страница логина реализуется как отдельное SPA-приложение на Vue.js  
(см. папку `frontend/`).

- Где найти исходники: `frontend/`
- Как запускать: стандартный Vue.js workflow (`npm install`, `npm run dev` или `npm run build`)
- Как подключить к API: настройте переменную окружения VITE_API_BASE_URL или аналогичную в .env фронта.

---

## Новые web‑эндпоинты (2FA)

- POST /api/web/login
  Тело: { "login": "admin", "password": "..." }
  Ответы:
    - 200 OK — успех (демо‑флоу)
    - 401 — требуется ввод кода 2FA (Next=enter-2fa)
    - 403 — нужно сначала привязать 2FA (Next=setup-2fa) или аккаунт заблокирован

- POST /api/web/2fa/start
  Тело: { "login": "admin", "issuer": "ExiledCMS" }
  Ответ 200: { "Secret": "BASE32...", "OtpauthUri": "otpauth://...", "QrCodeDataUrl": "data:image/png;base64,..." }

- POST /api/web/2fa/verify
  Тело: { "login": "admin", "code": "123456" }
  Ответы:
    - 200 OK: { "Message": "2FA успешно привязана" } (после этого Require2FA=true, MustSetup2FA=false)
    - 401: { "Message": "Неверный код 2FA" }

**Весь web‑флоу теперь реализуется на Vue.js SPA.**

---

## phpMyAdmin (опционально)

phpMyAdmin добавлен в docker-compose и включается только при использовании профиля pma вместе с mysql.

- Запуск (пример):

```bash
# API + MySQL + Prometheus + Grafana + phpMyAdmin
docker compose --profile mysql --profile pma up -d
```

- Доступ: http://localhost:${PHPMYADMIN_PORT:-8081}
- Логин/пароль: теперь всегда запрашиваются на экране входа (мы не передаём PMA_USER/PMA_PASSWORD в контейнер).
  Введите учётные данные вашей БД:
    - если используете не-root пользователя: DB_USER / DB_PASSWORD из .env (и этот пользователь должен существовать в
      БД);
    - если входите под root: логин root и пароль MYSQL_ROOT_PASSWORD (из .env, профиль mysql).
- Переменная порта: PHPMYADMIN_PORT в .env (по умолчанию 8081).

Примечание: phpMyAdmin вообще не запускается, если вы используете PostgreSQL или локальную БД вне контейнеров и не
включили профиль pma.

---

## Очистка тестовых данных (MySQL)

Добавлен SQL‑скрипт tests/cleanup_db_mysql.sql для быстрой очистки демо‑данных (сидов). Внимание: операция
разрушительная.

Пример выполнения из хоста:

```bash
# Используя docker compose (контейнер mysql)
docker exec -i mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$DB_NAME" < tests/cleanup_db_mysql.sql
```

Или через любой MySQL‑клиент/IDE/phpMyAdmin — просто выполните содержимое файла против вашей базы.

---

## Дополнения к конфигурации (.env)

Новые/уточнённые переменные:

- SWAGGER_ENABLED=true|false — включение Swagger вне окружения Development.
- HTTPS_REDIRECT_ENABLED=true|false — включает middleware перенаправления на HTTPS (по умолчанию false в контейнерах).
- PHPMYADMIN_PORT=8081 — порт для phpMyAdmin, когда включён профиль pma.
- Особенность для MySQL: если DB_USER=root, API использует MYSQL_ROOT_PASSWORD для подключения (даже если DB_PASSWORD
  указан иначе) — это упрощает запуск в Docker Compose.

---


---

### Обновление примера .env

В .env.example добавлены/уточнены переменные:

- MYSQL_PORT — проброс порта MySQL в Docker Compose (по умолчанию 3306).
- POSTGRES_PORT — проброс порта PostgreSQL в Docker Compose (по умолчанию 5432).
- PHPMYADMIN_PORT — порт phpMyAdmin (активен при запуске профиля pma), по умолчанию 8081.
- GRAFANA_INSTALL_PLUGINS — список плагинов Grafana для автоматической установки (необязательно).
- Подсказка по ASPNETCORE_ENVIRONMENT — можно установить Development, чтобы всегда был доступен Swagger в контейнере.

Напоминание по безопасности Prometheus UI:

- Чтобы Prometheus требовал логин/пароль, задайте в .env обе переменные: PROMETHEUS_WEB_USER и
  PROMETHEUS_WEB_PASSWORD_BCRYPT
  (пароль в bcrypt; сгенерируйте через htpasswd -nB -C 10 <user>). Если переменные не заданы, UI будет доступен без
  авторизации.
