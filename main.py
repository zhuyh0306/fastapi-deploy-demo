from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from sqlalchemy import create_engine, Column, Integer, String, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
import os
from dotenv import load_dotenv


# 加载环境变量
load_dotenv()

# 应用配置
app_name = os.getenv("APP_NAME", "FastAPI Deployment Demo")
debug = os.getenv("DEBUG", "False").lower() == "true"

# 创建FastAPI应用
app = FastAPI(
    title=app_name,
    description="这是一个FastAPI部署示例应用",
    version="1.0.0",
    debug=debug
)

# CORS配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境中应指定具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 数据库配置
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./app.db")

# 创建数据库引擎
enable_echo = debug  # 调试模式下启用SQL日志
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False} if SQLALCHEMY_DATABASE_URL.startswith("sqlite") else {},
    echo=enable_echo
)

# 创建会话工厂
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 创建基类
Base = declarative_base()

# 数据库模型
class Item(Base):
    __tablename__ = "items"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    description = Column(String, index=True, nullable=True)
    price = Column(Float)
    category = Column(String, index=True)

# 创建数据库表
Base.metadata.create_all(bind=engine)

# Pydantic模型
class ItemBase(BaseModel):
    name: str
    description: Optional[str] = None
    price: float
    category: str

class ItemCreate(ItemBase):
    pass

class Item(ItemBase):
    id: int
    
    class Config:
        from_attributes = True

# 依赖项：获取数据库会话
def get_db():
    """获取数据库会话"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# 1. 健康检查端点

@app.get("/health", status_code=status.HTTP_200_OK)
def health_check():
    """基本健康检查端点"""
    return {
        "status": "healthy",
        "service": app_name,
        "version": "1.0.0"
    }

@app.get("/ready", status_code=status.HTTP_200_OK)
def ready_check(db: Session = Depends(get_db)):
    """应用就绪检查端点，验证数据库连接"""
    try:
        # 测试数据库连接
        db.execute("SELECT 1")
        return {
            "status": "ready",
            "service": app_name,
            "database": "connected"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"数据库连接失败: {str(e)}"
        )

# 2. API端点

@app.get("/", tags=["根路径"])
def read_root():
    """根路径"""
    return {
        "message": f"欢迎使用{app_name}！",
        "documentation": "/docs",
        "redoc": "/redoc"
    }

@app.get("/items", response_model=List[Item], tags=["项目"])
def get_items(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """获取项目列表"""
    items = db.query(Item).offset(skip).limit(limit).all()
    return items

@app.get("/items/{item_id}", response_model=Item, tags=["项目"])
def get_item(item_id: int, db: Session = Depends(get_db)):
    """获取单个项目"""
    item = db.query(Item).filter(Item.id == item_id).first()
    if item is None:
        raise HTTPException(status_code=404, detail="项目未找到")
    return item

@app.post("/items", response_model=Item, status_code=status.HTTP_201_CREATED, tags=["项目"])
def create_item(item: ItemCreate, db: Session = Depends(get_db)):
    """创建新项目"""
    db_item = Item(**item.model_dump())
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

@app.put("/items/{item_id}", response_model=Item, tags=["项目"])
def update_item(item_id: int, item: ItemCreate, db: Session = Depends(get_db)):
    """更新项目"""
    db_item = db.query(Item).filter(Item.id == item_id).first()
    if db_item is None:
        raise HTTPException(status_code=404, detail="项目未找到")
    
    for key, value in item.model_dump().items():
        setattr(db_item, key, value)
    
    db.commit()
    db.refresh(db_item)
    return db_item

@app.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["项目"])
def delete_item(item_id: int, db: Session = Depends(get_db)):
    """删除项目"""
    db_item = db.query(Item).filter(Item.id == item_id).first()
    if db_item is None:
        raise HTTPException(status_code=404, detail="项目未找到")
    
    db.delete(db_item)
    db.commit()
    return None

# 3. 环境信息端点（仅用于调试）

@app.get("/env", tags=["调试"])
def get_env():
    """获取环境信息"""
    if not debug:
        raise HTTPException(status_code=403, detail="禁止访问")
    
    return {
        "app_name": app_name,
        "debug": debug,
        "database_url": SQLALCHEMY_DATABASE_URL,
        "python_version": os.sys.version,
        "os": os.sys.platform
    }

# 4. 应用信息端点

@app.get("/info", tags=["信息"])
def get_info():
    """获取应用信息"""
    return {
        "name": app_name,
        "version": "1.0.0",
        "description": "FastAPI部署示例应用",
        "framework": "FastAPI"
    }