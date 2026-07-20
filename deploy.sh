#!/bin/bash

# Todo App Deployment Helper Script
# Usage: ./deploy.sh [command] [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
DOCKER_ORG="ghcr.io/egarc-global"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

log_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

log_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

show_help() {
    cat << EOF
${BLUE}Todo App Deployment Tool${NC}

Usage: ./deploy.sh [command] [options]

Commands:

  ${GREEN}local${NC}
    Start Todo App locally for development
    Usage: ./deploy.sh local [start|stop|logs|restart]

  ${GREEN}build${NC}
    Build Docker images locally
    Usage: ./deploy.sh build

  ${GREEN}push${NC}
    Push images to GitHub Container Registry (GHCR)
    Usage: ./deploy.sh push [registry] (default: ghcr.io/egarc-global)

  ${GREEN}check${NC}
    Check SSH access to all servers
    Usage: ./deploy.sh check

  ${GREEN}deploy${NC}
    Deploy Todo App to all servers (first time only)
    Usage: ./deploy.sh deploy

  ${GREEN}update${NC}
    Rolling deploy (zero-downtime update)
    Usage: ./deploy.sh update

  ${GREEN}status${NC}
    Check app status on all servers
    Usage: ./deploy.sh status

  ${GREEN}logs${NC}
    View logs from a server
    Usage: ./deploy.sh logs [server1|server2|server3] [backend|frontend]

  ${GREEN}restart${NC}
    Restart containers on a server
    Usage: ./deploy.sh restart [server1|server2|server3] [backend|frontend|all]

  ${GREEN}health${NC}
    Check health of all servers
    Usage: ./deploy.sh health

Examples:

  # Local development
  ./deploy.sh local start
  ./deploy.sh local logs

  # Build and push images
  ./deploy.sh build
  ./deploy.sh push

  # Deploy to production
  ./deploy.sh check          # Verify SSH access
  ./deploy.sh deploy         # First deployment
  ./deploy.sh update         # Rolling update
  ./deploy.sh status         # Check status
  ./deploy.sh health         # Check health

EOF
}

# Local development commands
local_start() {
    log_info "Starting Todo App locally..."
    docker compose up -d
    log_success "Services started"
    echo ""
    log_info "Access at: http://localhost:3000"
    log_info "Backend API: http://localhost:8080/api"
    log_info "Health check: http://localhost:8080/health"
}

local_stop() {
    log_info "Stopping Todo App..."
    docker compose down
    log_success "Services stopped"
}

local_logs() {
    log_info "Showing logs (Ctrl+C to exit)..."
    docker compose logs -f
}

local_restart() {
    log_info "Restarting services..."
    docker compose restart
    log_success "Services restarted"
}

# Build images
build_images() {
    log_info "Building Docker images..."
    docker build -t "$DOCKER_ORG/todo-backend:latest" ./backend
    log_success "Backend image built"
    docker build -t "$DOCKER_ORG/todo-frontend:latest" ./frontend
    log_success "Frontend image built"
}

# Push to registry
push_images() {
    local registry="${1:-$DOCKER_ORG}"
    log_warning "Make sure you're logged in to Docker registry"
    log_info "Pushing images to $registry..."
    docker push "$registry/todo-backend:latest"
    log_success "Backend image pushed"
    docker push "$registry/todo-frontend:latest"
    log_success "Frontend image pushed"
}

# Check SSH access
check_servers() {
    log_info "Checking SSH access to servers..."
    cd "$ANSIBLE_DIR"
    ansible -i hosts.yml app_servers -m ping
    log_success "All servers are reachable"
}

# Deploy to servers
deploy_to_servers() {
    log_warning "This is the FIRST deployment. Use 'update' for rolling deployments."
    log_info "Deploying to all servers..."
    cd "$ANSIBLE_DIR"
    ansible-playbook -i hosts.yml playbooks/deploy_todo.yml
    log_success "Deployment complete!"
}

# Rolling update
rolling_update() {
    log_info "Starting rolling deployment (zero downtime)..."
    cd "$ANSIBLE_DIR"
    ansible-playbook -i hosts.yml playbooks/rolling_deploy_todo.yml
    log_success "Rolling deployment complete!"
}

# Check status
check_status() {
    log_info "Checking app status on all servers..."
    cd "$ANSIBLE_DIR"
    ansible -i hosts.yml app_servers -m shell -a "docker ps | grep todo_"
}

# View logs
view_logs() {
    local server="${1:-server1}"
    local service="${2:-backend}"
    local host=""

    case "$server" in
        server1) host="46.224.47.3" ;;
        server2) host="37.27.246.171" ;;
        server3) host="157.180.123.77" ;;
        *)
            log_error "Unknown server: $server"
            exit 1
            ;;
    esac

    log_info "Viewing logs from $server ($host) - $service"
    ssh "root@$host" "docker logs -f --tail=100 todo_$service"
}

# Restart services
restart_service() {
    local server="${1:-server1}"
    local service="${2:-all}"
    local host=""

    case "$server" in
        server1) host="46.224.47.3" ;;
        server2) host="37.27.246.171" ;;
        server3) host="157.180.123.77" ;;
        *)
            log_error "Unknown server: $server"
            exit 1
            ;;
    esac

    log_info "Restarting $service on $server ($host)..."
    ssh "root@$host" "cd /opt/todo-app && docker compose restart $service"
    log_success "Restart complete"
}

# Health check
health_check() {
    log_info "Checking health of all servers..."
    servers=(
        "46.224.47.3:8090"
        "37.27.246.171:8090"
        "157.180.123.77:8090"
    )

    for server in "${servers[@]}"; do
        if curl -s "http://$server/health" > /dev/null 2>&1; then
            log_success "$server is healthy"
        else
            log_error "$server is DOWN"
        fi
    done
}

# Main script logic
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

case "$1" in
    local)
        case "${2:-start}" in
            start) local_start ;;
            stop) local_stop ;;
            logs) local_logs ;;
            restart) local_restart ;;
            *) log_error "Unknown local command: $2"; exit 1 ;;
        esac
        ;;
    build)
        build_images
        ;;
    push)
        push_images "${2}"
        ;;
    check)
        check_servers
        ;;
    deploy)
        deploy_to_servers
        ;;
    update)
        rolling_update
        ;;
    status)
        check_status
        ;;
    logs)
        view_logs "$2" "$3"
        ;;
    restart)
        restart_service "$2" "$3"
        ;;
    health)
        health_check
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
