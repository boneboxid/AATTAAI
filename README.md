# Adobe Animate → Godot 4 Importer Plugin (AATTAAI)

A Godot 4 plugin for importing texture atlases and animations exported from Adobe Animate into Godot scenes with a full AnimationPlayer, including per-part transforms and sprite swapping.

---

## Table of Contents
- [Critical Adobe Animate Setup Requirements](#-critical-adobe-animate-setup-requirements)
- [Features](#features)
- [Adobe Animate Output Structure](#adobe-animate-output-structure)
- [Installation](#installation)
- [Usage — Via Editor Menu](#usage--via-editor-menu)
- [Usage — Via Script (Runtime)](#usage--via-script-runtime)
- [Generating a Texture Atlas in Adobe Animate](#generating-a-texture-atlas-in-adobe-animate)
- [Notes](#notes)
- [Compatibility](#compatibility)

---

> [!IMPORTANT]
> ### ⚠️ Critical Adobe Animate Setup Requirements
> To ensure the importer successfully parses and imports your animations without errors, you **must** follow these rules when setting up your project in Adobe Animate:
> 
> 1. **Required Library Folder Structure**: You must organize your Library folders exactly like this:
>    - `📁 character_name` (e.g., `boss`)
>      - `📁 anim` (MovieClip symbols for the animation states: e.g. `idle`, `walk`, `punch`)
>      - `📁 parts` (MovieClip symbols for the character parts)
> 2. **Nesting Level**: Only **Level 1** nesting is supported. The structure must be: `Character_Master` (Master) ➔ `Idle/Walk/etc` (Animations) ➔ `Character Symbol Parts` (Flat sprites). Any deep nesting beyond this will cause errors.
> 3. **Single Layer in Master**: All animation symbols (`Idle`, `Walk`, `Punch`) inside the `Character_Master` timeline must be placed on the **same single timeline layer** (placing them on different layers will cause import failures).
> 4. **MovieClips ONLY**: Both the animations and character parts **must** be created as **MovieClip** symbols (select *MovieClip* at the moment of creation). Changing symbol behavior to MovieClip later may not work as expected.
> 5. **No Hyphens or Special Symbols in Symbol Names**: Do not use hyphens (`-`), parentheses `()`, or other special symbols in symbol names or character actions, as they can cause import errors (e.g., use `boss1_attack1` instead of `boss-1_attack(1)`).
> 6. **No Hyphens or Parentheses in .fla Filename and Library Folder Names**: The Adobe Animate project file (`.fla`) and all Library folder names **must not contain hyphens (`-`) or parentheses (`()`)**, as these can cause path parsing and export errors (e.g., use `my_character.fla` or `MyCharacter.fla`, not `my-character.fla` or `my(character).fla`).

---

## Features

- **Dual-Mode Import**: Natively supports both multiple animation JSON files (in a folder) and a single master `Animation.json` file containing nested animation symbols (splits them automatically in-memory).
- **Flexible Library Organization**: Automatically detects and splits master animations from flat parts using structural analysis (symbols with child instances `SI` vs raw sprites `ASI`) instead of requiring folder naming conventions.
- **Automatic Frame Picker & Swap Symbol Support**: Supports both swapping different Library symbols and picking specific frames within a single Graphic symbol using Adobe Animate's Frame Picker (supports `PICK`).
- **Auto-Normalization (Optimized & Unoptimized JSON)**: Seamlessly imports both optimized (short keys) and unoptimized (verbose keys like `ANIMATION`, `SYMBOL_DICTIONARY`, `Matrix3D` dictionaries) JSON exports.
- **Keyframe Optimization (Deduplication)**: Discards redundant baked keyframes. Stationary properties on transform tracks (`position`, `rotation`, `scale`) get only 1 keyframe at `t = 0.0` instead of duplicated every frame.
- **Correct Draw Order**: Automatically maps layers from back-to-front to match the Adobe Animate timeline draw order in Godot.
- **Dynamic Z-Ordering**: Keyframes the `z_index` property of each active Sprite2D node at the start of each animation, ensuring the correct depth order is maintained per animation.
- **Shared Nodes**: Reuses Sprite2D nodes across animations with identical layer names (no duplicates).
- **Runtime API**: Allows importing and building character scenes dynamically from code, supporting all customization flags.
- **Robust AnimationTree Blending**: Uses `Vector2` direction vectors (`r_vec`) for rotation tracks instead of float angles, which natively resolves the 180-degree rotation wrapping glitch during `AnimationTree` blending.
- **Texture Filter Selection**: Exposes options for `"Nearest (Pixel Art)"` and `"Linear (Smooth)"` filtering to support different art styles natively on import.
- **Multi-Skin / Costume Swapper**: Optionally attaches a `@tool` skin-swapper script to the root node, allowing you to swap skin textures on the fly via the Inspector in the Editor or at Runtime.
- **Quick-Fix Pivot Wrappers**: Optionally wraps sprites in parent `Node2D` pivot nodes, allowing designers to manually adjust the local offset of any sprite part in the Godot Viewport without having to edit the importer settings.
- **Interactive Preview Dialog**: Adds a beautiful live preview panel inside the import dialog, featuring play/pause controls, an animation selector, a scrubbing slider, a background color picker, and zoom/pan controls.

---

## Adobe Animate Output Structure

Adobe Animate typically generates these files when exporting a texture atlas:

| File | Description |
|------|-------------|
| `spritemap1.png` | Spritesheet (atlas PNG) |
| `spritemap1.json` | Coordinates of each sprite in the atlas |
| `Animation.json` | Per-layer, per-frame animation data (position, rotation, scale) |

Multiple animation JSON files can live in the same folder — the plugin will pick them all up automatically.

---

## Installation

1. Copy the `addons/AATTAAI/` folder into your Godot project's `addons/` folder (note: the correct folder name is `AATTAAI`).
2. Open **Project → Project Settings → Plugins**.
3. Enable **Adobe Animate Importer**.

### you can watch this video for overview tutorial
- [V1.6.0 demo](https://www.youtube.com/watch?v=K_uXYJD_xFI)
- [V1.6.5 demo (WIP)]()
---

## Usage — Via Editor Menu (Import to Scene File)

1. Open **Tools → Import Adobe Animate...**
2. Provide paths for `spritemap1.json` (atlas JSON), the animation JSON file (or folder), and `spritemap1.png` (atlas PNG).
3. Set the output scene path (e.g. `res://scenes/MyCharacter.tscn`).
4. **Configure Options**:
   * **Use Pivot Wrapper Nodes**: Creates an intermediate `Node2D` wrapper parent for each body part sprite node. All keyframed transforms target the parent wrapper, allowing you to freely adjust the local pivot/offset of each part in the viewport without editing the importer settings.
   * **Add Skin Swapper Script**: Attaches a `@tool` costume-swapper script to the root node, exposing a `Skin Texture` file inspector property. Simply drag a new sprite atlas texture sheet onto this field to swap all sprites to the new texture.
   * **Texture Filter Mode**: Choose between `Linear (Smooth)` (for high-resolution assets) and `Nearest (Pixel Art)` (for clean, sharp pixel art).
5. **Interactive Preview**:
   * Once valid file paths are provided, the character will instantly load inside the right viewport container.
   * **Play / Pause**: Click to start or pause the preview playback.
   * **Animation Dropdown**: Select from any of the parsed animations.
   * **Timeline Scrubber**: Drag or click the timeline slider to scrub through the animation frames (works both while playing and paused, updating the preview in real-time).
   * **Background Color Picker**: Click the small color square next to the animation selector to change the preview background color dynamically (useful to see dark or light characters against a contrasting background).
   * **Zoom**: Scroll the **Mouse Wheel** inside the preview panel to zoom in or out.
   * **Pan**: Click and drag with the **Right Mouse Button** or **Middle Mouse Button** to move the viewport camera.
   * **Reset Camera**: **Double-click** with the **Left Mouse Button** to instantly center and reset the zoom.
6. Click **Import & Generate Scene**.

The generated scene structure (with Pivot Wrappers enabled) looks like:

```text
AnimatedCharacter (Node2D)  ← [Skin Swapper script attached]
├── AnimationPlayer
├── leg_arm (Node2D, Wrapper)
│   └── Sprite (Sprite2D)   ← [Editable offset/pivot]
├── right_arm (Node2D, Wrapper)
│   └── Sprite (Sprite2D)
└── ...
```

Shared sprites: layers with the same name across different animation files share a single `Sprite2D`/Wrapper node — no duplicate nodes. Layers with duplicate names within the same animation are kept separate.

---

## Usage — Via Script (Runtime)

Attach `AATTAI_runtime.gd` to a `Node2D`, then call `build()` from `_ready()` or another initialization function. You can pass the new customization parameters to the `build` function or set them in the Inspector on the node before calling `build()`.

```gdscript
func _ready():
    $MyCharacter.build(
        "res://assets/spritemap1.json",
        "res://assets/Animation.json",
        "res://assets/spritemap1.png",
        0,                 # fps_override (0 = read from JSON)
        [],                # anim_files_override (custom list of paths, or empty)
        true,              # p_use_pivot_wrappers (Feature 3)
        true,              # p_add_skin_swapper (Feature 7)
        "Nearest"          # p_filter_mode (Linear or Nearest) (Feature 10)
    )
    $MyCharacter/AnimationPlayer.play("walk")
```

You can also set the export-vars in the Inspector on the runtime node:

```gdscript
# export vars on the runtime node
atlas_json_path     = "res://assets/spritemap1.json"
animation_json_path = "res://assets/Animation.json"  # or a folder
png_path            = "res://assets/spritemap1.png"
auto_play           = "walk"
fps_override        = 0   # 0 = read FPS from JSON
texture_filter_mode = "Linear" # or "Nearest" (Feature 10)
use_pivot_wrappers  = true # Feature 3
add_skin_swapper    = true # Feature 7
```

---

## Usage — With AnimationTree (BlendTree)

To blend different imported animations (such as blending `idle` and `walk`, or triggering actions like `punch` and `jump`) smoothly using an `AnimationTree`, you can set up an `AnimationNodeBlendTree` as follows:

1. **Add an `AnimationTree` Node**: Add an `AnimationTree` node as a child of your imported character root node.
2. **Assign the AnimationPlayer**: In the Inspector of the `AnimationTree`, set the **Anim Player** property to the character's `AnimationPlayer`.
3. **Set the Tree Root**: Set the **Tree Root** property to **New AnimationNodeBlendTree** and set **Active** to `true`.
4. **Build the BlendTree Graph**: Open the `AnimationTree` panel at the bottom of the editor and add nodes:
   - **Animation Nodes**: Add nodes for your imported animations (e.g. `idle`, `walk`, `jump`, `punch`).
   - **Transition Nodes**: Use `AnimationNodeTransition` to switch between states (e.g., `idle` and `walk`). Adjust their cross-fade time (e.g., `0.2s`) for smooth blending.
   - **OneShot Nodes**: Use `AnimationNodeOneShot` for action triggers (e.g., `jump` or `punch`) over continuous animations.
   - **Blend2 Nodes**: Use `AnimationNodeBlend2` to blend two animations together continuously by adjusting a blend parameter from `0.0` to `1.0`.
5. **Shortest-Path Rotation Blending**: Thanks to the built-in Vector2 direction blending (`r_vec`), you can blend any of these animations at any weight (e.g. `0.5`) without experiencing any 180-degree rotation flip.
6. **Scripting the Blending Parameters**: Update these parameters in your player controller GDScript:

```gdscript
extends CharacterBody2D

@onready var anim_tree: AnimationTree = $AnimatedCharacter/AnimationTree

func _physics_process(delta):
    # Example: Blending between Idle and Walk based on velocity
    var speed_blend = clamp(velocity.length() / max_speed, 0.0, 1.0)
    anim_tree.set("parameters/MoveBlend/blend_amount", speed_blend)

    # Example: Triggering a OneShot action like Punch
    if Input.is_action_just_pressed("attack"):
        anim_tree.set("parameters/PunchOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
```
### you can watch this video, thanks to Gwizz
[Watch the video (Godot 4 Animation Blend Tree Tutorial Part 2 by Gwizz)](https://www.youtube.com/watch?v=eQUrKp19iXE)
---

## Multiple Animations

If you have several animation JSON files in one folder, point the importer at the folder instead of a single file. Each JSON becomes a separate animation in the `AnimationPlayer`, named after its filename.

```
assets/
├── spritemap1.json
├── spritemap1.png
├── Animation001.json       → animation "Animation001"
├── Animation002.json       → animation "Animation002"
└── Animation003.json       → animation "Animation003"
```

```gdscript
var ap = $AnimatedCharacter/AnimationPlayer
ap.get_animation_list()  # ["Animation001", "Animation002", "Animation003"]
ap.play("Animation002")
```

---

## Generating a Texture Atlas in Adobe Animate

This guide explains how to convert vector animations into a packed texture atlas (bitmap sheet and JSON data) for use in Godot 4 using two different workflows.

### Workflow A: Single Master File (Recommended)
This workflow packs all animations into a single `Animation.json` file and a single spritemap. This is the most robust way because it guarantees all animations share a single, consistent texture layout.

1. **Create a Master Symbol**: Create a new Empty Movie Clip symbol in the Library (e.g., named `Character_Master`).
2. **Nest Your Animations (Level 1 Only)**: Inside this `Character_Master` symbol, drag-and-drop instances of all your individual animation symbols (e.g., `Idle`, `Walk`, `Jump`, `Punch`) onto the stage.
   * ⚠️ **Important (Single Layer Nesting)**: When placing your animations (e.g., `Idle`, `Walk`, `Punch`) inside the `Character_Master` timeline, **make sure to place them all on the same single timeline layer**. Placing them on different layers will cause the export to fail or generate incorrect data.
   * ⚠️ **Important (Nesting Limit)**: The importer only supports **Level 1** nesting. This means the structure must be: `Character_Master` (Master) ➔ `Idle/Walk/etc` (Animations) ➔ `Character Symbol Parts` (Flat sprites). Deeper nesting will be ignored or cause errors.
   * ⚠️ **Important (MovieClip vs Graphic)**: Make sure to select **MovieClip** as the type *at the moment of creating the symbols* for both the animations and the character parts. Changing the symbol type to MovieClip after creation may not work correctly.

### Required Library Folder Structure
To ensure the importer parses and maps the symbol coordinates correctly, you **must** organize your Adobe Animate Library folders exactly like this:
```
📁 boss (Character Root)
├── 📁 anim  (contains MovieClip animation states like idle, walk, punch)
└── 📁 parts (contains MovieClip character symbol parts)
```

3. **Export Texture Atlas**: Right-click the `Character_Master` symbol in the Library and select **Generate Texture Atlas**.
4. **Configure Settings**:
   - **Image Dimension**: Set maximum texture limits (e.g., 2048×2048). Use Autosize.
   - **Optimize Dimensions**: Enable to crop empty pixels around each image frame.
   - **Padding**: Add a small padding (e.g., 2px) to avoid texture bleeding.
   - **Format**: PNG (32-bit).
5. **Export**: Click **Export**. This generates a single `Animation.json` containing all nested animations and a matching `spritemap1.json` + `spritemap1.png` atlas.

---

### Workflow B: Individual Files (Batch Export using JSFL)
You can export animations into separate individual `.json` files (e.g., `idle.json`, `run.json`) using JSFL scripts.

1. **Prepare JSFL script**: Use a script such as [Batch-Export-Texture-Atlas](https://github.com/boneboxid/Batch-Export-Texture-Atlas) to automate exporting multiple selected symbols from the Library.
2. **Select & Run**: Select all the animation symbols in the Library, run the JSFL script, and choose an output directory.
3. **⚠️ CRITICAL WARNING FOR INDIVIDUAL EXPORTS**: 
   When exporting individually, **the shapes, symbols, and body parts list in the library must be exactly identical across all selected animations**. 
   If one animation uses a part/shape that is missing, modified, or placed in a different order in another animation, Adobe Animate will generate different sprite sheet layouts for each export. If you export them this way, the Godot importer will fail or generate broken animations because the texture coordinates won't align.
   
   If you have parts that are unique to certain animations (like open hands for a casting animation), you **must** use **Workflow A (Single Master File)** to ensure they are packed together correctly.

---

## Output Files (Reference)

Adobe Animate's export usually contains:

| File Name | Format | Description |
|-----------|--------|-------------|
| `Animation.json` | JSON | Layer structures, frame timings, and animation hierarchy data |
| `spritemap1.png` / `spritesheet.png` | PNG | The composite image containing all pieces |
| `spritemap1.json` / `spritesheet.json` | JSON | X/Y coordinates and pixel sizes for each sprite |

(Your export filenames may vary; the plugin expects atlas JSON, atlas PNG, and one or more animation JSON files.)

---

## Adobe Animate JSON Structure (Reference)

spritemap1.json example:

```json
{
  "ATLAS": {
    "SPRITES": [
      {"SPRITE": {"name": "0000", "x": 0, "y": 50, "w": 16, "h": 63}}
    ]
  }
}
```

Animation.json (summary):

```json
{
  "AN": {
    "N": "scene_name",
    "SN": "Animation Name",
    "TL": {
      "L": [
        {
          "LN": "layer_name",
          "FR": [
            {
              "I": 0,       // frame index
              "DU": 1,      // duration (frames)
              "E": [
                {
                  "SI": {   // Symbol Instance (animated sub-symbol)
                    "SN": "stickman/parts/arm",
                    "M3D": [/* 4x4 matrix */]
                  }
                }
              ]
            }
          ]
        }
      ]
    },
    "MD": {"FRT": 60.0}   // FPS
  },
  "SD": { /* sub-symbol definitions */ }
}
```

The plugin decomposes the 4×4 row-major `M3D` matrix into:
- position (tx, ty from column 3)
- rotation (extracted via atan2 from rotation components, normalized to avoid >180° jumps)
- scale (magnitude of row vectors; negative scale supported for flipping)

---

## Notes

- `CenterMarker` layers are automatically skipped (internal Adobe Animate / EDAP Tools layer).
- Sub-symbols (type `SI`) are mapped to atlas sprite names via their symbol path.
- Sprite instances (type `ASI`) use the sprite name from the atlas directly.
- `region_rect` is keyframed per frame, allowing sprites to swap textures mid-animation.
- **Vector2 Rotation Blending**: Rotation is keyframed using a helper direction vector property (`r_vec`) rather than raw angles. This allows `AnimationTree` to interpolate angles using standard linear blending without encountering 180-degree rotation flips.
- **Visibility Tracking**: Nodes that are inactive in a given animation are automatically hidden (`visible = false`) at `t = 0.0`.
- **Z-Index Handling**: Active nodes have their `z_index` property keyframed at the start of each animation based on their timeline depth in the JSON (from `0` for the backmost layer to `total_layers - 1` for the frontmost).
- **Naming Conventions**: Symbol names and character animations in Adobe Animate should **not** contain hyphens (`-`) or other special symbols. These can cause import errors. Instead, use letters, numbers, and underscores (e.g., `attack_1` instead of `attack-1`).

---

## Compatibility

- Godot 4.x (GDScript, `@tool` enabled where applicable)
- Adobe Animate 2023+ (JSON Texture Atlas format)
- EDAP Tools / Flash POWERTOOLS compatible

