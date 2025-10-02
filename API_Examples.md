# ExiledProjectCMS API - Примеры запросов

Коллекция примеров для тестирования API совместимости с GMLLauncher.

## 🔐 Авторизация (Authentication)

### Эндпоинт: `POST /api/v1/integrations/auth/signin`

#### ✅ Успешная авторизация (200)

```bash
curl -X POST "https://localhost:5001/api/v1/integrations/auth/signin" \
  -H "Content-Type: application/json" \
  -d '{
    "Login": "GamerVII",
    "Password": "testpass"
  }'
```

**Ответ:**

```json
{
  "Login": "GamerVII",
  "UserUuid": "c07a9841-2275-4ba0-8f1c-2e1599a1f22f",
  "Message": "Успешная авторизация"
}
```

#### ❌ Неверный пароль (401)

```bash
curl -X POST "https://localhost:5001/api/v1/integrations/auth/signin" \
  -H "Content-Type: application/json" \
  -d '{
    "Login": "GamerVII",
    "Password": "wrongpassword"
  }'
```

**Ответ:**

```json
{
  "Message": "Неверный логин или пароль"
}
```

#### 🚫 Заблокированный пользователь (403)

```bash
curl -X POST "https://localhost:5001/api/v1/integrations/auth/signin" \
  -H "Content-Type: application/json" \
  -d '{
    "Login": "BlockedUser",
    "Password": "testpass"
  }'
```

**Ответ:**

```json
{
  "Message": "Пользователь заблокирован. Причина: Раздача на спавне"
}
```

#### 👤 Пользователь не найден (404)

```bash
curl -X POST "https://localhost:5001/api/v1/integrations/auth/signin" \
  -H "Content-Type: application/json" \
  -d '{
    "Login": "NonExistentUser",
    "Password": "anypassword"
  }'
```

**Ответ:**

```json
{
  "Message": "Пользователь не найден"
}
```

#### 📝 Некорректные данные (400)

```bash
curl -X POST "https://localhost:5001/api/v1/integrations/auth/signin" \
  -H "Content-Type: application/json" \
  -d '{
    "Login": "",
    "Password": ""
  }'
```

**Ответ:**

```json
{
  "Message": "Некорректные данные запроса"
}
```

---

## 📰 Новости (News)

### Эндпоинт: `GET /api/news`

#### 📋 Все новости

```bash
curl -X GET "https://localhost:5001/api/news" \
  -H "Accept: application/json"
```

#### 📄 Пагинация - первые 5 новостей

```bash
curl -X GET "https://localhost:5001/api/news?limit=5" \
  -H "Accept: application/json"
```

#### 📄 Пагинация - следующие 5 новостей

```bash
curl -X GET "https://localhost:5001/api/news?limit=5&offset=5" \
  -H "Accept: application/json"
```

#### 📊 Пример ответа новостей

```json
[
  {
    "id": 1,
    "title": "Обновление сервера v1.0",
    "description": "Сервер обновлен до последней версии Minecraft. Добавлены новые функции и исправлены ошибки.",
    "createdAt": "2024-01-01T12:00:00.000Z"
  },
  {
    "id": 2,
    "title": "Новый ивент: Строительный конкурс",
    "description": "Приглашаем всех игроков принять участие в большом строительном конкурсе! Призы ждут победителей.",
    "createdAt": "2024-01-01T10:00:00.000Z"
  }
]
```

#### ❌ Некорректные параметры (400)

```bash
# Отрицательный limit
curl -X GET "https://localhost:5001/api/news?limit=-1" \
  -H "Accept: application/json"

# Отрицательный offset
curl -X GET "https://localhost:5001/api/news?offset=-5" \
  -H "Accept: application/json"
```

**Ответ:**

```json
{
  "Message": "Параметр limit должен быть больше или равен 0"
}
```

---

## 🧪 Тестирование в PowerShell

### Авторизация

```powershell
# Успешная авторизация
$authBody = @{
    Login = "GamerVII"
    Password = "testpass"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://localhost:5001/api/v1/integrations/auth/signin" `
                  -Method POST `
                  -Body $authBody `
                  -ContentType "application/json"
```

### Получение новостей

```powershell
# Все новости
Invoke-RestMethod -Uri "https://localhost:5001/api/news" -Method GET

# С пагинацией
Invoke-RestMethod -Uri "https://localhost:5001/api/news?limit=3&offset=0" -Method GET
```

---

## 🌐 Интеграция с GMLLauncher

### Настройка в GMLLauncher

1. **Авторизация:**
    - Перейдите в настройки: `Интеграции` → `Аутентификация` → `Собственная аутентификация`
    - URL: `https://your-domain.com/api/v1/integrations/auth/signin`

2. **Новости:**
    - Перейдите в настройки: `Интеграции` → `Импорт новостей с внешнего ресурса`
    - URL: `https://your-domain.com/api/news`

### Проверка совместимости

Все ответы API строго соответствуют требованиям GMLLauncher:

- ✅ Статусы HTTP: 200, 401, 403, 404
- ✅ Формат JSON ответов
- ✅ Структура данных авторизации
- ✅ Формат массива новостей
- ✅ Поддержка пагинации

---

## 🔧 Дополнительные инструменты

### Postman Collection

```json
{
  "info": {
    "name": "ExiledProjectCMS API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Auth - Successful Login",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"Login\": \"GamerVII\",\n  \"Password\": \"testpass\"\n}"
        },
        "url": {
          "raw": "{{baseUrl}}/api/v1/integrations/auth/signin",
          "host": ["{{baseUrl}}"],
          "path": ["api", "v1", "integrations", "auth", "signin"]
        }
      }
    },
    {
      "name": "News - Get All",
      "request": {
        "method": "GET",
        "url": {
          "raw": "{{baseUrl}}/api/news",
          "host": ["{{baseUrl}}"],
          "path": ["api", "news"]
        }
      }
    }
  ],
  "variable": [
    {
      "key": "baseUrl",
      "value": "https://localhost:5001"
    }
  ]
}
```