"""批量NPC对话生成器"""

import sys
import os
import json
from datetime import datetime
from typing import Dict, Optional

# 添加HelloAgents到Python路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'HelloAgents'))

from hello_agents import HelloAgentsLLM
from agents import NPC_ROLES

class NPCBatchGenerator:
    """批量生成NPC对话的生成器
    
    核心思路: 一次LLM调用生成所有NPC的对话,降低API成本和延迟
    """
    
    def __init__(self):
        """初始化批量生成器"""
        print("🎨 正在初始化批量对话生成器...")
        
        try:
            # 初始化 LLM，显式设置 max_tokens 为整数，避免 API 报错
            self.llm = HelloAgentsLLM(max_tokens=2000)
            self.enabled = True
            print("✅ 批量生成器初始化成功")
        except Exception as e:
            print(f"❌ 批量生成器初始化失败: {e}")
            print("⚠️  将使用预设对话模式")
            self.llm = None
            self.enabled = False
        
        self.npc_configs = NPC_ROLES
        
        # 预设对话库(当LLM不可用时使用)
        self.preset_dialogues = {
            "morning": {
                "老年李白": "清晨醒来,提笔记录昨夜梦中所得诗句。",
                "青年李白": "新的一天,继续游历四方,探索名山大川!",
                "中年李白": "在长安宫中,为今日的宫廷宴会准备诗作。"
            },
            "noon": {
                "老年李白": "漂泊路上,偶遇故人,把酒言欢,诗兴大发。",
                "青年李白": "游历至江南水乡,见小桥流水,灵感涌现。",
                "中年李白": "在长安市集中,观察市井生活,寻找创作灵感。"
            },
            "afternoon": {
                "老年李白": "午后独坐,思考人生,提笔写下心中感慨。",
                "青年李白": "登上名山,俯瞰群山,豪情万丈,欲作诗一首。",
                "中年李白": "在梁园中,与文人雅集,吟诗作对,好不快活。"
            },
            "evening": {
                "老年李白": "夜幕降临,举杯邀月,回忆往昔,感慨万千。",
                "青年李白": "夜晚宿于客栈,整理今日游历见闻,准备创作。",
                "中年李白": "傍晚时分,在长安宫中,为今日所见所感作诗。"
            }
        }
    
    def generate_batch_dialogues(self, context: Optional[str] = None) -> Dict[str, str]:
        """批量生成所有NPC的对话
        
        Args:
            context: 场景上下文(如"上午工作时间"、"午餐时间"等)
        
        Returns:
            Dict[str, str]: NPC名称到对话内容的映射
        """
        if not self.enabled or self.llm is None:
            # 使用预设对话
            return self._get_preset_dialogues()
        
        try:
            # 构建批量生成提示词
            prompt = self._build_batch_prompt(context)

            # 一次LLM调用生成所有对话
            # 使用invoke方法而不是chat方法
            response = self.llm.invoke([
                {"role": "system", "content": "你是一个游戏NPC对话生成器,擅长创作自然真实的诗人对话,了解李白不同时期的创作风格和人生经历。"},
                {"role": "user", "content": prompt}
            ],
            temperature=0.9,        # 温度越高,生成内容越随机,越容易出现意想不到的对话
            )

            # 解析JSON响应
            dialogues = self._parse_response(response)

            if dialogues:
                print(f"✅ 批量生成成功: {len(dialogues)}个NPC对话")
                return dialogues
            else:
                print("⚠️  解析失败,使用预设对话")
                return self._get_preset_dialogues()

        except Exception as e:
            print(f"❌ 批量生成失败: {e}")
            return self._get_preset_dialogues()
    
    def _build_batch_prompt(self, context: Optional[str] = None) -> str:
        """构建批量生成提示词"""
        # 根据时间自动推断场景
        if context is None:
            context = self._get_current_context()
        
        # 构建NPC描述
        npc_descriptions = []
        for name, cfg in self.npc_configs.items():
            desc = f"- {name}({cfg['title']}): 在{cfg['location']}{cfg['activity']},性格{cfg['personality']}"
            npc_descriptions.append(desc)
        
        npc_desc_text = "\n".join(npc_descriptions)
        
        prompt = f"""请为李白三个时期的NPC生成当前的对话或行为描述。

【场景】{context}

【NPC信息】
{npc_desc_text}

【生成要求】
1. 每个NPC生成1句话(20-40字)
2. 内容要符合角色设定、当前活动和场景氛围
3. 可以是自言自语、创作状态描述、或简单的思考
4. 要自然真实,像真实的诗人李白
5. 可以体现不同时期的性格特点和情绪
6. 可以适当引用或模仿李白的诗句风格
7. 可以适当引用李白在对应时期的经典故事,吸引玩家继续对话
8. 在对话中谈及李白在对应时期有交集的其它人物,吸引玩家继续对话
9. **同一NPC在短时间内的多次发言,内容和表达方式应明显不同,不要重复上一轮的句式或意象**
10. **主动推动剧情或心境变化,可以提及新的细节、新的感受或新的动作,而不是简单改写上一轮的话**
11. **必须严格按照JSON格式返回**

【输出格式】(严格遵守)
{{"老年李白": "...", "青年李白": "...", "中年李白": "..."}}

【示例输出】
{{"老年李白": "漂泊路上,偶得佳句,提笔记录。", "青年李白": "游历四方,见名山大川,诗兴大发!", "中年李白": "在长安宫中,为陛下作诗,虽得赏识,但理想未遂。"}}

请生成(只返回JSON,不要其他内容):
"""
        return prompt
    
    def _parse_response(self, response: str) -> Optional[Dict[str, str]]:
        """解析LLM响应"""
        try:
            # 尝试直接解析JSON
            dialogues = json.loads(response)
            
            # 验证格式
            if isinstance(dialogues, dict) and all(name in dialogues for name in self.npc_configs.keys()):
                return dialogues
            else:
                print(f"⚠️  JSON格式不正确: {dialogues}")
                return None
                
        except json.JSONDecodeError:
            # 尝试提取JSON部分
            try:
                # 查找第一个{和最后一个}
                start = response.find('{')
                end = response.rfind('}') + 1
                
                if start != -1 and end > start:
                    json_str = response[start:end]
                    dialogues = json.loads(json_str)
                    
                    if isinstance(dialogues, dict):
                        return dialogues
            except:
                pass
            
            print(f"⚠️  无法解析响应: {response[:100]}...")
            return None
    
    def _get_current_context(self) -> str:
        """根据当前时间推断场景上下文"""
        hour = datetime.now().hour
        
        if 6 <= hour < 9:
            return "清晨时分,开始新的一天"
        elif 9 <= hour < 12:
            return "上午"
        elif 12 <= hour < 14:
            return "午餐时间"
        elif 14 <= hour < 17:
            return "下午"
        elif 17 <= hour < 19:
            return "傍晚时分"
        else:
            return "夜晚时分,各种思念之情涌现"
    
    def _get_preset_dialogues(self) -> Dict[str, str]:
        """获取预设对话(根据时间)"""
        hour = datetime.now().hour
        
        if 6 <= hour < 12:
            period = "morning"
        elif 12 <= hour < 14:
            period = "noon"
        elif 14 <= hour < 18:
            period = "afternoon"
        else:
            period = "evening"
        
        return self.preset_dialogues.get(period, self.preset_dialogues["morning"])

# 全局单例
_batch_generator = None

def get_batch_generator() -> NPCBatchGenerator:
    """获取批量生成器单例"""
    global _batch_generator
    if _batch_generator is None:
        _batch_generator = NPCBatchGenerator()
    return _batch_generator

