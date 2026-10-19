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
│   ├── init-auth-db.sql            # Authorization service DB & user provisioning script
│   └── service-db-template.sql     # SQL template for microservice DB provisioning
├── redis/
│   ├── .env                        # Redis root config
│   ├── .env.example
│   ├── init-auth-acl.txt           # Authorization service Redis ACL provisioning script
│   ├── init-demo-acl.txt           # Demo service Redis ACL provisioning script
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

### 1. PostgreSQL: Authorization Service Database & User
After starting containers (or after running `docker compose down -v`), provision the authorization database and dedicated user:

#### Option A: One-line CLI (Fastest)
From the `infra/` directory:
```bash
docker exec -i vaultix-postgres psql -U postgres -d postgres < postgres/init-auth-db.sql
```

#### Option B: Via Adminer Web UI
1. Open **Adminer** at [http://localhost:8080](http://localhost:8080) and log in as `postgres` (password: `postgres`).
2. Go to **SQL command** and execute the contents of `postgres/init-auth-db.sql`:

```sql
-- 1. Create dedicated user
CREATE USER auth_user WITH ENCRYPTED PASSWORD 'auth_password';

-- 2. Revoke default connect on postgres DB
REVOKE CONNECT ON DATABASE postgres FROM PUBLIC;

-- 3. Create database owned by service user
CREATE DATABASE vaultix_auth_db OWNER auth_user;

-- 4. Secure the new database from public access
REVOKE ALL ON DATABASE vaultix_auth_db FROM PUBLIC;
GRANT ALL PRIVILEGES ON DATABASE vaultix_auth_db TO auth_user;
```

*(For new microservices, use the general template in `postgres/service-db-template.sql`)*.

---

### 2. Redis: Authorization Service ACL User
Provision the isolated Redis user restricted to the `auth:*` key pattern:

#### Option A: One-line CLI (Fastest)
From the `infra/` directory:
```bash
docker exec -i vaultix-redis redis-cli -a redis ACL SETUSER auth_user on >auth_password ~auth:* &* +@all
docker exec -i vaultix-redis redis-cli -a redis ACL SAVE
```

#### Option B: Via Redis Commander Web UI
1. Open **Redis Commander** at [http://localhost:8081](http://localhost:8081) (Username: `admin`, Password: `admin`).
2. Open the **Console** at the bottom and run each command from `redis/init-auth-acl.txt`:

```text
ACL SETUSER auth_user on >auth_password ~auth:* &* +@all
ACL SAVE
```

> **Note:** Running `ACL SAVE` writes the user to `/data/users.acl`, ensuring it persists across container restarts on the `redis_data` volume.

---

### 3. Redis: Demo Service ACL User (`demo_user`)
Provision the isolated Redis user for the `demo` service with read-only access to auth revocation stores and pub/sub channels:

#### Option A: One-line CLI (Fastest)
From the `infra/` directory:
```bash
docker exec -i vaultix-redis redis-cli -a redis ACL SETUSER demo_user on >demo_password ~demo:* %R~auth:blacklist:* %R~auth:permission:disabled %R~auth:role:disabled &auth:signing-key:revocation &auth:permission:revocation &auth:role:revocation &demo:* +@all
docker exec -i vaultix-redis redis-cli -a redis ACL SAVE
```

#### Option B: Via Redis Commander Web UI
1. Open **Redis Commander** at [http://localhost:8081](http://localhost:8081).
2. Open the **Console** and execute the contents of `redis/init-demo-acl.txt`:
```text
ACL SETUSER demo_user on >demo_password ~demo:* %R~auth:blacklist:* %R~auth:permission:disabled %R~auth:role:disabled &auth:signing-key:revocation &auth:permission:revocation &auth:role:revocation &demo:* +@all
ACL SAVE
```

*(For new microservices, use the general template in `redis/service-acl-template.txt`)*.

---

## Spring Boot Connection Configuration

### Authorization Service (`authorization/src/main/resources/application.yaml`):

```yaml
spring:
  datasource:
    url: ${SPRING_DATASOURCE_URL:jdbc:postgresql://localhost:5432/vaultix_auth_db}
    username: ${SPRING_DATASOURCE_USERNAME:auth_user}
    password: ${SPRING_DATASOURCE_PASSWORD:auth_password}
    driver-class-name: org.postgresql.Driver
  data:
    redis:
      host: ${SPRING_DATA_REDIS_HOST:localhost}
      port: ${SPRING_DATA_REDIS_PORT:6379}
      username: ${SPRING_DATA_REDIS_USERNAME:auth_user}
      password: ${SPRING_DATA_REDIS_PASSWORD:auth_password}
```

### Demo Service (`demo/src/main/resources/application.yaml`):

```yaml
spring:
  data:
    redis:
      host: ${SPRING_DATA_REDIS_HOST:localhost}
      port: ${SPRING_DATA_REDIS_PORT:6379}
      username: ${SPRING_DATA_REDIS_USERNAME:demo_user}
      password: ${SPRING_DATA_REDIS_PASSWORD:demo_password}
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
