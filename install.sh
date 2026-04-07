#!/bin/bash
set -e # Зупинити скрипт при помилці

echo "--- [1/7] Оновлення системи та встановлення пакетів ---"
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx mariadb-server openjdk-21-jdk sudo

echo "--- [2/7] Створення користувачів ---"
# Системний користувач для застосунку (без логіну)
sudo useradd -r -m -s /usr/sbin/nologin app || true

# Користувачі для роботи та перевірки
users=("student" "teacher" "operator")
for user in "${users[@]}"; do
    if id "$user" &>/dev/null; then
        echo "Користувач $user вже існує"
    else
        sudo useradd -m -s /bin/bash "$user"
        echo "$user:12345678" | sudo chpasswd
        # Примусова зміна пароля при першому вході (крім student)
        if [ "$user" != "student" ]; then
            sudo chage -d 0 "$user"
        fi
    fi
done

# Додавання прав sudo для student та teacher
sudo usermod -aG sudo student
sudo usermod -aG sudo teacher

echo "--- [3/7] Налаштування MariaDB ---"
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Створення БД та користувача (тільки для localhost)
sudo mysql -e "CREATE DATABASE IF NOT EXISTS notes_db;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'app_user'@'localhost' IDENTIFIED BY 'secure_password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON notes_db.* TO 'app_user'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "--- [4/7] Налаштування обмеженого sudo для operator ---"
# Створюємо файл у /etc/sudoers.d/
cat <<EOF | sudo tee /etc/sudoers.d/operator-rules
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mywebapp.service
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop mywebapp.service
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart mywebapp.service
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl status mywebapp.service
operator ALL=(ALL) NOPASSWD: /usr/bin/nginx -s reload
EOF
sudo chmod 0440 /etc/sudoers.d/operator-rules

echo "--- [5/7] Налаштування Systemd (Socket Activation) ---"
# Створюємо Socket юніт
cat <<EOF | sudo tee /etc/systemd/system/mywebapp.socket
[Unit]
Description=My Web App Socket

[Socket]
ListenStream=5200

[Install]
WantedBy=sockets.target
EOF

# Створюємо Service юніт (заглушка, ExecStart треба буде поправити під твій .jar)
cat <<EOF | sudo tee /etc/systemd/system/mywebapp.service
[Unit]
Description=Notes Service (KPI Lab 1)
After=network.target mariadb.service
Requires=mywebapp.socket

[Service]
User=app
Group=app
WorkingDirectory=/home/app
# Приклад запуску з аргументами (Варіант V2=1)
ExecStart=/usr/bin/java -jar /home/app/mywebapp.jar --port=5200 --db=notes_db
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mywebapp.socket

echo "--- [6/7] Налаштування Nginx (Reverse Proxy) ---"
cat <<EOF | sudo tee /etc/nginx/sites-available/mywebapp
server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/mywebapp_access.log;

    location / {
        proxy_pass http://127.0.0.1:5200;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Заборона доступу до сервісних ендпоінтів ззовні (за бажанням)
    # location /health { deny all; }
}
EOF

sudo ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

echo "--- [7/7] Фінальні кроки ---"
# Створення файлу gradebook
echo "6" | sudo tee /home/student/gradebook
sudo chown student:student /home/student/gradebook

echo "-------------------------------------------------------"
echo "Інфраструктура готова!"
echo "База даних: notes_db (MariaDB)"
echo "Порт застосунку: 5200 (через Nginx: 80)"
echo "Користувач operator має обмежені права через sudo."
echo "Початковий користувач НЕ заблокований для твоєї зручності (додай 'sudo passwd -l \$USER' в кінці за потреби)."