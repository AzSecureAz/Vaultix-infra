# Vaultix Infrastructure - Microservice Provisioning & Setup Guide

Comprehensive provisioning reference for PostgreSQL databases, Redis ACL isolated users, RabbitMQ topics/exchanges/queues, and MaxMind GeoIP setups.

---

## 1. PostgreSQL: Database & User Provisioning

### Authorization Service Database & User
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

## 2. Redis: ACL User Provisioning

### Authorization Service ACL User (`auth_user`)
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

### Demo Service ACL User (`demo_user`)
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

## 3. RabbitMQ: Exchange, Queue & User Provisioning

Provision dedicated users, topic exchange (`auth.exchange`), queue (`notification.auth`), and routing bindings:

### Option A: One-Click Declarative Import via Web UI (Fastest)
1. Open the **RabbitMQ Management UI** at [http://localhost:15672](http://localhost:15672) and log in with admin credentials (`admin` / `admin_password`).
2. On the **Overview** page, scroll down to the **Import definitions** section.
3. Click **Browse...**, select `infra/rabbitmq/definitions.json`, and click **Upload definition**.
4. All users (`auth_user`, `notification_user`), permissions, exchanges (`auth.exchange`), queues (`notification.auth`), and bindings are instantly provisioned!

### Option B: Step-by-Step UI or CLI
- **Authorization Service**: Run commands or follow UI steps in [`infra/rabbitmq/init-auth-rabbitmq.txt`](file:///c:/Users/vimal/Documents/Projects/Vaultix/infra/rabbitmq/init-auth-rabbitmq.txt) to create `auth_user` and `auth.exchange`.
- **Notification Service**: Run commands or follow UI steps in [`infra/rabbitmq/init-notification-rabbitmq.txt`](file:///c:/Users/vimal/Documents/Projects/Vaultix/infra/rabbitmq/init-notification-rabbitmq.txt) to create `notification_user`, `notification.auth` queue, and bind to `auth.exchange`.

*(For new microservices, use the general template in `rabbitmq/service-rabbitmq-template.txt`)*.

---

## 4. Spring Boot Microservice Connection References

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
  rabbitmq:
    host: ${SPRING_RABBITMQ_HOST:localhost}
    port: ${SPRING_RABBITMQ_PORT:5672}
    username: ${SPRING_RABBITMQ_USERNAME:auth_user}
    password: ${SPRING_RABBITMQ_PASSWORD:auth_password}
    virtual-host: ${SPRING_RABBITMQ_VIRTUAL_HOST:/}

vaultix:
  rabbitmq:
    exchange: ${VAULTIX_RABBITMQ_EXCHANGE:auth.exchange}
```

### Notification Service (`notification/src/main/resources/application.yaml`):

```yaml
spring:
  rabbitmq:
    host: ${SPRING_RABBITMQ_HOST:localhost}
    port: ${SPRING_RABBITMQ_PORT:5672}
    username: ${SPRING_RABBITMQ_USERNAME:notification_user}
    password: ${SPRING_RABBITMQ_PASSWORD:notification_password}
    virtual-host: ${SPRING_RABBITMQ_VIRTUAL_HOST:/}
  mail:
    host: ${SPRING_MAIL_HOST:localhost}
    port: ${SPRING_MAIL_PORT:1025}

vaultix:
  rabbitmq:
    auth-exchange: ${VAULTIX_RABBITMQ_AUTH_EXCHANGE:auth.exchange}
    auth-queue: ${VAULTIX_RABBITMQ_AUTH_QUEUE:notification.auth}
    auth-routing-key: ${VAULTIX_RABBITMQ_AUTH_ROUTING_KEY:auth.notification.*}
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

## 5. MaxMind GeoIP Database Setup

For client geolocation resolution (country, city) in the API Gateway:

1. Sign in to your free account on [MaxMind](https://www.maxmind.com/en/account/login).
2. In the left navigation, go to **GeoIP / GeoLite** -> **Download Files**.
3. Scroll to **GeoLite City** (Format: `GeoIP2 Binary (.mmdb)`) and click **Download GZIP**.
4. Extract the downloaded archive (`.tar.gz`) and copy the `GeoLite2-City.mmdb` file into:
   ```
   infra/geoip/GeoLite2-City.mmdb
   ```
5. `*.mmdb` files are ignored by `.gitignore` to prevent committing ~50 MB binary files to the repository.
