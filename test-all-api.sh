#!/bin/bash

# Скрипт для полного тестирования всех эндпоинтов API ExiledProjectCMS и Go-сервисов
# Требует curl и jq

# --- C# API ---
API_URL="http://localhost:5000"
# --- Go Services ---
SKINS_URL="http://localhost:8081"
GOAPI_URL="http://localhost:8080"
EMAIL_URL="http://localhost:8082"

ENDPOINT_COUNT=0

api_test() {
    local method=$1
    local url=$2
    local data=$3
    local expected_code=$4
    local description=$5
    local extra_headers=$6

    ((ENDPOINT_COUNT++))
    echo -e "\n=== $description ==="
    if [ "$method" == "GET" ] || [ "$method" == "DELETE" ]; then
        response=$(curl -s -w "\n%{{http_code}}" $extra_headers -X $method "$url")
    else
        response=$(curl -s -w "\n%{{http_code}}" -H "Content-Type: application/json" $extra_headers -X $method -d "$data" "$url")
    fi
    body=$(echo "$response" | head -n -1)
    code=$(echo "$response" | tail -n1)
    if [ "$code" == "$expected_code" ]; then
        echo "[OK] $method $url ($code)"
    else
        echo "[FAIL] $method $url (ожидалось $expected_code, получено $code)"
    fi
    echo "$body" | jq . || echo "$body"
}

# --- C# API ---
api_test "GET" "$API_URL/api/news" "" 200 "C# API: Get News"
api_test "POST" "$API_URL/api/v1/integrations/auth/signin" '{"login":"admin","password":"admin"}' 200 "C# API: Auth SignIn"
api_test "POST" "$API_URL/api/v1/integrations/auth/register" '{"login":"newuser","password":"newpass"}' 200 "C# API: Auth Register"
api_test "GET" "$API_URL/api/admin/system-info" "" 200 "C# API: Admin System Info"
api_test "POST" "$API_URL/api/admin/cache/clear" '{}' 200 "C# API: Admin Clear Cache"
api_test "POST" "$API_URL/api/admin/cache/clear/test*" '{}' 200 "C# API: Admin Clear Cache by Pattern"
api_test "GET" "$API_URL/api/admin/database/test-connection" "" 200 "C# API: Admin Test DB Connection"
api_test "GET" "$API_URL/api/admin/migrations" "" 200 "C# API: Admin Get Migrations"
api_test "POST" "$API_URL/api/admin/migrations/apply" '{}' 200 "C# API: Admin Apply Migrations"
api_test "GET" "$API_URL/api/admin/database/statistics" "" 200 "C# API: Admin DB Statistics"

# --- SkinsCapesService ---
UUID="12345678123456781234567812345678"
api_test "GET" "$SKINS_URL/api/v1/profile/$UUID" "" 200 "Skins: Get Profile"
api_test "POST" "$SKINS_URL/api/v1/profile/$UUID/skin" '{"skin":"base64string"}' 400 "Skins: Upload Skin (ожидается 400, нужен multipart)"
api_test "POST" "$SKINS_URL/api/v1/profile/$UUID/cape" '{"cape":"base64string"}' 400 "Skins: Upload Cape (ожидается 400, нужен multipart)"
api_test "DELETE" "$SKINS_URL/api/v1/profile/$UUID/skin" "" 200 "Skins: Delete Skin"
api_test "DELETE" "$SKINS_URL/api/v1/profile/$UUID/cape" "" 200 "Skins: Delete Cape"
api_test "GET" "$SKINS_URL/api/v1/textures/$UUID" "" 200 "Skins: Get Textures"
api_test "GET" "$SKINS_URL/api/v1/avatar/$UUID" "" 200 "Skins: Get Avatar"
api_test "GET" "$SKINS_URL/api/v1/avatar/$UUID/64" "" 200 "Skins: Get Avatar with Size"
api_test "GET" "$SKINS_URL/api/v1/head/$UUID" "" 200 "Skins: Get Head"
api_test "GET" "$SKINS_URL/api/v1/head/$UUID/64" "" 200 "Skins: Get Head with Size"
api_test "GET" "$SKINS_URL/api/v1/admin/stats" "" 200 "Skins: Admin Stats"
api_test "DELETE" "$SKINS_URL/api/v1/admin/user/$UUID" "" 200 "Skins: Admin Delete User Data"
api_test "GET" "$SKINS_URL/health" "" 200 "Skins: Health"

# --- HighPerformanceAPI ---
api_test "GET" "$GOAPI_URL/health" "" 200 "GoAPI: Health"
api_test "GET" "$GOAPI_URL/api/v1/stats" "" 200 "GoAPI: Stats"
api_test "GET" "$GOAPI_URL/api/v1/metrics" "" 200 "GoAPI: Metrics"
api_test "POST" "$GOAPI_URL/api/v1/bulk-operations" '[{"id":1}]' 200 "GoAPI: Bulk Operations"
api_test "GET" "$GOAPI_URL/api/v1/cached-news" "" 200 "GoAPI: Cached News"
api_test "POST" "$GOAPI_URL/api/v1/process-uploads" '{"files":["file1.txt"],"type":"test"}' 200 "GoAPI: Process Uploads"

# --- EmailService ---
api_test "POST" "$EMAIL_URL/api/v1/email/send" '{"to":["test@example.com"],"subject":"Test","body":"Hello"}' 200 "Email: Send Email"
api_test "POST" "$EMAIL_URL/api/v1/email/send/bulk" '{"recipients":[{"email":"test@example.com"}],"subject":"Bulk","body":"Bulk body"}' 200 "Email: Send Bulk Email"
api_test "POST" "$EMAIL_URL/api/v1/email/send/template" '{"to":["test@example.com"],"subject":"Test","template":"welcome","data":{}}' 404 "Email: Send Template Email (ожидается 404, если нет шаблона)"
api_test "GET" "$EMAIL_URL/api/v1/templates/" "" 200 "Email: Get Templates"
api_test "GET" "$EMAIL_URL/api/v1/templates/welcome" "" 404 "Email: Get Template by Name (ожидается 404, если нет)"
api_test "POST" "$EMAIL_URL/api/v1/templates/" '{"name":"welcome","subject":"Hi","html_body":"<b>Hi</b>","text_body":"Hi"}' 200 "Email: Create Template"
api_test "PUT" "$EMAIL_URL/api/v1/templates/welcome" '{"subject":"Hi2","html_body":"<b>Hi2</b>","text_body":"Hi2"}' 200 "Email: Update Template"
api_test "DELETE" "$EMAIL_URL/api/v1/templates/welcome" "" 200 "Email: Delete Template"
api_test "GET" "$EMAIL_URL/api/v1/email/logs" "" 200 "Email: Get Email Logs"
api_test "GET" "$EMAIL_URL/api/v1/email/logs/1" "" 404 "Email: Get Email Log by ID (ожидается 404, если нет)"
api_test "GET" "$EMAIL_URL/api/v1/email/stats" "" 200 "Email: Get Email Stats"
api_test "POST" "$EMAIL_URL/api/v1/email/retry/1" "" 404 "Email: Retry Email (ожидается 404, если нет)"
api_test "POST" "$EMAIL_URL/api/v1/email/test" '{"host":"localhost","port":25,"username":"","password":""}' 200 "Email: Test SMTP Connection"
api_test "POST" "$EMAIL_URL/api/v1/webhooks/email/delivered" '{}' 200 "Email: Webhook Delivered"
api_test "POST" "$EMAIL_URL/api/v1/webhooks/email/bounced" '{}' 200 "Email: Webhook Bounced"
api_test "POST" "$EMAIL_URL/api/v1/webhooks/email/complained" '{}' 200 "Email: Webhook Complained"
api_test "GET" "$EMAIL_URL/health" "" 200 "Email: Health"

echo -e "\nТестирование завершено. Проверено эндпоинтов: $ENDPOINT_COUNT."
