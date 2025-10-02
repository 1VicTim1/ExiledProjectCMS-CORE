# 🔧 ExiledProjectCMS - Устранение проблем сборки

## ⚠️ Решённые проблемы

### 🐹 Проблема совместимости Go версий

**Симптомы:**

```
go: go.mod requires go >= 1.23 (running go 1.21.13; GOTOOLCHAIN=local)
The command '/bin/sh -c go mod download' returned a non-zero code: 1
ERROR: Service 'go-api' failed to build : Build failed
```

**Причина:**
Go сервисы требуют Go версии 1.23+, а Dockerfile использовал более старую версию 1.21.

**✅ Решение (УЖЕ ИСПРАВЛЕНО):**

Все Dockerfile обновлены на версию Go 1.23:

```dockerfile
# Было:
FROM golang:1.21-alpine AS builder

# Стало:
FROM golang:1.23-alpine AS builder
```

**Файлы исправлены:**

- `GoServices/HighPerformanceAPI/Dockerfile`
- `GoServices/SkinsCapesService/Dockerfile`
- `GoServices/EmailService/Dockerfile`
- `GoServices/SkinsCapesService/go.mod`

## 🛠️ Автоматическое исправление

Создан скрипт `fix-go-services.sh` для автоматического исправления:

```bash
chmod +x fix-go-services.sh
./fix-go-services.sh
```

**Что делает скрипт:**

- ✅ Обновляет Go версию во всех Dockerfile до 1.23
- ✅ Обновляет Go версию во всех go.mod до 1.23
- ✅ Очищает и обновляет зависимости
- ✅ Создаёт отсутствующие go.sum файлы
- ✅ Тестирует сборку Docker образов

## 🚀 Проверка исправления

### 1. Проверка версий Go в файлах

```bash
# Проверка Dockerfile
grep "golang:" GoServices/*/Dockerfile
# Ожидаемый результат: все показывают golang:1.23-alpine

# Проверка go.mod
grep "go 1\." GoServices/*/go.mod
# Ожидаемый результат: все показывают go 1.23
```

### 2. Тест сборки конкретного сервиса

```bash
# Тестирование HighPerformanceAPI
docker build -t test-go-api GoServices/HighPerformanceAPI/

# Тестирование SkinsCapesService
docker build -t test-skins GoServices/SkinsCapesService/

# Тестирование EmailService
docker build -t test-email GoServices/EmailService/
```

### 3. Полная сборка через docker-compose

```bash
# Сборка всех Go сервисов
docker-compose build go-api skins-service email-service

# Или сборка всего проекта
docker-compose build
```

## 🔍 Диагностика проблем сборки

### Проверка Docker окружения

```bash
# Версия Docker
docker --version

# Версия Docker Compose
docker-compose --version

# Доступное место на диске
df -h

# Проверка Docker демона
docker ps
```

### Очистка Docker кеша

Если проблемы сборки продолжаются:

```bash
# Очистка build кеша
docker builder prune -f

# Удаление неиспользуемых образов
docker image prune -f

# Полная очистка (ОСТОРОЖНО!)
docker system prune -a -f
```

### Логи сборки

```bash
# Подробные логи сборки
docker-compose build --no-cache --progress=plain go-api

# Сборка конкретного сервиса с выводом
docker build --no-cache --progress=plain -t test-service GoServices/ServiceName/
```

## 🎯 Частые проблемы и решения

### 1. **Out of disk space**

**Симптомы:**

```
no space left on device
```

**Решение:**

```bash
# Очистка Docker
docker system prune -a -f

# Проверка места
df -h
```

### 2. **Network timeouts при скачивании зависимостей**

**Симптомы:**

```
timeout: the request timed out
```

**Решение:**

```bash
# Увеличение timeout в Docker
export DOCKER_BUILDKIT=1
export BUILDKIT_PROGRESS=plain

# Или использование proxy
docker build --build-arg HTTPS_PROXY=your-proxy .
```

### 3. **Permission denied ошибки**

**Симптомы:**

```
permission denied
```

**Решение:**

```bash
# Проверка прав на файлы
ls -la GoServices/*/

# Исправление прав если нужно
chmod 644 GoServices/*/go.mod
chmod 644 GoServices/*/go.sum
chmod 755 GoServices/*/
```

### 4. **Go modules checksum mismatch**

**Симптомы:**

```
verifying module: checksum mismatch
```

**Решение:**

```bash
# Для каждого Go сервиса:
cd GoServices/ServiceName/
go clean -modcache
go mod tidy
go mod download
cd -
```

## 📋 Чек-лист для устранения проблем

### ✅ Перед сборкой убедитесь:

- [ ] Docker запущен и работает
- [ ] Достаточно места на диске (минимум 2GB)
- [ ] Все Dockerfile содержат `golang:1.23-alpine`
- [ ] Все go.mod содержат `go 1.23`
- [ ] Есть все необходимые файлы (main.go, go.mod, go.sum)
- [ ] Сетевое соединение работает для скачивания зависимостей

### ✅ При проблемах попробуйте:

1. Запустите `./fix-go-services.sh`
2. Очистите Docker кеш: `docker builder prune -f`
3. Пересоберите без кеша: `docker-compose build --no-cache`
4. Проверьте логи: `docker-compose build --progress=plain`
5. Перезапустите Docker демон

### ✅ После исправления проверьте:

1. Успешная сборка: `docker-compose build`
2. Запуск сервисов: `docker-compose up -d`
3. Health checks: `./test-deployment.sh`

## 🆘 Если ничего не помогает

### Полная переустановка Go сервисов:

```bash
# 1. Остановить все сервисы
docker-compose down

# 2. Удалить все образы проекта
docker images | grep exiled | awk '{print $3}' | xargs docker rmi -f

# 3. Очистить весь Docker кеш
docker system prune -a -f

# 4. Запустить скрипт исправления
./fix-go-services.sh

# 5. Собрать заново
docker-compose build --no-cache

# 6. Запустить
docker-compose up -d
```

### Альтернативная сборка без Docker:

Если у вас установлен Go 1.23+ локально:

```bash
# Для каждого сервиса
cd GoServices/HighPerformanceAPI/
go mod tidy
go build -o high-perf-api .
./high-perf-api

cd ../SkinsCapesService/
go mod tidy
go build -o skins-service .
./skins-service

cd ../EmailService/
go mod tidy
go build -o email-service .
./email-service
```

## 📞 Поддержка

Если проблема не решается:

1. Проверьте версии:
   ```bash
   docker --version
   docker-compose --version
   go version (если установлен локально)
   ```

2. Соберите информацию о системе:
   ```bash
   uname -a
   df -h
   docker info
   ```

3. Сохраните логи ошибок:
   ```bash
   docker-compose build 2>&1 | tee build-error.log
   ```

---

**Обновлено:** После исправления версий Go все сервисы должны собираться успешно! 🎉