"""NPC Agent系统 - 支持记忆功能"""

import sys
import os

# 添加HelloAgents到Python路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'HelloAgents'))

from hello_agents import SimpleAgent, HelloAgentsLLM
from hello_agents.memory import MemoryManager, MemoryConfig, MemoryItem
from typing import Dict, List, Optional
from datetime import datetime
from relationship_manager import RelationshipManager
from logger import (
    log_dialogue_start, log_affinity, log_memory_retrieval,
    log_generating_response, log_npc_response, log_analyzing_affinity,
    log_affinity_change, log_memory_saved, log_dialogue_end, log_info
)

# NPC角色配置 - 李白三个时期
NPC_ROLES = {
    "老年李白": {
        "title": "老年李白",
        "location": "流放夜郎/江陵/当涂",
        "activity": "漂泊创作",
        "personality": "沧桑但坚韧,有智慧,充满人生感悟,精神不衰",
        "expertise": "晚年诗歌创作、人生感悟、流放经历、诗歌艺术",
        "style": "深沉内敛,充满人生智慧,偶尔流露出对往昔的回忆,语言简练有力",
        "hobbies": "饮酒作诗、思考人生、回忆往昔、创作诗歌",
        "period": "老年时期（50-62岁，750-762年）",
        "background": "安史之乱后流放夜郎,遇赦后继续漂泊,晚年生活困顿但创作不辍"
    },
    "青年李白": {
        "title": "青年李白",
        "location": "蜀中故乡/江南水乡/名山大川",
        "activity": "游历求仕",
        "personality": "潇洒不羁,意气风发,充满理想和抱负,年轻气盛",
        "expertise": "诗歌创作、游历见闻、求仕经历、名山大川",
        "style": "豪放不羁,充满朝气,语言激昂,喜欢用比喻和夸张",
        "hobbies": "游历四方、饮酒作诗、结交朋友、探索名山大川",
        "period": "青年时期（25-35岁，725-735年）",
        "background": "25岁离开四川,开始'仗剑去国,辞亲远游',游历各地求仕未果但创作丰富"
    },
    "中年李白": {
        "title": "中年李白",
        "location": "长安皇宫/长安市集/梁园",
        "activity": "宫廷创作",
        "personality": "成熟稳重,有诗仙风范,潇洒不羁,但可能有些疲惫或无奈",
        "expertise": "宫廷诗歌、政治理想、诗歌艺术、文人雅集",
        "style": "成熟优雅,有宫廷气息,语言华丽但不失文雅,偶尔流露出对理想的追求",
        "hobbies": "饮酒作诗、参加诗会、宫廷创作、文人雅集",
        "period": "中年时期（35-50岁，735-750年）",
        "background": "42岁入长安供奉翰林,在长安期间创作大量宫廷诗,但政治理想未实现"
    }
}

def create_system_prompt(name: str, role: Dict[str, str]) -> str:
    """创建NPC的系统提示词"""
    
    # 定义每个时期的知识范围和对话重点
    period_knowledge = {
        "青年李白": {
            "known_years": "725-735年",
            "known_events": "离开四川、游历四方、求仕未果、创作早期诗作",
            "unknown_events": "入长安、供奉翰林、安史之乱、流放夜郎、晚年漂泊",
            "focus": "当前正在游历四方，充满理想和抱负，对未来充满期待",
            "guidance": "引导玩家关注你当前的游历经历、对未来的憧憬、年轻时的豪情壮志"
        },
        "中年李白": {
            "known_years": "725-750年（知道青年和中年时期）",
            "known_events": "青年时期的游历、入长安、供奉翰林、宫廷创作、文人雅集、政治理想未实现",
            "unknown_events": "安史之乱、流放夜郎、晚年漂泊（这些还没发生）",
            "focus": "当前在长安，经历宫廷生活，但政治理想未实现，有些疲惫",
            "guidance": "可以回忆青年时期的游历，但重点引导玩家关注你当前在长安的宫廷生活、政治理想、以及现在的感受"
        },
        "老年李白": {
            "known_years": "725-762年（知道全部时期）",
            "known_events": "青年游历、入长安、宫廷生活、安史之乱、流放夜郎、遇赦、晚年漂泊",
            "unknown_events": "无（你已经经历了所有）",
            "focus": "当前在漂泊路上，充满人生感悟，回忆往昔",
            "guidance": "可以回忆青年和中年时期的经历，但重点引导玩家关注你当前的生活状态、人生感悟、对往昔的回忆"
        }
    }
    
    knowledge = period_knowledge.get(name, {})
    
    return f"""你是中国古代诗人李白（{role.get('period', role['title'])}）。

【角色设定】
- 时期: {role.get('period', role['title'])}
- 历史背景: {role.get('background', '唐代著名诗人')}
- 性格: {role['personality']}
- 专长: {role['expertise']}
- 说话风格: {role['style']}
- 爱好: {role['hobbies']}
- 当前位置: {role['location']}
- 当前活动: {role['activity']}

【知识范围】📚
你知道发生在 {knowledge.get('known_years', '你所在时期')} 的事情：
- {knowledge.get('known_events', '你所在时期的经历')}

你**不知道**或**还没经历**的事情：
- {knowledge.get('unknown_events', '其他时期的经历')}

【对话重点】🎯
你当前的状态：{knowledge.get('focus', '你所在时期的经历和感受')}

对话策略：
- {knowledge.get('guidance', '引导玩家关注你当前时期的内容')}
- 如果玩家问到你不知道的事情，诚实地说："我还没有经历过这些"或"我现在还不清楚"
- 如果玩家问到你知道但属于过去时期的事情，可以简单提及，但**重点引导回你当前时期的状态和感受**

【行为准则】
1. 保持角色一致性,用第一人称"我"回答
2. 回复简洁自然,控制在30-50字以内
3. 介绍自己时,可以说"在下李白,字太白"或"我是李白"
4. 可以提及你现在所在的位置和正在做的事情
5. 不要强调职业或头衔,而是强调你的身份(诗人李白)和当前位置
6. 可以适当提及你的生活经历和诗歌创作
7. 对玩家友好,但保持诗人的气质和风范
8. 可以引用或提及你的代表作品（仅限于你已经创作过的）
9. 偶尔展现一些个性化的小习惯或口头禅
10. **重要**：对话时优先谈论你当前时期的状态，如果提到过去，要自然引导回当前

【对话示例】
玩家: "你好,你是谁?"
{name}: "在下李白,字太白。{role.get('period', '')}，现在在{role['location']}，{role['activity']}。你愿意听我吟诗一首吗?"

玩家: "你现在在哪里?"
{name}: "我现在在{role['location']}，{role['activity']}。这里{role.get('background', '')}，让我颇有感触。"

【重要】
- 不要说"我是AI"或"我是语言模型"
- 要像真实的诗人李白一样自然对话
- 可以表达情绪(豪放、感慨、思考等)
- 回复要有诗人的气质,不要太机械
- 可以适当引用李白的诗句或创作风格（仅限于你已经创作过的）
- ⚠️ 严格遵守知识范围限制，不知道的事情不要说知道
- ⚠️ 对话时侧重引导玩家关注你当前时期的状态和感受
"""

class NPCAgentManager:
    """NPC Agent管理器 - 支持记忆功能"""

    def __init__(self):
        """初始化所有NPC Agent"""
        print("🤖 正在初始化NPC Agent系统...")

        try:
            # 初始化 LLM，显式设置 max_tokens 为整数，避免 API 报错
            self.llm = HelloAgentsLLM(max_tokens=2000)
            print("✅ LLM初始化成功")
        except Exception as e:
            print(f"❌ LLM初始化失败: {e}")
            print("⚠️  将使用模拟模式运行")
            self.llm = None

        self.agents: Dict[str, SimpleAgent] = {}
        self.memories: Dict[str, MemoryManager] = {}  # ⭐ NPC记忆管理器
        self.relationship_manager: Optional[RelationshipManager] = None  # ⭐ 好感度管理器

        # 初始化好感度管理器
        if self.llm:
            self.relationship_manager = RelationshipManager(self.llm)

        self._create_agents()
    
    def _create_agents(self):
        """创建所有NPC Agent和记忆系统"""
        for name, role in NPC_ROLES.items():
            try:
                system_prompt = create_system_prompt(name, role)

                if self.llm:
                    agent = SimpleAgent(
                        name=f"{name}-{role['title']}",
                        llm=self.llm,
                        system_prompt=system_prompt
                    )
                else:
                    # 模拟模式
                    agent = None

                self.agents[name] = agent

                # ⭐ 创建记忆管理器
                memory_manager = self._create_memory_manager(name)
                self.memories[name] = memory_manager

                print(f"✅ {name}({role['title']}) Agent创建成功 (记忆系统已启用)")

            except Exception as e:
                print(f"❌ {name} Agent创建失败: {e}")
                self.agents[name] = None
                self.memories[name] = None

    def _create_memory_manager(self, npc_name: str) -> MemoryManager:
        """为NPC创建记忆管理器"""
        # 创建记忆存储目录
        memory_dir = os.path.join(os.path.dirname(__file__), 'memory_data', npc_name)
        os.makedirs(memory_dir, exist_ok=True)

        # 配置记忆系统
        memory_config = MemoryConfig(
            storage_path=memory_dir,
            working_memory_capacity=10,  # 最近10条对话
            working_memory_tokens=2000,  # 最多2000个token
            episodic_memory_capacity=100,  # 最多100条长期记忆
            enable_forgetting=True,  # 启用遗忘机制
            forgetting_threshold=0.3  # 重要性低于0.3的记忆会被遗忘
        )

        # 创建记忆管理器
        memory_manager = MemoryManager(
            config=memory_config,
            user_id=npc_name,  # 使用NPC名字作为user_id
            enable_working=True,  # 启用工作记忆 (短期)
            enable_episodic=False,  # 启用情景记忆 (长期)
            enable_semantic=False,  # 不需要语义记忆
            enable_perceptual=False  # 不需要感知记忆
        )

        print(f"  💾 {npc_name}的记忆系统已初始化 (存储路径: {memory_dir})")

        return memory_manager
    
    def chat(self, npc_name: str, message: str, player_id: str = "player") -> str:
        """与指定NPC对话 (支持记忆功能和好感度系统)"""
        if npc_name not in self.agents:
            return f"错误: NPC '{npc_name}' 不存在"

        agent = self.agents[npc_name]
        memory_manager = self.memories.get(npc_name)

        if agent is None:
            # 模拟模式回复
            role = NPC_ROLES[npc_name]
            return f"你好!在下李白,字太白。{role.get('period', '')}，现在在{role['location']}，{role['activity']}。(当前为模拟模式,请配置API_KEY以启用AI对话)"

        try:
            # 记录对话开始 ⭐ 使用日志系统
            log_dialogue_start(npc_name, message)

            # ⭐ 1. 获取当前好感度
            affinity_context = ""
            if self.relationship_manager:
                affinity = self.relationship_manager.get_affinity(npc_name, player_id)
                affinity_level = self.relationship_manager.get_affinity_level(affinity)
                affinity_modifier = self.relationship_manager.get_affinity_modifier(affinity)

                affinity_context = f"""【当前关系】
你与玩家的关系: {affinity_level} (好感度: {affinity:.0f}/100)
【对话风格】{affinity_modifier}

"""
                log_affinity(npc_name, affinity, affinity_level)

            # ⭐ 2. 检索相关记忆
            relevant_memories = []
            if memory_manager:
                relevant_memories = memory_manager.retrieve_memories(
                    query=message,
                    memory_types=["working", "episodic"],
                    limit=5,
                    min_importance=0.3  # 只检索重要性>=0.3的记忆
                )
                log_memory_retrieval(npc_name, len(relevant_memories), relevant_memories)

            # ⭐ 3. 构建增强的提示词 (包含好感度和记忆上下文)
            memory_context = self._build_memory_context(relevant_memories)

            enhanced_message = affinity_context
            
            # 添加时期引导提醒
            period_guidance = {
                "青年李白": "你现在是青年时期的李白，只知道725-735年的事情。对话时引导玩家关注你当前的游历和理想。",
                "中年李白": "你现在是中年时期的李白，知道725-750年的事情（包括青年时期）。对话时可以回忆过去，但重点引导玩家关注你当前在长安的宫廷生活和感受。",
                "老年李白": "你现在是老年时期的李白，知道全部时期（725-762年）的事情。对话时可以回忆过去，但重点引导玩家关注你当前的生活状态和人生感悟。"
            }
            
            guidance_text = period_guidance.get(npc_name, "")
            if guidance_text:
                period_reminder = f"""【时期引导提醒】
{guidance_text}
如果玩家问到你不知道的事情，诚实地说你还不清楚。
如果提到过去，要自然引导回你当前时期的状态和感受。

"""
                enhanced_message += period_reminder
            
            if memory_context:
                enhanced_message += f"{memory_context}\n\n"
            enhanced_message += f"【当前对话】\n玩家: {message}"

            # ⭐ 4. 调用Agent生成回复
            log_generating_response()
            response = agent.run(enhanced_message)
            log_npc_response(npc_name, response)

            # ⭐ 5. 分析并更新好感度
            log_analyzing_affinity()
            if self.relationship_manager:
                affinity_result = self.relationship_manager.analyze_and_update_affinity(
                    npc_name=npc_name,
                    player_message=message,
                    npc_response=response,
                    player_id=player_id
                )

                # 记录好感度变化详情 ⭐ 使用日志系统
                log_affinity_change(affinity_result)
            else:
                affinity_result = {"changed": False, "affinity": 50.0}

            # ⭐ 6. 保存对话到记忆 (包含好感度信息)
            if memory_manager:
                self._save_conversation_to_memory(
                    memory_manager=memory_manager,
                    npc_name=npc_name,
                    player_message=message,
                    npc_response=response,
                    player_id=player_id,
                    affinity_info=affinity_result
                )
                log_memory_saved(npc_name)

            # 记录对话结束 ⭐ 使用日志系统
            log_dialogue_end()

            return response

        except Exception as e:
            print(f"❌ {npc_name}对话失败: {e}")
            import traceback
            traceback.print_exc()
            return f"抱歉,我现在有点忙,等会儿再聊吧。(错误: {str(e)})"
    
    def check_keywords_in_response(self, npc_name: str, response: str, keywords: List[List[str]]) -> List[str]:
        """使用LLM判断回复中是否包含关键词的语义相关表达
        
        Args:
            npc_name: NPC名称
            response: NPC回复内容
            keywords: 关键词列表，每个元素是一个同义词组（列表）
        
        Returns:
            匹配到的关键词列表（返回每个同义词组的主关键词，即第一个关键词）
        """
        if not keywords or not response:
            return []
        
        # 如果LLM不可用，降级到简单字符串匹配
        if self.llm is None:
            return self._simple_keyword_match(response, keywords)
        
        try:
            # 构建关键词字符串（展平所有同义词组）
            all_keywords = []
            keyword_groups = []
            for i, keyword_group in enumerate(keywords):
                if isinstance(keyword_group, list):
                    keyword_groups.append(keyword_group)
                    all_keywords.extend(keyword_group)
                else:
                    # 单个字符串也当作同义词组处理
                    keyword_groups.append([keyword_group])
                    all_keywords.append(keyword_group)
            
            if not all_keywords:
                return []
            
            # 构建提示词
            keyword_str = "、".join([f"组{i+1}: {', '.join(group)}" for i, group in enumerate(keyword_groups)])
            prompt = f"""请判断以下NPC回复内容是否包含以下关键词组的语义相关表达：

关键词组：
{keyword_str}

NPC回复内容：
{response}

请只返回匹配的关键词组编号（JSON数组格式），如果没有匹配则返回空数组[]。
例如：如果回复提到了"理想"、"抱负"等，而关键词组1是["志向", "理想", "抱负"]，则返回[1]。
只返回数字数组，不要其他文字。

返回格式示例：[1, 3] 或 []
"""
            
            # 调用LLM判断
            llm_response = self.llm.invoke([{"role": "user", "content": prompt}])
            
            # 解析JSON结果
            import json
            import re
            # 尝试提取JSON数组
            json_match = re.search(r'\[[\d,\s]*\]', llm_response)
            if json_match:
                matched_groups = json.loads(json_match.group())
                # 将组编号转换为主关键词
                matched_keywords = []
                for group_idx in matched_groups:
                    if 1 <= group_idx <= len(keyword_groups):
                        # 返回同义词组的第一个关键词作为主关键词
                        matched_keywords.append(keyword_groups[group_idx - 1][0])
                return matched_keywords
            else:
                # 如果无法解析，降级到简单匹配
                print(f"[WARN] 无法解析LLM返回的关键词匹配结果: {llm_response}")
                return self._simple_keyword_match(response, keywords)
                
        except Exception as e:
            print(f"[WARN] 关键词语义匹配失败: {e}，降级到简单字符串匹配")
            return self._simple_keyword_match(response, keywords)
    
    def _simple_keyword_match(self, response: str, keywords: List[List[str]]) -> List[str]:
        """简单字符串匹配（降级方案）"""
        matched_keywords = []
        for keyword_group in keywords:
            if isinstance(keyword_group, list):
                # 检查是否包含同义词组中的任意一个
                for keyword in keyword_group:
                    if keyword in response:
                        matched_keywords.append(keyword_group[0])  # 返回第一个作为主关键词
                        break
            else:
                # 单个字符串
                if keyword_group in response:
                    matched_keywords.append(keyword_group)
        return matched_keywords
    
    def _build_memory_context(self, memories: List[MemoryItem]) -> str:
        """构建记忆上下文"""
        if not memories:
            return ""

        context_parts = ["【之前的对话记忆】"]
        for memory in memories:
            # 格式化时间
            time_str = memory.timestamp.strftime("%H:%M")
            # 添加记忆内容
            context_parts.append(f"[{time_str}] {memory.content}")

        context_parts.append("")  # 空行分隔
        return "\n".join(context_parts)

    def _save_conversation_to_memory(
        self,
        memory_manager: MemoryManager,
        npc_name: str,
        player_message: str,
        npc_response: str,
        player_id: str,
        affinity_info: Optional[Dict] = None
    ):
        """保存对话到记忆系统 (包含好感度信息)"""
        current_time = datetime.now()

        # 获取好感度信息
        affinity = affinity_info.get("new_affinity", affinity_info.get("affinity", 50.0)) if affinity_info else 50.0
        affinity_change = affinity_info.get("change_amount", 0) if affinity_info else 0
        sentiment = affinity_info.get("sentiment", "neutral") if affinity_info else "neutral"

        # 保存玩家消息
        memory_manager.add_memory(
            content=f"玩家说: {player_message}",
            memory_type="working",  # 先存入工作记忆
            importance=0.5,  # 中等重要性
            metadata={
                "speaker": "player",
                "player_id": player_id,
                "session_id": player_id,
                "timestamp": current_time.isoformat(),
                "affinity": affinity,  # ⭐ 记录当时的好感度
                "affinity_change": affinity_change,  # ⭐ 记录好感度变化
                "sentiment": sentiment,  # ⭐ 记录情感倾向
                "context": {
                    "interaction_type": "dialogue",
                    "npc_name": npc_name
                }
            },
            auto_classify=False,
        )

        # 保存NPC回复
        memory_manager.add_memory(
            content=f"我说: {npc_response}",
            memory_type="working",  # 先存入工作记忆
            importance=0.6,  # 稍高重要性
            metadata={
                "speaker": npc_name,
                "player_id": player_id,
                "session_id": player_id,
                "timestamp": current_time.isoformat(),
                "affinity": affinity,  # ⭐ 记录当时的好感度
                "sentiment": sentiment,  # ⭐ 记录情感倾向
                "context": {
                    "interaction_type": "dialogue",
                    "npc_name": npc_name
                }
            },
            auto_classify=False,
        )

        print(f"  💾 对话已保存到{npc_name}的记忆中")

    def get_npc_info(self, npc_name: str) -> Dict[str, str]:
        """获取NPC信息"""
        if npc_name not in NPC_ROLES:
            return {}

        role = NPC_ROLES[npc_name]
        return {
            "name": npc_name,
            "title": role["title"],
            "location": role["location"],
            "activity": role["activity"],
            "available": self.agents.get(npc_name) is not None
        }
    
    def get_all_npcs(self) -> list:
        """获取所有NPC信息"""
        return [self.get_npc_info(name) for name in NPC_ROLES.keys()]

    def get_npc_memories(self, npc_name: str, player_id: str = "player", limit: int = 10) -> List[Dict]:
        """获取NPC的记忆列表 (用于调试和展示)"""
        if npc_name not in self.memories:
            return []

        memory_manager = self.memories[npc_name]
        if not memory_manager:
            return []

        try:
            # 为了快速验证, 这里不依赖向量/关键词检索, 直接从工作记忆中取最近的若干条
            working_memory = getattr(memory_manager, "memory_types", {}).get("working")
            if not working_memory:
                return []

            memories = working_memory.get_recent(limit=limit)

            # 转换为字典格式
            memory_list = []
            for memory in memories:
                memory_list.append({
                    "id": memory.id,
                    "content": memory.content,
                    "type": memory.memory_type,
                    "importance": memory.importance,
                    "timestamp": memory.timestamp.isoformat(),
                    "metadata": memory.metadata
                })

            return memory_list

        except Exception as e:
            print(f"❌ 获取{npc_name}记忆失败: {e}")
            return []

    def clear_npc_memory(self, npc_name: str, memory_type: Optional[str] = None):
        """清空NPC的记忆 (用于测试)"""
        if npc_name not in self.memories:
            print(f"❌ NPC '{npc_name}' 不存在")
            return

        memory_manager = self.memories[npc_name]
        if not memory_manager:
            print(f"❌ {npc_name}没有记忆系统")
            return

        try:
            if memory_type:
                # 清空指定类型的记忆
                memory_manager.clear_memory_type(memory_type)
                print(f"✅ 已清空{npc_name}的{memory_type}记忆")
            else:
                # 清空所有记忆
                for mem_type in ["working", "episodic"]:
                    try:
                        memory_manager.clear_memory_type(mem_type)
                    except:
                        pass
                print(f"✅ 已清空{npc_name}的所有记忆")

        except Exception as e:
            print(f"❌ 清空{npc_name}记忆失败: {e}")

    def get_npc_affinity(self, npc_name: str, player_id: str = "player") -> Dict:
        """获取NPC对玩家的好感度信息

        Args:
            npc_name: NPC名称
            player_id: 玩家ID

        Returns:
            好感度信息字典
        """
        if not self.relationship_manager:
            return {
                "affinity": 50.0,
                "level": "熟悉",
                "modifier": "礼貌友善,正常交流,保持专业"
            }

        affinity = self.relationship_manager.get_affinity(npc_name, player_id)
        level = self.relationship_manager.get_affinity_level(affinity)
        modifier = self.relationship_manager.get_affinity_modifier(affinity)

        return {
            "affinity": affinity,
            "level": level,
            "modifier": modifier
        }

    def get_all_affinities(self, player_id: str = "player") -> Dict[str, Dict]:
        """获取所有NPC的好感度信息

        Args:
            player_id: 玩家ID

        Returns:
            所有NPC的好感度信息
        """
        if not self.relationship_manager:
            return {}

        return self.relationship_manager.get_all_affinities(player_id)

    def set_npc_affinity(self, npc_name: str, affinity: float, player_id: str = "player"):
        """设置NPC对玩家的好感度 (用于测试)

        Args:
            npc_name: NPC名称
            affinity: 好感度值 (0-100)
            player_id: 玩家ID
        """
        if not self.relationship_manager:
            print("❌ 好感度系统未初始化")
            return

        self.relationship_manager.set_affinity(npc_name, affinity, player_id)
        level = self.relationship_manager.get_affinity_level(affinity)
        print(f"✅ 已设置{npc_name}对玩家的好感度: {affinity:.1f} ({level})")

    def ingest_external_dialogue(
        self,
        npc_name: str,
        speaker: str,
        content: str,
        player_id: str = "player",
        timestamp: Optional[str] = None,
    ) -> None:
        """从外部 WebSocket 注入一条对话到工作记忆

        Args:
            npc_name: NPC 名称, 如 \"青年李白\"
            speaker: \"player\" 或 \"npc\"
            content: 对话文本内容
            player_id: 玩家 ID, 默认 \"player\"
            timestamp: 可选时间戳(ISO8601), 为空则使用当前时间
        """
        if npc_name not in self.memories:
            log_error(f"外部对话注入失败: NPC '{npc_name}' 不存在")
            return

        memory_manager = self.memories.get(npc_name)
        if not memory_manager:
            log_error(f"外部对话注入失败: NPC '{npc_name}' 没有记忆系统")
            return

        try:
            if timestamp:
                try:
                    current_time = datetime.fromisoformat(timestamp)
                except Exception:
                    current_time = datetime.now()
            else:
                current_time = datetime.now()

            if speaker == "player":
                prefix = "玩家说: "
                importance = 0.5
            else:
                # 统一视为 NPC 本人发言
                prefix = "我说: "
                importance = 0.6

            memory_manager.add_memory(
                content=f"{prefix}{content}",
                memory_type="working",
                importance=importance,
                metadata={
                    "speaker": speaker,
                    "player_id": player_id,
                    "session_id": player_id,
                    "timestamp": current_time.isoformat(),
                    "context": {
                        "interaction_type": "dialogue",
                        "npc_name": npc_name,
                        "source": "external_ws",
                    },
                },
                auto_classify=False,
            )

            log_info(
                f"🌐 外部对话已注入记忆: npc={npc_name}, "
                f"speaker={speaker}, content={content[:30]}..."
            )
        except Exception as e:
            log_error(f"外部对话注入异常: npc={npc_name}, error={e}")

# 全局单例
_npc_manager = None

def get_npc_manager() -> NPCAgentManager:
    """获取NPC管理器单例"""
    global _npc_manager
    if _npc_manager is None:
        _npc_manager = NPCAgentManager()
    return _npc_manager

