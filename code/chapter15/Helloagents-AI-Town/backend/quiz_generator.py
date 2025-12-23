"""基于 NPC 设定与历史对话的动态答题生成模块

本模块仅提供题目生成的骨架接口, 不直接耦合具体的 LLM 提示词与调用细节。
返回结构需与 contracts/quizzes-generated.yaml 中的模式以及
前端 Godot `quiz_manager.gd` / `quiz_ui.gd` 期望字段保持一致。
"""

from typing import List, Optional
import json

from hello_agents import HelloAgentsLLM

from models import GeneratedQuizResponse, GeneratedQuestion
from agents import NPC_ROLES, get_npc_manager


class QuizGenerator:
    """答题生成器

    职责:
    - 组装 NPC 设定与历史对话为提示词上下文
    - 调用 HelloAgentsLLM 生成题目
    - 解析 JSON 并返回 GeneratedQuizResponse
    """

    def __init__(self) -> None:
        try:
            # 题目本身文本不需要特别长, 适当控制 max_tokens
            self.llm = HelloAgentsLLM(max_tokens=1500)
            self.enabled = True
        except Exception as exc:  # pragma: no cover - 防御性降级
            print(f"❌ 初始化 QuizGenerator 失败, 将返回空题目: {exc}")
            self.llm = None
            self.enabled = False

    # ==================== 对外主接口 ====================

    def generate_quiz(
        self,
        npc_name: str,
        count: int = 3,
        quiz_id: Optional[str] = None,
    ) -> GeneratedQuizResponse:
        """为指定 NPC 生成一组答题题目

        当 LLM 或解析失败时, 会返回 questions 为空的结果,
        由前端根据规范回退到本地题库。
        """
        title = f"{npc_name}知识问答（动态生成）"
        real_quiz_id = quiz_id or ""

        # 若 LLM 不可用, 直接返回空题目, 由前端回退
        if not self.enabled or self.llm is None:
            return GeneratedQuizResponse(
                quiz_id=real_quiz_id,
                npc_name=npc_name,
                title=title,
                questions=[],
            )

        try:
            npc_info = NPC_ROLES.get(npc_name)
            if not npc_info:
                # 未知 NPC 直接返回空结果
                return GeneratedQuizResponse(
                    quiz_id=real_quiz_id,
                    npc_name=npc_name,
                    title=title,
                    questions=[],
                )

            # 1. 构建上下文: NPC 设定 + 历史对话记忆
            npc_manager = get_npc_manager()
            memories = npc_manager.get_npc_memories(npc_name, limit=8)
            prompt = self._build_prompt(npc_name, npc_info, memories, count)

            # 调试输出提示词，方便验证是否包含历史对话
            print("\n" + "=" * 40)
            print(f"🧩 QuizGenerator 提示词预览 - NPC: {npc_name}, quiz_id: {real_quiz_id}")
            print(prompt)
            print("=" * 40 + "\n")

            # 2. 调用 LLM 生成题目(JSON 数组)
            raw = self.llm.invoke(
                [
                    {
                        "role": "system",
                        "content": "你是一个游戏出题助手, 需要基于给定的 NPC 设定和历史对话, 为该 NPC 生成多选题。",
                    },
                    {"role": "user", "content": prompt},
                ]
            )

            # 3. 解析并校验题目
            questions = self._parse_and_validate_questions(raw, count)

            return GeneratedQuizResponse(
                quiz_id=real_quiz_id,
                npc_name=npc_name,
                title=title,
                questions=questions,
            )
        except Exception as exc:  # pragma: no cover - 防御性降级
            print(f"❌ 生成答题失败: {exc}")
            return GeneratedQuizResponse(
                quiz_id=real_quiz_id,
                npc_name=npc_name,
                title=title,
                questions=[],
            )

    # ==================== 内部工具方法 ====================

    def _build_prompt(
        self,
        npc_name: str,
        npc_info: dict,
        memories: List[dict],
        count: int,
    ) -> str:
        """根据 NPC 设定与记忆构造提示词"""
        profile = f"""名字: {npc_name}
时期: {npc_info.get('period', npc_info.get('title', ''))}
背景: {npc_info.get('background', '')}
性格: {npc_info.get('personality', '')}
位置: {npc_info.get('location', '')}
当前活动: {npc_info.get('activity', '')}
"""

        dialogue_lines: List[str] = []
        for mem in memories:
            content = mem.get("content", "")
            if not content:
                continue
            dialogue_lines.append(content)

        dialogue_block = "\n".join(
            f"{idx+1}. {line}" for idx, line in enumerate(dialogue_lines)
        )

        prompt = f"""你是一个游戏出题助手, 需要根据下面这位 NPC 的设定和与玩家的历史对话, 为该 NPC 生成多选题。

【NPC信息】
{profile}

【历史对话节选】(如果为空, 则更多依赖 NPC 设定出题)
{dialogue_block if dialogue_block else "暂无历史对话"}

【出题要求】
1. 一共生成 {count} 道多选题。
2. 题目内容要能从 NPC 的形象、经历或历史对话中“推导出来”, 不要完全无中生有。
3. 题目以考察玩家对 NPC 形象、情绪和对话含义的理解为主, 可以少量包含记忆型题目。
4. 每道题使用如下字段:
   - "type": "story" 或 "poem" 或 "knowledge" 等
   - "question": 题干文本
   - "options": 4个备选项, 字符串数组
   - "correct": 正确选项在 options 中的下标(从0开始)
5. 严格以 JSON 数组形式输出, 不要添加任何注释或额外文本。

【输出格式示例】
[
  {{
    "type": "story",
    "question": "...",
    "options": ["...", "...", "...", "..."],
    "correct": 0
  }}
]

现在请生成题目:
"""
        return prompt

    def _parse_and_validate_questions(
        self, raw: str, count: int
    ) -> List[GeneratedQuestion]:
        """解析 LLM 响应并进行基本校验"""
        try:
            # 尝试直接解析为 JSON
            data = json.loads(raw)
        except json.JSONDecodeError:
            # 尝试从响应中截取 JSON 数组部分
            start = raw.find("[")
            end = raw.rfind("]") + 1
            if start == -1 or end <= start:
                return []
            try:
                data = json.loads(raw[start:end])
            except Exception:
                return []

        if not isinstance(data, list):
            return []

        questions: List[GeneratedQuestion] = []
        for item in data:
            if not isinstance(item, dict):
                continue
            try:
                # 基本字段存在性校验
                if "question" not in item or "options" not in item or "correct" not in item:
                    continue
                options = item.get("options") or []
                if not isinstance(options, list) or len(options) < 2:
                    continue
                correct = int(item.get("correct", 0))
                if correct < 0 or correct >= len(options):
                    continue

                q = GeneratedQuestion(
                    type=item.get("type", "story"),
                    question=str(item["question"]),
                    options=[str(opt) for opt in options],
                    correct=correct,
                )
                questions.append(q)
            except Exception:
                continue

            if len(questions) >= count:
                break

        return questions


_quiz_generator: Optional[QuizGenerator] = None


def get_quiz_generator() -> QuizGenerator:
    """获取 QuizGenerator 单例

    便于在 FastAPI 路由等位置复用同一生成器实例。
    """
    global _quiz_generator
    if _quiz_generator is None:
        _quiz_generator = QuizGenerator()
    return _quiz_generator


