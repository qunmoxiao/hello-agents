"""数据模型定义"""

from pydantic import BaseModel, Field
from typing import Dict, List, Optional
from datetime import datetime

class ChatRequest(BaseModel):
    """单个NPC对话请求"""
    npc_name: str = Field(..., description="NPC名称")
    message: str = Field(..., description="玩家消息")
    
    class Config:
        json_schema_extra = {
            "example": {
                "npc_name": "老年李白",
                "message": "你好,最近在做什么?"
            }
        }

class ChatResponse(BaseModel):
    """单个NPC对话响应"""
    npc_name: str = Field(..., description="NPC名称")
    npc_title: str = Field(..., description="NPC职位")
    message: str = Field(..., description="NPC回复")
    success: bool = Field(default=True, description="是否成功")
    timestamp: Optional[datetime] = Field(default_factory=datetime.now, description="时间戳")
    
    class Config:
        json_schema_extra = {
            "example": {
                "npc_name": "老年李白",
                "npc_title": "老年李白",
                "message": "在下李白,字太白。最近在漂泊创作,你愿意听我吟诗一首吗?",
                "success": True
            }
        }

class NPCInfo(BaseModel):
    """NPC信息"""
    name: str = Field(..., description="NPC名称")
    title: str = Field(..., description="NPC职位")
    location: str = Field(..., description="NPC位置")
    activity: str = Field(..., description="当前活动")
    available: bool = Field(default=True, description="是否可对话")

class NPCStatusResponse(BaseModel):
    """NPC状态响应"""
    dialogues: Dict[str, str] = Field(..., description="NPC当前对话内容")
    last_update: Optional[datetime] = Field(None, description="上次更新时间")
    next_update_in: int = Field(..., description="下次更新倒计时(秒)")
    
    class Config:
        json_schema_extra = {
            "example": {
                "dialogues": {
                    "老年李白": "漂泊路上,偶得佳句,提笔记录。",
                    "青年李白": "游历四方,见名山大川,诗兴大发!",
                    "中年李白": "在长安宫中,为陛下作诗,虽得赏识,但理想未遂。"
                },
                "last_update": "2024-01-15T10:30:00",
                "next_update_in": 25
            }
        }

class NPCListResponse(BaseModel):
    """NPC列表响应"""
    npcs: List[NPCInfo] = Field(..., description="NPC列表")
    total: int = Field(..., description="NPC总数")

