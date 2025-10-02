-- Тестовые данные для ExiledProjectCMS

-- Создание тестового пользователя
-- Пароль "testpass" в SHA256 хеше
INSERT INTO Users (Login, PasswordHash, UserUuid, IsBlocked, BlockReason, CreatedAt, UpdatedAt)
VALUES ('GamerVII', 'uYLlQUyYU+DXJlBG5pBzSe8WJM+Oz4xeZdxrVMyCHN0=', 'c07a9841-2275-4ba0-8f1c-2e1599a1f22f', 0, NULL,
        GETUTCDATE(), GETUTCDATE()),
       ('TestUser', 'uYLlQUyYU+DXJlBG5pBzSe8WJM+Oz4xeZdxrVMyCHN0=', 'a1b2c3d4-5e6f-7890-abcd-ef1234567890', 0, NULL,
        GETUTCDATE(), GETUTCDATE()),
       ('BlockedUser', 'uYLlQUyYU+DXJlBG5pBzSe8WJM+Oz4xeZdxrVMyCHN0=', 'b2c3d4e5-6f70-8901-bcde-f23456789012', 1,
        'Раздача на спавне', GETUTCDATE(), GETUTCDATE());

-- Создание тестовых новостей
INSERT INTO News (Title, Description, IsPublished, CreatedAt, UpdatedAt)
VALUES ('Обновление сервера v1.0',
        'Сервер обновлен до последней версии Minecraft. Добавлены новые функции и исправлены ошибки.', 1, GETUTCDATE(),
        GETUTCDATE()),
       ('Новый ивент: Строительный конкурс',
        'Приглашаем всех игроков принять участие в большом строительном конкурсе! Призы ждут победителей.', 1,
        DATEADD(hour, -2, GETUTCDATE()), DATEADD(hour, -2, GETUTCDATE())),
       ('Временные работы на сервере', 'Завтра с 10:00 до 12:00 МСК сервер будет недоступен из-за технических работ.',
        1, DATEADD(day, -1, GETUTCDATE()), DATEADD(day, -1, GETUTCDATE())),
       ('Добро пожаловать!',
        'Добро пожаловать на наш Minecraft сервер! Читайте правила и получайте удовольствие от игры.', 1,
        DATEADD(day, -3, GETUTCDATE()), DATEADD(day, -3, GETUTCDATE())),
       ('Неопубликованная новость', 'Эта новость не должна отображаться в API, так как она не опубликована.', 0,
        GETUTCDATE(), GETUTCDATE());

-- Вывод информации для проверки
SELECT 'Пользователи:' as Info;
SELECT Login, UserUuid, IsBlocked, BlockReason
FROM Users;

SELECT 'Новости:' as Info;
SELECT Title, IsPublished, CreatedAt
FROM News
ORDER BY CreatedAt DESC;