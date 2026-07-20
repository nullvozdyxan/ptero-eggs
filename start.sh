#!/bin/ash

# Colors for output
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

# Function to print messages with colors
log_success() {
    echo -e "${GREEN}[SUCCESS] $1${RESET}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${RESET}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${RESET}"
}

# Clean up temp directory
echo "⏳ Cleaning up temporary files..."
if rm -rf /home/container/tmp/*; then
    log_success "Temporary files removed successfully."
else
    log_error "Failed to remove temporary files."
    exit 1
fi

# Check if python app is enabled (either environment variable PYTHON_APP is 1/true, or auto-detect requirements.txt/main.py/app.py)
PYTHON_ACTIVE=0
if [ "${PYTHON_APP}" = "true" ] || [ "${PYTHON_APP}" = "1" ]; then
    PYTHON_ACTIVE=1
elif [ -f "/home/container/webroot/requirements.txt" ] || [ -f "/home/container/webroot/main.py" ] || [ -f "/home/container/webroot/app.py" ]; then
    log_warning "Python files detected in webroot. Activating Python mode."
    PYTHON_ACTIVE=1
fi

if [ "$PYTHON_ACTIVE" -eq 1 ]; then
    echo "⏳ Configuring Python environment..."
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "/home/container/.venv" ]; then
        echo "⏳ Creating virtual environment..."
        python3 -m venv /home/container/.venv
    fi
    
    # Activate virtual environment
    source /home/container/.venv/bin/activate
    
    # Install/update requirements
    if [ -f "/home/container/webroot/requirements.txt" ]; then
        echo "⏳ Installing/updating Python requirements..."
        pip install --upgrade pip
        pip install -r /home/container/webroot/requirements.txt
    fi

    # Configure Nginx for Python (reverse proxy)
    if [ -f "/home/container/nginx/conf.d/default.conf.python" ]; then
        echo "⏳ Setting up Nginx configuration for Python..."
        # Extract the port currently defined in default.conf (configured by Pterodactyl)
        CURRENT_PORT=$(grep -E '^\s*listen\s+[0-9]+;' /home/container/nginx/conf.d/default.conf | awk '{print $2}' | sed 's/;//')
        if [ -z "$CURRENT_PORT" ]; then
            CURRENT_PORT="80"
        fi
        
        # Use Python to safely and dynamically rewrite nginx config files
        python3 -c '
import os, sys
port = os.environ.get("PYTHON_PORT", "8000")
listen_port = sys.argv[1]
proxy_all = os.environ.get("PYTHON_PROXY_ALL", "0") in ["1", "true"]

proxy_conf_direct = f"""
    location / {{
        proxy_pass http://127.0.0.1:{port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }}
"""

proxy_conf_fallback = f"""
    location / {{
        try_files $uri $uri/ @python;
    }}

    location @python {{
        proxy_pass http://127.0.0.1:{port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }}
"""

with open("/home/container/nginx/conf.d/default.conf.python", "r") as f:
    content = f.read()

content = content.replace("listen 80;", f"listen {listen_port};")
proxy_block = proxy_conf_direct if proxy_all else proxy_conf_fallback
content = content.replace("# PROXY_MODE_PLACEHOLDER", proxy_block)

with open("/home/container/nginx/conf.d/default.conf", "w") as f:
    f.write(content)
' "$CURRENT_PORT"
        log_success "Nginx configuration generated."
    else
        log_warning "default.conf.python not found. Using default Nginx config."
    fi
    
    # Start Python app in the background
    PYTHON_START=${PYTHON_START:-"python3 main.py"}
    echo "⏳ Starting Python application: ${PYTHON_START}..."
    cd /home/container/webroot
    nohup ${PYTHON_START} > /home/container/logs/python.log 2>&1 &
    PYTHON_PID=$!
    cd /home/container
    
    sleep 2
    if kill -0 $PYTHON_PID 2>/dev/null; then
        log_success "Python application started successfully (PID: $PYTHON_PID)."
    else
        log_error "Failed to start Python application. Check /home/container/logs/python.log for details."
        cat /home/container/logs/python.log
    fi
else
    # Start PHP-FPM
    echo "⏳ Starting PHP-FPM..."
    if /usr/sbin/php-fpm8 --fpm-config /home/container/php-fpm/php-fpm.conf --daemonize; then
        log_success "PHP-FPM started successfully."
    else
        log_error "Failed to start PHP-FPM."
        exit 1
    fi
fi

# NGINX if else WIP
echo "⏳ Starting Nginx..."
# Final message
log_success "Web server is running. All services started successfully."
/usr/sbin/nginx -c /home/container/nginx/nginx.conf -p /home/container/

# Keep the container running (optional, depending on your container setup)
tail -f /dev/null
