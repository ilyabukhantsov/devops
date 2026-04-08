#!/bin/bash
set -e

REPO_URL="https://github.com/ilyabukhantsov/devops"
PROJECT_DIR="Notes Service"
JAR_NAME="mywebapp.jar"

echo "--- [1/7] Updating system and installing packages (Java 21, Maven, Git) ---"
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx mariadb-server openjdk-21-jdk sudo git maven curl

echo "--- [2/7] Creating users ---"
# Check if service user 'app' exists
if ! id "app" &>/dev/null; then
    sudo useradd -r -m -d /home/app -s /usr/sbin/nologin app
else
    echo "User 'app' already exists, skipping..."
fi

users=("student" "teacher" "operator")
for user in "${users[@]}"; do
    if id "$user" &>/dev/null; then
        echo "User $user already exists, skipping..."
    else
        sudo useradd -m -s /bin/bash "$user"
        echo "$user:12345678" | sudo chpasswd
    fi
done

sudo usermod -aG sudo student
sudo usermod -aG sudo teacher

echo "--- [3/7] Configuring MariaDB (notes_db) ---"
sudo systemctl start mariadb
sudo systemctl enable mariadb
sudo mysql -e "CREATE DATABASE IF NOT EXISTS notes_db;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'app_user'@'localhost' IDENTIFIED BY 'secure_password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON notes_db.* TO 'app_user'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "--- [4/7] Cloning repository and building project ---"
BUILD_DIR="/tmp/app-build"
sudo rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
cd $BUILD_DIR

echo "Cloning from GitHub..."
git clone "$REPO_URL" .

if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
fi

echo "Building JAR via Maven (skipping tests)..."
mvn clean package -DskipTests

sudo cp target/mywebapp.jar /home/app/mywebapp.jar
sudo chown app:app /home/app/mywebapp.jar

echo "--- [5/7] Configuring Systemd (Service Only, No Socket) ---"
sudo systemctl stop mywebapp.socket 2>/dev/null || true
sudo systemctl disable mywebapp.socket 2>/dev/null || true
sudo rm -f /etc/systemd/system/mywebapp.socket

cat <<EOF | sudo tee /etc/systemd/system/mywebapp.service
[Unit]
Description=Notes Service (KPI Lab 1)
After=network.target mariadb.service

[Service]
User=app
Group=app
WorkingDirectory=/home/app
# Java handles port 5200 directly
ExecStart=/usr/bin/java -jar /home/app/mywebapp.jar \\
    --server.port=5200 \\
    --spring.datasource.url=jdbc:mariadb://127.0.0.1:3306/notes_db \\
    --spring.datasource.username=app_user \\
    --spring.datasource.password=secure_password
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mywebapp.service
sudo systemctl restart mywebapp.service

echo "--- [6/7] Configuring Nginx (Reverse Proxy) ---"
cat <<EOF | sudo tee /etc/nginx/sites-available/mywebapp
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5200;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        # Increased timeouts to prevent 504 Gateway Timeout during startup
        proxy_connect_timeout 10s;
        proxy_read_timeout 60s;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

echo "--- [7/7] Configuring sudoers for operator and files ---"
cat <<EOF | sudo tee /etc/sudoers.d/operator-rules
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mywebapp.service
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop mywebapp.service
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart mywebapp.service
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl status mywebapp.service
operator ALL=(ALL) NOPASSWD: /usr/sbin/nginx -s reload
EOF
sudo chmod 0440 /etc/sudoers.d/operator-rules

mkdir -p /home/student
echo "6" | sudo tee /home/student/gradebook
sudo chown student:student /home/student/gradebook

echo "-------------------------------------------------------"
echo "INFRASTRUCTURE AND SERVER ARE READY!"
echo "Access the site: http://<Your_VM_IP>/notes"
echo "Or via Port Forwarding: http://localhost:8080/notes"
echo "Check logs: sudo journalctl -u mywebapp.service -f"
echo "-------------------------------------------------------"