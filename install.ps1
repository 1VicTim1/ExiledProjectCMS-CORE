# ExiledProjectCMS Universal Installer for Windows PowerShell
# This script installs and configures ExiledProjectCMS with Docker support

param(
    [switch]$SkipDocker,
    [switch]$SkipGit,
    [string]$InstallPath = "C:\ExiledProjectCMS",
    [string]$ServiceName = "ExiledProjectCMS"
)

# Requires Administrator privileges
#Requires -RunAsAdministrator

# Configuration
$LogFile = "$env:TEMP\exiledproject-cms-install.log"
$ConfigPath = "$InstallPath\config"

# Color functions
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Step($Message) {
    Write-ColorOutput Cyan "[STEP] $Message"
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [STEP] $Message"
}

function Write-Success($Message) {
    Write-ColorOutput Green "[SUCCESS] $Message"
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [SUCCESS] $Message"
}

function Write-Warning($Message) {
    Write-ColorOutput Yellow "[WARNING] $Message"
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [WARNING] $Message"
}

function Write-Error($Message) {
    Write-ColorOutput Red "[ERROR] $Message"
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [ERROR] $Message"
}

function Print-Banner {
    Clear-Host
    Write-ColorOutput Magenta @"
╔═══════════════════════════════════════════════╗
║          ExiledProjectCMS Installer           ║
║     Advanced CMS with Docker Support         ║
╚═══════════════════════════════════════════════╝
"@
    Write-Host ""
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Chocolatey {
    Write-Step "Installing Chocolatey package manager..."

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Success "Chocolatey is already installed"
        return
    }

    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        Write-Success "Chocolatey installed successfully"
    }
    catch {
        Write-Error "Failed to install Chocolatey: $($_.Exception.Message)"
        exit 1
    }
}

function Install-Git {
    if ($SkipGit) {
        Write-Warning "Skipping Git installation"
        return
    }

    Write-Step "Installing Git..."

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Success "Git is already installed"
        git --version
        return
    }

    try {
        choco install git -y
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Success "Git installed successfully"
    }
    catch {
        Write-Error "Failed to install Git: $($_.Exception.Message)"
        exit 1
    }
}

function Install-DockerDesktop {
    if ($SkipDocker) {
        Write-Warning "Skipping Docker installation"
        return
    }

    Write-Step "Installing Docker Desktop..."

    # Check if Docker is already installed
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Success "Docker is already installed"
        docker --version
        return
    }

    try {
        # Download and install Docker Desktop
        $dockerUrl = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
        $dockerInstaller = "$env:TEMP\DockerDesktopInstaller.exe"

        Write-Step "Downloading Docker Desktop..."
        Invoke-WebRequest -Uri $dockerUrl -OutFile $dockerInstaller

        Write-Step "Installing Docker Desktop (this may take a while)..."
        Start-Process -FilePath $dockerInstaller -Args "install --quiet" -Wait

        Write-Success "Docker Desktop installed. Please restart your computer and run this script again."
        Read-Host "Press Enter to exit after restart"
        exit 0
    }
    catch {
        Write-Error "Failed to install Docker Desktop: $($_.Exception.Message)"
        Write-Warning "Please install Docker Desktop manually from https://docker.com/products/docker-desktop"
    }
}

function Install-DotNetSDK {
    Write-Step "Checking .NET SDK..."

    try {
        $dotnetVersion = dotnet --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success ".NET SDK is already installed: $dotnetVersion"
            return
        }
    }
    catch {
        # .NET is not installed
    }

    Write-Step "Installing .NET SDK..."
    try {
        choco install dotnet-sdk -y
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Success ".NET SDK installed successfully"
    }
    catch {
        Write-Error "Failed to install .NET SDK: $($_.Exception.Message)"
        exit 1
    }
}

function Install-NodeJS {
    Write-Step "Installing Node.js..."

    if (Get-Command node -ErrorAction SilentlyContinue) {
        Write-Success "Node.js is already installed"
        node --version
        npm --version
        return
    }

    try {
        choco install nodejs -y
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Success "Node.js installed successfully"
    }
    catch {
        Write-Error "Failed to install Node.js: $($_.Exception.Message)"
        exit 1
    }
}

function Install-Go {
    Write-Step "Installing Go..."

    if (Get-Command go -ErrorAction SilentlyContinue) {
        Write-Success "Go is already installed"
        go version
        return
    }

    try {
        choco install golang -y
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Success "Go installed successfully"
    }
    catch {
        Write-Error "Failed to install Go: $($_.Exception.Message)"
        exit 1
    }
}

function Setup-Directories {
    Write-Step "Setting up directories..."

    $directories = @(
        $InstallPath,
        $ConfigPath,
        "$InstallPath\logs",
        "$InstallPath\plugins",
        "$InstallPath\uploads",
        "$InstallPath\backups"
    )

    foreach ($dir in $directories) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    Write-Success "Directories created successfully"
}

function Configure-Environment {
    Write-Step "Configuring environment..."

    # Copy environment template
    $envTemplate = ".\.env.example"
    $envFile = "$ConfigPath\.env"

    if (Test-Path $envTemplate) {
        Copy-Item -Path $envTemplate -Destination $envFile -Force
    } else {
        Write-Error "Environment template file not found: $envTemplate"
        exit 1
    }

    # Interactive configuration
    Write-ColorOutput Cyan "Environment Configuration"
    Write-Host "Configure your ExiledProjectCMS installation:"
    Write-Host ""

    # Database selection
    Write-Host "Select database provider:"
    Write-Host "1) SQL Server (recommended for Windows)"
    Write-Host "2) MySQL"
    Write-Host "3) PostgreSQL"
    $dbChoice = Read-Host "Enter choice (1-3) [1]"
    if ([string]::IsNullOrEmpty($dbChoice)) { $dbChoice = "1" }

    switch ($dbChoice) {
        "1" { $DatabaseProvider = "SqlServer" }
        "2" { $DatabaseProvider = "MySQL" }
        "3" { $DatabaseProvider = "PostgreSQL" }
        default { $DatabaseProvider = "SqlServer" }
    }

    # Cache selection
    Write-Host "Select cache provider:"
    Write-Host "1) Memory (development/single instance)"
    Write-Host "2) Redis (recommended for production)"
    $cacheChoice = Read-Host "Enter choice (1-2) [2]"
    if ([string]::IsNullOrEmpty($cacheChoice)) { $cacheChoice = "2" }

    switch ($cacheChoice) {
        "1" { $CacheProvider = "Memory" }
        "2" { $CacheProvider = "Redis" }
        default { $CacheProvider = "Redis" }
    }

    # Admin user configuration
    $adminUser = Read-Host "Admin username [admin]"
    if ([string]::IsNullOrEmpty($adminUser)) { $adminUser = "admin" }

    $adminEmail = Read-Host "Admin email [admin@example.com]"
    if ([string]::IsNullOrEmpty($adminEmail)) { $adminEmail = "admin@example.com" }

    do {
        $adminPass = Read-Host "Admin password (min 8 characters)" -AsSecureString
        $adminPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPass))
    } while ($adminPassPlain.Length -lt 8)

    # Update .env file
    $envContent = Get-Content $envFile
    $envContent = $envContent -replace "DATABASE_PROVIDER=.*", "DATABASE_PROVIDER=$DatabaseProvider"
    $envContent = $envContent -replace "CACHE_PROVIDER=.*", "CACHE_PROVIDER=$CacheProvider"
    $envContent = $envContent -replace "ADMIN_USERNAME=.*", "ADMIN_USERNAME=$adminUser"
    $envContent = $envContent -replace "ADMIN_EMAIL=.*", "ADMIN_EMAIL=$adminEmail"
    $envContent = $envContent -replace "ADMIN_PASSWORD=.*", "ADMIN_PASSWORD=$adminPassPlain"

    Set-Content -Path $envFile -Value $envContent

    Write-Success "Environment configured"

    # Store variables for later use
    $script:AdminUser = $adminUser
    $script:AdminEmail = $adminEmail
    $script:AdminPass = $adminPassPlain
    $script:DatabaseProvider = $DatabaseProvider
}

function Deploy-Application {
    Write-Step "Deploying ExiledProjectCMS..."

    # Copy application files
    $sourceFiles = @("*.yml", "*.yaml", "*.json", "*.md", "*.txt", "ExiledProjectCMS*", "GoServices", "Frontend", "nginx", "scripts", "monitoring")

    foreach ($pattern in $sourceFiles) {
        Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.PSIsContainer) {
                Copy-Item -Path $_.FullName -Destination $InstallPath -Recurse -Force
            } else {
                Copy-Item -Path $_.FullName -Destination $InstallPath -Force
            }
        }
    }

    # Create symlink to config (requires elevated privileges)
    try {
        $configLink = "$InstallPath\.env"
        if (Test-Path $configLink) {
            Remove-Item $configLink -Force
        }
        cmd /c mklink "$configLink" "$ConfigPath\.env"
    }
    catch {
        # Fallback: copy file instead of symlink
        Copy-Item -Path "$ConfigPath\.env" -Destination "$InstallPath\.env" -Force
    }

    Write-Success "Application deployed to $InstallPath"
}

function Start-Services {
    Write-Step "Starting services..."

    Set-Location $InstallPath

    # Load environment variables
    $envFile = "$InstallPath\.env"
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
            }
        }
    }

    # Generate connection strings based on database provider
    switch ($DatabaseProvider) {
        "SqlServer" {
            $env:DB_CONNECTION_STRING = "Server=localhost,1433;Database=ExiledProjectCMS;User Id=sa;Password=ExiledStrong123!;TrustServerCertificate=true;"
            $env:GO_DB_CONNECTION_STRING = "sqlserver://sa:ExiledStrong123!@localhost:1433?database=ExiledProjectCMS"
            $composeProfile = "sqlserver"
        }
        "MySQL" {
            $env:DB_CONNECTION_STRING = "Server=localhost;Database=ExiledProjectCMS;Uid=exiled;Pwd=ExiledPass123!;"
            $env:GO_DB_CONNECTION_STRING = "exiled:ExiledPass123!@tcp(localhost:3306)/ExiledProjectCMS?charset=utf8mb4&parseTime=True&loc=Local"
            $composeProfile = "mysql"
        }
        "PostgreSQL" {
            $env:DB_CONNECTION_STRING = "Host=localhost;Database=ExiledProjectCMS;Username=exiled;Password=ExiledPass123!;"
            $env:GO_DB_CONNECTION_STRING = "postgres://exiled:ExiledPass123!@localhost:5432/ExiledProjectCMS?sslmode=disable"
            $composeProfile = "postgres"
        }
    }

    try {
        # Start services
        docker-compose --profile $composeProfile up -d

        # Wait for services to be ready
        Write-Host "Waiting for services to start..."
        Start-Sleep -Seconds 30

        # Create admin user
        Write-Step "Creating admin user..."
        docker-compose exec -T cms-api dotnet ExiledProjectCMS.API.dll create-admin $script:AdminUser $script:AdminEmail $script:AdminPass "Administrator"

        Write-Success "Services started successfully"
    }
    catch {
        Write-Error "Failed to start services: $($_.Exception.Message)"
        Write-Warning "Please check Docker Desktop is running and try again"
    }
}

function Install-WindowsService {
    Write-Step "Installing Windows Service..."

    # Create service wrapper script
    $serviceScript = @"
@echo off
cd /d "$InstallPath"
docker-compose up -d
"@

    $serviceScriptPath = "$InstallPath\start-services.bat"
    Set-Content -Path $serviceScriptPath -Value $serviceScript

    try {
        # Use NSSM (Non-Sucking Service Manager) to create Windows service
        choco install nssm -y

        # Install service
        nssm install $ServiceName $serviceScriptPath
        nssm set $ServiceName DisplayName "ExiledProjectCMS Docker Services"
        nssm set $ServiceName Description "ExiledProjectCMS CMS with Docker containers"
        nssm set $ServiceName Start SERVICE_AUTO_START

        # Start service
        nssm start $ServiceName

        Write-Success "Windows Service installed and started"
    }
    catch {
        Write-Warning "Failed to install Windows Service: $($_.Exception.Message)"
        Write-Warning "You can manually start services using: docker-compose up -d"
    }
}

function Configure-Firewall {
    Write-Step "Configuring Windows Firewall..."

    try {
        # Allow ports through Windows Firewall
        $ports = @(80, 443, 3000, 5006, 8080, 8090)

        foreach ($port in $ports) {
            New-NetFirewallRule -DisplayName "ExiledProjectCMS Port $port" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow -ErrorAction SilentlyContinue
        }

        Write-Success "Windows Firewall configured"
    }
    catch {
        Write-Warning "Failed to configure firewall: $($_.Exception.Message)"
        Write-Warning "Please manually allow ports: 80, 443, 3000, 5006, 8080, 8090"
    }
}

function Print-CompletionInfo {
    Write-Success "ExiledProjectCMS installation completed successfully!"
    Write-Host ""
    Write-ColorOutput Cyan "=== ACCESS INFORMATION ==="
    Write-ColorOutput Green "Main API:        http://localhost:5006"
    Write-ColorOutput Green "Admin Panel:     http://localhost:3000"
    Write-ColorOutput Green "Website:         http://localhost:8090"
    Write-ColorOutput Green "Go API:          http://localhost:8080"
    Write-ColorOutput Green "Load Balancer:   http://localhost:80"
    Write-Host ""
    Write-ColorOutput Cyan "=== ADMIN CREDENTIALS ==="
    Write-ColorOutput Green "Username:        $($script:AdminUser)"
    Write-ColorOutput Green "Email:           $($script:AdminEmail)"
    Write-ColorOutput Green "Password:        [as configured]"
    Write-Host ""
    Write-ColorOutput Cyan "=== MANAGEMENT COMMANDS ==="
    Write-ColorOutput Green "Start services:   docker-compose up -d"
    Write-ColorOutput Green "Stop services:    docker-compose down"
    Write-ColorOutput Green "View logs:        docker-compose logs -f"
    Write-ColorOutput Green "Update system:    git pull && docker-compose build && docker-compose up -d"
    Write-Host ""
    Write-ColorOutput Cyan "=== CONFIGURATION ==="
    Write-ColorOutput Green "Config file:      $ConfigPath\.env"
    Write-ColorOutput Green "Install dir:      $InstallPath"
    Write-ColorOutput Green "Log file:         $LogFile"
    Write-Host ""
    Write-ColorOutput Yellow "Note: Please secure your installation by changing default passwords and configuring SSL certificates."
}

function Main {
    Print-Banner

    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starting ExiledProjectCMS installation..."

    if (-not (Test-Administrator)) {
        Write-Error "This script must be run as Administrator"
        Read-Host "Press Enter to exit"
        exit 1
    }

    try {
        Install-Chocolatey
        Install-Git
        Install-DotNetSDK
        Install-NodeJS
        Install-Go
        Install-DockerDesktop
        Setup-Directories
        Configure-Environment
        Deploy-Application
        Start-Services
        Install-WindowsService
        Configure-Firewall
        Print-CompletionInfo

        Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Installation completed successfully"
    }
    catch {
        Write-Error "Installation failed: $($_.Exception.Message)"
        Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Installation failed: $($_.Exception.Message)"
        exit 1
    }
}

# Run main function
Main