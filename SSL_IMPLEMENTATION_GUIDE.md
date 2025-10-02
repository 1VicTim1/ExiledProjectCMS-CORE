# ExiledProjectCMS - SSL Implementation Guide

## Обзор SSL инфраструктуры

Полноценная система SSL/TLS для безопасной межсервисной коммуникации с автоматической генерацией сертификатов, взаимной
аутентификацией и централизованным управлением.

## 🔐 Архитектура SSL

### Уровни безопасности

1. **Certificate Authority (CA)**
    - Самоподписанный Root CA для внутренней инфраструктуры
    - Срок действия: 10 лет
    - RSA 4096 бит
    - Безопасное хранение приватного ключа

2. **Service Certificates**
    - Индивидуальные сертификаты для каждого сервиса
    - Срок действия: 1 год (настраивается)
    - RSA 2048 бит
    - Subject Alternative Names (SAN) для всех DNS имен

3. **Client Certificates**
    - Сертификаты для взаимной аутентификации (mTLS)
    - Используются сервисами для подключения друг к другу
    - Автоматическая ротация

## 🚀 Быстрый старт

### 1. Генерация сертификатов

```bash
cd ssl-infrastructure
chmod +x generate-certificates.sh
./generate-certificates.sh
```

### 2. Установка с SSL

```bash
# Linux/macOS
./install-interactive.sh

# Выберите "Enable SSL for inter-service communication" -> Yes
# Выберите режим SSL: Generate new certificates
```

### 3. Проверка сертификатов

```bash
cd ssl-certificates
./validate-certificates.sh
```

## 📋 Компоненты SSL инфраструктуры

### Генерируемые сертификаты

| Сервис            | Сертификат        | Ключ              | DNS имена                                     | Порты SSL  |
|-------------------|-------------------|-------------------|-----------------------------------------------|------------|
| **CMS API**       | cms-api.crt       | cms-api.key       | cms-api.exiled.local, exiled-cms-api          | 8443, 8444 |
| **Go API**        | go-api.crt        | go-api.key        | go-api.exiled.local, exiled-go-api            | 8443, 8444 |
| **Nginx**         | nginx.crt         | nginx.key         | nginx.exiled.local, loadbalancer.exiled.local | 443, 8443  |
| **Redis**         | redis.crt         | redis.key         | redis.exiled.local, cache.exiled.local        | 6380       |
| **PostgreSQL**    | postgres.crt      | postgres.key      | postgres.exiled.local, database.exiled.local  | 5432       |
| **Skins Service** | skins-service.crt | skins-service.key | skins-service.exiled.local                    | 8443       |
| **Email Service** | email-service.crt | email-service.key | email-service.exiled.local                    | 8443       |

### Структура файлов

```
ssl-certificates/
├── ca/
│   ├── ca.crt                    # Root CA certificate
│   ├── ca.key                    # Root CA private key
│   └── ca.srl                    # Serial number file
├── services/
│   ├── cms-api/
│   │   ├── cms-api.crt           # Service certificate
│   │   ├── cms-api.key           # Service private key
│   │   ├── cms-api-bundle.crt    # Cert + CA bundle
│   │   └── cms-api-full.pem      # Key + Cert + CA
│   └── [other services...]
├── clients/
│   └── internal-client/
│       ├── internal-client-client.crt
│       └── internal-client-client.key
├── dhparam.pem                   # DH parameters for PFS
├── create-secrets.sh             # Docker secrets script
├── validate-certificates.sh      # Certificate validation
└── renew-certificates.sh         # Certificate renewal
```

## ⚙️ Конфигурация сервисов

### C# API (ASP.NET Core)

```json
{
  "Kestrel": {
    "Endpoints": {
      "Http": { "Url": "http://0.0.0.0:8080" },
      "Https": {
        "Url": "https://0.0.0.0:8443",
        "Certificate": {
          "Path": "/app/ssl/cms-api.crt",
          "KeyPath": "/app/ssl/cms-api.key"
        }
      },
      "HttpsInternal": {
        "Url": "https://0.0.0.0:8444",
        "ClientCertificateMode": "RequireCertificate"
      }
    }
  },
  "SSL": {
    "RequireHttpsForInternal": true,
    "ClientCertificateValidation": true,
    "TrustedCA": "/app/ssl/ca.crt"
  }
}
```

### Go API

```yaml
server:
  https:
    port: 8443
    cert_file: "/app/ssl/go-api.crt"
    key_file: "/app/ssl/go-api.key"
  https_internal:
    port: 8444
    ca_file: "/app/ssl/ca.crt"
    client_auth: "require_and_verify"

ssl:
  ca_cert: "/app/ssl/ca.crt"
  client_cert: "/app/ssl/clients/internal-client-client.crt"
  client_key: "/app/ssl/clients/internal-client-client.key"
  verify_peer: true
  min_version: "TLS1.2"
```

### Nginx Load Balancer

```nginx
# Upstream with SSL backend
upstream cms_api_backend {
    server cms-api:8443;
}

server {
    listen 443 ssl http2;

    # Server certificate
    ssl_certificate /etc/ssl/certs/nginx.crt;
    ssl_certificate_key /etc/ssl/private/nginx.key;

    # Backend SSL configuration
    proxy_ssl_verify on;
    proxy_ssl_trusted_certificate /etc/ssl/ca/ca.crt;
    proxy_ssl_certificate /etc/ssl/clients/internal-client-client.crt;
    proxy_ssl_certificate_key /etc/ssl/clients/internal-client-client.key;

    location /api/ {
        proxy_pass https://cms_api_backend/api/;
        proxy_ssl_name cms-api.exiled.local;
    }
}
```

### Redis с TLS

```conf
# Redis SSL configuration
tls-port 6380
port 0  # Disable non-TLS
tls-cert-file /etc/ssl/certs/redis.crt
tls-key-file /etc/ssl/private/redis.key
tls-ca-cert-file /etc/ssl/ca/ca.crt
tls-auth-clients yes
tls-protocols "TLSv1.2 TLSv1.3"
```

### PostgreSQL с SSL

```bash
postgres \
  -c ssl=on \
  -c ssl_cert_file=/etc/ssl/certs/postgres.crt \
  -c ssl_key_file=/etc/ssl/private/postgres.key \
  -c ssl_ca_file=/etc/ssl/ca/ca.crt \
  -c ssl_min_protocol_version='TLSv1.2'
```

## 🔄 Управление сертификатами

### Проверка сертификатов

```bash
# Проверить все сертификаты
./ssl-certificates/validate-certificates.sh

# Проверить конкретный сертификат
openssl x509 -in ssl-certificates/services/cms-api/cms-api.crt -text -noout

# Проверить соответствие сертификата и ключа
openssl x509 -noout -modulus -in cms-api.crt | openssl md5
openssl rsa -noout -modulus -in cms-api.key | openssl md5
```

### Обновление сертификатов

```bash
# Обновить все сертификаты (перед истечением срока действия)
./ssl-certificates/renew-certificates.sh

# Обновить конкретный сервис
openssl req -new -config ssl-config/cms-api.conf \
  -key ssl-certificates/services/cms-api/cms-api.key \
  -out ssl-certificates/services/cms-api/cms-api.csr

openssl x509 -req -in ssl-certificates/services/cms-api/cms-api.csr \
  -CA ssl-certificates/ca/ca.crt \
  -CAkey ssl-certificates/ca/ca.key \
  -CAcreateserial \
  -out ssl-certificates/services/cms-api/cms-api.crt \
  -days 365 \
  -extensions v3_req \
  -extfile ssl-config/cms-api.conf
```

### Ротация CA

```bash
# ВНИМАНИЕ: Требует обновления всех сертификатов!

# 1. Создать новый CA
openssl genpkey -algorithm RSA -bits 4096 -out ca-new.key
openssl req -new -x509 -config ca.conf -key ca-new.key -out ca-new.crt -days 3650

# 2. Обновить все сервисные сертификаты с новым CA
# 3. Развернуть новые сертификаты
# 4. Заменить старый CA
```

## 🔒 Режимы безопасности

### Standard Security (TLS 1.2+)

```bash
SSL_MIN_VERSION="TLSv1.2"
SSL_CIPHERS="ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384"
```

### High Security (TLS 1.3)

```bash
SSL_MIN_VERSION="TLSv1.3"
SSL_CIPHERS="TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256"
```

### Custom Security

```bash
SSL_MIN_VERSION="TLSv1.2"
SSL_CIPHERS="[custom cipher list]"
SSL_REQUIRE_CLIENT_CERTS="true"
SSL_OCSP_STAPLING="true"
```

## 🐳 Docker интеграция

### Docker Secrets

```bash
# Создать секреты для Docker Swarm
./ssl-certificates/create-secrets.sh

# Использование в compose файле
services:
  cms-api:
    secrets:
      - exiled-cms-api-cert
      - exiled-cms-api-key
      - exiled-ca-cert

secrets:
  exiled-cms-api-cert:
    external: true
  exiled-cms-api-key:
    external: true
  exiled-ca-cert:
    external: true
```

### Kubernetes Secrets

```bash
# Создать секреты для Kubernetes
./ssl-certificates/create-k8s-secrets.sh

# Использование в pod
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: cms-api
    volumeMounts:
    - name: ssl-certs
      mountPath: /app/ssl
  volumes:
  - name: ssl-certs
    secret:
      secretName: exiled-cms-api-tls
```

## 🔍 Мониторинг и отладка

### SSL соединения

```bash
# Тест подключения к сервису
openssl s_client -connect cms-api:8443 \
  -cert ssl-certificates/services/clients/internal-client-client.crt \
  -key ssl-certificates/services/clients/internal-client-client.key \
  -CAfile ssl-certificates/ca/ca.crt

# Проверка сертификата сервера
echo | openssl s_client -connect nginx:443 -servername example.com 2>/dev/null | openssl x509 -noout -dates
```

### Логирование SSL

```bash
# Nginx SSL логи
error_log /var/log/nginx/ssl_error.log debug;

# ASP.NET Core SSL логи
"Microsoft.AspNetCore.Authentication.Certificate": "Debug"

# Go API SSL логи
ssl_debug: true
```

### Метрики SSL

```bash
# Prometheus метрики для SSL
ssl_certificate_expiry_days{service="cms-api"} 45
ssl_handshakes_total{service="cms-api"} 1250
ssl_errors_total{service="cms-api"} 0
```

## 🚨 Безопасность и рекомендации

### Обязательные меры безопасности

1. **Защита CA ключа**
   ```bash
   chmod 600 ssl-certificates/ca/ca.key
   chown root:root ssl-certificates/ca/ca.key
   # Рассмотрите использование HSM для продакшена
   ```

2. **Регулярная ротация сертификатов**
   ```bash
   # Настройте cron для автоматического обновления
   0 2 1 * * /path/to/renew-certificates.sh && docker-compose restart
   ```

3. **Мониторинг истечения сертификатов**
   ```bash
   # Alert за 30 дней до истечения
   ssl_certificate_expiry_days < 30
   ```

4. **Firewall правила**
   ```bash
   # Разрешить только необходимые SSL порты
   ufw allow 443/tcp    # Public HTTPS
   ufw allow 8443/tcp   # Internal HTTPS
   ```

5. **Audit логирование**
   ```bash
   # Логировать все SSL соединения
   log_connections = on
   log_disconnections = on
   ```

### Рекомендации по развертыванию

1. **Staging среда**: Всегда тестируйте SSL конфигурацию в staging
2. **Backup сертификатов**: Регулярное резервное копирование CA и ключей
3. **Certificate pinning**: Для критичных соединений
4. **OCSP stapling**: Для повышения производительности
5. **Perfect Forward Secrecy**: Используйте ephemeral ключи

## 🛠️ Устранение неполадок

### Типичные проблемы

**Ошибка: Certificate verify failed**

```bash
# Проверить цепочку сертификатов
openssl verify -CAfile ca.crt service.crt

# Проверить SAN имена
openssl x509 -in service.crt -text -noout | grep -A 1 "Subject Alternative Name"
```

**Ошибка: SSL handshake failed**

```bash
# Проверить совместимость TLS версий
openssl s_client -connect service:8443 -tls1_2
openssl s_client -connect service:8443 -tls1_3
```

**Ошибка: Client certificate required**

```bash
# Убедиться что client сертификат доступен
ls -la /app/ssl/clients/internal-client-client.{crt,key}
```

### Диагностические команды

```bash
# Проверить все SSL настройки
docker-compose exec cms-api openssl version -a
docker-compose exec nginx nginx -V 2>&1 | grep -o with-http_ssl_module

# Проверить SSL порты
netstat -tlnp | grep :443
netstat -tlnp | grep :8443

# SSL трафик
tcpdump -i any port 443 -X
```

## 📚 Дополнительные ресурсы

- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [SSL Labs Server Test](https://www.ssllabs.com/ssltest/)
- [TLS Security Best Practices](https://wiki.mozilla.org/Security/Server_Side_TLS)

---

**🔐 Безопасность - это путешествие, а не пункт назначения. Регулярно обновляйте и аудируйте вашу SSL инфраструктуру!**