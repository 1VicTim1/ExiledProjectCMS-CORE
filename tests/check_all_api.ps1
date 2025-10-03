# Скрипт для полного тестирования всех эндпоинтов MainApi
# Запуск: powershell -ExecutionPolicy Bypass -File tests/check_all_api.ps1

$baseUrl = "http://localhost:5000" # Измените при необходимости

Write-Host "\n== Тест: /health =="
$response = Invoke-WebRequest -Uri "$baseUrl/health" -Method GET -ErrorAction SilentlyContinue
Write-Host "Status: $($response.StatusCode)"; Write-Host $response.Content

Write-Host "\n== Тест: /api/news =="
$response = Invoke-WebRequest -Uri "$baseUrl/api/news" -Method GET -ErrorAction SilentlyContinue
Write-Host "Status: $($response.StatusCode)"; Write-Host $response.Content

Write-Host "\n== Тест: /api/v1/integrations/auth/signin (неверные данные) =="
$body = @{ Login = "notfound"; Password = "wrong" } | ConvertTo-Json
$response = Invoke-WebRequest -Uri "$baseUrl/api/v1/integrations/auth/signin" -Method POST -Body $body -ContentType 'application/json' -ErrorAction SilentlyContinue
Write-Host "Status: $($response.StatusCode)"; Write-Host $response.Content

Write-Host "\n== Тест: /api/v1/integrations/auth/signin (пустые поля) =="
$body = @{ Login = ""; Password = "" } | ConvertTo-Json
$response = Invoke-WebRequest -Uri "$baseUrl/api/v1/integrations/auth/signin" -Method POST -Body $body -ContentType 'application/json' -ErrorAction SilentlyContinue
Write-Host "Status: $($response.StatusCode)"; Write-Host $response.Content

# Для успешного теста авторизации укажите существующего пользователя:
# $body = @{ Login = "user"; Password = "password" } | ConvertTo-Json
# $response = Invoke-WebRequest -Uri "$baseUrl/api/v1/integrations/auth/signin" -Method POST -Body $body -ContentType 'application/json' -ErrorAction SilentlyContinue
# Write-Host "Status: $($response.StatusCode)"; Write-Host $response.Content

Write-Host "\n== Тест: /metrics =="
$response = Invoke-WebRequest -Uri "$baseUrl/metrics" -Method GET -ErrorAction SilentlyContinue
Write-Host "Status: $($response.StatusCode)"; Write-Host ($response.Content -split "\n")[0..10] -join "\n" # Показываем только первые строки

Write-Host "\n== Все тесты завершены =="

