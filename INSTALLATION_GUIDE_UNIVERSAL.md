# 🚀 ExiledProjectCMS Universal Installation Guide

## 📋 Обзор

**ExiledProjectCMS Universal Installer** - это продвинутый скрипт установки, который поддерживает:

- 🏠 **Одномашинную установку** - всё на одном сервере
- 🌐 **Распределённое развёртывание** - компоненты на разных машинах через SSH
- 🔄 **Гибридную установку** - микс локальных и удалённых компонентов
- 🔍 **Автоматические проверки здоровья** и производительности
- 📊 **Детальное логирование** и отчётность
- 🔐 **Безопасность-ориентированная** настройка доступа

## 🎯 Основные возможности

### 1. Модульная архитектура

Выберите только нужные компоненты:

- **cms-api** - Основное C# API
- **go-api** - Высокопроизводительное Go API
- **skins-service** - Сервис скинов и плащей Minecraft
- **email-service** - Почтовые уведомления
- **admin-panel** - Vue.js админ-панель
- **webapp** - Публичный Vue.js сайт
- **nginx** - Load balancer и reverse proxy
- **database** - База данных (MySQL/PostgreSQL/SQL Server)
- **redis** - Сервис кеширования
- **monitoring** - Prometheus + Grafana

### 2. SSH развёртывание

- Автоматическое подключение к удалённым серверам
- Поддержка SSH ключей и паролей
- Проверка доступности хостов
- Возможность ручной установки при недоступности

### 3. Контроль доступа

- Настройка сетевого доступа для каждого компонента
- Поддержка `127.0.0.1`, `0.0.0.0`, пользовательских IP
- Безопасные настройки по умолчанию

### 4. Мониторинг и проверки

- Проверка здоровья всех сервисов
- Бенчмарки производительности API
- Детальные отчёты в JSON и Markdown
- Автоматическое логирование

## 📦 Требования

### Системные требования

- **OS**: Linux (Ubuntu, Debian, CentOS, RHEL, Fedora, Arch)
- **Docker**: 20.10+
- **Docker Compose**: 1.29+
- **Bash**: 4.0+

### Дополнительные пакеты

```bash
curl jq ssh scp
```

### Для SSH развёртывания

- SSH доступ к целевым серверам
- SSH ключи или пароли
- sudo/root права на целевых серверах

## 🚀 Быстрый старт

### 1. Загрузка

```bash
git clone <repository_url>
cd ExiledProjectCMS
chmod +x install-universal.sh
```

### 2. Запуск установки

```bash
# Интерактивная установка
sudo ./install-universal.sh

# С логированием
sudo ./install-universal.sh 2>&1 | tee installation.log
```

## 📖 Подробное руководство

### Шаг 1: Выбор режима установки

При запуске скрипт предложит выбрать режим:

```
1) 🏠 Single Machine    - Install everything on current machine
2) 🌐 Distributed      - Deploy components across multiple machines
3) 🔄 Hybrid           - Mix of local and remote components
```

#### Одномашинная установка

- Все компоненты устанавливаются на текущей машине
- Простейший вариант для тестирования и небольших проектов
- Не требует SSH настроек

#### Распределённая установка

- Компоненты распределяются по разным серверам
- Требует SSH доступ к целевым машинам
- Идеально для production среды

#### Гибридная установка

- Часть компонентов локально, часть удалённо
- Гибкость в размещении сервисов
- Оптимально для переходных сценариев

### Шаг 2: SSH конфигурация (для распределённой/гибридной установки)

#### Настройка SSH ключей (рекомендуется)

```bash
# Создание SSH ключа
ssh-keygen -t rsa -b 4096 -f ~/.ssh/exiled_deployment

# Копирование на целевые серверы
ssh-copy-id -i ~/.ssh/exiled_deployment.pub user@target-host
```

#### Настройка в скрипте

```
SSH username [root]: deployment-user
SSH authentication method:
1) SSH Key (recommended)
2) Password (less secure)
Select authentication method (1-2): 1
SSH private key path [~/.ssh/id_rsa]: ~/.ssh/exiled_deployment
Master host IP/hostname: 192.168.1.100
```

### Шаг 3: Выбор компонентов

```
Available components:

1) Main C# API Service [cms-api]
2) High-Performance Go API [go-api]
3) Minecraft Skins & Capes [skins-service]
4) Email Notification Service [email-service]
5) Vue.js Admin Panel [admin-panel]
6) Public Vue.js Website [webapp]
7) Load Balancer & Reverse Proxy [nginx]
8) Database Service [database]
9) Cache Service [redis]
10) Prometheus + Grafana [monitoring]

Select components (comma-separated numbers, or 'all' for everything):
Selection: 1,2,7,8,9
```

### Шаг 4: Назначение хостов

Для каждого выбранного компонента укажите хост:

```
Component: Main C# API Service [cms-api]
Host for cms-api [192.168.1.100]: 192.168.1.101
✅ SSH connection to 192.168.1.101 successful
✅ Host assigned: 192.168.1.101
```

### Шаг 5: Настройка доступа

```
Component: Database Service [database]
Default access: 127.0.0.1
Options:
  127.0.0.1      - Localhost only
  master         - Master host only
  0.0.0.0        - All interfaces
  custom         - Custom IP/CIDR
Access configuration [127.0.0.1]: 127.0.0.1
```

## 🔧 Конфигурация безопасности

### Рекомендуемые настройки доступа

| Компонент         | Рекомендуемый доступ | Описание                             |
|-------------------|----------------------|--------------------------------------|
| **database**      | `127.0.0.1`          | Только локальный доступ              |
| **redis**         | `master,apis`        | Доступ с мастер-хоста и API серверов |
| **cms-api**       | `0.0.0.0`            | Публичный доступ через load balancer |
| **go-api**        | `0.0.0.0`            | Публичный доступ                     |
| **skins-service** | `0.0.0.0`            | Публичный доступ для скинов          |
| **email-service** | `127.0.0.1`          | Только локальные вызовы              |
| **nginx**         | `0.0.0.0`            | Публичный доступ                     |
| **monitoring**    | `master`             | Доступ только с мастер-хоста         |

### Пользовательские IP настройки

```bash
# Разрешить доступ только с офисной сети
Access configuration: 192.168.0.0/24

# Разрешить доступ с конкретных IP
Access configuration: 10.0.0.1,10.0.0.2,10.0.0.3
```

## 📊 Мониторинг и проверки

### Автоматические проверки здоровья

Скрипт автоматически проверяет:

- HTTP статус всех API endpoints
- Время отклика сервисов
- Состояние Docker контейнеров
- Подключения к базе данных и Redis

### Бенчмарки производительности

```
▶ Benchmarking CMS API performance
  Response Time: 0.045s
  HTTP Code: 200
  Running load test (10 concurrent requests)...
  Load Test Result: Average: 0.052 Max: 0.089 Min: 0.031
```

### Отчёты

Скрипт генерирует несколько типов отчётов:

1. **health-report-TIMESTAMP.json** - JSON отчёт о состоянии сервисов
2. **deployment-summary-TIMESTAMP.md** - Markdown сводка развёртывания
3. **deployment-inventory.json** - Инвентарь развёрнутых компонентов
4. **manual-deployment-*.md** - Инструкции для ручной установки

## 📁 Сгенерированные файлы

### docker-compose.generated.yml

Автоматически сгенерированный Docker Compose файл с выбранными компонентами

### deployment-inventory.json

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

## 🛠️ Управление после установки

### Основные команды

```bash
# Просмотр состояния сервисов
docker-compose -f docker-compose.generated.yml ps

# Просмотр логов
docker-compose -f docker-compose.generated.yml logs -f cms-api

# Перезапуск сервиса
docker-compose -f docker-compose.generated.yml restart cms-api

# Остановка всех сервисов
docker-compose -f docker-compose.generated.yml down

# Обновление конфигурации
docker-compose -f docker-compose.generated.yml up -d
```

### Мониторинг инвентаря

```bash
# Просмотр всех развёрнутых компонентов
cat /var/lib/exiledproject-cms/deployment-inventory.json | jq

# Поиск компонента по хосту
cat /var/lib/exiledproject-cms/deployment-inventory.json | jq '.components | to_entries | map(select(.value.host == "192.168.1.101"))'
```

## 🔄 Обновление развёртывания

### Добавление новых компонентов

```bash
# Запуск скрипта для добавления компонентов
sudo ./install-universal.sh

# Скрипт определит существующие компоненты и предложит добавить новые
```

### Изменение конфигурации

```bash
# Редактирование сгенерированного compose файла
nano docker-compose.generated.yml

# Применение изменений
docker-compose -f docker-compose.generated.yml up -d
```

## 🚨 Устранение неполадок

### Проблемы SSH подключения

```bash
# Проверка SSH соединения
ssh -i ~/.ssh/exiled_deployment user@target-host

# Проверка SSH агента
ssh-add -l
ssh-add ~/.ssh/exiled_deployment
```

### Проблемы с Docker

```bash
# Проверка статуса Docker
systemctl status docker

# Проверка Docker Compose версии
docker-compose --version

# Очистка неиспользуемых ресурсов
docker system prune
```

### Проблемы с сетью

```bash
# Проверка портов
netstat -tulpn | grep :5006
ss -tulpn | grep :5006

# Проверка firewall
ufw status
iptables -L
```

### Логи и диагностика

```bash
# Просмотр логов установки
tail -f /var/log/exiledproject-cms-install.log

# Просмотр логов конкретного сервиса
docker-compose -f docker-compose.generated.yml logs cms-api

# Проверка состояния health checks
docker-compose -f docker-compose.generated.yml ps
```

## 🔐 Безопасность

### Рекомендации по безопасности

1. **SSH ключи**: Используйте SSH ключи вместо паролей
2. **Firewall**: Настройте firewall правила
3. **SSL/TLS**: Настройте SSL сертификаты для production
4. **Паролі**: Смените пароли по умолчанию
5. **Обновления**: Регулярно обновляйте систему

### Настройка firewall

```bash
# UFW (Ubuntu/Debian)
ufw allow from 192.168.1.0/24 to any port 5006
ufw allow 80
ufw allow 443

# Firewalld (CentOS/RHEL)
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="5006" protocol="tcp" accept'
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --reload
```

## 📈 Примеры развёртывания

### Пример 1: Разработческая среда (всё локально)

```bash
Mode: Single Machine
Components: cms-api, database, redis, admin-panel
Access: All 0.0.0.0 (development only)
```

### Пример 2: Production среда (распределённая)

```bash
Mode: Distributed
Load Balancer: 192.168.1.100 (nginx)
APIs: 192.168.1.101-103 (cms-api, go-api, skins-service)
Database: 192.168.1.104 (database - 127.0.0.1 access)
Cache: 192.168.1.105 (redis - restricted access)
Monitoring: 192.168.1.100 (prometheus, grafana)
```

### Пример 3: Гибридная среда

```bash
Mode: Hybrid
Local: database, redis, monitoring
Remote: cms-api (192.168.1.101), nginx (192.168.1.102)
```

## ❓ FAQ

### Q: Можно ли изменить конфигурацию после установки?

A: Да, отредактируйте `docker-compose.generated.yml` и выполните `docker-compose up -d`

### Q: Как добавить новый сервер в кластер?

A: Запустите скрипт повторно, он определит существующие компоненты и позволит добавить новые

### Q: Что делать если SSH недоступен?

A: Скрипт создаст инструкции для ручной установки в файлах `manual-deployment-*.md`

### Q: Как посмотреть что где установлено?

A: Проверьте файл `/var/lib/exiledproject-cms/deployment-inventory.json`

### Q: Поддерживается ли Windows?

A: Нет, скрипт предназначен для Linux. Для Windows используйте WSL2 или Docker Desktop

---

*Создано ExiledProjectCMS Universal Installer v2.0.0*