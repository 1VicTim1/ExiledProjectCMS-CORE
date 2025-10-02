# 🚀 ExiledProjectCMS - Руководство по установке

## 📋 Краткий обзор

ExiledProjectCMS предоставляет универсальную систему установки с поддержкой:

- **Одномашинной установки** - всё на одном сервере
- **Распределённого развёртывания** - компоненты на разных серверах через SSH
- **Автоматического тестирования** - проверка работоспособности после установки

## 🎯 Возможности установщика

### ✨ Основные функции

1. **Модульная установка** - выбор только нужных компонентов
2. **SSH развёртывание** - автоматическая установка на удалённые серверы
3. **Контроль доступа** - настройка безопасности для каждого сервиса
4. **Проверки здоровья** - автоматическая валидация после установки
5. **Детальная отчётность** - JSON/HTML отчёты о развёртывании

### 🧩 Доступные компоненты

| Компонент         | Описание                      | Порт           | Доступ по умолчанию |
|-------------------|-------------------------------|----------------|---------------------|
| **cms-api**       | Основное C# API               | 5006           | 0.0.0.0             |
| **go-api**        | Высокопроизводительное Go API | 8080           | 0.0.0.0             |
| **skins-service** | Minecraft скины/плащи         | 8081           | 0.0.0.0             |
| **email-service** | Почтовые уведомления          | 8082           | 127.0.0.1           |
| **admin-panel**   | Vue.js админ-панель           | 3000           | 0.0.0.0             |
| **webapp**        | Публичный Vue.js сайт         | 8090           | 0.0.0.0             |
| **nginx**         | Load balancer                 | 80/443         | 0.0.0.0             |
| **database**      | База данных                   | 3306/5432/1433 | 127.0.0.1           |
| **redis**         | Кеширование                   | 6379           | master,apis         |
| **monitoring**    | Prometheus+Grafana            | 9090/3001      | master              |

## 🚀 Быстрый запуск

### 1. Подготовка

```bash
git clone <repository_url>
cd ExiledProjectCMS
chmod +x install-universal.sh
chmod +x test-deployment.sh
```

### 2. Установка

```bash
# Запуск установщика
sudo ./install-universal.sh

# Тестирование после установки
./test-deployment.sh
```

### 3. Проверка результатов

```bash
# Просмотр инвентаря
cat /var/lib/exiledproject-cms/deployment-inventory.json | jq

# Состояние сервисов
docker-compose -f docker-compose.generated.yml ps
```

## 🛠️ Режимы установки

### 🏠 Одномашинная установка

**Когда использовать:** Разработка, тестирование, малые проекты

**Пример конфигурации:**

```
Mode: Single Machine
Host: localhost
Components: cms-api, database, redis, admin-panel
```

**Преимущества:**

- Простая настройка
- Не требует SSH
- Быстрое развёртывание

### 🌐 Распределённая установка

**Когда использовать:** Production среда, высокие нагрузки

**Пример конфигурации:**

```
Mode: Distributed
Load Balancer: 192.168.1.100
APIs: 192.168.1.101-103
Database: 192.168.1.104
Cache: 192.168.1.105
```

**Преимущества:**

- Высокая производительность
- Отказоустойчивость
- Горизонтальное масштабирование

### 🔄 Гибридная установка

**Когда использовать:** Постепенная миграция, смешанная инфраструктура

**Пример конфигурации:**

```
Mode: Hybrid
Local: database, redis, monitoring
Remote: cms-api (remote-server-1), nginx (remote-server-2)
```

## 🔐 Настройка безопасности

### SSH ключи (рекомендуется)

```bash
# Создание ключа
ssh-keygen -t rsa -b 4096 -f ~/.ssh/exiled_deployment

# Копирование на серверы
ssh-copy-id -i ~/.ssh/exiled_deployment.pub user@server

# Использование в установщике
SSH Key Path: ~/.ssh/exiled_deployment
```

### Настройки доступа

- **127.0.0.1** - только локально (база данных)
- **0.0.0.0** - публичный доступ (API, фронтенд)
- **master** - доступ только с главного хоста
- **custom** - пользовательские IP/подсети

### Firewall конфигурация

```bash
# Автоматическая настройка в скрипте
# Или ручная:
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow from 192.168.1.0/24 to any port 5006
```

## 🧪 Тестирование развёртывания

### Автоматические тесты

```bash
# Полное тестирование
./test-deployment.sh

# Результаты в:
# - /var/lib/exiledproject-cms/test-reports/test-report-*.json
# - /var/lib/exiledproject-cms/test-reports/test-report-*.html
```

### Что тестируется

- ✅ **Health checks** - состояние всех сервисов
- ⚡ **Performance** - время отклика API
- 🔍 **Security** - базовые проверки безопасности
- 🐳 **Containers** - состояние Docker контейнеров
- 🌐 **Connectivity** - доступность endpoints

### Интерпретация результатов

```bash
# Все тесты прошли
✅ All tests passed! (8/8)
🎉 Deployment is healthy and ready for use

# Частичные проблемы
⚠️ Most tests passed (6/8)
⚠️ Some services need attention

# Критические проблемы
❌ Multiple test failures (3/8 failed)
❌ Deployment needs investigation
```

## 📊 Файлы и отчёты

### Сгенерированные файлы

- **docker-compose.generated.yml** - Docker Compose конфигурация
- **deployment-inventory.json** - Инвентарь установленных компонентов
- **test-report-*.json** - Результаты тестирования (JSON)
- **test-report-*.html** - Результаты тестирования (HTML)
- **manual-deployment-*.md** - Инструкции для ручной установки

### Структура инвентаря

```json
{
  "deployment_info": {
    "timestamp": "2024-01-15T14:30:00Z",
    "mode": "distributed",
    "version": "2.0.0"
  },
  "components": {
    "cms-api": {
      "host": "192.168.1.101",
      "access": "0.0.0.0",
      "status": "deployed",
      "timestamp": "2024-01-15T14:35:00Z"
    }
  }
}
```

## 🔧 Управление после установки

### Основные команды

```bash
# Статус сервисов
docker-compose -f docker-compose.generated.yml ps

# Логи сервиса
docker-compose -f docker-compose.generated.yml logs -f cms-api

# Перезапуск сервиса
docker-compose -f docker-compose.generated.yml restart cms-api

# Остановка всех сервисов
docker-compose -f docker-compose.generated.yml down

# Обновление
git pull && docker-compose -f docker-compose.generated.yml build
```

### Мониторинг

```bash
# Проверка здоровья
./test-deployment.sh

# Просмотр метрик (если установлен monitoring)
curl http://localhost:9090/metrics

# Grafana dashboard
# http://localhost:3001 (admin/admin)
```

## 🚨 Устранение неполадок

### Частые проблемы

**SSH соединение не работает**

```bash
# Проверка ключа
ssh -i ~/.ssh/exiled_deployment user@host

# Добавление в SSH агент
ssh-add ~/.ssh/exiled_deployment
```

**Сервисы не запускаются**

```bash
# Проверка логов
docker-compose -f docker-compose.generated.yml logs

# Проверка ресурсов
docker stats
df -h
```

**Порты заняты**

```bash
# Проверка портов
netstat -tulpn | grep :5006

# Изменение портов в .env
nano .env
```

**API недоступны**

```bash
# Проверка firewall
ufw status
iptables -L

# Тестирование локально
curl http://localhost:5006/health
```

### Логи и диагностика

```bash
# Логи установки
tail -f /var/log/exiledproject-cms-install.log

# Логи приложения
docker-compose -f docker-compose.generated.yml logs cms-api

# Системные логи
journalctl -u docker -f
```

## 📈 Примеры использования

### Пример 1: Разработческая среда

```bash
# Выбор режима: Single Machine
# Компоненты: cms-api, database, redis, admin-panel
# Доступ: все 0.0.0.0 для удобства разработки

# Результат:
# http://localhost:5006 - API
# http://localhost:3000 - Admin Panel
```

### Пример 2: Production кластер

```bash
# Выбор режима: Distributed
# Load Balancer: production-lb-01 (nginx)
# API Servers: api-01, api-02, api-03 (cms-api, go-api)
# Database: db-01 (database, только 127.0.0.1)
# Cache: cache-01 (redis, ограниченный доступ)

# Результат:
# http://production-lb-01 - Главный вход
# Внутренняя коммуникация через приватную сеть
```

### Пример 3: Staging среда

```bash
# Выбор режима: Hybrid
# Локально: database, redis (для изоляции данных)
# Удалённо: cms-api, nginx (staging-server)

# Результат:
# Изолированные данные локально
# Публичные сервисы на staging сервере
```

## ❓ FAQ

**Q: Можно ли изменить конфигурацию после установки?**
A: Да, отредактируйте `docker-compose.generated.yml` и выполните `docker-compose up -d`

**Q: Как добавить новый компонент?**
A: Запустите установщик повторно, он определит существующие компоненты

**Q: Что делать если SSH недоступен?**
A: Скрипт создаст инструкции для ручной установки в `manual-deployment-*.md`

**Q: Как проверить состояние всех сервисов?**
A: Используйте `./test-deployment.sh` для полной проверки

**Q: Поддерживается ли SSL?**
A: Да, настройте SSL сертификаты в nginx конфигурации после установки

---

*Руководство для ExiledProjectCMS Universal Installer v2.0.0*