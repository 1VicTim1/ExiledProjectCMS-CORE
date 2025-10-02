# ExiledProjectCMS - Архитектурная документация

## 🏗️ Текущая архитектура (v1.0)

### Clean Architecture в C#

```
┌──────────────────────────────────────────────────────────┐
│                    CURRENT ARCHITECTURE                  │
├──────────────────────────────────────────────────────────┤
│ Presentation Layer (API)                                 │
│ ├── Controllers/AuthController.cs                        │
│ ├── Controllers/NewsController.cs                        │
│ └── Program.cs (DI Configuration)                        │
├──────────────────────────────────────────────────────────┤
│ Application Layer                                        │
│ ├── Services/                                            │
│ │   ├── IAuthService / AuthService                       │
│ │   └── INewsService / NewsService                       │
│ └── DTOs/                                                │
│     ├── Auth/ (Request/Response models)                  │
│     └── News/ (Response models)                          │
├──────────────────────────────────────────────────────────┤
│ Domain Layer (Core)                                      │
│ ├── Entities/                                            │
│ │   ├── User.cs                                          │
│ │   └── News.cs                                          │
│ └── Repositories/ (Interfaces)                           │
│     ├── IUserRepository                                  │
│     └── INewsRepository                                  │
├──────────────────────────────────────────────────────────┤
│ Infrastructure Layer                                     │
│ ├── Data/ApplicationDbContext.cs                        │
│ └── Repositories/ (Implementations)                      │
│     ├── UserRepository                                   │
│     └── NewsRepository                                   │
└──────────────────────────────────────────────────────────┘
```

## 🔮 Планируемая микросервисная архитектура

### Многоязычная экосистема

```
┌─────────────────────────────────────────────────────────────┐
│                    PLANNED ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────┤
│ Frontend Layer                                              │
│ ├── Vue.js 3 + TypeScript (Public Site)                    │
│ ├── Vue.js 3 + TypeScript (Admin Panel)                    │
│ └── Mobile App (React Native / Flutter) [Future]           │
├─────────────────────────────────────────────────────────────┤
│ API Gateway & Load Balancer                                │
│ ├── Nginx / Traefik                                        │
│ ├── Rate Limiting                                          │
│ └── SSL Termination                                        │
├─────────────────────────────────────────────────────────────┤
│ Core Services (C#)                                         │
│ ├── Auth Service (Current + OAuth2/JWT)                    │
│ ├── News Service (Current + Rich Content)                  │
│ ├── User Management Service                                │
│ └── Admin Dashboard Service                                │
├─────────────────────────────────────────────────────────────┤
│ High-Performance Services (Go)                             │
│ ├── Real-time Chat Service                                 │
│ ├── Game Statistics Collector                              │
│ ├── File Upload/CDN Service                                │
│ └── WebSocket Notification Hub                             │
├─────────────────────────────────────────────────────────────┤
│ Integration Layer (JS/Python)                              │
│ ├── GML Launcher Bridge (Node.js)                          │
│ ├── Minecraft Server Connector (Python)                    │
│ ├── Discord Bot Integration (Discord.js)                   │
│ └── External API Adapters                                  │
├─────────────────────────────────────────────────────────────┤
│ Data Layer                                                  │
│ ├── SQL Server (Core Data)                                 │
│ ├── Redis (Caching & Sessions)                             │
│ ├── MongoDB (Logs & Analytics)                             │
│ └── MinIO/S3 (File Storage)                                │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Технологический стек по слоям

### Backend Services

#### C# Services (ASP.NET Core)

- **Auth Service**: Расширенная аутентификация с JWT, OAuth2, 2FA
- **CMS Service**: Управление контентом, новости, страницы
- **User Service**: Профили, настройки, достижения
- **Admin Service**: Административная панель

**Преимущества C#:**

- Строгая типизация и производительность
- Богатая экосистема .NET
- Отличная интеграция с SQL Server
- Зрелые инструменты для Web API

#### Go Services (Высоконагруженные)

- **Real-time Chat**: WebSocket чат с поддержкой каналов
- **Statistics Collector**: Сбор метрик игроков в реальном времени
- **File Service**: Загрузка/раздача файлов модов и текстур
- **Notification Hub**: Push уведомления и WebSocket события

**Преимущества Go:**

- Отличная производительность для concurrent операций
- Низкое потребление памяти
- Простота развертывания (single binary)
- Идеально для WebSocket и streaming

#### JS/Python Интеграции

- **Node.js Bridge**: Адаптер для GML Launcher API
- **Python Connectors**: Интеграция с Minecraft серверами через RCON
- **Discord Bot**: JavaScript бот для Discord интеграции
- **Webhook Handlers**: Обработка внешних webhook'ов

**Преимущества JS/Python:**

- Быстрая разработка интеграций
- Богатые экосистемы библиотек
- Простота в поддержке и изменении
- Хорошо подходят для glue-кода

### Frontend

#### Vue.js 3 + TypeScript

- **Public Site**: Новости, информация о сервере, регистрация
- **Admin Panel**: Управление пользователями, контентом, настройками
- **Player Dashboard**: Личный кабинет игрока, статистика, настройки

**Преимущества Vue.js:**

- Простота в изучении и разработке
- Отличная реактивность
- TypeScript поддержка из коробки
- Хорошая экосистема (Vuetify, Pinia)

## 🔄 Межсервисное взаимодействие

### Паттерны коммуникации

```
┌─────────────────────────────────────────────────────────┐
│                SERVICE COMMUNICATION                    │
├─────────────────────────────────────────────────────────┤
│ Synchronous                                             │
│ ├── HTTP/REST (C# ↔ C#, Frontend ↔ C#)                 │
│ ├── gRPC (C# ↔ Go, Go ↔ Go)                           │
│ └── GraphQL (Frontend ↔ Aggregated APIs)               │
├─────────────────────────────────────────────────────────┤
│ Asynchronous                                            │
│ ├── Message Queues (RabbitMQ / Apache Kafka)           │
│ ├── Event Sourcing                                     │
│ └── WebSockets (Real-time updates)                     │
├─────────────────────────────────────────────────────────┤
│ Data Consistency                                        │
│ ├── Distributed Transactions (Saga Pattern)            │
│ ├── Event Sourcing                                     │
│ └── CQRS (Command Query Responsibility Segregation)    │
└─────────────────────────────────────────────────────────┘
```

## 📊 Масштабирование и производительность

### Горизонтальное масштабирование

```yaml
# docker-compose.yml example
version: '3.8'
services:
  # C# Services
  auth-service:
    image: exiledproject/auth-service:latest
    replicas: 3

  cms-service:
    image: exiledproject/cms-service:latest
    replicas: 2

  # Go Services
  chat-service:
    image: exiledproject/chat-service:latest
    replicas: 2

  stats-collector:
    image: exiledproject/stats-service:latest
    replicas: 1

  # Data Services
  postgres:
    image: postgres:15

  redis:
    image: redis:7-alpine

  nginx:
    image: nginx:alpine
    replicas: 2
```

### Производительность по сервисам

| Сервис          | Язык | Ожидаемый RPS | Память | CPU    |
|-----------------|------|---------------|--------|--------|
| Auth Service    | C#   | 1,000         | 256MB  | Low    |
| CMS Service     | C#   | 2,000         | 512MB  | Low    |
| Chat Service    | Go   | 10,000        | 128MB  | Medium |
| File Service    | Go   | 5,000         | 256MB  | High   |
| Stats Collector | Go   | 50,000        | 512MB  | High   |

## 🔐 Безопасность и авторизация

### Многоуровневая безопасность

```
┌─────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS                      │
├─────────────────────────────────────────────────────────┤
│ API Gateway Layer                                       │
│ ├── Rate Limiting (по IP и пользователю)                │
│ ├── CORS настройки                                      │
│ ├── SSL/TLS терминация                                  │
│ └── WAF (Web Application Firewall)                      │
├─────────────────────────────────────────────────────────┤
│ Authentication Layer                                    │
│ ├── JWT Tokens с коротким TTL                          │
│ ├── Refresh Tokens                                     │
│ ├── OAuth2 providers (Discord, Google)                 │
│ └── 2FA/MFA поддержка                                  │
├─────────────────────────────────────────────────────────┤
│ Authorization Layer                                     │
│ ├── Role-Based Access Control (RBAC)                   │
│ ├── Permission-Based (Claims)                          │
│ ├── Resource-Level permissions                         │
│ └── Service-to-Service tokens                          │
├─────────────────────────────────────────────────────────┤
│ Data Protection                                         │
│ ├── Encryption at Rest                                 │
│ ├── Encryption in Transit                              │
│ ├── PII Data anonymization                             │
│ └── Audit Logging                                      │
└─────────────────────────────────────────────────────────┘
```

## 📈 Мониторинг и наблюдаемость

### Observability Stack

- **Metrics**: Prometheus + Grafana
- **Logging**: ELK Stack (Elasticsearch, Logstash, Kibana)
- **Tracing**: Jaeger или OpenTelemetry
- **Health Checks**: Built-in endpoints для каждого сервиса
- **Alerting**: AlertManager + Slack/Discord интеграция

### Key Performance Indicators (KPIs)

1. **Бизнес метрики**:
    - Количество активных игроков
    - Успешность авторизации
    - Использование новостей

2. **Технические метрики**:
    - Response time по сервисам
    - Error rate
    - Throughput (RPS)
    - Resource utilization

## 🚀 Развертывание и CI/CD

### Containerization Strategy

```dockerfile
# Пример для C# сервиса
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["ExiledProjectCMS.API/ExiledProjectCMS.API.csproj", "ExiledProjectCMS.API/"]
RUN dotnet restore "ExiledProjectCMS.API/ExiledProjectCMS.API.csproj"
COPY . .
WORKDIR "/src/ExiledProjectCMS.API"
RUN dotnet build "ExiledProjectCMS.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "ExiledProjectCMS.API.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "ExiledProjectCMS.API.dll"]
```

### Deployment Pipeline

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Test C# Services
        run: dotnet test
      - name: Test Go Services
        run: go test ./...
      - name: Test JS Services
        run: npm test

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Build Docker images
      - name: Push to registry

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Kubernetes
```

## 🔄 Миграционная стратегия

### Поэтапная миграция от монолита к микросервисам

1. **Этап 1** (Текущий): Монолитный C# API
2. **Этап 2**: Выделение Auth сервиса
3. **Этап 3**: Добавление Go сервисов для высоких нагрузок
4. **Этап 4**: JS/Python интеграционные сервисы
5. **Этап 5**: Полная микросервисная архитектура

### Стратегия данных

- **Phase 1**: Shared Database
- **Phase 2**: Database per Service
- **Phase 3**: CQRS + Event Sourcing для критических сервисов

## 📋 Заключение

Архитектура ExiledProjectCMS спроектирована для:

- **Масштабируемости**: Горизонтальное масштабирование сервисов
- **Производительности**: Использование оптимальных языков для задач
- **Поддерживаемости**: Четкое разделение ответственности
- **Расширяемости**: Простота добавления новых функций
- **Надежности**: Fault tolerance и graceful degradation

Текущая реализация на C# служит стабильной основой для постепенного перехода к более сложной микросервисной архитектуре
по мере роста нагрузки и требований.