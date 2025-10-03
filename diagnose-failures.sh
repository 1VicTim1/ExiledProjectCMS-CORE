#!/bin/bash

# Диагностика упавших сервисов ExiledProjectCMS
echo "🔍 Диагностика упавших сервисов"
echo "==============================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}❌ Обнаружены упавшие сервисы:${NC}"
echo "• exiled-cms-api (Exit 139) - Segmentation fault"
echo "• exiled-go-api (Exit 126) - Permission denied"
echo "• exiled-email-service (Exit 1) - General error"
echo "• exiled-skins-service (Exit 1) - General error"
echo

# Функция для показа логов сервиса
show_logs() {
    local container_name="$1"
    echo -e "${BLUE}📋 Логи $container_name:${NC}"
    echo "=========================="

    if docker logs --tail 20 "$container_name" 2>/dev/null; then
        echo
    else
        echo -e "${YELLOW}⚠️ Не удалось получить логи $container_name${NC}"
        echo
    fi
}

# Проверим логи каждого упавшего сервиса
show_logs "exiled-cms-api"
show_logs "exiled-go-api"
show_logs "exiled-email-service"
show_logs "exiled-skins-service"

echo -e "${YELLOW}🔧 Рекомендуемые исправления:${NC}"
echo "============================="
echo

echo -e "${RED}1. exiled-cms-api (Exit 139 - Segfault):${NC}"
echo "   • Проверить переменные окружения (.env файл)"
echo "   • Возможно проблема с подключением к базе данных"
echo "   • Команда: docker-compose restart cms-api"
echo

echo -e "${RED}2. exiled-go-api (Exit 126 - Permission):${NC}"
echo "   • Проблема с правами на исполняемый файл"
echo "   • Нужно пересобрать образ: docker-compose build --no-cache go-api"
echo "   • Или исправить Dockerfile с chmod +x"
echo

echo -e "${RED}3. exiled-email-service (Exit 1):${NC}"
echo "   • Проверить SMTP настройки в переменных окружения"
echo "   • Убедиться что go.sum файл корректен"
echo "   • Команда: docker-compose build --no-cache email-service"
echo

echo -e "${RED}4. exiled-skins-service (Exit 1):${NC}"
echo "   • Проблема с GORM зависимостями"
echo "   • Пересобрать с исправленным go.sum"
echo "   • Команда: docker-compose build --no-cache skins-service"
echo

echo -e "${GREEN}✅ Автоматическое исправление:${NC}"
echo "=============================="
echo "1. Создать/проверить .env файл:"
echo "   cp .env.example .env"
echo
echo "2. Пересобрать все сервисы:"
echo "   docker-compose build --no-cache"
echo
echo "3. Перезапустить все:"
echo "   docker-compose down && docker-compose up -d"
echo
echo "4. Проверить статус:"
echo "   docker-compose ps"