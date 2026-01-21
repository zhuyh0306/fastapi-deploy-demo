# FastAPI 部署示例

本目录包含FastAPI应用的多种部署方式示例，包括：
1. 直接使用Uvicorn部署
2. 使用Docker容器化部署
3. 使用Docker Compose部署
4. 使用systemd管理服务
5. 使用Nginx反向代理
6. 生产环境配置示例
7. CI/CD示例
8. 自动化部署脚本

## 0. 自动化部署脚本（推荐）

本目录提供了一个功能强大的自动化部署脚本 `deploy.sh`，可以简化FastAPI应用的部署流程。该脚本支持多种部署模式，并提供了完整的部署生命周期管理。

### 脚本功能

- 支持三种部署模式：uvicorn、docker、docker-compose
- 一键安装依赖
- 启动、停止、重启服务
- 查看服务状态
- 健康检查
- 资源清理

### 脚本使用

```bash
# 查看帮助信息
./deploy.sh --help

# 基本使用（默认uvicorn模式）
./deploy.sh

# 使用Docker模式部署，端口8001
./deploy.sh -m docker -p 8001

# 使用Docker Compose模式部署
./deploy.sh --mode docker-compose

# 只安装依赖（仅uvicorn模式支持）
./deploy.sh --install

# 只启动服务
./deploy.sh --start

# 只停止服务
./deploy.sh --stop

# 重启服务
./deploy.sh --restart

# 查看服务状态
./deploy.sh --status

# 清理资源
./deploy.sh --clean
```

### 脚本参数

| 参数 | 描述 | 默认值 |
|------|------|--------|
| -m, --mode | 部署模式（uvicorn/docker/docker-compose） | uvicorn |
| -e, --env-file | 环境变量文件 | .env |
| -r, --requirements | 依赖文件 | requirements.txt |
| -d, --app-dir | 应用目录 | . |
| -p, --port | 端口号 | 8000 |
| -H, --host | 主机地址 | 0.0.0.0 |
| -w, --workers | 工作进程数 | 4 |
| --install | 只安装依赖 | - |
| --start | 只启动服务 | - |
| --stop | 只停止服务 | - |
| --restart | 重启服务 | - |
| --status | 查看服务状态 | - |
| --clean | 清理资源 | - |

### 脚本示例

```bash
# 使用uvicorn模式，端口8002，工作进程数2
./deploy.sh -m uvicorn -p 8002 -w 2

# 使用docker模式，指定环境变量文件
./deploy.sh -m docker -e .env.production

# 使用docker-compose模式，重启服务
./deploy.sh --mode docker-compose --restart
```

### 脚本特点

1. **多模式支持**：可以根据不同环境选择合适的部署模式
2. **完整生命周期管理**：从安装依赖到启动服务，再到停止和清理
3. **健康检查**：自动检查服务是否正常运行
4. **环境变量支持**：可以通过.env文件配置应用
5. **灵活配置**：支持自定义端口、工作进程数等参数
6. **易于扩展**：可以根据需要添加新的部署模式或功能

使用自动化部署脚本可以大大简化FastAPI应用的部署流程，减少手动操作错误，提高部署效率。

## 1. 直接使用Uvicorn部署

### 安装依赖
```bash
# 安装生产依赖
pip install -r requirements.txt

# 或使用虚拟环境
python -m venv venv
source venv/bin/activate  # Linux/macOS
venv\Scripts\activate     # Windows
pip install -r requirements.txt
```

### 运行开发服务器
```bash
uvicorn main:app --reload
```

### 运行生产服务器
```bash
# 基本生产配置
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4

# 带访问日志的生产配置
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4 --access-log

# 带Gzip压缩的生产配置
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4 --access-log --gzip
```

### 选择合适的工作进程数量
```bash
# 建议工作进程数量 = CPU核心数 × 2 + 1
# 可以使用以下命令查看CPU核心数
nproc --all # Linux
sysctl -n hw.ncpu # macOS
wmic cpu get NumberOfCores # Windows
```

## 2. 使用Docker容器化部署

### Dockerfile优化
使用多阶段构建减小镜像大小：

```dockerfile
# 第一阶段：构建依赖
FROM python:3.10-slim as builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libc-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip wheel --no-cache-dir -r requirements.txt --wheel-dir /app/wheels

# 第二阶段：运行时
FROM python:3.10-slim

WORKDIR /app

# 复制构建好的依赖
COPY --from=builder /app/wheels /wheels
RUN pip install --no-cache /wheels/*

# 复制应用代码
COPY . .

# 设置环境变量
ENV PYTHONUNBUFFERED=1 \
    APP_NAME="FastAPI Deployment Demo" \
    DEBUG="False" \
    HOST="0.0.0.0" \
    PORT="8000"

# 暴露端口
EXPOSE 8000

# 运行应用
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 构建Docker镜像
```bash
docker build -t fastapi-deployment .

# 带标签的构建
 docker build -t fastapi-deployment:v1.0.0 .
```

### 运行Docker容器
```bash
# 基本运行
 docker run -d -p 8000:8000 fastapi-deployment

# 带环境变量的运行
 docker run -d -p 8000:8000 \
    -e DEBUG=False \
    -e DATABASE_URL=sqlite:///./app.db \
    fastapi-deployment

# 带数据持久化的运行
 docker run -d -p 8000:8000 \
    -v ./app.db:/app/app.db \
    fastapi-deployment

# 带日志挂载的运行
 docker run -d -p 8000:8000 \
    -v ./logs:/app/logs \
    fastapi-deployment
```

### Docker安全最佳实践
```bash
# 以非root用户运行容器
 docker run -d -p 8000:8000 \
    --user 1000:1000 \
    fastapi-deployment

# 限制容器资源
 docker run -d -p 8000:8000 \
    --memory 512m \
    --cpus 2 \
    fastapi-deployment
```

## 3. 使用Docker Compose部署

### 基本Docker Compose配置
```yaml
version: '3.8'

services:
  fastapi-app:
    build: .
    container_name: fastapi-deployment
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - APP_NAME=FastAPI Docker Compose Demo
      - DEBUG=False
      - DATABASE_URL=sqlite:///./app.db
    volumes:
      - app-data:/app
    networks:
      - app-network
    command: uvicorn main:app --host 0.0.0.0 --port 8000

volumes:
  app-data:

networks:
  app-network:
    driver: bridge
```

### 带PostgreSQL和Redis的Docker Compose配置
```yaml
version: '3.8'

services:
  fastapi-app:
    build: .
    container_name: fastapi-deployment
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - APP_NAME=FastAPI Docker Compose Demo
      - DEBUG=False
      - DATABASE_URL=postgresql://fastapi_user:fastapi_password@db/fastapi_db
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    volumes:
      - app-data:/app
    networks:
      - app-network
    command: uvicorn main:app --host 0.0.0.0 --port 8000

  # PostgreSQL数据库
  db:
    image: postgres:15-alpine
    container_name: fastapi-db
    restart: unless-stopped
    environment:
      - POSTGRES_DB=fastapi_db
      - POSTGRES_USER=fastapi_user
      - POSTGRES_PASSWORD=fastapi_password
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql  # 初始化脚本
    networks:
      - app-network

  # Redis缓存
  redis:
    image: redis:7-alpine
    container_name: fastapi-redis
    restart: unless-stopped
    volumes:
      - redis-data:/data
    networks:
      - app-network
    command: redis-server --appendonly yes  # 启用AOF持久化

volumes:
  app-data:
  postgres-data:
  redis-data:

networks:
  app-network:
    driver: bridge
```

### Docker Compose命令
```bash
# 启动服务
 docker-compose up -d

# 查看服务状态
 docker-compose ps

# 查看日志
 docker-compose logs -f
 docker-compose logs -f fastapi-app  # 只查看fastapi-app服务的日志

# 停止服务
 docker-compose down

# 停止并删除所有数据卷
 docker-compose down -v

# 重新构建并启动服务
 docker-compose up -d --build
```

## 4. 使用systemd管理服务

### 创建systemd服务文件
创建`/etc/systemd/system/fastapi.service`文件：
```ini
[Unit]
Description=FastAPI Application
After=network.target

[Service]
User=ubuntu  # 运行服务的用户
Group=ubuntu  # 运行服务的组
WorkingDirectory=/path/to/your/app  # 应用目录
ExecStart=/path/to/your/app/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4 --access-log
Restart=always  # 总是重启服务
RestartSec=3  # 重启间隔3秒

# 环境变量
Environment="PYTHONUNBUFFERED=1"
Environment="DEBUG=False"
Environment="DATABASE_URL=sqlite:///./app.db"

# 日志配置
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=fastapi

[Install]
WantedBy=multi-user.target
```

### systemd命令
```bash
# 重新加载systemd配置
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start fastapi

# 查看服务状态
sudo systemctl status fastapi

# 查看服务日志
sudo journalctl -u fastapi -f

# 启用服务开机自启
sudo systemctl enable fastapi

# 禁用服务开机自启
sudo systemctl disable fastapi

# 重启服务
sudo systemctl restart fastapi

# 停止服务
sudo systemctl stop fastapi
```

## 5. 使用Nginx反向代理

### 安装Nginx
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nginx

# CentOS/RHEL
sudo yum install epel-release
sudo yum install nginx
```

### 基本Nginx配置
创建`/etc/nginx/conf.d/fastapi.conf`文件：
```nginx
server {
    listen 80;
    server_name example.com www.example.com;  # 你的域名

    # 访问日志配置
    access_log /var/log/nginx/fastapi_access.log;
    error_log /var/log/nginx/fastapi_error.log error;

    # 反向代理配置
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # 静态文件配置（如果需要）
    location /static/ {
        alias /path/to/your/app/static/;
        expires 30d;
    }
}
```

### 带SSL的Nginx配置
```nginx
server {
    listen 80;
    server_name example.com www.example.com;
    return 301 https://$host$request_uri;  # 重定向HTTP到HTTPS
}

server {
    listen 443 ssl http2;
    server_name example.com www.example.com;

    # SSL证书配置
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;

    # SSL优化配置
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;  # 10分钟共享会话缓存
    ssl_session_tickets off;

    # TLS配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # HSTS配置
    add_header Strict-Transport-Security "max-age=63072000" always;

    # 访问日志配置
    access_log /var/log/nginx/fastapi_access.log;
    error_log /var/log/nginx/fastapi_error.log error;

    # 反向代理配置
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### Nginx命令
```bash
# 测试Nginx配置
sudo nginx -t

# 重新加载Nginx配置
sudo nginx -s reload

# 启动Nginx
sudo systemctl start nginx

# 查看Nginx状态
sudo systemctl status nginx

# 启用Nginx开机自启
sudo systemctl enable nginx
```

## 5. 生产环境配置

### 环境变量配置
创建`.env`文件：
```env
# 应用配置
APP_NAME=FastAPI Deployment Demo
DEBUG=False
HOST=0.0.0.0
PORT=8000

# 数据库配置
DATABASE_URL=sqlite:///./app.db
# DATABASE_URL=postgresql://user:password@localhost/dbname
# DATABASE_URL=mysql+pymysql://user:password@localhost/dbname

# 安全配置
SECRET_KEY=your-secret-key-here  # 生成方法：openssl rand -hex 32
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Redis配置（如果使用）
REDIS_URL=redis://localhost:6379/0

# CORS配置
ALLOWED_ORIGINS=https://example.com,https://www.example.com

# 日志配置
LOG_LEVEL=info
LOG_FILE=app.log
```

在应用中加载环境变量：
```python
from dotenv import load_dotenv
load_dotenv()
```

### Gunicorn配置
创建`gunicorn.conf.py`文件：
```python
# Gunicorn配置文件

# 绑定的主机和端口
bind = "0.0.0.0:8000"

# 工作进程数量
workers = 4

# 工作进程类型
worker_class = "uvicorn.workers.UvicornWorker"

# 每个工作进程的最大请求数
max_requests = 1000

# 最大请求数的抖动范围
max_requests_jitter = 100

# 工作进程启动超时时间（秒）
timeout = 30

# 工作进程关闭超时时间（秒）
graceful_timeout = 15

# 连接超时时间（秒）
keepalive = 5

# 日志配置
loglevel = "info"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"'
accesslog = "/path/to/your/app/logs/gunicorn_access.log"
errorlog = "/path/to/your/app/logs/gunicorn_error.log"

# PID文件路径
pidfile = "/path/to/your/app/gunicorn.pid"

# 预加载应用
preload_app = True

# 环境变量
raw_env = [
    "PYTHONUNBUFFERED=1",
    "APP_NAME=FastAPI Gunicorn Demo",
    "DEBUG=False"
]
```

使用Gunicorn运行应用：
```bash
gunicorn -c gunicorn.conf.py main:app
```

## 6. CI/CD示例

### GitHub Actions配置
创建`.github/workflows/deploy.yml`文件：
```yaml
name: Deploy FastAPI App

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v3
      with:
        python-version: '3.10'
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
        pip install pytest pytest-cov
    
    - name: Run tests
      run: |
        python -m pytest tests/ --cov=. --cov-report=xml
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.xml

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v3
      with:
        python-version: '3.10'
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
    
    - name: Build Docker image
      run: |
        docker build -t my-fastapi-app:${{ github.sha }} .
    
    - name: Deploy to server
      uses: appleboy/ssh-action@master
      with:
        host: ${{ secrets.SERVER_HOST }}
        username: ${{ secrets.SERVER_USER }}
        key: ${{ secrets.SERVER_KEY }}
        script: |
          # 登录Docker Registry（如果需要）
          # docker login -u ${{ secrets.DOCKER_USER }} -p ${{ secrets.DOCKER_PASS }}
          
          # 拉取最新镜像
          docker pull my-fastapi-app:${{ github.sha }}
          
          # 停止并删除旧容器
          docker stop fastapi-app || true
          docker rm fastapi-app || true
          
          # 运行新容器
          docker run -d --name fastapi-app -p 8000:8000 my-fastapi-app:${{ github.sha }}
          
          # 清理旧镜像
          docker system prune -f
```

### GitLab CI/CD配置
创建`.gitlab-ci.yml`文件：
```yaml
stages:
  - test
  - build
  - deploy

variables:
  DOCKER_IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

# 测试阶段
test:
  stage: test
  image: python:3.10-slim
  script:
    - pip install -r requirements.txt
    - pip install pytest pytest-cov
    - python -m pytest tests/ --cov=. --cov-report=xml
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml

# 构建阶段
build:
  stage: build
  image: docker:20.10.16
  services:
    - docker:20.10.16-dind
  script:
    - docker build -t $DOCKER_IMAGE .
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker push $DOCKER_IMAGE
  only:
    - main

# 部署阶段
deploy:
  stage: deploy
  image: alpine:latest
  script:
    - apk add --no-cache openssh-client
    - eval $(ssh-agent -s)
    - echo "$SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - mkdir -p ~/.ssh
    - chmod 700 ~/.ssh
    - echo "$SSH_KNOWN_HOSTS" > ~/.ssh/known_hosts
    - chmod 644 ~/.ssh/known_hosts
    - ssh $SSH_USER@$SSH_HOST "
        docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY && 
        docker pull $DOCKER_IMAGE && 
        docker stop fastapi-app || true && 
        docker rm fastapi-app || true && 
        docker run -d --name fastapi-app -p 8000:8000 $DOCKER_IMAGE && 
        docker system prune -f
      "
  only:
    - main
```

## 7. 监控和日志

### 启用访问日志
```bash
# Uvicorn访问日志
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4 --access-log

# Gunicorn访问日志（在gunicorn.conf.py中配置）
accesslog = "/path/to/your/app/logs/gunicorn_access.log"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"'
```

### 结构化日志配置
使用Python的logging模块配置结构化日志：
```python
import logging
import json
from logging.handlers import RotatingFileHandler

# 创建日志记录器
logger = logging.getLogger("fastapi-app")
logger.setLevel(logging.INFO)

# 创建旋转文件处理器
file_handler = RotatingFileHandler(
    "app.log",
    maxBytes=10*1024*1024,  # 10MB
    backupCount=5  # 保留5个备份文件
)

# 创建结构化日志格式化器
class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "name": record.name,
            "message": record.getMessage(),
            "filename": record.filename,
            "lineno": record.lineno,
            "funcName": record.funcName
        }
        return json.dumps(log_record)

file_handler.setFormatter(JSONFormatter())
logger.addHandler(file_handler)
```

### 使用Prometheus监控
安装依赖：
```bash
pip install prometheus-fastapi-instrumentator
```

在应用中添加监控：
```python
from prometheus_fastapi_instrumentator import Instrumentator

# 创建监控实例
instrumentator = Instrumentator(
    should_group_status_codes=True,
    should_ignore_untemplated=True,
    should_respect_env_var=True,
    should_instrument_requests_inprogress=True,
    excluded_handlers=["/metrics", "/health", "/ready"],
    env_var_name="ENABLE_METRICS",
    inprogress_labels=True
)

# 初始化应用后添加监控
@app.on_event("startup")
async def startup():
    instrumentator.instrument(app).expose(app, include_in_schema=False, endpoint="/metrics")
```

访问`/metrics`端点查看监控指标，或使用Prometheus + Grafana进行可视化监控。

### 使用ELK Stack或Loki进行日志聚合

#### ELK Stack（Elasticsearch + Logstash + Kibana）
1. 安装ELK Stack
2. 配置Filebeat收集FastAPI日志
3. 在Kibana中创建仪表盘

#### Loki + Promtail + Grafana
1. 安装Loki、Promtail和Grafana
2. 配置Promtail收集FastAPI日志
3. 在Grafana中创建仪表盘

## 8. 安全配置

### HTTPS配置

#### 使用Let's Encrypt获取SSL证书
```bash
# 安装Certbot
sudo apt install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d example.com -d www.example.com

# 自动续订证书测试
sudo certbot renew --dry-run

# 设置自动续订定时器
sudo systemctl enable certbot.timer
```

#### 配置Uvicorn使用HTTPS
```bash
uvicorn main:app --host 0.0.0.0 --port 443 \
  --ssl-keyfile=/etc/letsencrypt/live/example.com/privkey.pem \
  --ssl-certfile=/etc/letsencrypt/live/example.com/fullchain.pem
```

#### 配置Gunicorn使用HTTPS
修改`gunicorn.conf.py`：
```python
# SSL配置
keyfile = "/etc/letsencrypt/live/example.com/privkey.pem"
certfile = "/etc/letsencrypt/live/example.com/fullchain.pem"
```

### CORS配置
在应用中配置CORS：
```python
from fastapi.middleware.cors import CORSMiddleware

# 从环境变量加载允许的来源
allowed_origins = os.getenv("ALLOWED_ORIGINS", "*").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Custom-Header"],
    max_age=600,
)
```

### 安全HTTP头
使用`fastapi-security-headers`包添加安全HTTP头：
```bash
pip install fastapi-security-headers
```

```python
from fastapi_security_headers import SecurityHeadersMiddleware

app.add_middleware(
    SecurityHeadersMiddleware,
    referrer_policy="strict-origin-when-cross-origin",
    x_content_type_options="nosniff",
    x_frame_options="DENY",
    x_xss_protection="1; mode=block",
    content_security_policy="default-src 'self'",
    strict_transport_security="max-age=31536000; includeSubDomains",
)
```

### 其他安全最佳实践
1. 使用`passlib`进行密码哈希
2. 实现速率限制（使用`slowapi`包）
3. 定期更新依赖（使用`pip-audit`或`safety`进行安全审计）
4. 实现API密钥或OAuth2认证
5. 定期备份数据库
6. 使用WAF（Web应用防火墙）保护应用

## 9. 性能优化

### 应用级优化

#### 使用异步数据库
```bash
pip install sqlalchemy[asyncio] aiosqlite
# 或使用PostgreSQL异步驱动
pip install sqlalchemy[asyncio] asyncpg
```

#### 启用Gzip压缩
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4 --gzip
```

#### 使用Redis缓存
安装依赖：
```bash
pip install fastapi-cache2[redis]
```

在应用中使用缓存：
```python
from fastapi_cache import FastAPICache
from fastapi_cache.backends.redis import RedisBackend
from fastapi_cache.decorator import cache
from redis import asyncio as aioredis

# 初始化Redis缓存
@app.on_event("startup")
async def startup():
    redis = aioredis.from_url("redis://localhost:6379/0")
    FastAPICache.init(RedisBackend(redis), prefix="fastapi-cache:")

# 使用缓存装饰器
@app.get("/cached-endpoint")
@cache(expire=60)  # 缓存60秒
async def cached_endpoint():
    # 耗时操作
    await asyncio.sleep(1)
    return {"message": "This response is cached"}
```

#### 优化数据库查询
1. 使用索引
2. 避免N+1查询问题
3. 使用分页
4. 使用异步数据库操作

### 部署级优化

#### 使用CDN加速静态资源
1. 使用Cloudflare、AWS CloudFront等CDN服务
2. 配置Nginx缓存静态资源

#### 垂直扩展
1. 增加服务器CPU和内存
2. 优化数据库配置

#### 水平扩展
1. 使用负载均衡器（如Nginx、HAProxy）
2. 实现无状态设计
3. 使用分布式缓存（如Redis Cluster）
4. 使用分布式数据库

## 10. 健康检查

### 实现健康检查端点
```python
@app.get("/health", status_code=200)
def health_check():
    """基本健康检查：检查应用是否运行"""
    return {
        "status": "healthy",
        "service": app.title,
        "version": app.version
    }

@app.get("/ready", status_code=200)
def ready_check():
    """就绪检查：检查应用及其依赖是否正常"""
    try:
        # 检查数据库连接
        # db.execute("SELECT 1")
        
        # 检查Redis连接（如果使用）
        # redis.ping()
        
        return {
            "status": "ready",
            "service": app.title,
            "dependencies": {
                "database": "connected",
                "redis": "connected"
            }
        }
    except Exception as e:
        raise HTTPException(
            status_code=503,
            detail=f"服务不可用: {str(e)}"
        )
```

### 配置负载均衡器健康检查
在Nginx中配置健康检查：
```nginx
upstream fastapi_backend {
    server 127.0.0.1:8000 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:8001 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:8002 max_fails=3 fail_timeout=30s;
}

server {
    # ... 其他配置 ...
    
    location / {
        proxy_pass http://fastapi_backend;
        # ... 其他代理配置 ...
    }
    
    # 健康检查端点
    location /health {
        proxy_pass http://fastapi_backend;
        proxy_connect_timeout 2s;
        proxy_read_timeout 2s;
        proxy_send_timeout 2s;
    }
}
```

## 11. 常见部署问题排查

### 端口被占用
```bash
# 查看端口占用情况
lsof -i :8000  # Linux/macOS
netstat -ano | findstr :8000  # Windows

# 终止占用端口的进程
kill -9 <PID>  # Linux/macOS
taskkill /F /PID <PID>  # Windows
```

### 服务无法启动
```bash
# 查看服务日志
sudo journalctl -u fastapi -f  # systemd服务日志
 docker logs -f fastapi-app  # Docker容器日志

# 检查应用配置
python -m pytest  # 运行测试
```

### 性能问题
```bash
# 使用cProfile进行性能分析
python -m cProfile -o profile.stats main.py

# 使用snakeviz可视化性能分析结果
pip install snakeviz
snakeviz profile.stats

# 使用Py-Spy进行实时性能分析
pip install py-spy
py-spy top --pid <PID>
```

### 数据库连接问题
1. 检查数据库服务是否运行
2. 检查数据库连接字符串
3. 检查数据库用户权限
4. 检查防火墙设置

## 12. 部署清单

在部署前，确保完成以下检查：

### 应用配置
- [ ] DEBUG模式已关闭
- [ ] 已设置安全的SECRET_KEY
- [ ] 已配置正确的数据库连接
- [ ] 已配置CORS（如果需要）
- [ ] 已配置正确的环境变量

### 安全配置
- [ ] 已启用HTTPS
- [ ] 已配置安全HTTP头
- [ ] 已实现适当的认证和授权
- [ ] 已配置速率限制
- [ ] 已定期更新依赖

### 监控和日志
- [ ] 已配置访问日志
- [ ] 已配置应用日志
- [ ] 已实现健康检查端点
- [ ] 已配置监控

### 性能优化
- [ ] 已启用Gzip压缩
- [ ] 已配置适当的工作进程数量
- [ ] 已优化数据库查询
- [ ] 已实现缓存（如果需要）

### 部署配置
- [ ] 已配置自动化部署
- [ ] 已配置负载均衡（如果需要）
- [ ] 已配置高可用性（如果需要）
- [ ] 已配置数据备份

## 13. 参考资源

- [FastAPI官方部署文档](https://fastapi.tiangolo.com/deployment/)
- [Uvicorn官方文档](https://www.uvicorn.org/deployment/)
- [Docker官方文档](https://docs.docker.com/)
- [Nginx官方文档](https://nginx.org/en/docs/)
- [systemd官方文档](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [Prometheus官方文档](https://prometheus.io/docs/introduction/overview/)
- [Grafana官方文档](https://grafana.com/docs/grafana/latest/)

## 总结

本目录提供了FastAPI应用的多种部署方式示例，包括直接部署、Docker容器化部署、Docker Compose部署、systemd服务管理和Nginx反向代理等。同时，还包含了生产环境配置、CI/CD示例、监控和日志、安全配置、性能优化等方面的内容。

选择合适的部署方式取决于你的应用规模、团队经验和基础设施环境。对于小型应用，可以直接使用Uvicorn部署；对于中大型应用，建议使用Docker容器化部署或Docker Compose部署；对于生产环境，建议使用systemd管理服务并配置Nginx反向代理。

无论选择哪种部署方式，都应该关注应用的安全性、性能和可维护性，定期监控和更新应用，确保应用的稳定运行。