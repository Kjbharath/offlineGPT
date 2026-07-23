# 🚀 OfflineGPT — Portable Native (No-Docker) Deployment Guide

**For strict corporate office environments where Docker or root/sudo access is not allowed.**

---

## 📋 Features

- ❌ **Zero Docker Required** — Runs 100% natively on Linux
- ❌ **Zero Root / Sudo Required** — Runs entirely inside your user home directory
- ✅ **100% Offline Air-Gapped** — Includes pre-cached Python `.whl` packages and portable binaries
- ✅ **NVIDIA GPU Acceleration** — Uses standalone Ollama binary with CUDA libraries
- ✅ **Complete Feature Parity** — Chat Interface (Port 67) + Admin Dashboard (Port 68)

---

## 📁 Package Contents

```
AmetekGPT/
├── bin/
│   ├── ollama                     # Standalone 38MB Ollama binary
│   └── lib/ollama/                # Portable CUDA GPU acceleration libraries
├── models/
│   └── Qwen2.5-7B-Instruct-Q4_K_M.gguf # AI model file
├── pip_wheels/                    # Offline cached Python wheels
├── scripts/
│   ├── setup_native.sh            # Local Python venv & wheel installer
│   ├── start_native.sh            # Background service launcher
│   ├── stop_native.sh             # Graceful process killer
│   └── health_native.sh           # Port & service health checker
├── dashboard/                     # Admin Dashboard Web App
│   ├── app.py
│   └── templates/index.html
└── README_NATIVE.md               # This guide
```

---

## 🚀 Step-by-Step Office Deployment Guide (No Internet & No Docker Needed)

### Step 1: Copy to Office Server
Copy the `AmetekGPT` folder from your USB drive to any directory on the office server:
```bash
cp -r /media/usb/AmetekGPT ~/AmetekGPT
cd ~/AmetekGPT
```

### Step 2: One-Time Local Setup (No Root Required)
Run the native setup script. This creates a local Python virtual environment (`venv/`) and installs Open WebUI & Dashboard dependencies directly from the included `./pip_wheels/` folder:
```bash
bash scripts/setup_native.sh
```

### Step 3: Start All Services
Launch Ollama, Open WebUI, and the Admin Dashboard in the background:
```bash
bash scripts/start_native.sh
```

---

## 🌐 Accessing the Services

| Service | Local Access | Office Network Access | Credentials |
| :--- | :--- | :--- | :--- |
| **User Chat Interface** | **`http://localhost:67`** | **`http://ai.local:67`** (or `http://<SERVER_IP>:67`) | First user becomes Admin |
| **Admin Dashboard** | **`http://localhost:68`** | **`http://ai.local:68`** (or `http://<SERVER_IP>:68`) | Password: **`admin123`** |
| **Ollama AI Engine** | `http://localhost:11434` | Internal Local API | N/A |

---

## 📅 Daily Operations Commands

| Task | Native Script Command |
| :--- | :--- |
| **Start Services** | `bash scripts/start_native.sh` |
| **Stop Services** | `bash scripts/stop_native.sh` |
| **Check Health** | `bash scripts/health_native.sh` |
| **View Live Logs** | `tail -f data/logs/*.log` |

---

## 🔧 Troubleshooting

### "Python3 or venv missing"
If `python3-venv` is not available, ask your office admin or run:
`python3 -m venv --without-pip venv`
Our setup script automatically handles this and installs pip locally.

### "GPU not detected"
Ensure `nvidia-smi` works on the office host machine. The standalone binary in `./bin/lib/ollama` automatically hooks into system CUDA drivers (`libcuda.so`).
