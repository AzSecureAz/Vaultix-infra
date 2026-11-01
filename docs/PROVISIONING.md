# Vaultix Infrastructure - Microservice Provisioning & Setup Guide

Comprehensive provisioning reference for PostgreSQL databases, Redis ACL isolated users, RabbitMQ topics/exchanges/queues, and MaxMind GeoIP setups across the **Vaultix** microservices platform.

---

## Table of Contents
1. [PostgreSQL: Database & User Provisioning](#1-postgresql-database--user-provisioning)
2. [Redis: ACL User Provisioning](#2-redis-acl-user-provisioning)
3. [RabbitMQ: Exchange, Queue & User Provisioning](#3-rabbitmq-exchange-queue--user-provisioning)
4. [Mailpit: Local SMTP Testing](#4-mailpit-local-smtp-testing)
5. [MaxMind GeoIP Database Setup](#5-maxmind-geoip-database-setup)
6. [Spring Boot Microservice Connection References](#6-spring-boot-microservice-connection-references)

---

## 1. PostgreSQL: Database & User Provisioning

### Authorization Service Database & User
After starting containers (or after running `docker compose down -v`), provision the dedicated database and least-privilege service user:

#### Option A: One-line CLI (Fastest)
From the `infra/` directory:
```bash
docker exec -i vaultix-postgres psql -U postgres -d postgres < postgres/init-auth-db.sql
```

#### Option B: Via Adminer Web UI
1. Open **Adminer** at [http://localhost:8080](http://localhost:8080) and log in with system: `PostgreSQL`, server: `postgres`, user: `postgres`, password: `postgres`.
2. Go to **SQL command** and execute the contents of `postgres/init-auth-db.sql`:

```sql
/* 1. Create dedicated service user */
CREATE USER auth_user WITH ENCRYPTED PASSWORD 'auth_password';

/* 2. Revoke default connect privileges on administrative postgres DB */
REVOKE CONNECT ON DATABASE postgres FROM PUBLIC;

/* 3. Create dedicated service database owned by auth_user */
CREATE DATABASE vaultix_auth_db OWNER auth_user;

/* 4. Secure the new database from public access */
REVOKE ALL ON DATABASE vaultix_auth_db FROM PUBLIC;
GRANT ALL PRIVILEGES ON DATABASE vaultix_auth_db TO auth_user;
```

*(For new microservices, use the general template in `postgres/service-db-template.sql`)*.

---

## 2. Redis: ACL User Provisioning

Redis 7+ Access Control Lists (ACL) isolate microservices to dedicated key patterns, preventing accidental cross-service data modification or unauthorized key reads.

### Authorization Service ACL User (`auth_user`)
Provisions the service user with full access restricted strictly to the `auth:*` keyspace:

#### Option A: One-line CLI (Fastest)
From the `infra/` directory:
```bash
docker exec -i vaultix-redis redis-cli -a redis ACL SETUSER auth_user on >auth_password ~auth:* &* +@all
docker exec -i vaultix-redis redis-cli -a redis ACL SAVE
```

#### Option B: Via Redis Commander Web UI
1. Open **Redis Commander** at [http://localhost:8081](http://localhost:8081) (Username: `admin`, Password: `admin`).
2. Open the **Console** at the bottom and execute:
```text
ACL SETUSER auth_user on >auth_password ~auth:* &* +@all
ACL SAVE
```

> **Important Note:** Running `ACL SAVE` commits the in-memory rules to `/data/users.acl`, ensuring credentials persist across container restarts on the `redis_data` volume.

---

### Demo Resource Server ACL User (`demo_user`)
Provisions the least-privilege user for downstream resource servers with read-only access to token blacklists, sudo sessions, and revocation hashes:

#### Option A: One-line CLI (Fastest)
From the `infra/` directory:
```bash
docker exec -i vaultix-redis redis-cli -a redis ACL SETUSER demo_user on >demo_password ~demo:* %R~auth:blacklist:* %R~auth:sudo:session:* %R~auth:permission:disabled %R~auth:role:disabled &auth:signing-key:revocation &auth:permission:revocation &auth:role:revocation &demo:* +@all
docker exec -i vaultix-redis redis-cli -a redis ACL SAVE
```

#### Option B: Via Redis Commander Web UI
1. Open **Redis Commander** at [http://localhost:8081](http://localhost:8081).
2. Open the **Console** and execute:
```text
ACL SETUSER demo_user on >demo_password ~demo:* %R~auth:blacklist:* %R~auth:sudo:session:* %R~auth:permission:disabled %R~auth:role:disabled &auth:signing-key:revocation &auth:permission:revocation &auth:role:revocation &demo:* +@all
ACL SAVE
```

### Redis ACL Permission Matrix:

| User | Keyspace Pattern | Operation Types | Purpose |
| :--- | :--- | :--- | :--- |
| **`auth_user`** | `~auth:*` | Read / Write (`+@all`) | Authoritative ownership of tokens, sessions, KEK keys, challenges, and cooldowns |
| **`demo_user`** | `~demo:*` | Read / Write (`+@all`) | Isolated namespace for demo resource server |
| **`demo_user`** | `%R~auth:blacklist:*` | Read-only (`+get`, `+mget`) | Verifying revoked JWT JTI identifiers |
| **`demo_user`** | `%R~auth:sudo:session:*` | Read-only (`+get`, `+mget`) | Verifying elevated session timestamps |
| **`demo_user`** | `%R~auth:permission:disabled` | Read-only (`+hget`, `+hgetall`) | Verifying live permission revocations |
| **`demo_user`** | `%R~auth:role:disabled` | Read-only (`+hget`, `+hgetall`) | Verifying live role revocations |

*(For new microservices, use the general template in `redis/service-acl-template.txt`)*.

---

## 3. RabbitMQ: Exchange, Queue & User Provisioning

Provisions dedicated users, the topic exchange (`auth.exchange`), the consumer queue (`notification.auth`), and topic routing bindings:

### Option A: One-Click Declarative Import via Web UI (Fastest)
1. Open the **RabbitMQ Management UI** at [http://localhost:15672](http://localhost:15672) and log in with admin credentials (`admin` / `admin_password`).
2. On the **Overview** page, scroll down to the **Import definitions** section.
3. Click **Browse...**, select `infra/rabbitmq/definitions.json`, and click **Upload definition**.
4. All users (`auth_user`, `notification_user`), permissions, exchanges (`auth.exchange`), queues (`notification.auth`), and bindings are instantly provisioned.

### Option B: Step-by-Step UI or CLI
* **Authorization Service**: Follow UI steps or run commands in [`infra/rabbitmq/init-auth-rabbitmq.txt`](file:///c:/Users/vimal/Documents/Projects/Vaultix/infra/rabbitmq/init-auth-rabbitmq.txt) to configure `auth_user` and `auth.exchange`.
* **Notification Service**: Follow UI steps or run commands in [`infra/rabbitmq/init-notification-rabbitmq.txt`](file:///c:/Users/vimal/Documents/Projects/Vaultix/infra/rabbitmq/init-notification-rabbitmq.txt) to configure `notification_user`, the `notification.auth` queue, and the binding to `auth.exchange` with routing key `auth.notification.*`.

*(For new microservices, use the general template in `rabbitmq/service-rabbitmq-template.txt`)*.

---

## 4. Mailpit: Local SMTP Testing

Mailpit captures all outgoing emails sent by the platform during local development:
* **SMTP Server**: Listens on `localhost:1025` with no authentication required.
* **Web UI**: Access the inbox at [http://localhost:8025](http://localhost:8025) to inspect welcome emails, password reset OTPs, MFA activation notifications, and security alert messages with zero external email delivery risk.

---

## 5. MaxMind GeoIP Database Setup

For client geolocation resolution (city, region, country, coordinates, timezone) in the API Gateway:

1. Sign in to your free account on [MaxMind](https://www.maxmind.com/en/account/login).
2. In the navigation menu, select **GeoIP / GeoLite** &rarr; **Download Files**.
3. Locate **GeoLite2 City** (Format: `GeoIP2 Binary (.mmdb)`) and click **Download GZIP**.
4. Extract the downloaded archive (`.tar.gz`) and place `GeoLite2-City.mmdb` into:
   ```text
   infra/geoip/GeoLite2-City.mmdb
   ```
5. Binary `.mmdb` files are ignored by git in `.gitignore` to prevent committing large binary files to source control.

---

## 6. Spring Boot Microservice Connection References

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
    auth-exchange: ${VAULTIX_RABBITMQ_AUTH_EXCHANGE:auth.exchange}
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

### Demo Resource Server (`demo/src/main/resources/application.yaml`):

```yaml
spring:
  data:
    redis:
      host: ${SPRING_DATA_REDIS_HOST:localhost}
      port: ${SPRING_DATA_REDIS_PORT:6379}
      username: ${SPRING_DATA_REDIS_USERNAME:demo_user}
      password: ${SPRING_DATA_REDIS_PASSWORD:demo_password}
```
