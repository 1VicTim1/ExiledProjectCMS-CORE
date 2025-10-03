#!/bin/bash

# Быстрая проверка статуса всех сервисов ExiledProjectCMS
echo "🔍 Быстрая проверка статуса ExiledProjectCMS"
echo "============================================"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функция проверки HTTP эндпоинта
check_endpoint() {
    local name="$1"
    local url="$2"
    local timeout=${3:-5}

    echo -n "Проверяю $name... "

    if curl -s --max-time $timeout --connect-timeout $timeout "$url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ РАБОТАЕТ${NC}"
        return 0
    else
        echo -e "${RED}❌ НЕ ОТВЕЧАЕТ${NC}"
        return 1
    fi
}

# Определение docker compose и файла конфигурации
COMPOSE_CMD=""
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
fi

COMPOSE_FILE="docker-compose.generated.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
  COMPOSE_FILE="docker-compose.yml"
fi

# Проверка Docker статуса
echo
echo -e "${BLUE}🐳 Docker Контейнеры:${NC}"
echo "====================="

if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker работает${NC}"
        echo
        echo "Статус контейнеров (Exiled):"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(exiled|cms|go-api|skins|email|nginx|prometheus|grafana)" || echo "Нет запущенных ExiledCMS контейнеров"

        if [ -n "$COMPOSE_CMD" ] && [ -f "$COMPOSE_FILE" ]; then
          echo
          echo -e "${BLUE}🧩 Docker Compose конфигурация:${NC}"
          echo "Файл: $COMPOSE_FILE"
          echo "Определённые сервисы:"
          $COMPOSE_CMD -f "$COMPOSE_FILE" config --services 2>/dev/null | sort | sed 's/^/  • /' || echo "(не удалось распарсить compose)"

          echo
          echo "Сравнение определённых vs запущенных:"
          defined=$($COMPOSE_CMD -f "$COMPOSE_FILE" config --services 2>/dev/null | sort)
          running=$(docker ps --format '{{.Names}}' | sort)
          for svc in $defined; do
            # ожидаем, что имена контейнеров начинаются с exiled- или совпадают с именем сервиса
            if echo "$running" | grep -E "(^|\n)(exiled-$svc|$svc)(\n|$)" >/dev/null; then
              echo -e "${GREEN}  ✓ $svc запущен${NC}"
            else
              echo -e "${RED}  ✗ $svc не запущен${NC}"
            fi
          done

          # Специальное предупреждение, если найдены только мониторинговые сервисы
          if echo "$defined" | grep -vE '^(prometheus|grafana)$' >/dev/null; then
            : # есть и другие сервисы
          else
            echo -e "${YELLOW}⚠ Обнаружены только сервисы мониторинга (Prometheus/Grafana).${NC}"
            echo -e "${YELLOW}  Если вы ожидали запуск основного API и других сервисов — перегенерируйте compose через установщик.${NC}"
          fi
        fi
    else
        echo -e "${RED}❌ Docker daemon не запущен${NC}"
    fi
else
    echo -e "${RED}❌ Docker не установлен${NC}"
fi

echo
echo -e "${BLUE}🌐 HTTP Эндпоинты:${NC}"
echo "=================="

# Основные сервисы
check_endpoint "CMS API Health" "http://localhost:5006/health"
check_endpoint "CMS API Swagger" "http://localhost:5006/swagger"
check_endpoint "Go API Health" "http://localhost:8080/health"
check_endpoint "Go API Metrics" "http://localhost:8080/metrics"
check_endpoint "Skins Service" "http://localhost:8081/health"
check_endpoint "Email Service" "http://localhost:8082/health"
check_endpoint "Nginx (Frontend)" "http://localhost:80"
check_endpoint "Redis" "http://localhost:6379" 1

echo
echo -e "${BLUE}📊 База данных:${NC}"
echo "==============="

# Проверка MySQL
echo -n "MySQL... "
if nc -z localhost 3306 2>/dev/null; then
    echo -e "${GREEN}✅ Порт 3306 открыт${NC}"
else
    echo -e "${RED}❌ Порт 3306 недоступен${NC}"
fi

echo
echo -e "${BLUE}📈 Мониторинг:${NC}"
echo "==============="

check_endpoint "Prometheus" "http://localhost:9090"
check_endpoint "Grafana" "http://localhost:3001"

echo
echo -e "${YELLOW}💡 Подсказки:${NC}"
echo "============="
echo "• Если сервисы не отвечают, проверьте: $([ -n "$COMPOSE_CMD" ] && echo "$COMPOSE_CMD ps" || echo "docker ps")"
echo "• Для перезапуска: $([ -n "$COMPOSE_CMD" ] && echo "$COMPOSE_CMD restart [service]" || echo "docker restart [container]")"
echo "• Логи сервиса: $([ -n "$COMPOSE_CMD" ] && echo "$COMPOSE_CMD logs [service]" || echo "docker logs [container]")"
echo "• Полный перезапуск: $([ -n "$COMPOSE_CMD" ] && echo "$COMPOSE_CMD -f $COMPOSE_FILE down && $COMPOSE_CMD -f $COMPOSE_FILE up -d" || echo "docker system prune")"
echo
echo "🎯 Основные URL:"
echo "• API: http://localhost:5006"
echo "• Go API: http://localhost:8080"
echo "• Frontend/Nginx: http://localhost:80"
echo "• Grafana: http://localhost:3001"