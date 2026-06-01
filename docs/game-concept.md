# Game Concept: 神探陈益 Roguelike

## Core Concept
Roguelike + Detective investigation game based on the novel "神探陈益" by 勤奋的关关.

## Source Material
- Novel: 神探陈益 (Detective Chen Yi)
- Author: 勤奋的关关
- Platform: 阅文集团 (QQ阅读)
- Chapters: 808 + extras (completed)
- Genre: Urban crime/detective fiction
- Synopsis: World-class detective Chen Yi transmigrates to a parallel world. Starting as a murder suspect, he rises through police ranks (from suspect → detective → deputy captain → special case unit leader → national-level investigator) solving bizarre cases using forensic science, psychological profiling, and logical deduction.

## Game Structure (Initial Design)

### Two Modes
1. **Investigation Mode (破案流程)**: Active case solving
2. **Daily Life Mode (非破案流程)**: Day-by-day progression with choices and branching storylines

### Daily Life Mode
- Time advances day by day
- Player makes choices that trigger different story events
- Choices affect relationships, reputation, and available cases

### Investigation Mode
- Cases are lightweight randomly-generated combinations (victim/suspect/clues/method)
- Player uses attributes and items to assist reasoning and case-solving
- Successful deduction earns "enhancement points" from the System

## Roguelike Elements

### 1. Lightweight Case Random Generation
- Cases are assembled from randomized components (not fully scripted 808 chapters)
- Each playthrough features different case combinations

### 2. Daily Life Random Events
- Random events during non-investigation days
- Can yield random attributes or items
- Choices affect story branches

### 3. The System (穿越系统)
- MC is a transmigrator with a "System" (cheat/golden finger)
- Performing deduction activities earns enhancement points
- Points can be exchanged for attribute boosts and items
- This is the core progression mechanic

### 4. Attributes & Items → Assist Investigation (TBD - needs deep design)
- How exactly do attributes (e.g., observation, charisma, forensics) affect case-solving?
- How do items provide mechanical advantages during investigation?
- This is the KEY design challenge

## Visual Style

### Daily Life Mode → Visual Novel
- Character portraits + dialogue + choice-based narrative
- Day-by-day progression with branching events
- Random encounters that yield items/attributes

### Investigation Mode → "Unheard" (疑案追声) Style + Point-and-Click Hybrid
- Top-down/isometric map of crime scene
- **Hybrid investigation approach:**
  - Direct scene examination: click on physical evidence, documents, objects
  - Surveillance playback: review CCTV footage, audio recordings for specific time windows
  - NOT full timeline replay like Unheard — more targeted "check this camera for this time"
- Skills and items unlock special actions:
  - Forensic analysis (鉴定)
  - Lab testing
  - Psychological profiling
  - Can command teammates to perform tasks (e.g., "send colleague to run DNA test")
  - Use identity/authority to order lab work, request records, etc.

### Team Management Mode
- Click-based interface to configure team members
- Each colleague has: talents, attributes, specializations
- Roguelike meta-progression: team grows across runs

### Career Progression System
- Virtual nationwide leaderboard with AI opponents
- Compete on case solve rate, accuracy, speed
- Must exceed performance thresholds to advance rank
- Rank tiers: District (区级) → City (市级) → Province (省级) → National (国家级)
- Higher ranks unlock harder cases, better teammates, more resources

## Gameplay Loop

```
┌─────────────────────────────────────────┐
│            DAILY LIFE (Visual Novel)     │
│  ├─ Wake up → random events             │
│  ├─ Interact with colleagues/NPCs       │
│  ├─ Manage team (talents/attributes)    │
│  ├─ Use System: exchange points → items │
│  └─ Check leaderboard / career progress │
├─────────────────────────────────────────┤
│         CASE ASSIGNED                   │
├─────────────────────────────────────────┤
│        INVESTIGATION (疑案追声 style)    │
│  ├─ Enter crime scene map               │
│  ├─ Click to examine: evidence, audio,  │
│  │   video, documents, objects          │
│  ├─ Use skills/items for analysis       │
│  ├─ Command teammates for tasks         │
│  ├─ Interrogate suspects                │
│  ├─ Deduce and present conclusion       │
│  └─ Earn enhancement points from System │
├─────────────────────────────────────────┤
│         CASE RESULT                     │
│  ├─ Success → points, rank progress     │
│  ├─ Partial → some points, reputation   │
│  └─ Failure → ???  (TBD)               │
├─────────────────────────────────────────┤
│       RANK EVALUATION                   │
│  └─ Pass threshold → promote to next    │
│     level, unlock new cases/teammates   │
└─────────────────────────────────────────┘
```

## First Prototype Scope

**Target: 1 day of daily life + 1 simple investigation case**

Purpose: Validate the two-mode switching mechanic
- Daily life VN: 1 morning sequence with random event + system interaction
- Investigation: 1 crime scene with ~5 clickable evidence items + 1 surveillance clip + 1 interrogation
- Minimal team management (1-2 teammates)
- Basic System: earn points from successful deduction, exchange for 1 attribute boost

## Open Questions
- Failure state: what happens when you fail a case?
- Case generation algorithm: how are random cases assembled?
- Attribute list: what specific attributes exist?
- Item taxonomy: consumable vs permanent? case-specific?
- How closely to follow original novel vs original content
- Teammate AI: do they act autonomously or only on command?
- Art asset pipeline: who creates character portraits and scene art?
