"""外部接口管理器 - 统一管理所有外部接口调用"""

import httpx
import asyncio
from typing import Dict, List, Optional, Callable, Any
from datetime import datetime
import os

class ExternalAPIManager:
    """外部接口管理器 - 统一管理所有外部接口调用"""
    
    def __init__(self):
        """初始化外部接口管理器"""
        # 从环境变量读取配置
        self.enabled = os.getenv("EXTERNAL_API_ENABLED", "true").lower() == "true"
        self.timeout = float(os.getenv("EXTERNAL_API_TIMEOUT", "5.0"))
        self.base_url = os.getenv("EXTERNAL_API_BASE_URL", "")
        
        # 事件钩子字典
        self.hooks: Dict[str, List[Callable]] = {}
        
        print(f"🔌 外部接口管理器初始化: enabled={self.enabled}, timeout={self.timeout}s")
        
    def register_hook(self, event: str, callback: Callable):
        """注册事件钩子
        
        Args:
            event: 事件名称 (如 'before_chat', 'after_chat', 'on_affinity_change')
            callback: 回调函数 (可以是同步或异步函数)
        """
        if event not in self.hooks:
            self.hooks[event] = []
        self.hooks[event].append(callback)
        print(f"✅ 已注册事件钩子: {event} -> {callback.__name__}")
    
    def unregister_hook(self, event: str, callback: Callable):
        """取消注册事件钩子
        
        Args:
            event: 事件名称
            callback: 要移除的回调函数
        """
        if event in self.hooks and callback in self.hooks[event]:
            self.hooks[event].remove(callback)
            print(f"✅ 已取消注册事件钩子: {event} -> {callback.__name__}")
    
    async def trigger_hooks(self, event: str, *args, **kwargs):
        """触发事件钩子（异步执行，不阻塞）
        
        Args:
            event: 事件名称
            *args, **kwargs: 传递给回调函数的参数
        """
        if not self.enabled:
            return
        
        if event not in self.hooks:
            return
        
        # 异步执行所有钩子，不阻塞主流程
        for callback in self.hooks[event]:
            try:
                if asyncio.iscoroutinefunction(callback):
                    # 异步函数，创建任务异步执行
                    asyncio.create_task(callback(*args, **kwargs))
                else:
                    # 同步函数，在线程池中执行
                    loop = asyncio.get_event_loop()
                    await loop.run_in_executor(None, callback, *args, **kwargs)
            except Exception as e:
                print(f"❌ 事件钩子执行失败 ({event} -> {callback.__name__}): {e}")
                import traceback
                traceback.print_exc()
    
    async def call_external_api(
        self, 
        url: str, 
        method: str = "POST",
        data: Optional[Dict] = None,
        headers: Optional[Dict] = None,
        params: Optional[Dict] = None
    ) -> Optional[Dict]:
        """调用外部API
        
        Args:
            url: API地址（可以是完整URL或相对于base_url的路径）
            method: HTTP方法 (GET/POST/PUT/DELETE)
            data: 请求数据（用于POST/PUT）
            headers: 请求头
            params: URL参数（用于GET）
        
        Returns:
            API响应数据（JSON），失败返回None
        """
        if not self.enabled:
            return None
        
        # 如果提供了base_url且url是相对路径，则拼接
        if self.base_url and not url.startswith("http"):
            url = f"{self.base_url.rstrip('/')}/{url.lstrip('/')}"
        
        # 默认请求头
        default_headers = {
            "Content-Type": "application/json",
            "User-Agent": "HelloAgents-NPC-System/1.0"
        }
        if headers:
            default_headers.update(headers)
        
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                method_upper = method.upper()
                
                if method_upper == "GET":
                    response = await client.get(url, headers=default_headers, params=params or data)
                elif method_upper == "POST":
                    response = await client.post(url, json=data, headers=default_headers, params=params)
                elif method_upper == "PUT":
                    response = await client.put(url, json=data, headers=default_headers, params=params)
                elif method_upper == "DELETE":
                    response = await client.delete(url, headers=default_headers, params=params)
                else:
                    print(f"❌ 不支持的HTTP方法: {method}")
                    return None
                
                response.raise_for_status()
                
                # 尝试解析JSON响应
                if response.content:
                    try:
                        return response.json()
                    except:
                        return {"status": "success", "content": response.text}
                return {"status": "success"}
                
        except httpx.TimeoutException:
            print(f"❌ 外部API调用超时: {url} (超时时间: {self.timeout}s)")
            return None
        except httpx.HTTPStatusError as e:
            print(f"❌ 外部API调用失败: {url}, 状态码: {e.response.status_code}")
            if e.response.content:
                try:
                    error_detail = e.response.json()
                    print(f"   错误详情: {error_detail}")
                except:
                    print(f"   错误详情: {e.response.text}")
            return None
        except Exception as e:
            print(f"❌ 外部API调用异常: {url}, 错误: {e}")
            import traceback
            traceback.print_exc()
            return None
    
    def get_registered_hooks(self) -> Dict[str, List[str]]:
        """获取已注册的钩子列表（用于调试）
        
        Returns:
            事件名称到回调函数名称列表的映射
        """
        return {
            event: [callback.__name__ for callback in callbacks]
            for event, callbacks in self.hooks.items()
        }

# 全局单例
_external_api_manager = None

def get_external_api_manager() -> ExternalAPIManager:
    """获取外部接口管理器单例"""
    global _external_api_manager
    if _external_api_manager is None:
        _external_api_manager = ExternalAPIManager()
    return _external_api_manager

