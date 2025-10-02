# ExiledProjectCMS

A comprehensive Content Management System designed for Minecraft launcher integration with GMLLauncher support,
featuring microservices architecture and distributed deployment capabilities.

## 🚀 Features

- **GMLLauncher Integration**: Full compatibility with GMLLauncher API
- **Microservices Architecture**: Scalable design with C#, Go, and Vue.js services
- **Multi-Database Support**: SQL Server, MySQL, PostgreSQL
- **Caching Systems**: Redis and Memory Cache options
- **Role-Based Access Control**: Comprehensive user management with permissions
- **Docker Ready**: Complete containerization with single-machine and distributed deployment
- **Admin Panel**: Web-based administration interface
- **Plugin System**: Extensible architecture supporting C#, Go, and JavaScript plugins
- **Discord OAuth2**: Social authentication integration
- **High Performance**: Go-based high-performance API for intensive operations

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │   Frontend      │    │   Admin Panel   │
│     (Nginx)     │◄──►│   (Vue.js)      │    │   (Vue.js)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CMS API       │    │   Go API        │    │   Cache         │
│   (C# .NET 9)   │◄──►│   (Gin)         │◄──►│   (Redis)       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Database Layer                              │
│              (SQL Server / MySQL / PostgreSQL)                 │
└─────────────────────────────────────────────────────────────────┘
```

## 📦 Services

| Service         | Port           | Description                        |
|-----------------|----------------|------------------------------------|
| **CMS API**     | 5006           | Main C# API for content management |
| **Go API**      | 8080           | High-performance operations        |
| **Admin Panel** | 3000           | Administrative interface           |
| **Web App**     | 8090           | Public website                     |
| **Nginx**       | 80/443         | Load balancer and reverse proxy    |
| **Redis**       | 6379           | Caching service                    |
| **Database**    | 1433/3306/5432 | Data persistence                   |

## 🔧 Quick Start

### 🚀 Interactive Installation (Recommended)

**New modular installer with component selection and external service support!**

#### Prerequisites

- **Linux/macOS**: Docker, Docker Compose, `sudo` privileges
- **Windows**: Docker Desktop, PowerShell with Administrator privileges

#### Linux/macOS Installation

```bash
git clone https://github.com/yourusername/ExiledProjectCMS.git
cd ExiledProjectCMS
chmod +x install-interactive.sh
sudo ./install-interactive.sh
```

#### Windows Installation

```powershell
git clone https://github.com/yourusername/ExiledProjectCMS.git
cd ExiledProjectCMS
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install-interactive.ps1
```

### 🎯 Installation Options

The interactive installer allows you to choose:

- **Database**: Local (MySQL/PostgreSQL/SQL Server) or External
- **Cache**: Memory/Local Redis/External Redis
- **Services**: Go API, Skins Service, Email Service, Frontend, Load Balancer
- **Monitoring**: Prometheus + Grafana stack
- **Storage**: Local or AWS S3 for file uploads
- **🔐 SSL/TLS**: Inter-service encryption with automatic certificate generation

### 📋 Example Configurations

#### Minimal Setup (Development)

```bash
# Components: C# API + Memory Cache + Frontend
# Perfect for development and testing
```

#### Standard Setup (Production)

```bash
# Components: C# API + Go API + PostgreSQL + Redis + Frontend + Nginx
# Recommended for most production environments
```

#### Enterprise Setup

```bash
# Components: All services + Monitoring + S3 + Email
# Maximum functionality with external integrations
```

#### Distributed Setup

```bash
# Components: API services only + External databases
# For cluster deployments across multiple machines
```

### 📖 Quick Installation Guide

See [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) for detailed documentation.

### 🔐 SSL Security Guide

See [SSL_IMPLEMENTATION_GUIDE.md](SSL_IMPLEMENTATION_GUIDE.md) for SSL/TLS configuration.

### 🔧 Legacy Manual Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/ExiledProjectCMS.git
   cd ExiledProjectCMS
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env file with your settings
   ```

3. **Start services**
   ```bash
   docker-compose up -d
   ```

## 🌐 Distributed Deployment

For multi-machine deployment using Docker Swarm:

### Initialize Swarm Manager

```bash
./deploy-distributed.sh init-swarm --manager-ip YOUR_MANAGER_IP
```

### Join Worker Nodes

```bash
./deploy-distributed.sh join-swarm SWARM_TOKEN --manager-ip MANAGER_IP
```

### Deploy Services

```bash
./deploy-distributed.sh deploy --database-node db-server --redis-node cache-server
```

### Scale Services

```bash
./deploy-distributed.sh scale cms-api=3 go-api=5 webapp=2
```

## ⚙️ Configuration

### Database Providers

Configure your preferred database in `.env`:

```bash
# SQL Server
DATABASE_PROVIDER=SqlServer
DB_CONNECTION_STRING=Server=localhost,1433;Database=ExiledProjectCMS;User Id=sa;Password=YourPassword;

# MySQL
DATABASE_PROVIDER=MySQL
DB_CONNECTION_STRING=Server=localhost;Database=ExiledProjectCMS;Uid=root;Pwd=YourPassword;

# PostgreSQL
DATABASE_PROVIDER=PostgreSQL
DB_CONNECTION_STRING=Host=localhost;Database=ExiledProjectCMS;Username=postgres;Password=YourPassword;
```

### Cache Providers

```bash
# Redis (Recommended for production)
CACHE_PROVIDER=Redis
REDIS_PASSWORD=YourRedisPassword

# Memory (Development only)
CACHE_PROVIDER=Memory
```

### Service Scaling

```bash
# API Services
API_REPLICAS=2
GO_API_REPLICAS=3

# Frontend Services
WEBAPP_REPLICAS=2
```

## 🔐 Security Configuration

### JWT & Encryption

```bash
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
ENCRYPTION_KEY=your-32-character-encryption-key12
```

### Admin User Creation

Create the first admin user via command line:

```bash
docker exec -it exiled-cms-api dotnet ExiledProjectCMS.API.dll create-admin
```

### Discord OAuth2

```bash
DISCORD_CLIENT_ID=your-discord-client-id
DISCORD_CLIENT_SECRET=your-discord-client-secret
DISCORD_REDIRECT_URI=https://yourdomain.com/auth/discord/callback
```

## 📡 API Endpoints

### Authentication

- `POST /api/auth/signin` - User authentication
- `POST /api/auth/register` - User registration
- `GET /api/auth/check-login/{login}` - Check login availability
- `GET /api/auth/check-email/{email}` - Check email availability

### GMLLauncher Integration

- `GET /api/integration/minecraft/news` - Get news for launcher
- `POST /api/integration/minecraft/authlib/authenticate` - Minecraft authentication
- `POST /api/integration/minecraft/authlib/refresh` - Refresh authentication
- `POST /api/integration/minecraft/authlib/validate` - Validate token

### Admin Panel

- `GET /api/admin/info` - System information
- `POST /api/admin/cache/clear` - Clear cache
- `GET /api/admin/database/stats` - Database statistics
- `POST /api/admin/database/migrate` - Run migrations

## 🔍 Monitoring

### Service Status

```bash
# Check all services
docker-compose ps

# View service logs
docker-compose logs -f cms-api
```

### Distributed Cluster Status

```bash
./deploy-distributed.sh status
```

### Health Checks

All services include health check endpoints:

- CMS API: `http://localhost:5006/health`
- Go API: `http://localhost:8080/health`

## 🛠️ Development

### Local Development Setup

```bash
# Start development environment
docker-compose -f docker-compose.development.yml up -d

# Watch logs
docker-compose logs -f
```

### Building Custom Images

```bash
# Build all services
docker-compose build

# Build specific service
docker-compose build cms-api
```

### Database Migrations

```bash
# Run migrations
docker exec -it exiled-cms-api dotnet ef database update

# Create new migration
docker exec -it exiled-cms-api dotnet ef migrations add MigrationName
```

## 🔧 Management Commands

### Service Management

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart service
docker-compose restart cms-api

# Update services
docker-compose pull && docker-compose up -d
```

### Distributed Management

```bash
# Scale services
./deploy-distributed.sh scale cms-api=3

# Update services
./deploy-distributed.sh update

# View logs
./deploy-distributed.sh logs cms-api

# Remove stack
./deploy-distributed.sh remove
```

## 📊 Performance Tuning

### Resource Limits

Configure service resources in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 1G
      cpus: '0.5'
    reservations:
      memory: 512M
      cpus: '0.25'
```

### Cache Configuration

```bash
# Cache expiration times (seconds)
CACHE_DEFAULT_EXPIRATION=1800
CACHE_NEWS_EXPIRATION=900
CACHE_USERS_EXPIRATION=3600

# Rate limiting
RATE_LIMIT_REQUESTS_PER_MINUTE=60
RATE_LIMIT_BURST=10
```

## 🐛 Troubleshooting

### Common Issues

**Services not starting:**

```bash
# Check logs
docker-compose logs service-name

# Check service status
docker-compose ps
```

**Database connection issues:**

```bash
# Verify database is running
docker-compose ps database

# Check connection string in .env
# Ensure firewall allows database port
```

**Memory issues:**

```bash
# Check resource usage
docker stats

# Increase memory limits in docker-compose.yml
```

### Log Locations

- Container logs: `docker logs container-name`
- Application logs: `/app/Logs/exiled-cms.log` (inside container)
- Nginx logs: `/var/log/nginx/` (inside nginx container)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Wiki](https://github.com/yourusername/ExiledProjectCMS/wiki)
- **Issues**: [GitHub Issues](https://github.com/yourusername/ExiledProjectCMS/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/ExiledProjectCMS/discussions)

## 🏷️ Version

**Current Version**: 1.0.0

### Changelog

- **1.0.0**: Initial release with full Docker support and distributed deployment

---

Made with ❤️ for the Minecraft community