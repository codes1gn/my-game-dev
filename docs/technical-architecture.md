# Technical Architecture — 神探陈益 Roguelike Detective

## Design Principles

1. **Data-driven**: All content (dialogue, cases, evidence, characters) lives in JSON/resource files, not in code
2. **Modular**: Each system (VN, Investigation, Team, System) is an independent scene/module
3. **Extensible**: Adding a new case = adding data files, not modifying engine code
4. **Separation of concerns**: Game logic ↔ Presentation ↔ Data are cleanly separated

## Project Structure

```
my-game-dev/
├── project.godot
├── addons/
│   └── godot-runtime-bridge/        # GRB addon
├── src/
│   ├── autoload/                     # Global singletons
│   │   ├── game_manager.gd           # Master state machine
│   │   ├── save_manager.gd           # Save/load system
│   │   ├── event_bus.gd              # Global signal bus
│   │   └── system_manager.gd         # "穿越系统" points & exchange
│   ├── vn/                           # Visual Novel (Daily Life) module
│   │   ├── vn_scene.tscn             # VN display scene
│   │   ├── vn_scene.gd               # VN runtime engine
│   │   ├── dialogue_box.tscn         # Reusable dialogue UI
│   │   ├── dialogue_box.gd
│   │   ├── choice_panel.tscn         # Choice selection UI
│   │   ├── choice_panel.gd
│   │   └── portrait_display.gd       # Character portrait manager
│   ├── investigation/                # Investigation module
│   │   ├── investigation_scene.tscn  # Crime scene map
│   │   ├── investigation_scene.gd    # Investigation runtime
│   │   ├── evidence_popup.tscn       # Evidence detail viewer
│   │   ├── evidence_popup.gd
│   │   ├── surveillance_player.tscn  # Surveillance clip playback
│   │   ├── surveillance_player.gd
│   │   ├── interrogation_scene.tscn  # Interrogation interface
│   │   ├── interrogation_scene.gd
│   │   └── deduction_board.tscn      # Final deduction / conclusion
│   ├── team/                         # Team management module
│   │   ├── team_scene.tscn
│   │   ├── team_scene.gd
│   │   └── teammate_card.tscn        # Individual teammate config
│   ├── career/                       # Career progression module
│   │   ├── career_scene.tscn
│   │   ├── career_scene.gd
│   │   └── leaderboard.tscn
│   ├── ui/                           # Shared UI components
│   │   ├── main_menu.tscn
│   │   ├── hud.tscn                  # In-game HUD
│   │   ├── inventory_panel.tscn      # Items display
│   │   ├── status_panel.tscn         # Attributes display
│   │   └── transition.tscn           # Scene transition effects
│   └── common/                       # Shared utilities
│       ├── enums.gd                  # Global enums
│       └── utils.gd                  # Utility functions
├── data/                             # ALL game content (data-driven)
│   ├── characters/                   # Character definitions
│   │   ├── chen_yi.json
│   │   ├── zhou_yebin.json
│   │   └── _schema.json              # Character data schema
│   ├── cases/                        # Case definitions
│   │   ├── case_001_liu_ge.json      # Case 1: Liu Ge murder
│   │   └── _schema.json              # Case data schema
│   ├── dialogue/                     # VN dialogue scripts
│   │   ├── day_001.json              # Day 1 dialogue tree
│   │   └── _schema.json
│   ├── evidence/                     # Evidence item definitions
│   │   ├── case_001/
│   │   │   ├── evidence_001.json
│   │   │   └── evidence_002.json
│   │   └── _schema.json
│   ├── scenes/                       # Crime scene map definitions
│   │   ├── case_001_apartment.json   # Scene layout + hotspots
│   │   └── _schema.json
│   ├── items/                        # System items
│   │   └── _schema.json
│   ├── attributes/                   # Attribute definitions
│   │   └── _schema.json
│   └── events/                       # Random daily events
│       ├── pool_common.json
│       └── _schema.json
├── assets/                           # Art, audio, fonts
│   ├── portraits/                    # Character portraits
│   ├── scenes/                       # Crime scene background images
│   ├── evidence/                     # Evidence item images
│   ├── ui/                           # UI elements
│   ├── audio/                        # Music, SFX, voice clips
│   └── fonts/
└── docs/
    ├── game-concept.md
    └── technical-architecture.md     # This file
```

## State Machine (GameManager)

```
                    ┌──────────────┐
                    │  MAIN_MENU   │
                    └──────┬───────┘
                           │ New Game / Load
                           ▼
                    ┌──────────────┐
             ┌──────│  DAILY_LIFE  │──────┐
             │      │   (VN Mode)  │      │
             │      └──────┬───────┘      │
             │             │              │
             │      Case Assigned         │ Open Team/Career
             │             │              │
             │             ▼              ▼
             │      ┌──────────────┐  ┌──────────────┐
             │      │ INVESTIGATION│  │ TEAM_MANAGE  │
             │      │  (Map Mode)  │  └──────┬───────┘
             │      └──────┬───────┘         │
             │             │                 │ Back
             │             │                 │
             │      ┌──────┴───────┐         │
             │      │              │         │
             │      ▼              ▼         │
             │  ┌────────┐  ┌──────────┐     │
             │  │INTERROG │  │DEDUCTION │     │
             │  │ ATION   │  │  BOARD   │     │
             │  └────┬────┘  └────┬─────┘     │
             │       │            │            │
             │       └─────┬──────┘            │
             │             │                   │
             │      Case Complete              │
             │             │                   │
             │             ▼                   │
             │      ┌──────────────┐           │
             │      │ CASE_RESULT  │           │
             │      │  (Score/Pts) │           │
             │      └──────┬───────┘           │
             │             │                   │
             └─────────────┴───────────────────┘
                    Return to Daily Life
```

### State Transitions (game_manager.gd)

```
enum GameState {
    MAIN_MENU,
    DAILY_LIFE,       # VN mode
    INVESTIGATION,    # Crime scene map
    INTERROGATION,    # Suspect questioning
    DEDUCTION,        # Final deduction board
    CASE_RESULT,      # Score and rewards
    TEAM_MANAGE,      # Team configuration
    CAREER_VIEW,      # Leaderboard and rank
    SYSTEM_SHOP,      # Exchange points for items/attributes
}
```

## Data Schemas

### Character Schema (`data/characters/_schema.json`)

```json
{
  "id": "chen_yi",
  "name": "陈益",
  "name_en": "Chen Yi",
  "role": "protagonist",
  "title": "刑警",
  "rank": "district",
  "portrait": "res://assets/portraits/chen_yi.png",
  "attributes": {
    "observation": 8,
    "interrogation": 9,
    "forensics": 7,
    "psychology": 9,
    "fitness": 6,
    "charisma": 7
  },
  "talents": ["criminal_profiling", "micro_expression"],
  "bio": "穿越到平行世界的世界级侦探..."
}
```

### Case Schema (`data/cases/_schema.json`)

```json
{
  "id": "case_001",
  "title": "刘格命案",
  "title_en": "Liu Ge Murder Case",
  "difficulty": 1,
  "rank_required": "district",
  "summary": "刘格在公寓中被害，陈益从嫌疑人到参与侦查",
  "victim": {
    "character_id": "liu_ge",
    "cause_of_death": "TBD",
    "location": "apartment"
  },
  "suspects": ["fu_linwang", "suspect_b", "suspect_c"],
  "true_culprit": "TBD",
  "scenes": ["case_001_apartment"],
  "evidence_ids": ["ev_001", "ev_002", "ev_003", "ev_004", "ev_005"],
  "dialogue_file": "data/dialogue/case_001_investigation.json",
  "phases": [
    {
      "id": "phase_1",
      "name": "现场勘查",
      "type": "investigation",
      "scene_id": "case_001_apartment",
      "required_evidence": ["ev_001", "ev_002"]
    },
    {
      "id": "phase_2",
      "name": "审讯付林旺",
      "type": "interrogation",
      "target": "fu_linwang",
      "dialogue_file": "data/dialogue/case_001_interrogation_fu.json"
    },
    {
      "id": "phase_3",
      "name": "监控分析",
      "type": "surveillance",
      "clip_id": "surveillance_001"
    },
    {
      "id": "phase_4",
      "name": "最终推理",
      "type": "deduction",
      "required_evidence": ["ev_001", "ev_002", "ev_003", "ev_004"]
    }
  ],
  "scoring": {
    "max_points": 100,
    "evidence_found_weight": 0.3,
    "interrogation_quality_weight": 0.3,
    "deduction_accuracy_weight": 0.4
  }
}
```

### Dialogue Schema (`data/dialogue/_schema.json`)

```json
{
  "id": "day_001",
  "type": "vn_dialogue",
  "nodes": [
    {
      "id": "start",
      "speaker": "narrator",
      "text": "清晨，陈益从梦中醒来...",
      "next": "node_2"
    },
    {
      "id": "node_2",
      "speaker": "chen_yi",
      "text": "又是新的一天。",
      "portrait_emotion": "neutral",
      "next": "choice_1"
    },
    {
      "id": "choice_1",
      "type": "choice",
      "prompt": "今天先做什么？",
      "options": [
        {
          "text": "去办公室看案件",
          "next": "node_office",
          "condition": null
        },
        {
          "text": "找同事聊天",
          "next": "node_chat",
          "condition": null
        },
        {
          "text": "使用系统",
          "next": "node_system",
          "condition": {"system_points_gte": 10}
        }
      ]
    }
  ]
}
```

### Evidence Schema (`data/evidence/_schema.json`)

```json
{
  "id": "ev_001",
  "case_id": "case_001",
  "name": "现场足迹",
  "description": "案发现场门口发现的泥印足迹",
  "type": "physical",
  "image": "res://assets/evidence/case_001/footprint.png",
  "discovery_location": {"scene": "case_001_apartment", "hotspot": "entrance"},
  "analysis_options": [
    {
      "action": "basic_examine",
      "result": "男性鞋印，约42码，鞋底花纹为运动鞋",
      "skill_required": null
    },
    {
      "action": "forensic_analysis",
      "result": "泥土成分含特定地区黏土，与嫌疑人A住所附近土质一致",
      "skill_required": {"forensics": 5},
      "item_required": null
    },
    {
      "action": "lab_test",
      "result": "检测到微量血迹混入泥土",
      "skill_required": null,
      "item_required": "forensic_kit",
      "teammate_can_do": true,
      "time_cost": 2
    }
  ],
  "relevance": {
    "suspects_implicated": ["suspect_a"],
    "deduction_tags": ["location_link", "physical_evidence"]
  }
}
```

### Scene Map Schema (`data/scenes/_schema.json`)

```json
{
  "id": "case_001_apartment",
  "name": "刘格公寓",
  "background": "res://assets/scenes/apartment_topdown.png",
  "dimensions": {"width": 960, "height": 540},
  "hotspots": [
    {
      "id": "entrance",
      "label": "门口",
      "rect": {"x": 50, "y": 400, "w": 80, "h": 60},
      "evidence_ids": ["ev_001"],
      "interaction": "examine"
    },
    {
      "id": "living_room",
      "label": "客厅",
      "rect": {"x": 300, "y": 200, "w": 200, "h": 150},
      "evidence_ids": ["ev_002", "ev_003"],
      "interaction": "examine"
    },
    {
      "id": "surveillance_monitor",
      "label": "监控录像",
      "rect": {"x": 700, "y": 100, "w": 60, "h": 40},
      "evidence_ids": [],
      "interaction": "surveillance",
      "clip_id": "surveillance_001"
    }
  ]
}
```

## Module Communication

All modules communicate via the **EventBus** singleton (signal-based, decoupled):

```
EventBus signals:
  - game_state_changed(old_state, new_state)
  - dialogue_started(dialogue_id)
  - dialogue_ended(dialogue_id)
  - choice_made(choice_id, option_index)
  - evidence_discovered(evidence_id)
  - evidence_analyzed(evidence_id, analysis_type, result)
  - interrogation_started(suspect_id)
  - interrogation_ended(suspect_id, quality_score)
  - deduction_submitted(case_id, answers: Dictionary)
  - case_completed(case_id, score, points_earned)
  - system_points_changed(old_value, new_value)
  - attribute_changed(attribute_name, old_value, new_value)
  - item_acquired(item_id)
  - item_used(item_id)
  - day_advanced(new_day_number)
  - random_event_triggered(event_id)
  - teammate_assigned(teammate_id, task)
  - teammate_task_completed(teammate_id, task, result)
  - rank_changed(old_rank, new_rank)
```

## Extensibility Points

### Adding a New Case
1. Create `data/cases/case_NNN.json` following case schema
2. Create evidence files in `data/evidence/case_NNN/`
3. Create dialogue files in `data/dialogue/case_NNN_*.json`
4. Create scene files in `data/scenes/case_NNN_*.json`
5. Add scene background image to `assets/scenes/`
6. **No code changes required** — GameManager auto-discovers cases from data/

### Adding a New Character
1. Create `data/characters/character_id.json`
2. Add portrait images to `assets/portraits/`
3. Reference in case/dialogue files

### Future: Random Case Generation
- Cases will be assembled from modular components (TBD - secret mechanism from user)
- Data schema already supports this: victim/suspects/evidence are referenced by ID
- A generator module can compose new case JSONs from template pieces

## Tech Stack Summary

| Component | Technology |
|---|---|
| Engine | Godot 4.6 |
| Language | GDScript |
| Data Format | JSON (all game content) |
| AI Bridge | GRB (Godot Runtime Bridge) via MCP |
| Version Control | Git + GitHub |
| AI Agent | Cursor IDE |
