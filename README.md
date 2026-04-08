# Notes Service - DevOps Lab 1 (Option 6)

This repository contains the source code and automation infrastructure for the **Notes Service** web application, deployed on Ubuntu 24.04 LTS.

---

## 1. Individual Task Assignment

The project parameters are calculated based on the student gradebook number **N = 6**.

### Calculation Table
| Parameter | Formula | Calculation | Value |
| :--- | :--- | :--- | :--- |
| **V2** (Config & DB) | `(N % 2) + 1` | `(6 % 2) + 1 = 1` | **1** |
| **V3** (App Topic) | `(N % 3) + 1` | `(6 % 3) + 1 = 1` | **1** |
| **V5** (App Port) | `(N % 5) + 1` | `(6 % 5) + 1 = 2` | **2** |

### Assignment Description
* **Application Topic:** Notes Service (`mywebapp`).
* **Database:** MariaDB (Restricted to `127.0.0.1`).
* **Application Port:** `5200`.
* **Reverse Proxy:** Nginx (Port 80 -> Port 5200).
* **Service Management:** Systemd Unit (Standalone Service).
* **Automation Requirements:** Zero-touch deployment including user creation (`student`, `teacher`, `operator`) and RBAC configuration.

---

## 2. Web Application Documentation

### Purpose
The **Notes Service** is a backend application designed for managing text-based notes. It provides a RESTful interface to perform basic CRUD operations, allowing users to store and retrieve data persistently using a MariaDB database.

### API Documentation
The application supports the `application/json` format. Use the `Accept` header to specify the response format.

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/notes` | Returns a list of all notes (includes only `id` and `title`). |
| `POST` | `/notes` | Creates a new note. Requires JSON with `title` and `content`. |
| `GET` | `/notes/{id}` | Returns the full content and timestamp for a specific note. |

---

## 3. Environment Setup & Deployment

### Virtual Machine Requirements
* **Base Image:** [Ubuntu Server 24.04.4 LTS (Noble Numbat)](https://ubuntu.com/download/server/thank-you?version=24.04.4&architecture=amd64&lts=true)
* **CPU:** 2 Cores
* **RAM:** 2 GB
* **Disk:** 20 GB
* **Network:** * **NAT** with Port Forwarding (Host Port `8080` -> Guest Port `80`).
    * Ensure internet access is available for package installation.

### Access Credentials
* **Default OS User:** Defined during installation (e.g., `vboxuser`).
* **Lab Users:** `student`, `teacher`, `operator`.
* **Default Password:** `12345678` (Users `teacher` and `operator` are prompted for a password change on first login).
* **Access Method:** SSH or VirtualBox Console.

---

## 4. Deployment Automation

The deployment is fully automated via the `install.sh` script, which configures the server from a clean state.

### How to Run the Automation
1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/ilyabukhantsov/devops.git](https://github.com/ilyabukhantsov/devops.git)
    cd devops/"Notes Service"
    ```
2.  **Run the script:**
    ```bash
    chmod +x install.sh
    sudo ./install.sh
    ```

### Automation Workflow
* **Package Installation:** Installs OpenJDK 21, Maven, MariaDB, and Nginx.
* **User Provisioning:** Creates required system users and sets up RBAC via `/etc/sudoers.d/operator-rules`.
* **Database Initialization:** Sets up the `notes_db` and a dedicated `app_user`.
* **Build Process:** Clones source code and compiles the JAR using Maven.
* **Systemd Setup:** Configures the `mywebapp.service`. Note: Socket activation was replaced by a standalone service for improved port management on port 5200.
* **Nginx Configuration:** Deploys a Reverse Proxy configuration to map Port 80 to the application.

---

## 5. Testing Instructions

Verify the deployment with these steps:

### 1. Service Status
```bash
sudo systemctl status mywebapp.service
# Network Binding
sudo ss -tulpn | grep :5200
# API Functional Test
curl -I http://localhost/notes
# Log in as operator
sudo su - operator
# Attempt to restart service (should not ask for password)
sudo systemctl restart mywebapp.service
cat /home/student/gradebook
# Result: 6

# Api health check
curl -I http://localhost/health/alive
curl -I http://localhost/health/ready