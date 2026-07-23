# 🤖 OfflineGPT

**Your Private, Offline AI Chat Server** — Like ChatGPT, but running entirely on your own hardware. No internet needed. No data leaves your office.

---

## 📋 Table of Contents

1. [What is OfflineGPT?](#-what-is-offlinegpt)
2. [Service URLs & Ports](#-service-urls--ports)
3. [What You Need (Requirements)](#-what-you-need-requirements)
4. [Step-by-Step Setup Guide](#-step-by-step-setup-guide)
5. [Offline USB Deployment Guide (Air-Gapped)](#-offline-usb-transfer--deployment-guide-no-internet-needed)
6. [How to Use OfflineGPT](#-how-to-use-offlinegpt)
7. [🎛️ Admin Dashboard Guide](#️-admin-dashboard)
8. [Office Network DNS Setup (`ai.local`)](#-office-network-dns-setup-ailocal)
9. [Daily Operations & Direct Docker Commands](#-daily-operations)
10. [Troubleshooting](#-troubleshooting)

---

## 🤔 What is OfflineGPT?

OfflineGPT is a **private AI chat server** that your entire team can use — just like ChatGPT, but:

- ✅ **Runs on YOUR computer** — no cloud, no subscriptions
- ✅ **No internet needed** — works completely offline (air-gapped)
- ✅ **Your data stays private** — nothing is sent outside your office
- ✅ **Multiple users** — everyone gets their own account and private chat history
- ✅ **Built-in Admin Dashboard** — monitor server performance, GPU VRAM, token usage, and user analytics
- ✅ **Free forever** — no API costs, no per-user fees

---

## 🌐 Service URLs & Ports

| Service | Access URL | Description | Credentials |
| :--- | :--- | :--- | :--- |
| **User Chat Interface** | **`http://localhost:67`** *(or `http://ai.local:67`)* | Open WebUI ChatGPT-style chat interface for team members | User accounts |
| **Admin Dashboard** | **`http://localhost:68`** *(or `http://ai.local:68`)* | Comprehensive system monitoring & server management UI | Password: **`admin123`** |
| **Ollama GPU Engine** | `http://localhost:11434` | Backend AI inference engine (Qwen 2.5 7B) | Local internal API |

---

## 💻 What You Need (Requirements)

| Requirement | Details |
|---|---|
| **Computer** | Any desktop/server with Ubuntu Linux (20.04 or newer) |
| **GPU** | NVIDIA GPU with **12GB+ VRAM** (e.g., RTX 3060 12GB, RTX 4070, RTX 5060 Ti, RTX A4000) |
| **RAM** | At least 16GB system RAM |
| **Storage** | At least 20GB free disk space (for AI model + Docker images) |
| **Network** | Connected to your office network (so other computers can access it) |
| **Internet** | Needed only during initial setup. Can be disconnected for full air-gap operation. |

---

## 🚀 Step-by-Step Setup Guide

---

### Step 1: Install Docker

```bash
# 1.1 Remove old Docker packages
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# 1.2 Install prerequisite packages
sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg lsb-release

# 1.3 Add Docker official GPG key & repository
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 1.4 Install Docker Engine & Compose
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 1.5 Add current user to Docker group
sudo usermod -aG docker $USER
```

> ⚠️ **Log out and log back in** for group permissions to take effect.

---

### Step 2: Install NVIDIA GPU Drivers & Toolkit

```bash
# 2.1 Verify NVIDIA drivers
nvidia-smi

# 2.2 If nvidia-smi fails, install driver:
sudo apt-get update && sudo apt-get install -y nvidia-driver-550
sudo reboot

# 2.3 Install NVIDIA Container Toolkit (enables GPU inside Docker)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

---

### Step 3: Start OfflineGPT

```bash
# 3.1 Navigate to the project directory
cd /home/bharath/AmetekGPT

# 3.2 Launch all services (Ollama, Chat UI, Admin Dashboard)
docker compose up -d
```

---

## 📦 Offline USB Transfer & Deployment Guide (No Internet Needed)

All required Docker container images have been pre-packaged into **`docker-images/`** (~2.7 GB total compressed). You can copy this entire project folder to a USB drive and deploy it on any office server offline.

### How to Deploy on your Office Machine:

1. **Copy the project folder to the office computer/server.**
2. **Open Terminal in the project folder and load pre-packaged Docker images:**
   ```bash
   docker load -i docker-images/open-webui-image.tar.gz
   docker load -i docker-images/ollama-image.tar.gz
   ```
3. **Start the application stack:**
   ```bash
   docker compose up -d
   ```
4. **Access the Interfaces:**
   - **User Chat UI**: `http://localhost:67` or `http://ai.local:67`
   - **Admin Dashboard**: `http://localhost:68` or `http://ai.local:68`

---

## 💬 How to Use OfflineGPT

### Creating Your Admin Account (First User)

The **first person** to create an account in the Chat UI automatically becomes the **Open WebUI Administrator**.

1. Open your browser (Chrome, Firefox, Edge, etc.)
2. Go to: `http://localhost:67` (or `http://ai.local:67`)
3. Click **"Sign up"**
4. Enter your **name**, **email**, and choose a **password**
5. Click **"Create Account"**

---

### Inviting Team Members

Tell your team members to:

1. Open their browser on any computer **connected to the same office network**
2. Go to: `http://ai.local:67` (or `http://<SERVER_IP>:67`)
3. Click **"Sign up"** and create their account.

Each person gets their own **private chat history** — nobody can see each other's conversations.

---

## 🎛️ Admin Dashboard Guide

An admin-only web application is available for system monitoring and server management:

- **URL**: **`http://localhost:68`** (or `http://ai.local:68`)
- **Default Password**: `admin123` (configurable via `DASHBOARD_PASSWORD` in `.env`)

```
========================================================================
                      OFFLINEGPT ADMIN DASHBOARD
========================================================================
 [1] System Health        -> Live CPU, RAM, Disk & GPU VRAM / Telemetry
 [2] Containers           -> Service status, 1-click restart, Live SSE Logs
 [3] Users & Analytics    -> User directory, Token metrics, User Inspector Modal
 [4] Models & Speed       -> Loaded models, 1-click Token Speed Benchmark
 [5] Settings             -> Browser-based .env configuration editor
========================================================================
```

### Dashboard Features

#### 1. 📊 System Health & GPU Telemetry
- **CPU & RAM Gauges**: Real-time utilization and memory tracking.
- **NVIDIA GPU Telemetry**: Real-time VRAM utilization (MB used / total), core temperature (°C), GPU load (%), and power draw (W).

#### 2. 🐳 Container Controls & Live SSE Terminal Logs
- **Service Status Overview**: Real-time status for `offlinegpt-dashboard`, `offlinegpt-webui`, and `offlinegpt-ollama`.
- **One-Click Restarts**: Restart services directly from the browser.
- **Live Terminal Log Streaming**: Real-time log streaming using Server-Sent Events (SSE).

#### 3. 👥 Users & Analytics (Merged Menu)
- **Top Summary Cards**: Total Registered Users, 24h Active Users, Total Conversations, Total Messages, and Total Tokens Used.
- **Clean User Directory**: Displays User Name, Email, Role, Total Chats, Overall Tokens Used (`k`/`M`), and Last Active date.
- **🔍 Interactive User Inspector Modal**: Click any User Name to open a detailed modal showing:
  - Overall Tokens Used (formatted in `k` or `M`).
  - Prompt vs Response Token Breakdown (`In: 450 | Out: 1.3k`).
  - Conversation list featuring **Title** and **Exact User Prompt Preview** (e.g. `💬 "how to drive a car..."`).
  - **Context Capacity Bar**: Visual indicator showing memory used vs server context limit (`1.8k / 8.2k tokens`).
- **Live SQLite WAL Mode Reading**: Uses Read-Only SQLite URI queries (`file:/data/webui.db?mode=ro`) to read uncommitted Write-Ahead Logs in real time with zero latency.

#### 4. ⚡ Models & Token Speed Benchmark
- **Model List**: Displays loaded model details, quantization (`Q4_K_M`), and file sizes.
- **Inference Speed Test**: One-click benchmark tool that tests GPU generation speed in **tokens/second**.

#### 5. ⚙️ Settings Editor
- Edit `.env` parameters (`CONTEXT_SIZE`, `PARALLEL_SLOTS`, `PORT`, `ENABLE_SIGNUP`, `DASHBOARD_PASSWORD`) directly from the browser.

---

## 🌐 Office Network DNS Setup (`ai.local`)

To allow your team to access the server using **`http://ai.local:67`** (Chat) and **`http://ai.local:68`** (Dashboard):

### Option 1: Server Hostname Method (mDNS / Local Network)
On your office server, set the system hostname to `ai`:
```bash
sudo hostnamectl set-hostname ai
```
Every computer connected to your office network (Wi-Fi or Ethernet) can now access:
- **Chat UI**: `http://ai.local:67`
- **Admin Dashboard**: `http://ai.local:68`

### Option 2: Office Router / Internal DNS Method
In your office router, Active Directory, or DNS server (like Pi-hole / BIND):
1. Create an **A Record** or **CNAME** pointing `ai.local` to your server's IP address (e.g. `192.168.1.100`).
2. Users can now open `http://ai.local:67` or `http://ai.local:68`.

---

## 📅 Daily Operations & Direct Docker Commands

You can manage the entire server using standard `docker compose` commands:

| Task | Command |
|---|---|
| **Start server (background)** | `docker compose up -d` |
| **Stop server** | `docker compose down` |
| **Restart server** | `docker compose restart` |
| **Check running containers** | `docker ps` |
| **View live logs** | `docker compose logs -f` |
| **Lock signups** | Set `ENABLE_SIGNUP=false` in `.env` then run `docker compose up -d` |
| **Unlock signups** | Set `ENABLE_SIGNUP=true` in `.env` then run `docker compose up -d` |
| **Open Chat UI (local)** | `http://localhost:67` |
| **Open Admin Dashboard** | `http://localhost:68` |

---

## 🔧 Troubleshooting

### "GPU Telemetry shows 0 / 0 MB in Admin Dashboard"
Ensure the `dashboard` service in `docker-compose.yml` has GPU device reservations enabled:
```yaml
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu, utility]
```
Then run `docker compose up -d --force-recreate dashboard`.

### "Dashboard stats did not update after asking a question"
The database uses SQLite WAL mode. Ensure `app.py` connects via URI mode: `file:/data/webui.db?mode=ro`.

### "I get 'out of memory' or GPU errors"
Your GPU is running out of VRAM. Edit `.env` via the Admin Dashboard Settings tab or text editor:
1. Change `CONTEXT_SIZE=8192` to `CONTEXT_SIZE=4096`
2. Change `PARALLEL_SLOTS=4` to `PARALLEL_SLOTS=2`
3. Restart containers: `docker compose restart`

---

## 📁 Project File Structure

```
AmetekGPT/
├── docker-compose.yml        # Container orchestration (WebUI, Ollama, Dashboard)
├── .env                      # System configuration settings
├── README.md                 # Project guide
├── models/                   # AI model GGUF files
│   └── Qwen2.5-7B-Instruct-Q4_K_M.gguf
├── dashboard/                # Admin Dashboard Web App
│   ├── app.py                # FastAPI backend API
│   ├── templates/
│   │   └── index.html        # Single-page Dashboard frontend
│   ├── Dockerfile            # Container definition
│   └── requirements.txt      # Python dependencies
├── static/                   # Static branding assets
│   ├── custom.css
│   ├── logo.png
│   └── favicon.ico
└── docker-images/            # Pre-packaged offline container tars
```

---

*OfflineGPT — Private AI for your team. No cloud. No cost. No compromise.* 🛡️
