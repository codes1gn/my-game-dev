# 开发进度日志

## 2026-06-02 进度总结

### 已完成功能

| 功能 | 状态 | 说明 |
|------|------|------|
| Godot项目骨架 | ✅ 完成 | GDScript, Autoload架构 |
| 主菜单 | ✅ 完成 | 暗色侦探主题 |
| VN引擎（视觉小说） | ✅ 完成 | 对话、选择、肖像、打字机效果 |
| 调查场景 | ✅ 完成 | 可点击热点、证据弹窗 |
| 推理板 | ✅ 完成 | 证据展示、问答评分 |
| 结局分支 | ✅ 完成 | 基于flag的正确/部分正确结局 |
| AI美术 | ✅ 完成 | Pollinations.ai生成人物肖像和场景 |
| UI主题系统 | ✅ 完成 | ThemeManager Autoload |
| BGM音乐系统 | ✅ 完成 | 4首BGM + 交叉淡入淡出 |
| 语音配音系统 | ✅ 完成 | Edge TTS, 98条语音, 6种角色声音 |
| Case 1 完整流程 | ✅ 完成 | 开场→调查→推理→结局可跑通 |

### 已完成数据/资源

| 资源 | 数量 | 说明 |
|------|------|------|
| 对话JSON | 3个文件 | opening, investigation, conclusion |
| 证据JSON | 5个文件 | 5种关键证据 |
| 推理板数据 | 1个文件 | 5道推理题 |
| BGM音乐 | 4首 | CC0授权, OGG/MP3 |
| 语音文件 | 98个MP3 | Edge TTS生成 |
| 人物肖像 | 5张 | AI生成 JPG |
| 场景背景 | 2张 | AI生成 JPG |
| 小说全文 | ~6.3MB | 742章完整内容, 用于素材拆解 |

### 架构文件

| Autoload | 文件 | 职责 |
|----------|------|------|
| EventBus | event_bus.gd | 全局事件总线 |
| GameManager | game_manager.gd | 游戏状态、玩家数据、flag管理 |
| ThemeManager | theme_manager.gd | UI主题、外部图片加载 |
| AudioManager | audio_manager.gd | BGM交叉淡入淡出 + 语音播放 |

### Git 最新提交

- `c41000a` - feat: add BGM music system and Edge TTS character voice acting for Case 1

### 当前痛点分析

1. **选择系统** — 所有分支最终汇合，选择没有实际影响
2. **属性未使用** — 观察力、审讯力等定义了但从未检定
3. **推理是选择题** — 不是真正的推理，是选答案
4. **无roguelike循环** — 没有系统点数、天赋树、道具使用
5. **无随机性** — 案件完全写死，重玩无意义

### 下一步计划

1. **拆解小说案件素材库** — 从742章中识别案件边界，提取关键要素
2. **实现天赋树/学习树** — 属性升级 + 技能解锁 + 金色强力技能
3. **实现道具系统** — 调查中可使用道具获取额外信息
4. **改造推理板** — 从选择题改为证据连线拼图
5. **实现属性检定** — 调查/审讯时根据属性决定信息量
6. **实现显式反馈** — 检定成功/技能触发时的视觉音效提示
7. **实现时间预算** — 调查阶段有限时间，逼迫选择

### 设计文档

- `docs/game-concept.md` — 游戏概念
- `docs/technical-architecture.md` — 技术架构
- `docs/voice-acting-roadmap.md` — 语音系统路线图
- `docs/roguelike-investigation-design.md` — Roguelike破案机制设计方案（本次新建）
