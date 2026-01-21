#!/bin/bash

# FastAPI 自动化部署脚本
# 支持多种部署方式：uvicorn、docker、docker-compose

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 脚本信息
SCRIPT_NAME=$(basename "$0")
VERSION="1.0.0"

# 默认配置
DEPLOY_MODE="uvicorn"  # 可选: uvicorn, docker, docker-compose
env_file=".env"
requirements_file="requirements.txt"
app_dir="."
port=8000
host="0.0.0.0"
workers=4

# 显示帮助信息
show_help() {
    echo -e "${GREEN}FastAPI 自动化部署脚本${NC}"
    echo -e "版本: $VERSION\n"
    echo -e "用法: $SCRIPT_NAME [选项]\n"
    echo -e "选项:"
    echo -e "  -h, --help              显示帮助信息"
    echo -e "  -m, --mode MODE         部署模式 (默认: $DEPLOY_MODE)"
    echo -e "                          可选值: uvicorn, docker, docker-compose"
    echo -e "  -e, --env-file FILE     环境变量文件 (默认: $env_file)"
    echo -e "  -r, --requirements FILE  依赖文件 (默认: $requirements_file)"
    echo -e "  -d, --app-dir DIR        应用目录 (默认: $app_dir)"
    echo -e "  -p, --port PORT         端口号 (默认: $port)"
    echo -e "  -H, --host HOST         主机地址 (默认: $host)"
    echo -e "  -w, --workers NUM       工作进程数 (默认: $workers)"
    echo -e "  --install               只安装依赖"
    echo -e "  --start                只启动服务"
    echo -e "  --stop                 只停止服务"
    echo -e "  --restart              重启服务"
    echo -e "  --status               查看服务状态"
    echo -e "  --clean                清理资源"
    echo -e "\n示例:"
    echo -e "  $SCRIPT_NAME -m docker -p 8001        # 使用Docker部署，端口8001"
    echo -e "  $SCRIPT_NAME --mode docker-compose   # 使用Docker Compose部署"
    echo -e "  $SCRIPT_NAME --restart               # 重启服务"
    echo -e "  $SCRIPT_NAME --stop                  # 停止服务"
}

# 显示错误信息
show_error() {
    echo -e "${RED}错误: $1${NC}"
    exit 1
}

# 显示成功信息
show_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 显示警告信息
show_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 检查命令是否存在（修改原有 check_command 函数）
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        # 如果 docker 不存在，尝试使用 podman 替代
        if [ "$cmd" = "docker" ] && command -v podman &> /dev/null; then
            show_warning "命令 '$cmd' 不存在，使用 podman 替代"
            alias docker=podman
        elif [ "$cmd" = "docker-compose" ] && command -v podman-compose &> /dev/null; then
            show_warning "命令 '$cmd' 不存在，使用 podman-compose 替代"
            alias docker-compose=podman-compose
        else
            show_error "命令 '$cmd' 不存在，请先安装"
        fi
    fi
}

# 检查环境变量文件
check_env_file() {
    if [ -f "$env_file" ]; then
        show_success "找到环境变量文件: $env_file"
        export $(grep -v '^#' "$env_file" | xargs)
    else
        show_warning "未找到环境变量文件: $env_file，使用默认配置"
    fi
}

# 安装依赖（uvicorn模式）
install_dependencies() {
    show_success "开始安装依赖..."
    
    # 检查Python是否安装
    check_command python3
    
    # 创建虚拟环境（如果不存在）
    if [ ! -d "venv" ]; then
        show_success "创建虚拟环境..."
        python3 -m venv venv
    fi
    
    # 激活虚拟环境
    show_success "激活虚拟环境..."
    source venv/bin/activate
    
    # 升级pip
    show_success "升级pip..."
    pip install --upgrade pip
    
    # 安装依赖
    if [ -f "$requirements_file" ]; then
        show_success "安装项目依赖..."
        pip install -r "$requirements_file"
    else
        show_error "未找到依赖文件: $requirements_file"
    fi
    
    show_success "依赖安装完成"
}

# 启动服务（uvicorn模式）
start_uvicorn() {
    show_success "启动Uvicorn服务..."
    
    # 检查虚拟环境是否存在
    if [ ! -d "venv" ]; then
        show_error "虚拟环境不存在，请先运行安装命令"
    fi
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 检查是否已在运行
    if pgrep -f "uvicorn main:app" > /dev/null; then
        show_warning "服务已在运行，先停止旧服务..."
        stop_uvicorn
    fi
    
    # 启动服务
    show_success "启动Uvicorn服务，端口: $port，工作进程: $workers"
    nohup uvicorn main:app --host "$host" --port "$port" --workers "$workers" --access-log > uvicorn.log 2>&1 &
    
    # 保存PID
    echo $! > uvicorn.pid
    show_success "服务已启动，PID: $(cat uvicorn.pid)"
    show_success "日志文件: uvicorn.log"
}

# 停止服务（uvicorn模式）
stop_uvicorn() {
    show_success "停止Uvicorn服务..."
    
    if [ -f "uvicorn.pid" ]; then
        pid=$(cat uvicorn.pid)
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            show_success "服务已停止，PID: $pid"
            rm -f uvicorn.pid
        else
            show_warning "服务未在运行，清理PID文件"
            rm -f uvicorn.pid
        fi
    else
        # 尝试查找并停止所有uvicorn进程
        pids=$(pgrep -f "uvicorn main:app")
        if [ -n "$pids" ]; then
            kill $pids
            show_success "已停止所有Uvicorn进程"
        else
            show_warning "未找到运行中的Uvicorn服务"
        fi
    fi
}

# 查看服务状态（uvicorn模式）
status_uvicorn() {
    if [ -f "uvicorn.pid" ]; then
        pid=$(cat uvicorn.pid)
        if kill -0 "$pid" 2>/dev/null; then
            show_success "服务正在运行，PID: $pid"
            return 0
        else
            show_warning "PID文件存在，但进程未运行"
            rm -f uvicorn.pid
            return 1
        fi
    else
        pids=$(pgrep -f "uvicorn main:app")
        if [ -n "$pids" ]; then
            show_success "服务正在运行，PID: $pids"
            return 0
        else
            show_warning "服务未在运行"
            return 1
        fi
    fi
}

# 构建Docker镜像
build_docker() {
    show_success "构建Docker镜像..."
    
    # 检查Docker是否安装
    check_command docker
    
    # 构建镜像
    docker build -t fastapi-app:latest .
    show_success "Docker镜像构建完成"
}

# 启动服务（Docker模式）
start_docker() {
    show_success "启动Docker服务..."
    
    # 检查Docker是否安装
    check_command docker
    
    # 检查镜像是否存在
    if ! docker images | grep -q fastapi-app; then
        show_warning "Docker镜像不存在，开始构建..."
        build_docker
    fi
    
    # 停止旧容器
    stop_docker
    
    # 启动新容器
    show_success "启动Docker容器，端口: $port"
    docker run -d --name fastapi-app -p "$port:$port" --restart unless-stopped fastapi-app:latest
    
    show_success "Docker容器已启动"
    show_success "容器ID: $(docker ps -q -f name=fastapi-app)"
}

# 停止服务（Docker模式）
stop_docker() {
    show_success "停止Docker服务..."
    
    # 检查Docker是否安装
    check_command docker
    
    # 停止并删除容器
    if docker ps -q -f name=fastapi-app > /dev/null; then
        docker stop fastapi-app
        docker rm fastapi-app
        show_success "Docker容器已停止并删除"
    else
        show_warning "Docker容器未在运行"
    fi
}

# 查看服务状态（Docker模式）
status_docker() {
    # 检查Docker是否安装
    check_command docker
    
    if docker ps -q -f name=fastapi-app > /dev/null; then
        show_success "Docker容器正在运行"
        docker ps -f name=fastapi-app
        return 0
    else
        show_warning "Docker容器未在运行"
        return 1
    fi
}

# 启动服务（Docker Compose模式）
start_docker_compose() {
    show_success "启动Docker Compose服务..."
    
    # 检查Docker Compose是否安装
    check_command docker-compose
    
    # 启动服务
    show_success "使用Docker Compose启动服务"
    docker-compose up -d
    
    show_success "Docker Compose服务已启动"
}

# 停止服务（Docker Compose模式）
stop_docker_compose() {
    show_success "停止Docker Compose服务..."
    
    # 检查Docker Compose是否安装
    check_command docker-compose
    
    # 停止服务
    docker-compose down
    
    show_success "Docker Compose服务已停止"
}

# 查看服务状态（Docker Compose模式）
status_docker_compose() {
    # 检查Docker Compose是否安装
    check_command docker-compose
    
    show_success "查看Docker Compose服务状态"
    docker-compose ps
    return 0
}

# 清理资源
clean_resources() {
    show_success "清理资源..."
    
    case "$DEPLOY_MODE" in
        uvicorn)
            stop_uvicorn
            # 删除虚拟环境
            if [ -d "venv" ]; then
                show_warning "删除虚拟环境..."
                rm -rf venv
            fi
            # 删除日志文件
            if [ -f "uvicorn.log" ]; then
                show_warning "删除日志文件..."
                rm -f uvicorn.log
            fi
            ;;
        docker)
            stop_docker
            # 删除镜像
            if docker images | grep -q fastapi-app; then
                show_warning "删除Docker镜像..."
                docker rmi fastapi-app:latest
            fi
            ;;
        docker-compose)
            # 停止并删除所有资源，包括数据卷
            show_warning "停止并删除所有Docker Compose资源，包括数据卷..."
            docker-compose down -v
            ;;
    esac
    
    show_success "资源清理完成"
}

# 健康检查
health_check() {
    show_success "开始健康检查..."
    
    # 等待服务启动
    sleep 3
    
    # 检查服务是否可访问
    if curl -s "http://$host:$port/health" > /dev/null; then
        show_success "健康检查通过，服务正常运行"
        return 0
    else
        show_error "健康检查失败，服务不可访问"
        return 1
    fi
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -m|--mode)
                DEPLOY_MODE="$2"
                shift 2
                ;;
            -e|--env-file)
                env_file="$2"
                shift 2
                ;;
            -r|--requirements)
                requirements_file="$2"
                shift 2
                ;;
            -d|--app-dir)
                app_dir="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -H|--host)
                host="$2"
                shift 2
                ;;
            -w|--workers)
                workers="$2"
                shift 2
                ;;
            --install)
                install_only=true
                shift
                ;;
            --start)
                start_only=true
                shift
                ;;
            --stop)
                stop_only=true
                shift
                ;;
            --restart)
                restart=true
                shift
                ;;
            --status)
                status_only=true
                shift
                ;;
            --clean)
                clean_only=true
                shift
                ;;
            *)
                show_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 验证部署模式
    case "$DEPLOY_MODE" in
        uvicorn|docker|docker-compose)
            show_success "部署模式: $DEPLOY_MODE"
            ;;
        *)
            show_error "无效的部署模式: $DEPLOY_MODE，可选值: uvicorn, docker, docker-compose"
            ;;
    esac
}

# 主函数
main() {
    # 解析命令行参数
    parse_args "$@"
    
    # 切换到应用目录
    cd "$app_dir" || show_error "无法切换到目录: $app_dir"
    
    # 检查环境变量文件
    check_env_file
    
    # 执行操作
    if [ "$install_only" = true ]; then
        # 只安装依赖
        if [ "$DEPLOY_MODE" = "uvicorn" ]; then
            install_dependencies
        else
            show_warning "只有uvicorn模式支持--install选项"
        fi
    elif [ "$start_only" = true ]; then
        # 只启动服务
        case "$DEPLOY_MODE" in
            uvicorn)
                start_uvicorn
                ;;
            docker)
                start_docker
                ;;
            docker-compose)
                start_docker_compose
                ;;
        esac
        health_check
    elif [ "$stop_only" = true ]; then
        # 只停止服务
        case "$DEPLOY_MODE" in
            uvicorn)
                stop_uvicorn
                ;;
            docker)
                stop_docker
                ;;
            docker-compose)
                stop_docker_compose
                ;;
        esac
    elif [ "$restart" = true ]; then
        # 重启服务
        case "$DEPLOY_MODE" in
            uvicorn)
                stop_uvicorn
                start_uvicorn
                ;;
            docker)
                stop_docker
                start_docker
                ;;
            docker-compose)
                stop_docker_compose
                start_docker_compose
                ;;
        esac
        health_check
    elif [ "$status_only" = true ]; then
        # 查看服务状态
        case "$DEPLOY_MODE" in
            uvicorn)
                status_uvicorn
                ;;
            docker)
                status_docker
                ;;
            docker-compose)
                status_docker_compose
                ;;
        esac
    elif [ "$clean_only" = true ]; then
        # 清理资源
        clean_resources
    else
        # 完整部署流程
        show_success "开始完整部署流程..."
        
        case "$DEPLOY_MODE" in
            uvicorn)
                install_dependencies
                start_uvicorn
                ;;
            docker)
                start_docker
                ;;
            docker-compose)
                start_docker_compose
                ;;
        esac
        
        health_check
        show_success "部署完成！"
        show_success "服务地址: http://$host:$port"
        show_success "API文档: http://$host:$port/docs"
    fi
}

# 执行主函数
main "$@"