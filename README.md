# Adobe Animate → Godot 4 Importer Plugin

A Godot 4 plugin for importing **texture atlases** and **animations** from Adobe Animate
into Godot scenes with a full **AnimationPlayer**, including per-part transformations.

---

## Adobe Animate Output Structure

Adobe Animate generates three files when exporting a **Texture Atlas**:

| File | Description |
|------|-------------|
| `spritemap1.png` | Spritesheet (atlas PNG) |
| `spritemap1.json` | Coordinates of each sprite in the atlas |
| `Animation.json` | Per-layer, per-frame animation data (position, rotation, scale) |

Multiple animation JSON files can live in the same folder — the plugin will pick them all up automatically.

---

## Installation

1. Copy the `addons/adobe_animate_importer/` folder into your Godot project's `addons/` folder.
2. Open **Project → Project Settings → Plugins**.
3. Enable **Adobe Animate Importer**.

---

## Usage — Via Menu (Import to Scene File)

1. Open **Tools → Import Adobe Animate...**
2. Fill in the paths to `spritemap1.json`, the animation JSON file (or folder), and `spritemap1.png`.
3. Set the output scene path (`.tscn`).
4. Click **Import & Generate Scene**.

The generated scene contains:
```
AnimatedCharacter (Node2D)
├── AnimationPlayer
├── leg_arm (Sprite2D)      ← one node per layer
├── right_arm (Sprite2D)
├── head (Sprite2D)
├── body (Sprite2D)
└── ...
```

**Shared sprites:** layers with the same name across different animation files share a single
`Sprite2D` node — no duplicate nodes. Layers with duplicate names *within* the same animation
are kept separate with a `#index` suffix.

---

## Usage — Via Script (Runtime)

Attach `adobe_animate_runtime.gd` to a `Node2D`, then call `build()`:

```gdscript
func _ready():
    $MyCharacter.build(
        "res://assets/spritemap1.json",
        "res://assets/Animation.json",
        "res://assets/spritemap1.png"
    )
    $MyCharacter/AnimationPlayer.play("walk")
```

Or set the export vars directly in the Inspector:

```
atlas_json_path     = res://assets/spritemap1.json
animation_json_path = res://assets/Animation.json
png_path            = res://assets/spritemap1.png
auto_play           = walk
fps_override        = 0   # 0 = read FPS from JSON
```

---

## Multiple Animations

If you have several animation JSON files in one folder, point the importer at the **folder**
instead of a single file. Each JSON becomes a separate animation in the `AnimationPlayer`,
named after its **filename** (without extension).

```
assets/
├── spritemap1.json
├── spritemap1.png
├── idle.json       → animation "idle"
├── walk.json       → animation "walk"
└── run.json        → animation "run"
```

```gdscript
var ap = $AnimatedCharacter/AnimationPlayer
ap.get_animation_list()  # ["idle", "walk", "run"]
ap.play("walk")
```

---

## Exporting from Adobe Animate

1. Go to **File → Publish Settings** (or **File → Export → Export Video/Texture Atlas**)
2. Select **Texture Atlas** as the format.
3. Check **JSON** and **PNG**.
4. Click **Publish / Export**.

Adobe Animate will generate `spritemap1.json`, one or more `Animation.json` files, and `spritemap1.png`.

---

## Adobe Animate JSON Structure (Reference)

### spritemap1.json
```json
{
  "ATLAS": {
    "SPRITES": [
      {"SPRITE": {"name": "0000", "x": 0, "y": 50, "w": 16, "h": 63}}
    ]
  }
}
```

### Animation.json (summary)
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

**M3D** is a row-major 4×4 matrix. The plugin decomposes it into:
- `position` (tx, ty from column 3)
- `rotation` (from atan2 on the rotation components, normalized to avoid > 180° jumps between keyframes)
- `scale` (magnitude of the row vectors, negative scale supported for flipping)

---

## Notes

- **"CenterMarker" layers** are automatically skipped (internal Adobe Animate / EDAP Tools layer).
- **Sub-symbols** (type `SI`) are mapped to atlas sprite names via their symbol path.
- **Sprite instances** (type `ASI`) use the sprite name from the atlas directly.
- `region_rect` is keyframed per frame, allowing sprites to swap textures mid-animation.
- Rotation uses `INTERPOLATION_LINEAR_ANGLE` so Godot always picks the shortest path.
- There are no visibility tracks — all Sprite2D nodes remain visible at all times.

---

## Compatibility

- Godot 4.x (GDScript, `@tool`)
- Adobe Animate 2023+ (JSON Texture Atlas format)
- EDAP Tools / Flash POWERTOOLS compatible
