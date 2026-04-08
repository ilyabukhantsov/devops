#!/bin/bash
set -e

REPO_URL="https://github.com/ilyabukhantsov/devops"
PROJECT_DIR="Notes Service"
JAR_NAME="mywebapp.jar"

echo "--- [1/7] Оновлення системи та встановлення пакетів (Java 21, Maven, Git) ---"
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx mariadb-server openjdk-21-jdk sudo git maven curl

echo "--- [2/7] Створення користувачів ---"
sudo useradd -r -m -d /home/app -s /usr/sbin/nologin app 2>/dev/null || true

users=("student" "teacher" "operator")
for user in "${users[@]}"; do
    if id "$user" &>/dev/null; then
        echo "Користувач $user вже існує"
    else
        if getent group "$user" &>/dev/null; then
            sudo useradd -m -g "$user" -s /bin/bash "$user"
        else
            sudo useradd -m -s /bin/bash "$user"
        fi
        
        echo "$user:12345678" | sudo chpasswd
        if [ "$user" != "student" ]; then
            sudo chage -d 0 "$user"
        fi
    fi
done

sudo usermod -aG sudo student
sudo usermod -aG sudo teacher

echo "--- [3/7] Налаштування MariaDB (notes_db) ---"
sudo systemctl start mariadb
sudo systemctl enable mariadb
sudo mysql -e "CREATE DATABASE IF NOT EXISTS notes_db;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'app_user'@'localhost' IDENTIFIED BY 'secure_password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON notes_db.* TO 'app_user'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "--- [4/7] Клонування репозиторію та збірка проекту ---"
BUILD_DIR="/tmp/app-build"
sudo rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
cd $BUILD_DIR

echo "Клонування з GitHub..."
git clone "$REPO_URL" .

if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
fi

echo "Збірка JAR-файлу через Maven (пропускаючи тести)..."
mvn clean package -DskipTests

sudo cp target/mywebapp.jar /home/app/mywebapp.jar
sudo chown app:app /home/app/mywebapp.jar

echo "--- [5/7] Налаштування Systemd (Socket + Service) ---"
cat <<EOF | sudo tee /etc/systemd/system/mywebapp.socket
[Unit]
Description=My Web App Socket
[Socket]
ListenStream=5200
[Install]
WantedBy=sockets.target
EOF

cat <<EOF | sudo tee /etc/systemd/system/mywebapp.service
[Unit]
Description=Notes Service (KPI Lab 1)
After=network.target mariadb.service

[Service]
User=app
Group=app
WorkingDirectory=/home/app
ExecStart=/usr/bin/java -jar /home/app/mywebapp.jar \
    --server.port=5200 \
    --spring.datasource.url=jdbc:mariadb://127.0.0.1:3306/notes_db \
    --spring.datasource.username=app_user \
    --spring.datasource.password=secure_password
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now mywebapp.socket

echo "--- [6/7] Налаштування Nginx (Reverse Proxy) ---"
cat <<EOF | sudo tee /etc/nginx/sites-available/mywebapp
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:5200;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

echo "--- [7/7] Налаштування sudoers для operator та файли ---"
cat <<EOF | sudo tee /etc/sudoers.d/operator-rules
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mywebapp.service
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop mywebapp.service
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart mywebapp.service
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl status mywebapp.service
operator ALL=(ALL) NOPASSWD: /usr/sbin/nginx -s reload
EOF
sudo chmod 0440 /etc/sudoers.d/operator-rules

echo "6" | sudo tee /home/student/gradebook
sudo chown student:student /home/student/gradebook

echo "-------------------------------------------------------"
echo "ІНФРАСТРУКТУРА ТА СЕРВЕР ГОТОВІ!"
echo "Доступ до сайту: http://localhost/notes"
echo "Перегляд логів: sudo journalctl -u mywebapp -f"