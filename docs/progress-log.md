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

### 素材提取进度（因果链模型）

| 案件 | 章节 | 类型 | 状态 |
|------|------|------|------|
| 1. 刘格被杀案 | Ch 1-19 | 伪装自杀 | ✅ 完成 |
| 2. 马萌入室抢劫杀人案 | Ch 20-43 | 入室抢劫→杀人 | ✅ 完成 |
| 3. 王立华/贴加官案 | Ch 46-64 | 窒息谋杀 | ✅ 完成 |
| 4. 赵若瑶/福利院连环奸杀案 | Ch 65-82 | 连环奸杀 | ✅ 完成 |
| 5. 唐一平/针灸复仇杀人案 | Ch 85-110 | 针灸复仇 | ✅ 完成 |
| 6. 董玉波/床底藏尸情杀案 | Ch 120-128 | 情杀藏尸 | ✅ 完成 |
| 7. 江城大案/113连环杀人案 | Ch 132-158 | 跨25年连环杀人 | ✅ 完成 |
| 8. 王福江/头孢饮酒猝死案 | Ch 162-164 | 意外死亡+抛尸 | ✅ 完成 |
| 9. 郭佳茵/一案变四案 | Ch 166-181 | 杀妻+阴婚+骗婚+囚禁 | ✅ 完成 |
| 10. 吴倩倩碎尸案/三重顶罪案 | Ch 185-207 | 先奸后杀+碎尸+三层顶罪 | ✅ 完成 |
| 11. 樊梓琨/校园霸凌复仇连环杀人案 | Ch 210-226 | 罕见病+格斗复仇连环杀人 | ✅ 完成 |
| 12. 苗贝玲/演唱会过敏投毒案 | Ch 228-237 | 偶像圈过敏原投毒+嫁祸 | ✅ 完成 |
| 13+ | Ch 238+ | 待提取 | ⏳ 待续 |

全书共802章，预计约30-40个案件。提取文档位于 `docs/case-extractions/` 目录。

### Git 最新提交

- `56effbc` - feat: case selection UI and GEN-001 dialogue integration

### 当前痛点分析

1. ~~**推理是选择题** — 不是真正的推理，是选答案~~ ✅ 已改造为证据连线拼图
2. ~~**无roguelike循环** — 没有系统点数、天赋树、道具使用~~ ✅ 天赋树已实现
3. **选择系统** — 所有分支最终汇合，选择没有实际影响
4. **属性未使用** — 观察力、审讯力等定义了但从未检定
5. **无随机性** — 案件完全写死，重玩无意义

## 2026-06-05 进度更新

### 推理板改造 ✅

将推理板从**选择题模式**改造为**证据连线拼图模式**：
- 6张证据卡片环形排列在画布上
- 玩家在卡片之间拖拽画线，构建推理链
- 连线同一对卡片可以取消连线（toggle）
- 右键点击卡片查看详细证据信息
- 提交后按正确链/额外发现/错误连线三级评分
- 提交后连线变色显示结果（金色=正确/绿色=额外发现/红色=错误）
- 支持 BBCode 富文本结果展示

改动文件：
- `src/investigation/deduction_board.gd` — 全部重写
- `src/investigation/deduction_board.tscn` — 全部重写
- `data/cases/case_001_deduction.json` — 新数据格式

### 天赋树/学习树系统 ✅

实现5系×3阶的天赋树：
- **观察系**: 细节之眼 → 微表情识别 → ★全局视野
- **审讯系**: 压迫审讯 → 心理画像 → ★读心术
- **鉴定系**: 基础鉴定 → 交叉比对 → ★一眼鉴真
- **体能系**: 耐力训练 → 追击本能 → ★铁人
- **社交系**: 人脉网络 → 线人系统 → ★权力之言

功能：
- 消耗系统点数解锁天赋
- 前置依赖检查（需先学基础才能学进阶）
- 解锁天赋自动提升对应属性
- 金色技能解锁特殊技能标记
- 从主菜单可进入学习树界面
- 确认弹窗防止误操作

改动文件：
- `data/talent_tree.json` — 天赋树数据
- `src/ui/talent_tree.tscn` — 天赋树场景
- `src/ui/talent_tree.gd` — 天赋树逻辑
- `src/autoload/game_manager.gd` — 新增天赋/技能管理方法
- `src/ui/main_menu.tscn` — 新增「学习树」按钮
- `src/ui/main_menu.gd` — 连接学习树入口

### 属性检定系统 ✅

在调查场景中实现属性检定机制：
- **检定引擎**: `soft_check()` — 基于属性和阈值计算成功率,随机roll决定通过
  - 公式: `success_rate = clamp((attribute - threshold) * 15 + 50, 10, 95)`
  - 保底10%成功率,上限95%,不存在绝对通过/失败
- **d20检定**: `attribute_check()` — roll d20 + 属性 vs 难度值（备用）
- **UI集成**: 证据分析按钮显示所需属性和阈值 `[观察力 3]`
- **视觉反馈**: 检定成功→金色闪光横幅 / 失败→红色横幅,2.5秒后淡出
- 已有的证据JSON `skill_required` 字段现在被实际使用

改动文件：
- `src/autoload/game_manager.gd` — 新增 `soft_check()`, `attribute_check()`, `modify_attribute()`
- `src/investigation/investigation_scene.gd` — 分析按钮加入检定逻辑 + 视觉反馈
- `src/investigation/investigation_scene.tscn` — 新增 CheckBanner 节点

### 道具系统 ✅

7种道具,商店可购买5种:
- **高倍放大镜** (15点) — 自动通过检定
- **录音笔** (20点) — 审讯力检定+3
- **紫外灯** (25点) — 鉴定学检定+3
- **推理直觉** (10点,消耗品) — 推理板提示
- **权威传唤令** (30点,消耗品) — 强制证人到场
- **假身份证** (35点) — 魅力检定+5
- **黑客U盘** (40点) — 自动通过数字证据检定

功能：
- 系统商店界面,用系统点数购买
- 调查场景右上角道具栏,toggle选择活跃道具
- 活跃道具对检定提供加成(降低阈值)或自动通过
- GameManager新增完整道具管理API(buy/use/remove)
- 从主菜单可进入商店

改动文件：
- `data/items.json` — 道具数据+商店配置
- `src/ui/item_shop.tscn` + `item_shop.gd` — 商店界面
- `src/ui/main_menu.tscn` + `main_menu.gd` — 新增商店入口
- `src/investigation/investigation_scene.tscn` — 新增道具栏
- `src/investigation/investigation_scene.gd` — 道具加成逻辑
- `src/autoload/game_manager.gd` — 道具管理方法

### 时间预算系统 ✅

Roguelike调查的最后一个核心机制：
- 基础预算: 480分钟(8小时),体能属性每点+10分钟
- 铁人技能额外+120分钟
- 每个热点有时间消耗(20-60分钟不等)
- 时间耗尽→强制跳转推理板
- 左上角时间栏:数字+进度条,颜色随剩余时间变化(绿→黄→红)
- 热点按钮显示时间消耗 "(30m)"

改动文件：
- `src/autoload/game_manager.gd` — 时间预算管理方法
- `src/investigation/investigation_scene.gd` — 时间消耗+UI+强制推理
- `src/investigation/investigation_scene.tscn` — 时间栏节点
- `data/scenes/case_001_apartment.json` — 添加time_cost字段

### GEN-002~010 完整数据 ✅

9个案件全部拥有完整的调查+推理数据:
- 9个场景文件(各5个热点)
- 45个证据文件(各含analysis_options+skill_required)
- 9个推理板文件(各6节点+4连线+1奖励)
- case_index.json 已更新,标记为 investigation_ready

### 存档/读档系统 ✅

支持3个存档槽位的保存/读取功能:
- 保存: 当前天数、系统点数、属性、天赋、道具、flags
- 读取: 完全恢复游戏状态
- 删除: 可删除单个存档槽
- 从主菜单进入存档/读档界面

改动文件：
- `src/autoload/game_manager.gd` — save/load/delete方法
- `src/ui/save_load.tscn` + `save_load.gd` — 存档界面
- `src/ui/main_menu.tscn` + `main_menu.gd` — 存档/读档入口

### UI/UX 修复 ✅

全面修复 UI 适配和布局问题:
- **主菜单溢出** — VBox 包裹 ScrollContainer，按钮高度缩小，不再溢出
- **窗口尺寸** — 从 1280x720 升级为 1920x1080 最大化启动
- **响应式布局** — 天赋树/商店/推理板/调查场景全部改用 anchor+offset，适应不同分辨率
- **案件选择界面** — 支持 investigation_ready 状态，可直接进入调查
- **场景路径动态化** — 调查/推理场景从 flags 读取路径，不再硬编码 case_001

改动文件：
- `project.godot` — 窗口尺寸 + 最大化模式
- `src/ui/main_menu.tscn` — VBox 改用 ScrollContainer 包裹
- `src/ui/main_menu.gd` — 路径更新
- `src/ui/talent_tree.tscn` — Scroll 改为全屏 anchor
- `src/ui/item_shop.tscn` — Scroll 改为全屏 anchor
- `src/investigation/deduction_board.tscn` — Canvas 改为全屏 anchor
- `src/investigation/investigation_scene.tscn` — 地图/热点容器改为全屏 anchor
- `src/investigation/investigation_scene.gd` — 动态场景/证据路径
- `src/investigation/deduction_board.gd` — 动态推理数据路径
- `src/ui/case_select.gd` — 支持 investigation_ready + 直接进入调查

### 场景背景系统 ✅

为10个调查场景配置背景图:
- **下载脚本** — `tools/download_scene_backgrounds.ps1`，9个案件的 Pollinations.ai 精确 prompt
- **Pollinations.ai 限流** — 从 Agent 网络 IP 返回 HTTP 402，需本地运行脚本
- **动态背景加载** — 调查场景优先加载场景JSON中的 `background` 路径
- **过程化降级** — 缺少图片时生成对应氛围的过程化背景（7种配色方案）
- **配色方案**: temple(青苔绿), apartment(灰蓝), mansion(深棕), clinic(草药绿), house(暖灰), port(深海蓝), bar(霓虹紫红)

改动文件：
- `data/scenes/*.json` — 所有10个场景文件添加 `background` 路径
- `src/autoload/theme_manager.gd` — 新增 `SCENE_PALETTES` 和增强的 `generate_crime_scene_bg()`
- `src/investigation/investigation_scene.gd` — 动态背景加载 + 场景类型推断
- `tools/download_scene_backgrounds.ps1` — 一键下载脚本

### 当前状态总结 (2026-06-05 夜)

**已实现的完整系统:**
1. ✅ 推理板（证据连线拼图）
2. ✅ 天赋树/学习树（5系×3阶）
3. ✅ 属性检定系统（soft_check + d20）
4. ✅ 道具系统（7种道具+商店）
5. ✅ 时间预算系统
6. ✅ 存档/读档系统（3槽位）
7. ✅ GEN-002~010 完整调查+推理数据（63个JSON文件）
8. ✅ UI/UX 修复（溢出、窗口、响应式、案件选择）
9. ✅ 场景背景系统（动态加载+过程化降级）
10. ✅ 案件选择界面（支持 investigation_ready 直接进入调查）

**待完成/恢复工作要点:**
- 运行 `tools/download_scene_backgrounds.ps1` 下载 Pollinations.ai 场景图
- 为 GEN-002~010 添加开场对话数据
- 案件随机生成引擎（基于因果链模板库）
- 更多 UI 润色（字体、动画过渡、提示文字）
- 考虑 GEN-002~010 的语音配音

**Godot 验证:** 4.6.3 headless 编译通过 + 运行零错误

### 设计文档

- `docs/game-concept.md` — 游戏概念
- `docs/technical-architecture.md` — 技术架构
- `docs/voice-acting-roadmap.md` — 语音系统路线图
- `docs/roguelike-investigation-design.md` — Roguelike破案机制设计方案
- `docs/material-library-design.md` — 素材库设计（因果链模型）
- `docs/case-extractions/` — 案件因果链提取文档（已完成10个案件）
