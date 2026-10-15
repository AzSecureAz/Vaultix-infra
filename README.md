# Vaultix Infrastructure

Local development environment for the Vaultix microservices platform, powered by Docker Compose.

---

## Architecture & Services

| Service | Container Name | Port | Description | Web UI / Access |
| :--- | :--- | :--- | :--- | :--- |
| **PostgreSQL** | `vaultix-postgres` | `5432` | Relational database (Alpine) | [localhost:8080](http://localhost:8080) (via Adminer) |
| **Redis** | `vaultix-redis` | `6379` | In-memory key-value cache/store (Alpine) | [localhost:8081](http://localhost:8081) (via Redis Commander) |
| **Adminer** | `vaultix-adminer` | `8080` | Lightweight PostgreSQL web management GUI | [http://localhost:8080](http://localhost:8080) |
| **Redis Commander** | `vaultix-redis-commander` | `8081` | Web management GUI for Redis | [http://localhost:8081](http://localhost:8081) |

---

## Directory Structure

```
infra/
├── docker-compose.yml              # Main compose orchestrator
├── .gitignore                      # Ignores sensitive .env files
├── README.md                       # Infrastructure documentation
├── adminer/
│   ├── .env                        # Adminer config
│   └── .env.example
├── postgres/
│   ├── .env                        # PostgreSQL root config
│   ├── .env.example
│   └── service-db-template.sql     # SQL template for microservice DB provisioning
├── redis/
│   ├── .env                        # Redis root config
│   ├── .env.example
│   └── service-acl-template.txt    # Template for microservice ACL user provisioning
├── redis-commander/
│   ├── .env                        # UI authentication credentials
│   └── .env.example
└── geoip/
    ├── .gitkeep                    # Keeps directory tracked
    └── GeoLite2-City.mmdb          # MaxMind database (ignored by git, placed locally)
```

---

## Quick Start

### 1. Environment Setup
Before starting for the first time, ensure each service has its `.env` file copied from `.env.example`:
- `adminer/.env`
- `postgres/.env`
- `redis/.env`
- `redis-commander/.env`

### 2. Starting the Services
From the `infra/` directory:
```bash
docker compose up -d
```
Or from the project root:
```bash
docker compose -f infra/docker-compose.yml up -d
```

### 3. Stopping the Services
- **Keep data and users intact (Normal daily development)**:
  ```bash
  docker compose down
  ```
- **Wipe all storage volumes and start completely fresh**:
  ```bash
  docker compose down -v
  ```

---

## Default Admin Credentials

### Adminer (PostgreSQL GUI)
- **URL**: [http://localhost:8080](http://localhost:8080)
- **System**: `PostgreSQL`
- **Server**: `postgres`
- **Username**: `postgres`
- **Password**: `postgres`

### Redis Commander (Redis GUI)
- **URL**: [http://localhost:8081](http://localhost:8081)
- **HTTP Auth Username**: `admin`
- **HTTP Auth Password**: `admin`

---

## Microservice Provisioning Guide

### 1. PostgreSQL: Creating a Microservice Database & User
To create an isolated database and user for a microservice (e.g. `authorization`):

1. Open **Adminer** at [http://localhost:8080](http://localhost:8080) and log in as `postgres`.
2. Go to **SQL command** and run the template from `postgres/service-db-template.sql`:

```sql
-- 1. Create the dedicated user
CREATE USER auth_service_user WITH ENCRYPTED PASSWORD 'auth_secure_pass';

-- 2. Revoke connection rights from PUBLIC so non-superusers cannot connect to 'postgres'
REVOKE CONNECT ON DATABASE postgres FROM PUBLIC;

-- 3. Create the dedicated database and assign ownership
CREATE DATABASE vaultix_auth_db OWNER auth_service_user;

-- 4. Revoke public access (prevents other microservice users from accessing it)
REVOKE ALL ON DATABASE vaultix_auth_db FROM PUBLIC;

-- 5. Grant full privileges to the service user
GRANT ALL PRIVILEGES ON DATABASE vaultix_auth_db TO auth_service_user;
```

---

### 2. Redis: Creating a Microservice ACL User
To create a dedicated Redis user restricted strictly to its own key prefix (e.g. `auth:*`):

1. Open **Redis Commander** at [http://localhost:8081](http://localhost:8081).
2. Open the **Console** at the bottom and run one line at a time:

```text
ACL SETUSER auth_service on >auth_redis_pass ~auth:* &* +@all
ACL SAVE
```

> **Note:** Running `ACL SAVE` writes the user to `/data/users.acl`, ensuring it persists across container restarts on the `redis_data` volume.

---

## Spring Boot Connection Configuration

In your microservice's `src/main/resources/application.yaml`:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/vaultix_auth_db
    username: auth_service_user
    password: auth_secure_pass
    driver-class-name: org.postgresql.Driver
  data:
    redis:
      host: localhost
      port: 6379
      username: auth_service
      password: auth_redis_pass
```

---

## MaxMind GeoIP Database Setup

For client geolocation resolution (country, city) in the API Gateway:

1. Sign in to your free account on [MaxMind](https://www.maxmind.com/en/account/login).
2. In the left navigation, go to **GeoIP / GeoLite** -> **Download Files**.
3. Scroll to **GeoLite City** (Format: `GeoIP2 Binary (.mmdb)`) and click **Download GZIP**.
4. Extract the downloaded archive (`.tar.gz`) and copy the `GeoLite2-City.mmdb` file into:
   ```
   infra/geoip/GeoLite2-City.mmdb
   ```
5. `*.mmdb` files are ignored by `.gitignore` to prevent committing ~50 MB binary files to the repository.
