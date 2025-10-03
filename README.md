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
- PROMETHEUS_WEB_USER, PROMETHEUS_WEB_PASSWORD_BCRYPT — включает базовую авторизацию UI Prometheus (опционально).
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
