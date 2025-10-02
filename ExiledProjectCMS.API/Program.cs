using System.Reflection;
using ExiledProjectCMS.Application.Services;
using ExiledProjectCMS.Core.Interfaces;
using ExiledProjectCMS.Core.Repositories;
using ExiledProjectCMS.Infrastructure.Commands;
using ExiledProjectCMS.Infrastructure.Configuration;
using ExiledProjectCMS.Infrastructure.Data;
using ExiledProjectCMS.Infrastructure.Repositories;
using ExiledProjectCMS.Infrastructure.Services;
using Microsoft.OpenApi.Models;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);

// Конфигурация сервисов
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// Настройка Swagger/OpenAPI
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "ExiledProjectCMS API",
        Version = "v1",
        Description = @"
# ExiledProjectCMS - Backend API для интеграции с GMLLauncher

Система управления контентом (CMS) для интеграции с Minecraft лаунчером GMLLauncher.

## Технологическая архитектура

### Backend (C#)
- **Основной API**: ASP.NET Core с Clean Architecture
- **База данных**: SQL Server с Entity Framework Core
- **Высоконагруженные операции**: Go-сервисы (планируется)
- **Прослойки интеграции**: JavaScript/Python микросервисы (планируется)

### Frontend
- **Фронтенд**: Vue.js 3 + TypeScript (планируется)
- **Админ-панель**: Vue.js + TypeScript (планируется)

## Основные эндпоинты

### Авторизация GMLLauncher
- `POST /api/v1/integrations/auth/signin` - авторизация пользователей
- Поддержка всех статусов: 200 (успех), 401 (ошибка), 403 (блокировка), 404 (не найден)

### Новости для GMLLauncher
- `GET /api/news` - получение новостей с пагинацией
- Совместимость с форматом GMLLauncher API

## Интеграция

Для интеграции с GMLLauncher:
1. В настройках лаунчера укажите URL авторизации: `https://your-domain.com/api/v1/integrations/auth/signin`
2. Для новостей укажите: `https://your-domain.com/api/news`
        ",
        Contact = new OpenApiContact
        {
            Name = "ExiledProject Development Team",
            Email = "dev@exiledproject.com"
        },
        License = new OpenApiLicense
        {
            Name = "MIT License"
        }
    });

    // Включение XML комментариев
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath)) c.IncludeXmlComments(xmlPath);

    // Группировка по тегам
    c.TagActionsBy(api => new[] { api.GroupName ?? "Default" });
    c.DocInclusionPredicate((name, api) => true);

    // Настройка схем
    c.EnableAnnotations();
    c.UseInlineDefinitionsForEnums();
});

// Настройка базы данных (поддержка SqlServer, MySQL, PostgreSQL)
builder.Services.ConfigureDatabase(builder.Configuration);

// Настройка кеширования
var cacheProvider = builder.Configuration.GetValue<string>("CacheProvider") ?? "Memory";
switch (cacheProvider.ToLowerInvariant())
{
    case "redis":
        var redisConnectionString = builder.Configuration.GetConnectionString("Redis") ?? "localhost:6379";
        builder.Services.AddSingleton<IConnectionMultiplexer>(ConnectionMultiplexer.Connect(redisConnectionString));
        builder.Services.AddScoped<ICacheService, RedisCacheService>();
        break;
    case "memory":
    default:
        builder.Services.AddMemoryCache();
        builder.Services.AddScoped<ICacheService, MemoryCacheService>();
        break;
}

// Регистрация репозиториев
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<INewsRepository, NewsRepository>();

// Регистрация сервисов приложения
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<INewsService, NewsService>();

// Регистрация консольных команд
builder.Services.AddConsoleCommands();

// Настройка логирования
builder.Services.AddLogging(config =>
{
    config.AddConsole();
    config.AddDebug();
    config.SetMinimumLevel(LogLevel.Information);
});

// Настройка CORS для интеграции с GMLLauncher
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
            .AllowAnyMethod()
            .AllowAnyHeader();
    });
});

var app = builder.Build();

// Обработка консольных команд
await app.ProcessCommandLineArgsAsync(args);

// Конфигурация конвейера HTTP запросов
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "ExiledProjectCMS API v1");
        c.RoutePrefix = "swagger";
        c.DocumentTitle = "ExiledProjectCMS API - Swagger UI";
        c.DefaultModelsExpandDepth(-1); // Скрыть модели по умолчанию
        c.DisplayRequestDuration();
        c.EnableTryItOutByDefault();
    });
    app.UseDeveloperExceptionPage();
}
else
{
    // В продакшене тоже показываем Swagger для демонстрации
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "ExiledProjectCMS API v1");
        c.RoutePrefix = ""; // Swagger UI будет доступен на корневом пути
        c.DocumentTitle = "ExiledProjectCMS API";
    });
}

// Создание базы данных при запуске приложения
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    try
    {
        await context.Database.EnsureCreatedAsync();
        app.Logger.LogInformation("База данных успешно создана или уже существует");
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "Ошибка при создании базы данных");
    }
}

app.UseHttpsRedirection();
app.UseCors();
app.UseRouting();
app.MapControllers();

app.Logger.LogInformation("ExiledProjectCMS API запущен успешно");
app.Run();