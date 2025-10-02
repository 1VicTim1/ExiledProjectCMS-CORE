#!/bin/bash

# Демонстрационная конфигурация для интерактивного установщика
# Этот скрипт показывает различные сценарии использования

echo "=== ExiledProjectCMS Interactive Installer Demo ==="
echo ""
echo "Доступные сценарии установки:"
echo ""
echo "1) 🚀 Минимальная установка (разработка)"
echo "   - C# API + Memory Cache + Frontend"
echo "   - Идеально для разработки и тестирования"
echo ""
echo "2) 🏢 Стандартная установка (продакшн)"
echo "   - C# API + Go API + PostgreSQL + Redis + Frontend + Nginx"
echo "   - Рекомендуется для большинства случаев"
echo ""
echo "3) 🌐 Enterprise установка"
echo "   - Все сервисы + Мониторинг + S3 + Email"
echo "   - Максимальная функциональность"
echo ""
echo "4) ☁️ Distributed установка"
echo "   - Только API сервисы + внешние БД/Redis"
echo "   - Для кластерных развертываний"
echo ""

read -p "Выберите сценарий (1-4) или нажмите Enter для интерактивного режима: " scenario

case $scenario in
    1)
        echo "Запуск минимальной установки..."
        export DEMO_MODE="minimal"
        ;;
    2)
        echo "Запуск стандартной установки..."
        export DEMO_MODE="standard"
        ;;
    3)
        echo "Запуск enterprise установки..."
        export DEMO_MODE="enterprise"
        ;;
    4)
        echo "Запуск distributed установки..."
        export DEMO_MODE="distributed"
        ;;
    *)
        echo "Запуск интерактивного режима..."
        ;;
esac

echo ""
echo "Для полного контроля над установкой запустите:"
echo "./install-interactive.sh"
echo ""
echo "Для быстрой установки с предустановками используйте переменные окружения:"
echo "DEMO_MODE=standard ./install-interactive.sh"
echo ""