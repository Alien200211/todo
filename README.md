# 📝 Todo App - Infrastructure Learning Project

A simple Todo application built to learn about deploying applications across multiple servers with high availability, monitoring, and zero-downtime deployments.

## 🎯 Project Structure

```
todo-app/
├── backend/          # Node.js + Express API
│   ├── index.js      # Main server
│   ├── Dockerfile    # Backend container definition
│   └── package.json  # Dependencies
├── frontend/         # React app
│   ├── src/          # React components
│   ├── Dockerfile    # Frontend container definition
│   └── package.json  # Dependencies
├── ansible/          # Deployment automation
│   ├── hosts.yml     # Server inventory
│   ├── playbooks/    # Ansible playbooks
│   └── templates/    # Configuration templates
├── nginx/            # Reverse proxy config
├── docker-compose.yml      # Local development
├── docker-compose.prod.yml # Production deployment
└── README.md         # This file
```

## 🚀 Quick Start (Local Development)

### Prerequisites
- Docker & Docker Compose installed
- Node.js 18+
- Git

### Run Locally

```bash
cd ~/Downloads/todo-app
docker-compose up -d
```

Then visit: **http://localhost:3000**

Check services:
```bash
docker compose ps
docker compose logs -f backend
```

Stop:
```bash
docker compose down
```

## 📦 Understanding the Architecture

### Backend (Node.js + Express)

**What it does:**
- Runs on port 8080 (locally) / 8090 (production)
- Provides REST API for todos
- Connects to PostgreSQL database
- Health check endpoint: `/health`

**Key endpoints:**
```
GET    /api/todos          - Get all todos
POST   /api/todos          - Create new todo
GET    /api/todos/:id      - Get single todo
PUT    /api/todos/:id      - Update todo (mark complete)
DELETE /api/todos/:id      - Delete todo
GET    /health             - Health check (for monitoring)
```

**Environment variables:**
```
DB_HOST=postgres        # Database server
DB_USER=postgres        # DB username
DB_PASSWORD=postgres    # DB password
DB_NAME=todos_db        # Database name
DB_PORT=5432            # DB port
PORT=8080               # Backend port
NODE_ENV=production     # Environment
```

### Frontend (React)

**What it does:**
- Runs on port 3000 (locally) / 3010 (production)
- Built as static files + served with `serve`
- Fetches data from backend via `/api/*` endpoints
- Responsive UI with Tailwind-like styling

**Key files:**
- `src/App.js` - Main React component
- `src/App.css` - Styling
- `public/index.html` - HTML template

### Database (PostgreSQL)

**Auto-created tables:**
```sql
CREATE TABLE todos (
  id SERIAL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Local access:**
```bash
# From inside container
docker exec -it todo_postgres psql -U postgres -d todos_db

# From host
psql -h localhost -U postgres -d todos_db
```

## 🐳 Docker & Docker Compose Explained

### Why Docker?

- **Consistency**: Same code runs everywhere (laptop, server 1, server 2, etc.)
- **Isolation**: Each service (backend, frontend, database) runs independently
- **Easy deployment**: Just `docker pull` and `docker run`

### Docker Compose

Defines all services in one file:

```yaml
services:
  postgres:      # Database
  backend:       # API server
  frontend:      # Web UI
```

**Commands:**
```bash
docker-compose up -d                    # Start everything in background
docker-compose ps                       # List running containers
docker-compose logs -f backend          # View backend logs (live)
docker-compose exec backend sh          # Shell into backend container
docker-compose down                     # Stop everything
docker-compose restart backend          # Restart one service
```

## 🚀 Deploying to Production (Your 3 Servers)

### Prerequisites

1. **SSH access** to all servers as root
2. **Ansible** installed locally
3. **Docker & Docker Compose** on all servers (usually pre-installed)
4. **GitHub token** (to pull images from GHCR)

### Step 1: Build & Push Docker Images to Registry

Before deploying, push your images to GitHub Container Registry (GHCR):

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Build images
docker build -t ghcr.io/egarc-global/todo-backend:latest ./backend
docker build -t ghcr.io/egarc-global/todo-frontend:latest ./frontend

# Push to registry
docker push ghcr.io/egarc-global/todo-backend:latest
docker push ghcr.io/egarc-global/todo-frontend:latest
```

### Step 2: Deploy with Ansible (First Time Only)

**This sets up the app on all 3 servers:**

```bash
cd ~/Downloads/todo-app/ansible

# Verify connectivity to servers
ansible -i hosts.yml app_servers -m ping

# Deploy for the first time
ansible-playbook -i hosts.yml playbooks/deploy_todo.yml
```

This will:
1. Create `/opt/todo-app` on each server
2. Copy docker-compose.prod.yml
3. Pull images from registry
4. Start all containers
5. Wait for health checks

### Step 3: Rolling Deploy (Updates)

After making changes and pushing new images:

```bash
ansible-playbook -i hosts.yml playbooks/rolling_deploy_todo.yml
```

This deploys **one server at a time** (zero downtime!):

```
Server 1: Stop → Pull new image → Start → Health check ✓
Server 2: Stop → Pull new image → Start → Health check ✓
Server 3: Stop → Pull new image → Start → Health check ✓
All servers running new version!
```

### Step 4: Nginx Configuration

Add the todo app to your Nginx reverse proxy:

```bash
# Copy nginx config to all servers
scp nginx/todo.conf root@46.224.47.3:/etc/nginx/sites-enabled/

# Test Nginx config
ssh root@46.224.47.3 "nginx -t"

# Reload Nginx
ssh root@46.224.47.3 "systemctl reload nginx"
```

Then visit: **https://todo.egarcglobal.com**

## 📊 Monitoring Your App

### Check container status

```bash
# SSH to server 1
ssh root@46.224.47.3

# List running containers
docker ps

# View logs
docker logs todo_backend -f --tail=100
docker logs todo_frontend -f

# Check specific container status
docker ps | grep todo_
```

### Prometheus Metrics

Prometheus automatically scrapes your services. To view metrics:

1. Go to **https://prometheus.egarcglobal.com**
2. Search for `container_*` metrics
3. You'll see CPU, memory, network usage

### Grafana Dashboards

1. Go to **https://grafana.egarcglobal.com**
2. Create new dashboard
3. Add panels to query Prometheus

**Example queries:**
```
# Container CPU usage
rate(container_cpu_usage_seconds_total{name="todo_backend"}[5m])

# Container memory usage
container_memory_usage_bytes{name="todo_backend"}

# HTTP request rate
rate(http_requests_total{job="todo_backend"}[5m])
```

### Loki Logs

View all logs from all servers:

```bash
# Go to https://loki.egarcglobal.com
# Or query from command line
curl http://91.107.238.86:3100/loki/api/v1/query?query={container_name="todo_backend"}
```

## 🔄 Database Backups

Your backups (MinIO + Neon) automatically include the todos database.

**Check backup status:**
```bash
ssh root@91.107.238.86 "cat /opt/backup/last_backup.txt"
```

**Manual backup:**
```bash
ssh root@91.107.238.86 "bash /opt/scripts/backup.sh"
```

## 🐛 Troubleshooting

### Backend not connecting to database

```bash
# Check if PostgreSQL is running
ssh root@46.224.47.3 "docker ps | grep postgres"

# Check backend logs
ssh root@46.224.47.3 "docker logs todo_backend"

# Test database directly
ssh root@46.224.47.3 "docker exec todo_postgres psql -U postgres -d todos_db -c 'SELECT COUNT(*) FROM todos;'"
```

### Frontend showing "API error"

```bash
# Verify backend is responding
curl http://46.224.47.3:8090/health

# Check Nginx is routing correctly
ssh root@46.224.47.3 "curl -H 'Host: todo.egarcglobal.com' http://localhost/api/todos"

# View Nginx error log
ssh root@46.224.47.3 "tail -20 /var/log/nginx/error.log"
```

### Rolling deploy failed on Server 2

```bash
# Check what went wrong
ssh root@37.27.246.171 "docker logs todo_backend"

# Rollback to previous image
ssh root@37.27.246.171 "docker pull ghcr.io/egarc-global/todo-backend:v1.0"
ssh root@37.27.246.171 "cd /opt/todo-app && docker-compose up -d backend"
```

## 📈 What You're Learning

✅ **Docker & Containerization**
- Building images
- Running containers
- Volumes & networking

✅ **Docker Compose**
- Multi-container applications
- Service dependencies
- Health checks

✅ **Ansible Automation**
- Configuration management
- Playbooks & roles
- Deploying to multiple servers

✅ **Reverse Proxy (Nginx)**
- Traffic routing
- SSL termination
- Upstream servers

✅ **High Availability (HA)**
- Rolling deployments
- Zero-downtime updates
- Health checks

✅ **Monitoring**
- Prometheus metrics
- Grafana dashboards
- Log aggregation (Loki)

✅ **Database Replication**
- PostgreSQL read replicas
- Automatic backups
- Recovery procedures

## 🎓 Next Steps

1. **Modify the backend** - Add a new endpoint
2. **Rebuild the image** - `docker build -t todo-backend .`
3. **Test locally** - `docker-compose up`
4. **Deploy to servers** - `ansible-playbook ... rolling_deploy_todo.yml`
5. **Monitor in Grafana** - Watch metrics change in real-time

## 📚 Useful Commands Cheat Sheet

```bash
# Local Development
docker-compose up -d              # Start everything
docker-compose logs -f            # View logs
docker-compose ps                 # List services
docker-compose down               # Stop everything

# Production (SSH to server)
ssh root@46.224.47.3

# Check status
docker ps | grep todo_            # List todo containers
docker stats                       # Real-time resource usage

# View logs
docker logs todo_backend -f
docker logs todo_frontend

# Manual restart
docker-compose -f /opt/todo-app/docker-compose.yml restart backend

# Connect to database
docker exec -it todo_postgres psql -U postgres -d todos_db

# Ansible Deployment
ansible-playbook -i hosts.yml playbooks/deploy_todo.yml           # First deploy
ansible-playbook -i hosts.yml playbooks/rolling_deploy_todo.yml   # Updates
```

## 🤝 Contributing

Got improvements? Try:
1. Change code locally
2. Test with `docker-compose`
3. Push images to GHCR
4. Deploy with Ansible playbook
5. Monitor in Grafana

Good luck! 🚀
