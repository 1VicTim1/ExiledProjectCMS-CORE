# ExiledProjectCMS Interactive Installer for Windows
# Advanced modular installation with component selection

param(
    [switch]$SkipPrerequisites,
    [string]$EnvFile = ".env",
    [string]$LogFile
)

# Global variables
$script:SelectedComponents = @()
$script:ExternalServices = @()
$script:ComposeFile = "docker-compose.generated.yml"
$script:LogFile = if ($LogFile) { $LogFile } else { "exiledproject-cms-install.log" }
$script:EnvFile = $EnvFile
$script:EnvFileProvided = $PSBoundParameters.ContainsKey('EnvFile')

# Configuration variables
$script:DatabaseProvider = ""
$script:CacheProvider = ""
$script:AdminUsername = ""
$script:AdminEmail = ""
$script:AdminPassword = ""
$script:DomainName = ""
$script:JWTSecret = ""
$script:EncryptionKey = ""

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Write-Host $logMessage
    $logMessage | Add-Content -Path $script:LogFile
}

function Init-Logging {
    try {
        $dir = Split-Path -Parent $script:LogFile
        if ($dir -and -not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        New-Item -ItemType File -Path $script:LogFile -Force | Out-Null
    } catch {
        $script:LogFile = ".\install.log"
        New-Item -ItemType File -Path $script:LogFile -Force | Out-Null
    }
}

function Write-Banner {
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║       ExiledProjectCMS Interactive Installer       ║" -ForegroundColor Cyan
    Write-Host "║        Advanced Modular Installation System         ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "This installer will guide you through a custom installation" -ForegroundColor Green
    Write-Host "where you can choose exactly what components to install." -ForegroundColor Green
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "[STEP] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Ask-YesNo {
    param(
        [string]$Prompt,
        [string]$Default = "n"
    )

    do {
        if ($Default -eq "y") {
            $response = Read-Host "$Prompt [Y/n]"
            if ([string]::IsNullOrWhiteSpace($response)) { $response = "y" }
        } else {
            $response = Read-Host "$Prompt [y/N]"
            if ([string]::IsNullOrWhiteSpace($response)) { $response = "n" }
        }

        switch ($response.ToLower()) {
            "y" { return $true }
            "yes" { return $true }
            "n" { return $false }
            "no" { return $false }
            default { Write-Host "Please answer yes or no." -ForegroundColor Yellow }
        }
    } while ($true)
}

function Select-Database {
    Write-Host "`n=== DATABASE CONFIGURATION ===" -ForegroundColor Cyan
    Write-Host "Choose your database setup:"
    Write-Host ""
    Write-Host "1) Install MySQL locally (Docker container)"
    Write-Host "2) Install PostgreSQL locally (Docker container)"
    Write-Host "3) Install SQL Server locally (Docker container)"
    Write-Host "4) Use external MySQL database"
    Write-Host "5) Use external PostgreSQL database"
    Write-Host "6) Use external SQL Server database"
    Write-Host ""

    do {
        $dbChoice = Read-Host "Select database option (1-6)"
        switch ($dbChoice) {
            "1" {
                $script:DatabaseProvider = "MySQL"
                $script:SelectedComponents += "database-mysql"
                break
            }
            "2" {
                $script:DatabaseProvider = "PostgreSQL"
                $script:SelectedComponents += "database-postgres"
                break
            }
            "3" {
                $script:DatabaseProvider = "SqlServer"
                $script:SelectedComponents += "database-sqlserver"
                break
            }
            "4" {
                $script:DatabaseProvider = "MySQL"
                $script:ExternalServices += "mysql"
                Configure-ExternalDatabase -DbType "mysql"
                break
            }
            "5" {
                $script:DatabaseProvider = "PostgreSQL"
                $script:ExternalServices += "postgres"
                Configure-ExternalDatabase -DbType "postgres"
                break
            }
            "6" {
                $script:DatabaseProvider = "SqlServer"
                $script:ExternalServices += "sqlserver"
                Configure-ExternalDatabase -DbType "sqlserver"
                break
            }
            default {
                Write-Host "Invalid choice. Please select 1-6." -ForegroundColor Yellow
                continue
            }
        }
        break
    } while ($true)

    Write-Host "✓ Database: $($script:DatabaseProvider)" -ForegroundColor Green
}

function Configure-ExternalDatabase {
    param([string]$DbType)

    Write-Host "`nConfiguring external $DbType database:" -ForegroundColor Yellow

    $dbHost = Read-Host "Database host"
    $dbPort = Read-Host "Database port [default]"
    $dbName = Read-Host "Database name"
    $dbUser = Read-Host "Database username"
    $dbPassword = Read-Host "Database password" -AsSecureString
    $dbPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassword))

    switch ($DbType) {
        "mysql" {
            if ([string]::IsNullOrEmpty($dbPort)) { $dbPort = "3306" }
            $script:DbConnectionString = "Server=$dbHost;Port=$dbPort;Database=$dbName;Uid=$dbUser;Pwd=$dbPasswordPlain;"
            $script:GoDbConnectionString = "$dbUser`:$dbPasswordPlain@tcp($dbHost`:$dbPort)/$dbName`?charset=utf8mb4&parseTime=True&loc=Local"
        }
        "postgres" {
            if ([string]::IsNullOrEmpty($dbPort)) { $dbPort = "5432" }
            $script:DbConnectionString = "Host=$dbHost;Port=$dbPort;Database=$dbName;Username=$dbUser;Password=$dbPasswordPlain;"
            $script:GoDbConnectionString = "postgres://$dbUser`:$dbPasswordPlain@$dbHost`:$dbPort/$dbName`?sslmode=disable"
        }
        "sqlserver" {
            if ([string]::IsNullOrEmpty($dbPort)) { $dbPort = "1433" }
            $script:DbConnectionString = "Server=$dbHost,$dbPort;Database=$dbName;User Id=$dbUser;Password=$dbPasswordPlain;TrustServerCertificate=true;"
            $script:GoDbConnectionString = "sqlserver://$dbUser`:$dbPasswordPlain@$dbHost`:$dbPort`?database=$dbName"
        }
    }
}

function Select-Cache {
    Write-Host "`n=== CACHE CONFIGURATION ===" -ForegroundColor Cyan
    Write-Host "Choose your caching setup:"
    Write-Host ""
    Write-Host "1) Memory cache only (single instance, development)"
    Write-Host "2) Install Redis locally (Docker container)"
    Write-Host "3) Use external Redis server"
    Write-Host ""

    do {
        $cacheChoice = Read-Host "Select cache option (1-3)"
        switch ($cacheChoice) {
            "1" {
                $script:CacheProvider = "Memory"
                $script:RedisConnectionString = ""
                break
            }
            "2" {
                $script:CacheProvider = "Redis"
                $script:SelectedComponents += "cache-redis"
                $script:RedisConnectionString = "redis:6379,password=`${REDIS_PASSWORD}"
                break
            }
            "3" {
                $script:CacheProvider = "Redis"
                $script:ExternalServices += "redis"
                Configure-ExternalRedis
                break
            }
            default {
                Write-Host "Invalid choice. Please select 1-3." -ForegroundColor Yellow
                continue
            }
        }
        break
    } while ($true)

    Write-Host "✓ Cache: $($script:CacheProvider)" -ForegroundColor Green
}

function Configure-ExternalRedis {
    Write-Host "`nConfiguring external Redis:" -ForegroundColor Yellow

    $redisHost = Read-Host "Redis host"
    $redisPort = Read-Host "Redis port [6379]"
    if ([string]::IsNullOrEmpty($redisPort)) { $redisPort = "6379" }

    $redisPassword = Read-Host "Redis password (leave empty if none)" -AsSecureString
    $redisPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($redisPassword))

    if (![string]::IsNullOrEmpty($redisPasswordPlain)) {
        $script:RedisConnectionString = "$redisHost`:$redisPort,password=$redisPasswordPlain"
    } else {
        $script:RedisConnectionString = "$redisHost`:$redisPort"
    }
}

function Select-Services {
    Write-Host "`n=== SERVICES CONFIGURATION ===" -ForegroundColor Cyan
    Write-Host "Choose which services to install:"
    Write-Host ""

    # High-performance Go API
    if (Ask-YesNo "Install High-Performance Go API? (recommended for production)" "y") {
        $script:SelectedComponents += "services-go"
        Write-Host "✓ Go API will be installed" -ForegroundColor Green
    }

    # Skins & Capes service
    if (Ask-YesNo "Install Skins & Capes service? (for Minecraft skins support)" "y") {
        $script:SelectedComponents += "services-skins"
        Write-Host "✓ Skins & Capes service will be installed" -ForegroundColor Green

        # S3 Storage configuration for skins
        if (Ask-YesNo "Use AWS S3 for skins storage? (otherwise local storage)" "n") {
            Configure-S3Storage
        }
    }

    # Email service
    if (Ask-YesNo "Install Email service?" "y") {
        $script:SelectedComponents += "services-email"
        Configure-EmailService
        Write-Host "✓ Email service will be installed" -ForegroundColor Green
    }

    # Frontend
    if (Ask-YesNo "Install Frontend (Admin Panel + Website)?" "y") {
        $script:SelectedComponents += "frontend"
        Write-Host "✓ Frontend will be installed" -ForegroundColor Green
    }

    # Load Balancer
    if (Ask-YesNo "Install Nginx Load Balancer?" "y") {
        $script:SelectedComponents += "loadbalancer"
        Write-Host "✓ Nginx Load Balancer will be installed" -ForegroundColor Green
    }
}

function Configure-S3Storage {
    Write-Host "`nConfiguring AWS S3 storage:" -ForegroundColor Yellow

    $script:AwsAccessKeyId = Read-Host "AWS Access Key ID"
    $awsSecretKey = Read-Host "AWS Secret Access Key" -AsSecureString
    $script:AwsSecretAccessKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($awsSecretKey))

    $script:AwsRegion = Read-Host "AWS Region [us-east-1]"
    if ([string]::IsNullOrEmpty($script:AwsRegion)) { $script:AwsRegion = "us-east-1" }

    $script:AwsS3Bucket = Read-Host "S3 Bucket name"
    $script:StorageProvider = "s3"
}

function Configure-EmailService {
    Write-Host "`nConfiguring Email service:" -ForegroundColor Yellow

    $script:SmtpHost = Read-Host "SMTP Host (e.g., smtp.gmail.com)"
    $script:SmtpPort = Read-Host "SMTP Port [587]"
    if ([string]::IsNullOrEmpty($script:SmtpPort)) { $script:SmtpPort = "587" }

    $script:SmtpUsername = Read-Host "SMTP Username"
    $smtpPassword = Read-Host "SMTP Password" -AsSecureString
    $script:SmtpPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($smtpPassword))

    $script:SmtpFrom = Read-Host "From Email Address"

    if (Ask-YesNo "Use TLS encryption?" "y") {
        $script:SmtpUseTls = "true"
    } else {
        $script:SmtpUseTls = "false"
    }
}

function Select-Monitoring {
    Write-Host "`n=== MONITORING CONFIGURATION ===" -ForegroundColor Cyan

    if (Ask-YesNo "Install monitoring stack (Prometheus + Grafana)?" "n") {
        $script:SelectedComponents += "monitoring"

        Write-Host "`nConfiguring Grafana:" -ForegroundColor Yellow
        $script:GrafanaAdminUser = Read-Host "Grafana admin username [admin]"
        if ([string]::IsNullOrEmpty($script:GrafanaAdminUser)) { $script:GrafanaAdminUser = "admin" }

        do {
            $grafanaPassword = Read-Host "Grafana admin password (min 8 characters)" -AsSecureString
            $script:GrafanaPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($grafanaPassword))

            if ($script:GrafanaPassword.Length -ge 8) {
                break
            } else {
                Write-Error "Password must be at least 8 characters long"
            }
        } while ($true)

        Write-Host "✓ Monitoring stack will be installed" -ForegroundColor Green
    }
}

function Configure-AdminUser {
    Write-Host "`n=== ADMIN USER CONFIGURATION ===" -ForegroundColor Cyan

    $script:AdminUsername = Read-Host "Admin username [admin]"
    if ([string]::IsNullOrEmpty($script:AdminUsername)) { $script:AdminUsername = "admin" }

    $script:AdminEmail = Read-Host "Admin email [admin@example.com]"
    if ([string]::IsNullOrEmpty($script:AdminEmail)) { $script:AdminEmail = "admin@example.com" }

    $script:AdminDisplayName = Read-Host "Admin display name [Super Admin]"
    if ([string]::IsNullOrEmpty($script:AdminDisplayName)) { $script:AdminDisplayName = "Super Admin" }

    do {
        $adminPassword = Read-Host "Admin password (min 8 characters)" -AsSecureString
        $script:AdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPassword))

        if ($script:AdminPassword.Length -ge 8) {
            break
        } else {
            Write-Error "Password must be at least 8 characters long"
        }
    } while ($true)

    Write-Host "✓ Admin user configured" -ForegroundColor Green
}

function Configure-Security {
    Write-Host "`n=== SECURITY CONFIGURATION ===" -ForegroundColor Cyan

    # Generate secure random keys
    $script:JWTSecret = [System.Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    $script:EncryptionKey = [System.Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(24))

    Write-Host "✓ JWT secret generated" -ForegroundColor Green
    Write-Host "✓ Encryption key generated" -ForegroundColor Green

    # Domain configuration
    $script:DomainName = Read-Host "Domain name (for SSL configuration) [localhost]"
    if ([string]::IsNullOrEmpty($script:DomainName)) { $script:DomainName = "localhost" }

    if ($script:DomainName -ne "localhost") {
        if (Ask-YesNo "Configure SSL certificates?" "y") {
            Configure-SSL
        }
    }
}

function Configure-SSL {
    Write-Host "`nSSL Configuration:" -ForegroundColor Yellow
    Write-Host "1) Generate self-signed certificates"
    Write-Host "2) Use existing certificates"
    Write-Host "3) Use Let's Encrypt (manual setup required)"

    do {
        $sslChoice = Read-Host "Select SSL option (1-3)"
        switch ($sslChoice) {
            "1" {
                $script:SslMode = "self-signed"
                break
            }
            "2" {
                $script:SslMode = "existing"
                $script:SslCertPath = Read-Host "Path to SSL certificate file"
                $script:SslKeyPath = Read-Host "Path to SSL private key file"
                break
            }
            "3" {
                $script:SslMode = "letsencrypt"
                $script:LetsencryptEmail = Read-Host "Email for Let's Encrypt"
                break
            }
            default {
                Write-Host "Invalid choice. Please select 1-3." -ForegroundColor Yellow
                continue
            }
        }
        break
    } while ($true)
}

function Generate-RandomPassword {
    param([int]$Length = 16)
    $characters = 'abcdefghkmnprstuvwxyzABCDEFGHKMNPRSTUVWXYZ123456789'
    $password = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $password += $characters[(Get-Random -Maximum $characters.Length)]
    }
    return $password + "!"
}

function Generate-DockerCompose {
    Write-Step "Generating Docker Compose configuration..."

    # Start with base template
    Get-Content "docker-templates\base.yml" | Set-Content $script:ComposeFile

    # Add component templates
    foreach ($component in $script:SelectedComponents) {
        # Guard: skip frontend if sources are missing to avoid build errors
        if ($component -eq 'frontend') {
            $adminExists = Test-Path "Frontend\admin-panel"
            $webappExists = Test-Path "Frontend\webapp"
            if (-not $adminExists -and -not $webappExists) {
                Write-Warning "Frontend sources not found (Frontend/admin-panel or Frontend/webapp). Skipping frontend component."
                continue
            }
        }
        "`n# === $component ===" | Add-Content $script:ComposeFile
        # Remove version and networks section from component files
        Get-Content "docker-templates\$component.yml" |
            Where-Object { $_ -notmatch '^version:' -and $_ -notmatch '^networks:' } |
            Add-Content $script:ComposeFile
    }

    # Add networks section
    @"
`n# === NETWORKS ===
networks:
  exiled-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
"@ | Add-Content $script:ComposeFile

    Write-Success "Docker Compose configuration generated: $($script:ComposeFile)"
}

function Generate-EnvFile {
    Write-Step "Generating environment configuration..."

    # If a custom env file was provided and exists, do not overwrite
    if ((Test-Path $script:EnvFile) -and $script:EnvFileProvided) {
        Write-Warning "Environment file already exists at $($script:EnvFile). Using existing file."
        Write-Log "Using existing env file: $($script:EnvFile)"
        return
    }

    # Generate random passwords for databases
    $dbPassword = Generate-RandomPassword
    $dbSaPassword = Generate-RandomPassword + "Strong"
    $dbRootPassword = Generate-RandomPassword + "Root"
    $redisPassword = Generate-RandomPassword

    $envContent = @"
# ExiledProjectCMS Environment Configuration
# Generated by Interactive Installer on $(Get-Date)

# ===========================================
# APPLICATION SETTINGS
# ===========================================
ENVIRONMENT=production
APPLICATION_NAME=ExiledProjectCMS
DOMAIN_NAME=$($script:DomainName)

# ===========================================
# DATABASE CONFIGURATION
# ===========================================
DATABASE_PROVIDER=$($script:DatabaseProvider)
DB_NAME=${if ($script:DbName) { $script:DbName } else { "ExiledProjectCMS" }}
DB_USER=${if ($script:DbUser) { $script:DbUser } else { "exiled" }}
DB_PASSWORD=${if ($script:DbPassword) { $script:DbPassword } else { $dbPassword }}
DB_SA_PASSWORD=$dbSaPassword
DB_ROOT_PASSWORD=$dbRootPassword

# Connection strings
DB_CONNECTION_STRING=$($script:DbConnectionString)
GO_DB_CONNECTION_STRING=$($script:GoDbConnectionString)

# Database ports
SQLSERVER_PORT=1433
MYSQL_PORT=3306
POSTGRES_PORT=5432

# ===========================================
# CACHE CONFIGURATION
# ===========================================
CACHE_PROVIDER=$($script:CacheProvider)
REDIS_HOST=redis
REDIS_PASSWORD=$redisPassword
REDIS_PORT=6379
REDIS_DATABASE=0
REDIS_CONNECTION_STRING=$($script:RedisConnectionString)

# ===========================================
# API CONFIGURATION
# ===========================================
API_PORT=5006
GO_API_PORT=8080
SKINS_CAPES_PORT=8081
EMAIL_SERVICE_PORT=8082

# API Scaling
API_REPLICAS=1
GO_API_REPLICAS=2
SKINS_CAPES_REPLICAS=1
EMAIL_SERVICE_REPLICAS=1

# ===========================================
# FRONTEND CONFIGURATION
# ===========================================
ADMIN_PORT=3000
WEBAPP_PORT=8090
WEBAPP_REPLICAS=2

# API Base URLs for frontend
API_BASE_URL=http://$($script:DomainName):5006
GO_API_BASE_URL=http://$($script:DomainName):8080
SKINS_API_BASE_URL=http://$($script:DomainName):8081

# ===========================================
# LOAD BALANCER & PROXY
# ===========================================
HTTP_PORT=80
HTTPS_PORT=443
SSL_CERTS_PATH=./ssl

# ===========================================
# ADMIN USER
# ===========================================
ADMIN_USERNAME=$($script:AdminUsername)
ADMIN_EMAIL=$($script:AdminEmail)
ADMIN_PASSWORD=$($script:AdminPassword)
ADMIN_DISPLAY_NAME=$($script:AdminDisplayName)

# ===========================================
# SECURITY & SSL
# ===========================================
JWT_SECRET=$($script:JWTSecret)
ENCRYPTION_KEY=$($script:EncryptionKey)
SSL_MODE=$($script:SslMode)
SSL_CERT_PATH=$($script:SslCertPath)
SSL_KEY_PATH=$($script:SslKeyPath)
LETSENCRYPT_EMAIL=$($script:LetsencryptEmail)

# ===========================================
# EMAIL CONFIGURATION
# ===========================================
SMTP_HOST=$($script:SmtpHost)
SMTP_PORT=$($script:SmtpPort)
SMTP_USERNAME=$($script:SmtpUsername)
SMTP_PASSWORD=$($script:SmtpPassword)
SMTP_FROM=$($script:SmtpFrom)
SMTP_USE_TLS=$($script:SmtpUseTls)

# ===========================================
# STORAGE CONFIGURATION
# ===========================================
STORAGE_PROVIDER=${if ($script:StorageProvider) { $script:StorageProvider } else { "local" }}
SKINS_STORAGE_PATH=./storage/skins
BASE_URL=http://$($script:DomainName)

# AWS S3 Configuration
AWS_ACCESS_KEY_ID=$($script:AwsAccessKeyId)
AWS_SECRET_ACCESS_KEY=$($script:AwsSecretAccessKey)
AWS_REGION=$($script:AwsRegion)
AWS_S3_BUCKET=$($script:AwsS3Bucket)

# ===========================================
# MONITORING CONFIGURATION
# ===========================================
PROMETHEUS_PORT=9090
PROMETHEUS_RETENTION=15d
GRAFANA_PORT=3001
GRAFANA_ADMIN_USER=$($script:GrafanaAdminUser)
GRAFANA_PASSWORD=$($script:GrafanaPassword)

# ===========================================
# LOGGING
# ===========================================
LOG_LEVEL=Information
LOG_FILE_PATH=/app/Logs/exiled-cms.log
LOG_MAX_SIZE=100MB

# ===========================================
# PERFORMANCE SETTINGS
# ===========================================
CACHE_DEFAULT_EXPIRATION=1800
CACHE_NEWS_EXPIRATION=900
CACHE_USERS_EXPIRATION=3600
RATE_LIMIT_REQUESTS_PER_MINUTE=60
RATE_LIMIT_BURST=10

# ===========================================
# DEVELOPMENT SETTINGS
# ===========================================
DEBUG_MODE=false
ENABLE_SWAGGER=true
ENABLE_CORS=true
ENABLE_PLUGIN_HOT_RELOAD=true
"@

    $envContent | Set-Content $script:EnvFile -Encoding UTF8
    Write-Success "Environment file generated: $($script:EnvFile)"
}

function Show-InstallationSummary {
    Write-Host "`n=== INSTALLATION SUMMARY ===" -ForegroundColor Cyan
    Write-Host "The following components will be installed:" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "✓ ExiledProjectCMS API (C#) - Main application" -ForegroundColor Green

    foreach ($component in $script:SelectedComponents) {
        switch ($component) {
            "database-mysql" { Write-Host "✓ MySQL Database - Local Docker container" -ForegroundColor Green }
            "database-postgres" { Write-Host "✓ PostgreSQL Database - Local Docker container" -ForegroundColor Green }
            "database-sqlserver" { Write-Host "✓ SQL Server Database - Local Docker container" -ForegroundColor Green }
            "cache-redis" { Write-Host "✓ Redis Cache - Local Docker container" -ForegroundColor Green }
            "services-go" { Write-Host "✓ High-Performance Go API - Enhanced performance" -ForegroundColor Green }
            "services-skins" { Write-Host "✓ Skins & Capes Service - Minecraft assets" -ForegroundColor Green }
            "services-email" { Write-Host "✓ Email Service - Email notifications" -ForegroundColor Green }
            "frontend" { Write-Host "✓ Frontend Applications - Admin Panel + Website" -ForegroundColor Green }
            "loadbalancer" { Write-Host "✓ Nginx Load Balancer - Reverse proxy" -ForegroundColor Green }
            "monitoring" { Write-Host "✓ Monitoring Stack - Prometheus + Grafana" -ForegroundColor Green }
        }
    }

    if ($script:ExternalServices.Count -gt 0) {
        Write-Host "`nExternal services configured:" -ForegroundColor Yellow
        foreach ($service in $script:ExternalServices) {
            Write-Host "→ External $service" -ForegroundColor Blue
        }
    }

    Write-Host "`nDatabase: $($script:DatabaseProvider)" -ForegroundColor Cyan
    Write-Host "Cache: $($script:CacheProvider)" -ForegroundColor Cyan
    Write-Host "Domain: $($script:DomainName)" -ForegroundColor Cyan

    Write-Host ""
    if (Ask-YesNo "Proceed with installation?" "y") {
        return $true
    } else {
        Write-Warning "Installation cancelled by user"
        exit 0
    }
}

function Test-Prerequisites {
    Write-Step "Checking prerequisites..."

    # Check if Docker is installed
    try {
        docker --version | Out-Null
        Write-Success "Docker is installed"
    } catch {
        Write-Error "Docker is not installed. Please install Docker Desktop first."
        exit 1
    }

    # Check if Docker Compose is available
    try {
        docker-compose --version | Out-Null
        Write-Success "Docker Compose is available"
    } catch {
        try {
            docker compose version | Out-Null
            Write-Success "Docker Compose (plugin) is available"
        } catch {
            Write-Error "Docker Compose is not available. Please install Docker Compose."
            exit 1
        }
    }

    Write-Success "Prerequisites check passed"
}

function Install-System {
    Write-Step "Starting ExiledProjectCMS installation..."

    # Create necessary directories
    $directories = @("ssl", "logs", "storage\skins", "Plugins", "Uploads", "nginx\conf.d", "monitoring\grafana\dashboards", "scripts")
    foreach ($dir in $directories) {
        if (!(Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }

    # Prepare monitoring configuration files if monitoring stack is selected
    if ($script:SelectedComponents -contains "monitoring") {
        Write-Step "Preparing monitoring configuration files..."

        $monitoringDirs = @(
            "monitoring",
            "monitoring\grafana\dashboards",
            "monitoring\grafana\provisioning\datasources",
            "monitoring\grafana\provisioning\dashboards"
        )
        foreach ($dir in $monitoringDirs) {
            if (!(Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        }

        # Create default Prometheus configuration if missing
        if (!(Test-Path "monitoring\prometheus.yml")) {
            @'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'exiled-api'
    static_configs:
      - targets: ['api:5006']

  - job_name: 'go-api'
    static_configs:
      - targets: ['go-api:8080']

  - job_name: 'skins-capes'
    static_configs:
      - targets: ['skins-capes:8081']
'@ | Out-File -FilePath "monitoring\prometheus.yml" -Encoding UTF8 -Force
        }

        # Create Grafana datasource provisioning for Prometheus if missing
        if (!(Test-Path "monitoring\grafana\provisioning\datasources\datasource.yml")) {
            @'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
'@ | Out-File -FilePath "monitoring\grafana\provisioning\datasources\datasource.yml" -Encoding UTF8 -Force
        }

        # Create Grafana dashboards provider if missing
        if (!(Test-Path "monitoring\grafana\provisioning\dashboards\dashboard.yml")) {
            @'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
'@ | Out-File -FilePath "monitoring\grafana\provisioning\dashboards\dashboard.yml" -Encoding UTF8 -Force
        }

        Write-Success "Monitoring configuration prepared"
    }

    # Generate SSL certificates if needed
    if ($script:SslMode -eq "self-signed") {
        Write-Step "Generating self-signed SSL certificates..."
        # Note: This would require OpenSSL on Windows or PowerShell certificates
        Write-Warning "Self-signed certificate generation requires manual setup on Windows"
        Write-Host "Please use: New-SelfSignedCertificate or OpenSSL to generate certificates"
    }

    # Start services
    Write-Step "Starting Docker services..."
    try {
        docker-compose -f $script:ComposeFile --env-file "$script:EnvFile" up -d
    } catch {
        try {
            docker compose -f $script:ComposeFile --env-file "$script:EnvFile" up -d
        } catch {
            Write-Error "Failed to start Docker services"
            throw
        }
    }

    # Wait for services to be ready
    Write-Step "Waiting for services to start..."
    Start-Sleep -Seconds 30

    # Test services
    Write-Step "Testing service health..."
    $maxAttempts = 30
    $attempt = 0

    do {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:5006/health" -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Success "Main API is healthy"
                break
            }
        } catch {
            $attempt++
            if ($attempt -eq $maxAttempts) {
                Write-Warning "Main API health check failed, but continuing..."
                break
            } else {
                Write-Host "Waiting for API to be ready... (attempt $attempt/$maxAttempts)"
                Start-Sleep -Seconds 10
            }
        }
    } while ($attempt -lt $maxAttempts)

    Write-Success "ExiledProjectCMS installation completed!"
}

function Show-CompletionInfo {
    Write-Host "`n🎉 ExiledProjectCMS installation completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== ACCESS INFORMATION ===" -ForegroundColor Cyan

    if ($script:SelectedComponents -contains "frontend") {
        Write-Host "Admin Panel:     http://$($script:DomainName):3000" -ForegroundColor Green
        Write-Host "Website:         http://$($script:DomainName):8090" -ForegroundColor Green
    }

    Write-Host "Main API:        http://$($script:DomainName):5006" -ForegroundColor Green

    if ($script:SelectedComponents -contains "services-go") {
        Write-Host "Go API:          http://$($script:DomainName):8080" -ForegroundColor Green
    }

    if ($script:SelectedComponents -contains "services-skins") {
        Write-Host "Skins API:       http://$($script:DomainName):8081" -ForegroundColor Green
    }

    if ($script:SelectedComponents -contains "loadbalancer") {
        Write-Host "Load Balancer:   http://$($script:DomainName):80" -ForegroundColor Green
    }

    if ($script:SelectedComponents -contains "monitoring") {
        Write-Host "Prometheus:      http://$($script:DomainName):9090" -ForegroundColor Green
        Write-Host "Grafana:         http://$($script:DomainName):3001" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "=== ADMIN CREDENTIALS ===" -ForegroundColor Cyan
    Write-Host "Username:        $($script:AdminUsername)" -ForegroundColor Green
    Write-Host "Email:           $($script:AdminEmail)" -ForegroundColor Green
    Write-Host "Password:        [as configured]" -ForegroundColor Green

    Write-Host ""
    Write-Host "=== MANAGEMENT COMMANDS ===" -ForegroundColor Cyan
    Write-Host "Start services:   docker-compose -f $($script:ComposeFile) --env-file \"$($script:EnvFile)\" up -d" -ForegroundColor Green
    Write-Host "Stop services:    docker-compose -f $($script:ComposeFile) --env-file \"$($script:EnvFile)\" down" -ForegroundColor Green
    Write-Host "View logs:        docker-compose -f $($script:ComposeFile) --env-file \"$($script:EnvFile)\" logs -f" -ForegroundColor Green
    Write-Host "Update system:    git pull; docker-compose -f $($script:ComposeFile) --env-file \"$($script:EnvFile)\" build --pull" -ForegroundColor Green

    Write-Host ""
    Write-Host "Tip: If you start services manually, use: docker-compose -f $($script:ComposeFile) --env-file \"$($script:EnvFile)\" up -d" -ForegroundColor Yellow

    Write-Host "=== CONFIGURATION FILES ===" -ForegroundColor Cyan
    Write-Host "Environment:      $($script:EnvFile)" -ForegroundColor Green
    Write-Host "Docker Compose:   $($script:ComposeFile)" -ForegroundColor Green
    Write-Host "Installation log: $($script:LogFile)" -ForegroundColor Green

    Write-Host ""
    Write-Host "Important Notes:" -ForegroundColor Yellow
    Write-Host "• Please backup your environment file ($($script:EnvFile)) - it contains sensitive information" -ForegroundColor Yellow
    Write-Host "• Change default passwords in production environments" -ForegroundColor Yellow
    Write-Host "• Configure firewall rules for your selected services" -ForegroundColor Yellow
    if ($script:SslMode -eq "self-signed") {
        Write-Host "• Replace self-signed certificates with proper SSL certificates" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Main function
function Main {
    Init-Logging
    Write-Log "Starting ExiledProjectCMS Interactive Installation"
    Write-Log "Using env file: $($script:EnvFile)"
    Write-Log "Log file: $($script:LogFile)"

    Write-Banner

    if (!$SkipPrerequisites) {
        Test-Prerequisites
    }

    Select-Database
    Select-Cache
    Select-Services
    Select-Monitoring
    Configure-AdminUser
    Configure-Security

    if (Show-InstallationSummary) {
        Generate-DockerCompose
        Generate-EnvFile
        Install-System
        Show-CompletionInfo
    }

    Write-Log "Installation completed successfully"
}

# Error handling
trap {
    Write-Host "`nInstallation interrupted: $_" -ForegroundColor Red
    exit 1
}

# Run main function
Main