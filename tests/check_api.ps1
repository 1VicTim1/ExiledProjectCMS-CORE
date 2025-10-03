# PowerShell script to verify the Main API endpoints
# Usage: ./tests/check_api.ps1 -BaseUrl http://localhost:5190

param(
    [string]$BaseUrl = "http://localhost:5190"
)

Write-Host "Checking health..." -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Method GET -Uri "$BaseUrl/health"
    Write-Host "Health: $($health.status)" -ForegroundColor Green
} catch {
    Write-Host "Health check failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "\nTesting auth (success)..." -ForegroundColor Cyan
try {
    $body = @{ Login = "admin"; Password = "admin123" } | ConvertTo-Json
    $resp = Invoke-RestMethod -Method POST -Uri "$BaseUrl/api/v1/integrations/auth/signin" -ContentType 'application/json' -Body $body -SkipHttpErrorCheck
    $code = $LASTEXITCODE
    Write-Host "Response: $(ConvertTo-Json $resp)" -ForegroundColor Green
} catch {
    if ($_.Exception.Response -ne $null) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $respText = $reader.ReadToEnd()
        Write-Host "Auth (success) failed: $respText" -ForegroundColor Yellow
    } else {
        Write-Host "Auth (success) failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "\nTesting auth (invalid password -> 401)..." -ForegroundColor Cyan
try {
    $body = @{ Login = "admin"; Password = "wrong" } | ConvertTo-Json
    $resp = Invoke-WebRequest -Method POST -Uri "$BaseUrl/api/v1/integrations/auth/signin" -ContentType 'application/json' -Body $body
    Write-Host "Unexpected success" -ForegroundColor Yellow
} catch {
    if ($_.Exception.Response -ne $null) {
        $status = $_.Exception.Response.StatusCode.value__
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $respText = $reader.ReadToEnd()
        Write-Host "Expected 401, got $status; body: $respText" -ForegroundColor Green
    } else {
        Write-Host "Auth (invalid) network error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "\nTesting auth (2FA required -> 401)..." -ForegroundColor Cyan
try {
    $body = @{ Login = "tester"; Password = "test123" } | ConvertTo-Json
    $resp = Invoke-WebRequest -Method POST -Uri "$BaseUrl/api/v1/integrations/auth/signin" -ContentType 'application/json' -Body $body
    Write-Host "Unexpected success" -ForegroundColor Yellow
} catch {
    if ($_.Exception.Response -ne $null) {
        $status = $_.Exception.Response.StatusCode.value__
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $respText = $reader.ReadToEnd()
        Write-Host "Expected 401 (2FA), got $status; body: $respText" -ForegroundColor Green
    } else {
        Write-Host "Auth (2FA) network error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "\nTesting auth (banned -> 403)..." -ForegroundColor Cyan
try {
    $body = @{ Login = "banned"; Password = "banned123" } | ConvertTo-Json
    $resp = Invoke-WebRequest -Method POST -Uri "$BaseUrl/api/v1/integrations/auth/signin" -ContentType 'application/json' -Body $body
    Write-Host "Unexpected success" -ForegroundColor Yellow
} catch {
    if ($_.Exception.Response -ne $null) {
        $status = $_.Exception.Response.StatusCode.value__
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $respText = $reader.ReadToEnd()
        Write-Host "Expected 403, got $status; body: $respText" -ForegroundColor Green
    } else {
        Write-Host "Auth (banned) network error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "\nTesting news list..." -ForegroundColor Cyan
try {
    $news = Invoke-RestMethod -Method GET -Uri "$BaseUrl/api/news?limit=2&offset=0"
    Write-Host "News received: $($news.Count)" -ForegroundColor Green
    $news | ForEach-Object { Write-Host (ConvertTo-Json $_) }
} catch {
    Write-Host "News request failed: $($_.Exception.Message)" -ForegroundColor Red
}
