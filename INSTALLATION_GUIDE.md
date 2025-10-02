# ExiledProjectCMS - Интерактивный установщик

## Обзор

Новый интерактивный установщик позволяет гибко настраивать ExiledProjectCMS, выбирая только нужные компоненты и
используя как локальные, так и внешние сервисы.

## Возможности

### 🔧 Модульная архитектура

- Выбор только нужных компонентов
- Поддержка внешних сервисов
- Автоматическая генерация конфигурации

### 🗄️ База данных

- **Локальные**: MySQL, PostgreSQL, SQL Server (Docker контейнеры)
- **Внешние**: Подключение к существующим серверам БД
- Автоматическая генерация строк подключения

### ⚡ Кэширование

- **Memory Cache**: для разработки или одиночных экземпляров
- **Redis локальный**: Docker контейнер
- **Redis внешний**: подключение к существующему серверу

### 🚀 Сервисы (опционально)

- **High-Performance Go API**: высокопроизводительное API
- **Skins & Capes Service**: сервис скинов для Minecraft
- **Email Service**: сервис отправки email
- **Frontend**: админ-панель + публичный сайт
- **Nginx Load Balancer**: балансировщик нагрузки
- **Monitoring Stack**: Prometheus + Grafana

### 📦 Хранилище

- **Локальное**: файлы на диске
- **AWS S3**: облачное хранилище для скинов

## Быстрый старт

### Linux/macOS

```bash
# Клонирование репозитория
git clone <repository-url>
cd ExiledProjectCMS

# Запуск интерактивного установщика
chmod +x install-interactive.sh
sudo ./install-interactive.sh
```

### Windows (PowerShell)

```powershell
# Клонирование репозитория
git clone <repository-url>
cd ExiledProjectCMS

# Запуск интерактивного установщика (от имени администратора)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install-interactive.ps1
```

## Процесс установки

### 1. Выбор базы данных

```
1) Install MySQL locally (Docker container)
2) Install PostgreSQL locally (Docker container)
3) Install SQL Server locally (Docker container)
4) Use external MySQL database
5) Use external PostgreSQL database
6) Use external SQL Server database
```

### 2. Настройка кэширования

```
1) Memory cache only (single instance, development)
2) Install Redis locally (Docker container)
3) Use external Redis server
```

### 3. Выбор сервисов

- High-Performance Go API (рекомендуется для продакшена)
- Skins & Capes service (для поддержки скинов Minecraft)
- Email service (для уведомлений)
- Frontend (админ-панель + сайт)
- Nginx Load Balancer (балансировщик)

### 4. Мониторинг (опционально)

- Prometheus (метрики)
- Grafana (дашборды)

### 5. Конфигурация админа

- Имя пользователя
- Email
- Пароль
- Отображаемое имя

### 6. Безопасность

- Автоматическая генерация JWT секрета
- Автоматическая генерация ключа шифрования
- Настройка SSL (самоподписанные, существующие, Let's Encrypt)

## Примеры конфигураций

### Минимальная установка (разработка)

- C# API
- Memory Cache
- Встроенная SQLite БД
- Frontend

### Стандартная установка (продакшн)

- C# API + Go API
- PostgreSQL (локальный)
- Redis (локальный)
- Frontend
- Nginx Load Balancer

### Enterprise установка

- C# API + Go API
- External PostgreSQL кластер
- External Redis кластер
- Все сервисы (скины, email)
- Frontend
- Nginx Load Balancer
- Мониторинг (Prometheus + Grafana)
- AWS S3 для файлов

### Distributed установка

- C# API + Go API (без БД и Redis)
- External PostgreSQL
- External Redis
- External Email сервер
- Только основные сервисы

## Структура файлов после установки

```
ExiledProjectCMS/
├── docker-compose.generated.yml    # Сгенерированный compose файл
├── .env                            # Конфигурация среды
├── docker-templates/               # Шаблоны компонентов
│   ├── base.yml
│   ├── database-mysql.yml
│   ├── database-postgres.yml
│   ├── database-sqlserver.yml
│   ├── cache-redis.yml
│   ├── services-go.yml
│   ├── services-skins.yml
│   ├── services-email.yml
│   ├── frontend.yml
│   ├── loadbalancer.yml
│   └── monitoring.yml
├── ssl/                            # SSL сертификаты
├── logs/                           # Логи приложения
├── storage/                        # Локальное хранилище
├── Plugins/                        # Плагины
├── Uploads/                        # Загруженные файлы
└── nginx/                          # Конфигурация Nginx
```

## Управление после установки

### Основные команды

```bash
# Запуск сервисов
docker-compose -f docker-compose.generated.yml up -d

# Остановка сервисов
docker-compose -f docker-compose.generated.yml down

# Просмотр логов
docker-compose -f docker-compose.generated.yml logs -f

# Обновление системы
git pull
docker-compose -f docker-compose.generated.yml build --pull
docker-compose -f docker-compose.generated.yml up -d
```

### Масштабирование

```bash
# Увеличить количество API инстансов
docker-compose -f docker-compose.generated.yml up -d --scale cms-api=3

# Увеличить количество Go API инстансов
docker-compose -f docker-compose.generated.yml up -d --scale go-api=5
```

## Переменные окружения

Все настройки хранятся в файле `.env`. Основные категории:

- **APPLICATION_SETTINGS**: основные настройки приложения
- **DATABASE_CONFIGURATION**: настройки базы данных
- **CACHE_CONFIGURATION**: настройки кэширования
- **API_CONFIGURATION**: настройки API сервисов
- **FRONTEND_CONFIGURATION**: настройки фронтенда
- **SECURITY**: настройки безопасности
- **EMAIL_CONFIGURATION**: настройки email
- **STORAGE_CONFIGURATION**: настройки хранилища
- **MONITORING**: настройки мониторинга

## Безопасность

### Автоматически генерируемые секреты

- JWT_SECRET (32 байта, base64)
- ENCRYPTION_KEY (24 байта, base64)
- Пароли для БД (случайные, 16+ символов)

### SSL/TLS

- Самоподписанные сертификаты для разработки
- Поддержка существующих сертификатов
- Интеграция с Let's Encrypt

### Рекомендации

1. Измените пароли по умолчанию в продакшене
2. Используйте правильные SSL сертификаты
3. Настройте файрволл для выбранных сервисов
4. Регулярно обновляйте систему
5. Создавайте резервные копии `.env` файла

## Устранение неполадок

### Проблемы с Docker

```bash
# Проверить статус контейнеров
docker ps -a

# Перезапустить сервисы
docker-compose -f docker-compose.generated.yml restart

# Полная пересборка
docker-compose -f docker-compose.generated.yml down -v
docker-compose -f docker-compose.generated.yml build --no-cache
docker-compose -f docker-compose.generated.yml up -d
```

### Проблемы с подключением к БД

1. Проверьте настройки в `.env`
2. Убедитесь, что внешняя БД доступна
3. Проверьте права доступа пользователя БД

### Проблемы с Redis

1. Проверьте подключение к Redis серверу
2. Убедитесь в правильности пароля
3. Переключитесь на Memory Cache для тестирования

## Миграция со старой версии

1. Создайте резервную копию данных
2. Остановите старые сервисы
3. Запустите новый интерактивный установщик
4. Укажите существующую БД как внешнюю
5. Восстановите пользовательские данные

## Поддержка

При возникновении проблем:

1. Проверьте логи: `docker-compose logs -f`
2. Убедитесь в правильности конфигурации `.env`
3. Проверьте статус сервисов: `docker ps`
4. Обратитесь к документации по конкретному компоненту