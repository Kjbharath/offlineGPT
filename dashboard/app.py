"""
OfflineGPT Admin Dashboard — Backend API
=========================================
FastAPI application providing system monitoring, user management,
model management, chat analytics, server controls, and config editing.
"""

import os
import json
import time
import subprocess
import sqlite3
import hashlib
import secrets
from pathlib import Path
from datetime import datetime, timedelta
from contextlib import contextmanager

import psutil
import docker
import jwt
from fastapi import FastAPI, Request, HTTPException, Depends, Response
from fastapi.responses import HTMLResponse, StreamingResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
import httpx

# ── Configuration ───────────────────────────────────────────────
DASHBOARD_PASSWORD = os.getenv("DASHBOARD_PASSWORD", "admin123")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://offlinegpt-ollama:11434")
JWT_SECRET = os.getenv("JWT_SECRET", secrets.token_hex(32))
JWT_ALGORITHM = "HS256"
JWT_EXPIRY_HOURS = 24
WEBUI_DB_PATH = "/data/webui.db"
ENV_FILE_PATH = "/config/.env"
CONTAINER_PREFIX = "offlinegpt-"

# ── App Setup ───────────────────────────────────────────────────
app = FastAPI(title="OfflineGPT Admin Dashboard", docs_url=None, redoc_url=None)
templates = Jinja2Templates(directory="/app/templates")

# Docker client (connected via socket)
try:
    docker_client = docker.from_env()
except Exception:
    docker_client = None


# ── Auth Models & Helpers ───────────────────────────────────────
class LoginRequest(BaseModel):
    password: str

class ConfigUpdate(BaseModel):
    config: dict

class RoleUpdate(BaseModel):
    role: str


def create_token():
    """Create a JWT token for authenticated admin."""
    payload = {
        "sub": "admin",
        "exp": datetime.utcnow() + timedelta(hours=JWT_EXPIRY_HOURS),
        "iat": datetime.utcnow(),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def verify_token(request: Request):
    """Dependency: verify JWT from cookie or Authorization header."""
    token = request.cookies.get("dashboard_token")
    if not token:
        auth = request.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            token = auth[7:]
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    try:
        jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    return True


# ── Database Helper ─────────────────────────────────────────────
@contextmanager
def get_webui_db():
    """Context manager for Open WebUI SQLite database (reads WAL log mode)."""
    db_path = WEBUI_DB_PATH
    if not os.path.exists(db_path):
        raise HTTPException(status_code=500, detail=f"WebUI database not found at {db_path}")
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=5)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()



# ── Routes: Auth ────────────────────────────────────────────────
@app.post("/api/auth/login")
async def login(req: LoginRequest):
    if req.password != DASHBOARD_PASSWORD:
        raise HTTPException(status_code=401, detail="Invalid password")
    token = create_token()
    response = JSONResponse({"status": "ok", "token": token})
    response.set_cookie(
        key="dashboard_token",
        value=token,
        httponly=True,
        max_age=JWT_EXPIRY_HOURS * 3600,
        samesite="strict",
    )
    return response


@app.post("/api/auth/logout")
async def logout():
    response = JSONResponse({"status": "ok"})
    response.delete_cookie("dashboard_token")
    return response


@app.get("/api/auth/check")
async def auth_check(authenticated: bool = Depends(verify_token)):
    return {"status": "authenticated"}


# ── Routes: System Status ──────────────────────────────────────
@app.get("/api/system")
async def system_status(authenticated: bool = Depends(verify_token)):
    """Get CPU, RAM, Disk, and GPU stats."""
    # CPU
    cpu_percent = psutil.cpu_percent(interval=0.5)
    cpu_count = psutil.cpu_count()
    cpu_freq = psutil.cpu_freq()

    # Memory
    mem = psutil.virtual_memory()

    # Disk
    disk = psutil.disk_usage("/")

    # GPU (via nvidia-smi)
    gpu_info = []
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,power.limit",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            for line in result.stdout.strip().split("\n"):
                parts = [p.strip() for p in line.split(",")]
                if len(parts) >= 7:
                    gpu_info.append({
                        "name": parts[0],
                        "temperature": float(parts[1]),
                        "utilization": float(parts[2]),
                        "memory_used_mb": float(parts[3]),
                        "memory_total_mb": float(parts[4]),
                        "power_draw_w": float(parts[5]) if parts[5] != "[N/A]" else None,
                        "power_limit_w": float(parts[6]) if parts[6] != "[N/A]" else None,
                    })
    except Exception:
        pass

    # Uptime
    boot_time = datetime.fromtimestamp(psutil.boot_time())
    uptime_seconds = (datetime.now() - boot_time).total_seconds()

    return {
        "cpu": {
            "percent": cpu_percent,
            "count": cpu_count,
            "freq_mhz": cpu_freq.current if cpu_freq else None,
        },
        "memory": {
            "total_gb": round(mem.total / (1024**3), 1),
            "used_gb": round(mem.used / (1024**3), 1),
            "percent": mem.percent,
        },
        "disk": {
            "total_gb": round(disk.total / (1024**3), 1),
            "used_gb": round(disk.used / (1024**3), 1),
            "percent": round(disk.percent, 1),
        },
        "gpu": gpu_info,
        "uptime_seconds": int(uptime_seconds),
    }


# ── Routes: Container Management ──────────────────────────────
@app.get("/api/containers")
async def list_containers(authenticated: bool = Depends(verify_token)):
    """List all OfflineGPT services (Docker or Native processes)."""
    if docker_client:
        try:
            containers = docker_client.containers.list(all=True)
            result = []
            for c in containers:
                name = c.name
                if not (name.startswith(CONTAINER_PREFIX) or name.startswith("ametekgpt")):
                    continue
                result.append({
                    "name": name,
                    "status": c.status,
                    "image": c.image.tags[0] if c.image.tags else str(c.image.id)[:20],
                    "created": c.attrs.get("Created", ""),
                    "ports": _format_ports(c.ports),
                    "health": _get_health(c),
                })
            return result
        except Exception:
            pass

    # Native (No-Docker) Fallback Status Check
    chat_port = os.getenv("PORT", "67")
    dash_port = os.getenv("DASHBOARD_PORT", "68")
    
    native_services = [
        {"name": "offlinegpt-ollama (Native)", "port": "11434", "check_url": "http://127.0.0.1:11434/api/tags"},
        {"name": "offlinegpt-webui (Native)", "port": chat_port, "check_url": f"http://127.0.0.1:{chat_port}"},
        {"name": "offlinegpt-dashboard (Native)", "port": dash_port, "check_url": f"http://127.0.0.1:{dash_port}"},
    ]

    result = []
    async with httpx.AsyncClient(timeout=3) as client:
        for s in native_services:
            status = "stopped"
            try:
                resp = await client.get(s["check_url"])
                if resp.status_code in (200, 401):
                    status = "running"
            except Exception:
                status = "stopped"

            result.append({
                "name": s["name"],
                "status": status,
                "image": "native-binary / venv",
                "created": "System Service",
                "ports": f"0.0.0.0:{s['port']}",
                "health": "healthy" if status == "running" else "unhealthy",
            })
    return result


def _format_ports(ports: dict) -> str:
    """Format Docker port bindings into readable string."""
    parts = []
    for container_port, bindings in (ports or {}).items():
        if bindings:
            for b in bindings:
                parts.append(f"{b.get('HostIp', '0.0.0.0')}:{b['HostPort']}→{container_port}")
        else:
            parts.append(container_port)
    return ", ".join(parts) if parts else "none"


def _get_health(container) -> str:
    """Get container health status."""
    state = container.attrs.get("State", {})
    health = state.get("Health", {})
    return health.get("Status", "N/A")


@app.post("/api/containers/{name}/restart")
async def restart_container(name: str, authenticated: bool = Depends(verify_token)):
    if docker_client:
        try:
            container = docker_client.containers.get(name)
            container.restart(timeout=30)
            return {"status": "ok", "message": f"{name} restarted"}
        except Exception:
            pass

    return {"status": "ok", "message": f"Native service {name} state checked."}



@app.post("/api/containers/{name}/stop")
async def stop_container(name: str, authenticated: bool = Depends(verify_token)):
    if not docker_client:
        raise HTTPException(status_code=500, detail="Docker not available")
    try:
        container = docker_client.containers.get(name)
        container.stop(timeout=30)
        return {"status": "ok", "message": f"{name} stopped"}
    except docker.errors.NotFound:
        raise HTTPException(status_code=404, detail=f"Container {name} not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/containers/{name}/start")
async def start_container(name: str, authenticated: bool = Depends(verify_token)):
    if not docker_client:
        raise HTTPException(status_code=500, detail="Docker not available")
    try:
        container = docker_client.containers.get(name)
        container.start()
        return {"status": "ok", "message": f"{name} started"}
    except docker.errors.NotFound:
        raise HTTPException(status_code=404, detail=f"Container {name} not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/containers/{name}/logs")
async def stream_logs(name: str, lines: int = 100, authenticated: bool = Depends(verify_token)):
    """Stream container logs via SSE."""
    if not docker_client:
        raise HTTPException(status_code=500, detail="Docker not available")
    try:
        container = docker_client.containers.get(name)
    except docker.errors.NotFound:
        raise HTTPException(status_code=404, detail=f"Container {name} not found")

    def log_generator():
        try:
            for line in container.logs(stream=True, follow=True, tail=lines):
                text = line.decode("utf-8", errors="replace").strip()
                if text:
                    yield f"data: {json.dumps({'log': text})}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"

    return StreamingResponse(log_generator(), media_type="text/event-stream")


# ── Routes: User Management & Analytics ─────────────────────────
@app.get("/api/users")
async def list_users(authenticated: bool = Depends(verify_token)):
    """List all Open WebUI users with chat, message, token & context usage stats."""
    try:
        with get_webui_db() as conn:
            cursor = conn.execute(
                "SELECT id, name, email, role, profile_image_url, "
                "created_at, last_active_at, updated_at "
                "FROM user ORDER BY created_at DESC"
            )
            user_rows = cursor.fetchall()

            # Pre-fetch all chats for token & context analysis
            chats_cursor = conn.execute("SELECT id, user_id, chat, created_at, updated_at FROM chat")
            chats_by_user = {}
            total_system_chats = 0
            total_system_messages = 0
            total_system_tokens = 0

            for c_row in chats_cursor.fetchall():
                total_system_chats += 1
                uid = c_row["user_id"]
                if uid not in chats_by_user:
                    chats_by_user[uid] = []
                chats_by_user[uid].append(c_row)

            users = []
            day_ago = (datetime.now() - timedelta(hours=24)).timestamp()
            active_24h_count = 0

            for row in user_rows:
                uid = row["id"]
                user_chats = chats_by_user.get(uid, [])
                chat_count = len(user_chats)
                msg_count = 0
                total_chars = 0
                prompt_chars = 0
                completion_chars = 0

                for c in user_chats:
                    try:
                        c_data = json.loads(c["chat"])
                        messages = []
                        if "messages" in c_data and isinstance(c_data["messages"], list):
                            messages.extend(c_data["messages"])
                        
                        history_msgs = c_data.get("history", {}).get("messages", {})
                        if isinstance(history_msgs, dict):
                            messages.extend(history_msgs.values())
                        elif isinstance(history_msgs, list):
                            messages.extend(history_msgs)

                        msg_count += len(messages)
                        for m in messages:
                            if not isinstance(m, dict):
                                continue
                            content = str(m.get("content", ""))
                            c_len = len(content)
                            total_chars += c_len
                            if m.get("role") == "user":
                                prompt_chars += c_len
                            else:
                                completion_chars += c_len
                    except Exception:
                        pass


                # Token estimates (~3.8 chars per token for typical LLM text)
                estimated_tokens = int(total_chars / 3.8) if total_chars else 0
                prompt_tokens = int(prompt_chars / 3.8) if prompt_chars else 0
                completion_tokens = int(completion_chars / 3.8) if completion_chars else 0
                avg_context_tokens = int(estimated_tokens / chat_count) if chat_count > 0 else 0

                total_system_messages += msg_count
                total_system_tokens += estimated_tokens

                last_active = row["last_active_at"] or row["updated_at"]
                if last_active and last_active >= day_ago:
                    active_24h_count += 1

                users.append({
                    "id": uid,
                    "name": row["name"],
                    "email": row["email"],
                    "role": row["role"],
                    "avatar": row["profile_image_url"],
                    "created_at": row["created_at"],
                    "last_active": last_active,
                    "chats_count": chat_count,
                    "messages_count": msg_count,
                    "estimated_tokens": estimated_tokens,
                    "prompt_tokens": prompt_tokens,
                    "completion_tokens": completion_tokens,
                    "avg_context_tokens": avg_context_tokens,
                    "tokens_k": format_k(estimated_tokens),
                    "prompt_tokens_k": format_k(prompt_tokens),
                    "completion_tokens_k": format_k(completion_tokens),
                    "avg_context_k": format_k(avg_context_tokens),
                })

            return {
                "summary": {
                    "total_users": len(user_rows),
                    "total_chats": total_system_chats,
                    "total_messages": total_system_messages,
                    "total_tokens": total_system_tokens,
                    "total_tokens_k": format_k(total_system_tokens),
                    "active_users_24h": active_24h_count,
                },
                "users": users,
            }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


def format_k(n: int) -> str:
    """Format integers into human readable k/M token string (e.g. 1.8k, 2.5M)."""
    if not n:
        return "0"
    if n >= 1_000_000:
        return f"{round(n / 1_000_000, 1)}M"
    if n >= 1_000:
        return f"{round(n / 1_000, 1)}k"
    return str(n)


@app.get("/api/users/{user_id}/chats")
async def get_user_chats(user_id: str, authenticated: bool = Depends(verify_token)):
    """Get all past conversations and context window usage for a specific user."""
    try:
        with get_webui_db() as conn:
            user_row = conn.execute("SELECT id, name, email, role, created_at, last_active_at, updated_at FROM user WHERE id = ?", (user_id,)).fetchone()
            if not user_row:
                raise HTTPException(status_code=404, detail="User not found")

            cursor = conn.execute("SELECT id, title, chat, created_at, updated_at FROM chat WHERE user_id = ? ORDER BY updated_at DESC", (user_id,))
            chat_rows = cursor.fetchall()

            chats = []
            user_total_tokens = 0
            user_total_msgs = 0
            max_context_limit = int(os.getenv("CONTEXT_SIZE", "8192"))

            for c in chat_rows:
                c_data = {}
                try:
                    c_data = json.loads(c["chat"])
                except Exception:
                    pass

                messages = []
                if "messages" in c_data and isinstance(c_data["messages"], list):
                    messages.extend(c_data["messages"])
                h_msgs = c_data.get("history", {}).get("messages", {})
                if isinstance(h_msgs, dict):
                    messages.extend(h_msgs.values())
                elif isinstance(h_msgs, list):
                    messages.extend(h_msgs)

                msg_count = len(messages)
                user_total_msgs += msg_count
                total_chars = 0
                prompt_chars = 0
                completion_chars = 0
                first_user_prompt = ""
                user_prompts = []

                for m in messages:
                    if not isinstance(m, dict):
                        continue
                    content = str(m.get("content", ""))
                    c_len = len(content)
                    total_chars += c_len
                    if m.get("role") == "user":
                        prompt_chars += c_len
                        if content and not first_user_prompt:
                            first_user_prompt = content
                        if content:
                            user_prompts.append(content)
                    else:
                        completion_chars += c_len

                chat_tokens = int(total_chars / 3.8) if total_chars else 0
                p_tokens = int(prompt_chars / 3.8) if prompt_chars else 0
                c_tokens = int(completion_chars / 3.8) if completion_chars else 0
                user_total_tokens += chat_tokens

                # Percentage of max context window (e.g. 8192) used in this conversation
                context_pct = min(100, round((chat_tokens / max_context_limit) * 100, 1))

                raw_title = c_data.get("title") or c["title"] or ""
                if not raw_title or raw_title.lower() in ("new chat", "untitled chat", "untitled"):
                    title = first_user_prompt[:70] + ("..." if len(first_user_prompt) > 70 else "") if first_user_prompt else "Untitled Chat"
                else:
                    title = raw_title

                full_messages = []
                for m in messages:
                    if isinstance(m, dict):
                        full_messages.append({
                            "role": m.get("role", "user"),
                            "content": str(m.get("content", "")),
                            "timestamp": m.get("timestamp") or m.get("created_at"),
                        })

                chats.append({
                    "id": c["id"],
                    "title": title,
                    "first_prompt": first_user_prompt[:120] if first_user_prompt else "",
                    "user_prompts": [p[:100] for p in user_prompts[:5]],
                    "full_messages": full_messages,
                    "created_at": c["created_at"],
                    "updated_at": c["updated_at"],
                    "messages_count": msg_count,
                    "total_tokens": chat_tokens,
                    "total_tokens_k": format_k(chat_tokens),
                    "prompt_tokens": p_tokens,
                    "prompt_tokens_k": format_k(p_tokens),
                    "completion_tokens": c_tokens,
                    "completion_tokens_k": format_k(c_tokens),
                    "context_percent": context_pct,
                    "context_limit": max_context_limit,
                })



            return {
                "user": {
                    "id": user_row["id"],
                    "name": user_row["name"],
                    "email": user_row["email"],
                    "role": user_row["role"],
                    "chats_count": len(chats),
                    "messages_count": user_total_msgs,
                    "total_tokens": user_total_tokens,
                    "total_tokens_k": format_k(user_total_tokens),
                },
                "chats": chats,
            }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"User chats error: {str(e)}")




@app.post("/api/users/{user_id}/role")
async def update_user_role(user_id: str, req: RoleUpdate, authenticated: bool = Depends(verify_token)):
    """Change a user's role (admin/user/pending)."""
    if req.role not in ("admin", "user", "pending"):
        raise HTTPException(status_code=400, detail="Role must be 'admin', 'user', or 'pending'")
    try:
        with get_webui_db() as conn:
            conn.execute("UPDATE user SET role = ? WHERE id = ?", (req.role, user_id))
            conn.commit()
            return {"status": "ok", "message": f"User role updated to {req.role}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/api/users/{user_id}")
async def delete_user(user_id: str, authenticated: bool = Depends(verify_token)):
    """Delete a user from Open WebUI."""
    try:
        with get_webui_db() as conn:
            # Check user exists
            user = conn.execute("SELECT role FROM user WHERE id = ?", (user_id,)).fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="User not found")
            if user["role"] == "admin":
                # Don't allow deleting the last admin
                admin_count = conn.execute("SELECT COUNT(*) as c FROM user WHERE role='admin'").fetchone()["c"]
                if admin_count <= 1:
                    raise HTTPException(status_code=400, detail="Cannot delete the last admin user")
            conn.execute("DELETE FROM user WHERE id = ?", (user_id,))
            conn.commit()
            return {"status": "ok", "message": "User deleted"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Routes: Model Management ──────────────────────────────────
@app.get("/api/models")
async def list_models(authenticated: bool = Depends(verify_token)):
    """List models available in Ollama."""
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(f"{OLLAMA_URL}/api/tags")
            data = resp.json()
            models = []
            for m in data.get("models", []):
                details = m.get("details", {})
                models.append({
                    "name": m["name"],
                    "size_gb": round(m.get("size", 0) / (1024**3), 2),
                    "format": details.get("format", ""),
                    "family": details.get("family", ""),
                    "parameter_size": details.get("parameter_size", ""),
                    "quantization": details.get("quantization_level", ""),
                    "modified_at": m.get("modified_at", ""),
                })
            return models
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ollama API error: {str(e)}")


@app.get("/api/models/running")
async def running_models(authenticated: bool = Depends(verify_token)):
    """Get currently loaded/running models from Ollama."""
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(f"{OLLAMA_URL}/api/ps")
            data = resp.json()
            models = []
            for m in data.get("models", []):
                details = m.get("details", {})
                models.append({
                    "name": m.get("name", ""),
                    "size_gb": round(m.get("size", 0) / (1024**3), 2),
                    "size_vram_gb": round(m.get("size_vram", 0) / (1024**3), 2),
                    "parameter_size": details.get("parameter_size", ""),
                    "quantization": details.get("quantization_level", ""),
                    "expires_at": m.get("expires_at", ""),
                })
            return models
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ollama API error: {str(e)}")


# ── Routes: Chat Analytics ─────────────────────────────────────
@app.get("/api/analytics")
async def chat_analytics(authenticated: bool = Depends(verify_token)):
    """Get chat analytics: totals, active users, token speeds."""
    try:
        with get_webui_db() as conn:
            # Total chats
            total_chats = conn.execute("SELECT COUNT(*) as c FROM chat").fetchone()["c"]

            # Today's chats
            today_start = datetime.now().replace(hour=0, minute=0, second=0).timestamp()
            today_chats = conn.execute(
                "SELECT COUNT(*) as c FROM chat WHERE created_at >= ?",
                (int(today_start),)
            ).fetchone()["c"]

            # This week's chats
            week_start = (datetime.now() - timedelta(days=7)).timestamp()
            week_chats = conn.execute(
                "SELECT COUNT(*) as c FROM chat WHERE created_at >= ?",
                (int(week_start),)
            ).fetchone()["c"]

            # Total unique users who have chatted
            total_users = conn.execute("SELECT COUNT(*) as c FROM user").fetchone()["c"]

            # Active users (chatted in last 24h)
            day_ago = (datetime.now() - timedelta(hours=24)).timestamp()
            active_users = conn.execute(
                "SELECT COUNT(DISTINCT user_id) as c FROM chat WHERE updated_at >= ?",
                (int(day_ago),)
            ).fetchone()["c"]

            # Chat activity per day (last 7 days)
            daily_activity = []
            for i in range(7):
                day = datetime.now() - timedelta(days=6 - i)
                day_start = day.replace(hour=0, minute=0, second=0).timestamp()
                day_end = day.replace(hour=23, minute=59, second=59).timestamp()
                count = conn.execute(
                    "SELECT COUNT(*) as c FROM chat WHERE created_at >= ? AND created_at <= ?",
                    (int(day_start), int(day_end))
                ).fetchone()["c"]
                daily_activity.append({
                    "date": day.strftime("%a %d"),
                    "count": count,
                })

            # Per-user chat stats
            user_stats = []
            rows = conn.execute(
                "SELECT u.name, u.email, COUNT(c.id) as chat_count, "
                "MAX(c.updated_at) as last_chat "
                "FROM user u LEFT JOIN chat c ON u.id = c.user_id "
                "GROUP BY u.id ORDER BY chat_count DESC"
            ).fetchall()
            for row in rows:
                user_stats.append({
                    "name": row["name"],
                    "email": row["email"],
                    "chat_count": row["chat_count"],
                    "last_chat": row["last_chat"],
                })

            return {
                "total_chats": total_chats,
                "today_chats": today_chats,
                "week_chats": week_chats,
                "total_users": total_users,
                "active_users_24h": active_users,
                "daily_activity": daily_activity,
                "user_stats": user_stats,
            }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analytics error: {str(e)}")


# ── Routes: Token Speed (from Ollama) ──────────────────────────
@app.get("/api/token-speed")
async def token_speed(authenticated: bool = Depends(verify_token)):
    """Test token generation speed by sending a small prompt to Ollama."""
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            start = time.time()
            resp = await client.post(
                f"{OLLAMA_URL}/api/generate",
                json={
                    "model": "qwen2.5-7b:latest",
                    "prompt": "Say hello in one word.",
                    "stream": False,
                    "options": {"num_predict": 20},
                },
            )
            elapsed = time.time() - start
            data = resp.json()
            eval_count = data.get("eval_count", 0)
            eval_duration = data.get("eval_duration", 1)  # nanoseconds
            prompt_eval_count = data.get("prompt_eval_count", 0)
            prompt_eval_duration = data.get("prompt_eval_duration", 1)

            tokens_per_sec = (eval_count / (eval_duration / 1e9)) if eval_duration else 0
            prompt_tokens_per_sec = (prompt_eval_count / (prompt_eval_duration / 1e9)) if prompt_eval_duration else 0

            return {
                "tokens_generated": eval_count,
                "generation_speed": round(tokens_per_sec, 1),
                "prompt_tokens": prompt_eval_count,
                "prompt_speed": round(prompt_tokens_per_sec, 1),
                "total_time_ms": round(elapsed * 1000),
                "model": data.get("model", "unknown"),
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Token speed test error: {str(e)}")


# ── Routes: Configuration ─────────────────────────────────────
@app.get("/api/config")
async def get_config(authenticated: bool = Depends(verify_token)):
    """Read current .env configuration."""
    config = {}
    try:
        if os.path.exists(ENV_FILE_PATH):
            with open(ENV_FILE_PATH, "r") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        key, _, value = line.partition("=")
                        config[key.strip()] = value.strip()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Config read error: {str(e)}")
    return config


@app.post("/api/config")
async def update_config(req: ConfigUpdate, authenticated: bool = Depends(verify_token)):
    """Update .env configuration file."""
    try:
        # Read existing file to preserve comments and ordering
        lines = []
        existing_keys = set()
        if os.path.exists(ENV_FILE_PATH):
            with open(ENV_FILE_PATH, "r") as f:
                for line in f:
                    stripped = line.strip()
                    if stripped and not stripped.startswith("#") and "=" in stripped:
                        key = stripped.split("=", 1)[0].strip()
                        if key in req.config:
                            lines.append(f"{key}={req.config[key]}\n")
                            existing_keys.add(key)
                        else:
                            lines.append(line)
                    else:
                        lines.append(line)

        # Add any new keys
        for key, value in req.config.items():
            if key not in existing_keys:
                lines.append(f"{key}={value}\n")

        with open(ENV_FILE_PATH, "w") as f:
            f.writelines(lines)

        return {"status": "ok", "message": "Configuration saved"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Config write error: {str(e)}")


# ── Routes: Frontend ──────────────────────────────────────────
@app.get("/", response_class=HTMLResponse)
async def dashboard_page(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})


# ── Main ──────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
