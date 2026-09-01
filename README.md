# Adobe Animate → Godot 4 Importer Plugin (AATTAAI)

A powerful Godot 4 plugin for importing texture atlases and cut-out / symbol animations exported from Adobe Animate into clean, modular Godot scenes. Features a full `AnimationPlayer` setup, per-part transforms, dynamic Z-ordering, an advanced Visual Controller (`AATTAIController`) for seamless skin/slot equipment swapping, an interactive viewport preview with coordinate/floor grids, animation filtering, and non-destructive incremental scene updating.

---

## Table of Contents
- [Critical Adobe Animate Setup Requirements](#-critical-adobe-animate-setup-requirements)
- [Key Features](#key-features)
- [Installation](#installation)
- [Usage — Via Editor Menu](#usage--via-editor-menu)
  - [1. Importer Window Overview](#1-importer-window-overview)
  - [2. Animation Checklist & Fast Search (80+ Animations)](#2-animation-checklist--fast-search-80-animations)
  - [3. Incremental Scene Update vs Fresh Import](#3-incremental-scene-update-vs-fresh-import)
  - [4. Viewport Preview with Origin & Floor Grid](#4-viewport-preview-with-origin--floor-grid)
- [Visual Controller & Equipment API (AATTAIController)](#visual-controller--equipment-api-aattaicontroller)
  - [Global Reskin / Texture Swap](#global-reskin--texture-swap)
  - [Slot-Based Reskin (Weapon / Armor / Cosmetic)](#slot-based-reskin-weapon--armor--cosmetic)
  - [Equipping Custom Node / VFX / Hitbox](#equipping-custom-node--vfx--hitbox)
  - [Animation Playback & Signal Relays](#animation-playback--signal-relays)
- [Usage — With AnimationTree (BlendTree)](#usage--with-animationtree-blendtree)
- [Usage — Via Script (Runtime Import)](#usage--via-script-runtime-import)
- [Generating a Texture Atlas in Adobe Animate](#generating-a-texture-atlas-in-adobe-animate)
- [Adobe Animate JSON Structure Reference](#adobe-animate-json-structure-reference)
- [Compatibility](#compatibility)

---

> [!IMPORTANT]
> ### ⚠️ Critical Adobe Animate Setup Requirements
> To ensure the importer successfully parses and imports your animations without errors, follow these rules when setting up your project in Adobe Animate:
> 
> 1. **Required Library Folder Structure**: You must organize your Library folders like this:
>    - `📁 character_name` (e.g., `boss`)
>      - `📁 anim` (MovieClip symbols for the animation states: e.g. `idle`, `walk`, `punch`)
>      - `📁 parts` (MovieClip symbols for the character parts)
> 2. **Nesting Level**: Only **Level 1** nesting is supported: `Character_Master` (Master) ➔ `Idle/Walk/etc` (Animations) ➔ `Character Symbol Parts` (Flat sprites). Any deep nesting beyond this will cause errors.
> 3. **Single Layer in Master**: All animation symbols (`Idle`, `Walk`, `Punch`) inside the `Character_Master` timeline must be placed on the **same single timeline layer**.
> 4. **MovieClips ONLY**: Both the animations and character parts **must** be created as **MovieClip** symbols.
> 5. **No Hyphens or Special Symbols**: Do not use hyphens (`-`), parentheses `()`, or other special symbols in symbol names or filenames (e.g., use `boss1_attack1` instead of `boss-1_attack(1)`).
> 6. **Consistent Part Setup**: When exporting separate animation JSON files, the symbol list and atlas spritemap must share identical part dimensions. (Using a Single Master File is recommended).

---

## Key Features

- **Dual-Mode Import**: Natively supports both multiple animation JSON files (in a folder) and single master `Animation.json` files containing nested animation symbols.
- **Incremental Scene Update (`🔄 Update Existing Scene`)**: Add or update animations in an existing `.tscn` file without deleting custom user nodes (Hitboxes `Area2D`, Hurtboxes, Particle Systems, AudioStreamPlayers, or custom sprites).
- **Animation Checklist & Search**: Fast real-time search bar (`🔍`), multi-column grid layout, and quick-filter buttons (`☑️ All`, `⬜ None`, `🎯 Select Filtered`) designed to comfortably manage packs with 80+ animations.
- **Pinned Action Bar**: Bottom action buttons and status indicators are permanently pinned at the bottom of the window—no need to resize or stretch the window.
- **Interactive Viewport Preview with Grid**: Live preview with Zoom, Pan, Reset View, Color Picker, Scrubber Timeline, and toggleable **Coordinate & Floor Grid (`📏 Grid`)** featuring Ground (X-axis) and Center (Y-axis) guidelines.
- **Dedicated Visual Controller (`class_name AATTAIController`)**: Built-in methods for swapping skins, overriding individual slot textures (weapons/cosmetics), and equipping custom nodes to body parts.
- **Vector2 Rotation Blending**: Rotation is keyframed using a direction vector (`r_vec`) rather than raw float angles, natively resolving 180° rotation flipping during `AnimationTree` blending.
- **Dynamic Z-Ordering & Keyframe Deduplication**: Discards redundant baked keyframes and preserves back-to-front layer draw order across all animations.
- **Quick-Fix Pivot Wrappers**: Wraps sprites in parent `Node2D` pivot nodes, allowing designers to manually adjust the local pivot/offset of any body part in the Godot Viewport without modifying source assets.
- **Texture Filter Selection**: Choose between `Linear (Smooth)` for high-res art and `Nearest (Pixel Art)` for crisp pixel graphics.

---

## Installation

1. Copy the `addons/AATTAAI/` folder into your Godot project's `addons/` folder.
2. Open **Project → Project Settings → Plugins**.
3. Enable **Adobe Animate Importer (AATTAAI)**.

---

## Usage — Via Editor Menu

### 1. Importer Window Overview
Open **Project Menu → Tools → Import Adobe Animate...**:

1. **Spritemap JSON**: Select your atlas JSON (e.g. `res://assets/spritemap1.json`). The plugin will auto-predict the PNG and animation folder!
2. **Spritesheet PNG**: Select your atlas texture image (e.g. `res://assets/spritemap1.png`).
3. **Animation JSON File or Folder**: Select the master `Animation.json` or folder containing individual animation JSONs.
4. **Output scene path**: Target file path (e.g. `res://scenes/hero.tscn`).

---

### 2. Animation Checklist & Fast Search (80+ Animations)
Inside the form, all detected animations appear in an organized 2-column grid:
- **Search Bar**: Type any keyword (e.g. `"attack"`) to filter visible animations instantly.
- **`☑️ All`**: Check all animations.
- **`⬜ None`**: Uncheck all animations.
- **`🎯 Select Filtered`**: Check all animations currently matching the search filter.
- **Selection Counter**: Live badge shows selected count (e.g., `📋 Animations (65/80 selected):`).

---

### 3. Incremental Scene Update vs Fresh Import
The window provides two distinct action buttons pinned at the bottom:

- **`⬇️ Fresh Import`**: Generates a new scene from scratch (overwrites existing file completely).
- **`🔄 Update Existing Scene`**:
  - Automatically enabled when the output `.tscn` file already exists.
  - Adds missing layers and injects or updates selected animation tracks in the scene's `AnimationPlayer`.
  - **Preserves all custom nodes**: Custom `Area2D` hitboxes, weapons, collision shapes, cameras, or attached scripts are kept 100% intact!

---

### 4. Viewport Preview with Origin & Floor Grid
- **Play / Pause**: Play or pause current animation.
- **Animation Dropdown**: Switch between selected animations.
- **`📏 Grid` Toggle**: Toggles the 64px/32px grid, Ground line (Red X Axis), Center line (Green Y Axis), and `(0,0)` pivot marker.
- **Color Picker**: Change preview background color to test light/dark contrast.
- **Timeline Scrubber**: Drag or click to scrub animation frames smoothly.
- **Navigation Controls**:
  - **Zoom**: Mouse Wheel Up / Down.
  - **Pan**: Right-Click or Middle-Click drag.
  - **Reset View**: Double-Click Left Mouse Button.

---

## Visual Controller & Equipment API (AATTAIController)

When **Add Visual Controller Script** is enabled, the imported root node is attached with `AATTAIController` (`addons/AATTAAI/AATTAI_controller.gd`), providing a high-level API for game logic.

### Generated Hierarchy
```text
AnimatedCharacter (Node2D)  ← [AATTAIController attached]
├── AnimationPlayer
├── head (Node2D, Pivot Wrapper)
│   └── Sprite (Sprite2D)
├── weapon (Node2D, Pivot Wrapper)
│   └── Sprite (Sprite2D)
└── ...
```

### Scripting Examples:

#### Global Reskin / Texture Swap
Swap the entire character's appearance to a new spritesheet atlas on the fly:
```gdscript
extends CharacterBody2D

@onready var visual: AATTAIController = $AnimatedCharacter

func equip_ice_skin():
    # Changes all body parts to use the new atlas texture
    visual.change_skin(preload("res://skins/hero_ice_atlas.png"))

func reset_skin():
    visual.change_skin(preload("res://assets/spritemap1.png"))
```

#### Slot-Based Reskin (Weapon / Armor / Cosmetic)
Override an individual part (e.g. `"weapon"` or `"helmet"`) with a custom standalone sprite texture:
```gdscript
func change_weapon_skin():
    # Replaces the weapon slot sprite with a standalone axe texture
    visual.set_slot_texture("weapon", preload("res://sprites/axe.png"))

func reset_weapon():
    # Restores weapon to the original atlas spritemap
    visual.reset_slot_texture("weapon")

func reset_everything():
    visual.reset_all_slots()
```

#### Equipping Custom Node / VFX / Hitbox
Attach any custom Godot node (such as a 3D effect, Particle system, or Hitbox) directly to a body part:
```gdscript
func equip_fire_sword():
    var fire_fx = preload("res://scenes/vfx_fire.tscn").instantiate()
    visual.equip("weapon", fire_fx, true) # true = replaces previous custom attachment

func remove_sword_fx():
    visual.clear_slot("weapon")
```

#### Animation Playback & Signal Relays
```gdscript
func _ready():
    visual.animation_finished.connect(_on_anim_finished)
    visual.skin_changed.connect(func(tex): print("Skin swapped!"))

func attack():
    visual.play_anim("attack_combo_1")

func take_hit():
    visual.play_anim("hit_react")

func _on_anim_finished(anim_name: String):
    if anim_name.begins_with("attack"):
        visual.play_anim("idle")
```

---

## Usage — With AnimationTree (BlendTree)

The importer exports rotation tracks as Vector2 direction vectors (`r_vec`). This enables smooth linear interpolation without the standard 180° angular wrap flip:

1. Add an `AnimationTree` node as a child of your character root.
2. Set **Anim Player** to `$AnimatedCharacter/AnimationPlayer`.
3. Set **Tree Root** to `AnimationNodeBlendTree` and set **Active** = `true`.
4. Add `AnimationNodeBlend2` or `AnimationNodeTransition` nodes to blend `idle` and `walk` or trigger `attack` actions.

```gdscript
extends CharacterBody2D

@onready var anim_tree: AnimationTree = $AnimatedCharacter/AnimationTree

func _physics_process(delta):
    var speed_blend = clamp(velocity.length() / max_speed, 0.0, 1.0)
    anim_tree.set("parameters/MoveBlend/blend_amount", speed_blend)

    if Input.is_action_just_pressed("attack"):
        anim_tree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
```

---

## Usage — Via Script (Runtime Import)

To import and assemble Adobe Animate characters dynamically in code at runtime:

```gdscript
extends Node2D

func _ready():
    var runtime = load("res://addons/AATTAAI/AATTAI_runtime.gd").new()
    add_child(runtime)
    
    runtime.build(
        "res://assets/spritemap1.json",
        "res://assets/animations",
        "res://assets/spritemap1.png",
        0,                 # fps_override (0 = from JSON)
        [],                # anim_files_override
        true,              # use_pivot_wrappers
        true,              # add_skin_swapper
        "Linear"           # texture_filter_mode
    )
    
    runtime.play_anim("walk")
```

---

## Generating a Texture Atlas in Adobe Animate

### Workflow A: Single Master File (Recommended)
Packs all animations into a single `Animation.json` file and a single spritemap.

1. **Create Master Symbol**: Create a Movie Clip symbol (e.g. `Character_Master`).
2. **Nest Animations (Level 1)**: Drag instances of all animation symbols (`Idle`, `Walk`, `Jump`, `Attack`) onto the stage **on the same single timeline layer**.
3. **Export Texture Atlas**: Right-click `Character_Master` in the Library and click **Generate Texture Atlas**.
4. **Settings**:
   - **Dimensions**: Autosize (e.g. 2048×2048).
   - **Optimize Dimensions**: Enabled (crops empty pixels).
   - **Padding**: 2px.
   - **Format**: PNG (32-bit).

---

## Adobe Animate JSON Structure Reference

Adobe Animate Texture Atlas outputs:
- **`spritemap1.json`**: Atlas bounding rects (`name`, `x`, `y`, `w`, `h`).
- **`Animation.json`**: Layer hierarchy, timeline frames, symbol instances (`SI`), matrix transforms (`M3D` 4×4 row-major), and symbol dictionary (`SD`).

The importer automatically extracts `position`, `rotation` (vectorized), `scale`, `region_rect`, `visible`, and `z_index` keyframes into standard Godot `Animation` resources.

---

## Compatibility

- **Godot**: Godot 4.0 – 4.4+ (GDScript `@tool`)
- **Adobe Animate**: Adobe Animate 2020 – 2025+ (JSON Texture Atlas Format)
- **Tooling**: Fully compatible with EDAP Tools / Flash POWERTOOLS
