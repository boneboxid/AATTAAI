# Adobe Animate → Godot 4 Importer Plugin (AATTAAI)

A Godot 4 plugin for importing texture atlases and animations exported from Adobe Animate into Godot scenes with a full AnimationPlayer, including per-part transforms and sprite swapping.

---

## Features

- Import Adobe Animate texture atlas (spritesheet + atlas JSON) and animation JSON.
- Build a Godot scene with one Sprite2D node per animation layer and a shared AnimationPlayer.
- Keyframed position, rotation, scale and region_rect (texture swapping) per frame.
- Support for multiple animations (import a folder of Animation JSON files).
- Runtime API to build importer from code.

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

(You can also package and install from the Godot AssetLib if you publish there.)

---

## Usage — Via Editor Menu (Import to Scene File)

1. Open **Tools → Import Adobe Animate...**
2. Provide paths for `spritemap1.json` (atlas JSON), the animation JSON file (or folder), and `spritemap1.png` (atlas PNG).
3. Set the output scene path (e.g. `res://scenes/MyCharacter.tscn`).
4. Click **Import & Generate Scene**.

The generated scene structure looks like:

```text
AnimatedCharacter (Node2D)
├── AnimationPlayer
├── leg_arm (Sprite2D)      ← one node per layer
├── right_arm (Sprite2D)
├── head (Sprite2D)
├── body (Sprite2D)
└── ...
```

Shared sprites: layers with the same name across different animation files share a single `Sprite2D` node — no duplicate nodes. Layers with duplicate names within the same animation are kept separate with a `#index` suffix.

---

## Usage — Via Script (Runtime)

Attach `AATAAI_runtime.gd` to a `Node2D`, then call `build()` from `_ready()` or another initialization function:

```gdscript
func _ready():
    $MyCharacter.build(
        "res://assets/spritemap1.json",
        "res://assets/Animation.json",
        "res://assets/spritemap1.png"
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
```

---

## Multiple Animations

If you have several animation JSON files in one folder, point the importer at the folder instead of a single file. Each JSON becomes a separate animation in the `AnimationPlayer`, named after its filename (without extension).

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

This guide explains how to convert vector animations into a packed texture atlas (bitmap sheet and JSON data) for use in external game engines like Godot.

### Step 1: Select the Animation Symbol
1. Open your project file in Adobe Animate.
2. Locate the animated character or asset in the Library (Ctrl+L / Cmd+L).
3. Identify the Movie Clip / Graphic / Button symbol containing the animation.

### Step 2: Open the Generation Menu
1. Right-click the symbol in the Library or Stage.
2. Select **Generate Texture Atlas** from the context menu.

### Step 3: Configure Texture Settings
- Image Dimension: set maximum texture limits (e.g., 2048×2048). Use Autosize to reduce unused space.
- Optimize Dimensions: tightly crop empty pixels around each image frame.
- Padding: add a small padding (e.g., 2px) between textures to avoid bleeding.
- Format: choose PNG (32-bit) to preserve transparency.

### Step 4: Preview and Export
1. Use the Preview tab to verify the layout.
2. Choose an output folder and click Export. The export creates the spritesheet PNG, spritesheet JSON (atlas), and animation JSON files.

For batch export, see: https://github.com/boneboxid/Batch-Export-Texture-Atlas

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
- Rotation uses `INTERPOLATION_LINEAR_ANGLE` so Godot always picks the shortest path.
- There are no visibility tracks — all Sprite2D nodes remain visible at all times.

---

## Compatibility

- Godot 4.x (GDScript, `@tool` enabled where applicable)
- Adobe Animate 2023+ (JSON Texture Atlas format)
- EDAP Tools / Flash POWERTOOLS compatible

---

If you'd like further edits (add screenshots, example scene, or API docs), tell me what to include and I'll update the README again.
