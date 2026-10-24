# Vaultix Infrastructure

Local development environment for the Vaultix microservices platform, powered by Docker Compose.

---

## Architecture & Services

| Service | Container Name | Port | Description | Web UI / Access |
| :--- | :--- | :--- | :--- | :--- |
| **PostgreSQL** | `vaultix-postgres` | `5432` | Relational database (Alpine) | [localhost:8080](http://localhost:8080) (via Adminer) |
| **Redis** | `vaultix-redis` | `6379` | In-memory key-value cache/store (Alpine) | [localhost:8081](http://localhost:8081) (via Redis Commander) |
| **RabbitMQ** | `vaultix-rabbitmq` | `5672`, `15672` | Message broker with Management UI | [http://localhost:15672](http://localhost:15672) |
| **Mailpit** | `vaultix-mailpit` | `1025`, `8025` | Local SMTP server & testing Web UI | [http://localhost:8025](http://localhost:8025) |
| **Adminer** | `vaultix-adminer` | `8080` | Lightweight PostgreSQL web management GUI | [http://localhost:8080](http://localhost:8080) |
| **Redis Commander** | `vaultix-redis-commander` | `8081` | Web management GUI for Redis | [http://localhost:8081](http://localhost:8081) |


---
## Documentation Index

Detailed provisioning scripts, ACL commands, RabbitMQ declarations, and GeoIP setup guides are maintained in the [`docs/`](docs/) directory:

| Document | Description |
| :--- | :--- |
| 📖 [**Microservice Provisioning & Setup Guide**](docs/PROVISIONING.md) | Step-by-step instructions for PostgreSQL database & user provisioning, Redis ACL user setups (`auth_user`, `demo_user`), declarative RabbitMQ definition import, Spring Boot connection references, and MaxMind GeoLite2 installation. |

---

## Quick Start

### 1. Environment Setup
Before starting for the first time, ensure each service has its `.env` file copied from `.env.example`:
- `adminer/.env`
- `postgres/.env`
- `redis/.env`
- `redis-commander/.env`
- `rabbitmq/.env`
- `mailpit/.env`

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

### RabbitMQ Management UI
- **URL**: [http://localhost:15672](http://localhost:15672)
- **Username**: `admin`
- **Password**: `admin_password`

### Mailpit Web UI
- **URL**: [http://localhost:8025](http://localhost:8025)

---

## Directory Structure

```
infra/
├── docker-compose.yml              # Main compose orchestrator
├── .gitignore                      # Ignores sensitive .env files
├── README.md                       # Infrastructure documentation
├── docs/
│   └── PROVISIONING.md             # Detailed provisioning & ACL setup guide
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
├── rabbitmq/
│   ├── .env                        # RabbitMQ root credentials
│   ├── .env.example
│   ├── definitions.json            # Declarative users, vhosts, permissions
│   ├── init-auth-rabbitmq.txt      # Provisioning instructions
│   ├── init-notification-rabbitmq.txt
│   └── service-rabbitmq-template.txt# Template for microservice queue/exchange provisioning
├── mailpit/
│   ├── .env                        # Local SMTP and Web UI config
│   └── .env.example
└── geoip/
    ├── .gitkeep                    # Keeps directory tracked
    └── GeoLite2-City.mmdb          # MaxMind database (ignored by git, placed locally)
```
