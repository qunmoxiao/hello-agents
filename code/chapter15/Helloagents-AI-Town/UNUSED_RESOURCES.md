# 未使用的资源和代码清单

本文档列出了项目中未被使用的资源、脚本和文件，可以安全删除。

## 📋 脚本文件（Godot）

### 1. `helloagents-ai-town/scripts/hidden_item.gd`
- **状态**: ❌ 未使用
- **原因**: 
  - 没有任何场景文件引用此脚本
  - 代码中没有通过 `preload` 或 `load` 加载此脚本
  - 虽然脚本功能完整（用于收集隐藏物品/线索），但项目中未实际使用
- **建议**: 如果未来需要隐藏物品收集功能，可以保留；否则可以删除

### 2. `helloagents-ai-town/scripts/shortcut_hint_ui.gd`
- **状态**: ❌ 未使用
- **原因**: 
  - 没有对应的场景文件（`shortcut_hint_ui.tscn` 不存在）
  - 主场景中使用的是 `controls_hint_ui.tscn`，而不是 `shortcut_hint_ui`
  - 脚本本身功能与 `controls_hint_ui.gd` 类似，属于重复实现
- **建议**: 可以安全删除

## 📋 后端文件（Python）

### 1. `backend/external_api_examples.py`
- **状态**: ⚠️ 示例文件（未实际使用）
- **原因**: 
  - 这是一个示例/文档文件，展示如何使用外部API钩子
  - 代码中没有任何地方导入或使用此文件
  - 所有钩子注册代码都被注释掉了
- **建议**: 
  - 如果作为文档参考，可以保留
  - 如果不需要参考，可以删除

### 2. `backend/view_logs.py`
- **状态**: ✅ 工具脚本（保留）
- **原因**: 
  - 这是一个独立的命令行工具，用于查看日志
  - 虽然不在主程序中使用，但作为开发/调试工具很有用
- **建议**: **保留**（用于调试和日志查看）

## 🖼️ 资源文件（未使用的图片）

### 角色图片（Characters）

以下角色图片未被任何场景引用：

1. `helloagents-ai-town/assets/characters/character_4.png`
   - 只有 character_1, character_2, character_3 被使用

2. `helloagents-ai-town/assets/characters/image.png`
   - 未被引用

3. `helloagents-ai-town/assets/characters/image(1).png`
   - 未被引用

4. `helloagents-ai-town/assets/characters/image-removebg-preview(1).png`
   - 未被引用

5. `helloagents-ai-town/assets/characters/中年李白_2_-removebg-preview.png`
   - 只有 `中年李白-removebg-preview.png` 被使用（注意：没有 `_2_`）

### 场景图片（Interiors）

以下场景图片可能未被使用（需要进一步确认）：

1. `helloagents-ai-town/assets/interiors/1_Generic_48x48.png`
   - 未在场景文件中找到引用

2. `helloagents-ai-town/assets/interiors/13_Conference_Hall_48x48.png`
   - 未在场景文件中找到引用

3. `helloagents-ai-town/assets/interiors/Japanese_Home_1_preview_48x48.png`
   - 未在场景文件中找到引用

4. `helloagents-ai-town/assets/interiors/Room_Builder_48x48.png`
   - 未在场景文件中找到引用

5. `helloagents-ai-town/assets/interiors/中年.png`
   - 未在场景文件中找到引用

6. `helloagents-ai-town/assets/interiors/城镇.png`
   - 未在场景文件中找到引用

7. `helloagents-ai-town/assets/interiors/小鲸鱼.png`
   - 未在场景文件中找到引用

8. `helloagents-ai-town/assets/interiors/老年.png`
   - 未在场景文件中找到引用

**注意**: 这些图片可能通过代码动态加载，建议在删除前先搜索代码中的字符串引用。

## ✅ 正在使用的文件（供参考）

### 脚本文件
- ✅ `pause_menu.gd` - 被 `main.gd` 动态加载和使用
- ✅ `batch_generator.py` - 被 `state_manager.py` 使用
- ✅ 所有 AutoLoad 脚本都在 `project.godot` 中注册

### 资源文件
- ✅ `character_1.png` - 在 `player.tscn` 中使用
- ✅ `character_2.png` - 在 `npc.tscn` 中使用
- ✅ `character_3.png` - 在 `main.tscn` 中使用
- ✅ `老年李白-removebg-preview.png` - 在 `main.tscn` 中使用
- ✅ `青年李白-removebg-preview.png` - 在 `main.tscn` 中使用
- ✅ `中年李白-removebg-preview.png` - 在 `main.tscn` 中使用
- ✅ `背景1.png` - 在 `main.tscn` 中使用
- ✅ `好未来.png` - 在 `main.tscn` 中使用
- ✅ `7-2011101536234C.jpg` - 在 `main.tscn` 中使用
- ✅ `答题ui-removebg-preview.png` - 在 `quiz_ui.tscn` 中使用

## 🗑️ 删除建议

### 可以安全删除的文件：

1. **脚本文件**:
   - `helloagents-ai-town/scripts/hidden_item.gd` 及其 `.uid` 文件
   - `helloagents-ai-town/scripts/shortcut_hint_ui.gd` 及其 `.uid` 文件

2. **资源文件**（建议先备份）:
   - `helloagents-ai-town/assets/characters/character_4.png` 及其 `.import` 文件
   - `helloagents-ai-town/assets/characters/image.png` 及其 `.import` 文件
   - `helloagents-ai-town/assets/characters/image(1).png` 及其 `.import` 文件
   - `helloagents-ai-town/assets/characters/image-removebg-preview(1).png` 及其 `.import` 文件
   - `helloagents-ai-town/assets/characters/中年李白_2_-removebg-preview.png` 及其 `.import` 文件

3. **示例文件**（可选）:
   - `backend/external_api_examples.py`（如果不需要作为参考文档）

### 需要进一步确认的文件：

- 场景图片（interiors）中的未使用文件，建议先搜索代码中是否有动态加载

## 📝 注意事项

1. **删除前备份**: 建议在删除前先创建备份，以防误删重要资源
2. **.import 文件**: 删除资源文件时，Godot 会自动处理 `.import` 文件，但也可以手动删除
3. **.uid 文件**: 删除脚本文件时，建议同时删除对应的 `.uid` 文件
4. **动态加载**: 某些资源可能通过代码动态加载，删除前建议搜索代码中的字符串引用

## 🔍 如何验证文件是否被使用

1. 在 Godot 编辑器中，使用 "查找资源引用" 功能
2. 使用 grep 搜索文件名（不含扩展名）
3. 检查场景文件（.tscn）中的资源引用
4. 检查代码中的 `load()` 和 `preload()` 调用

