# Adobe Animate → Godot 4 Importer Plugin

Plugin Godot 4 untuk mengimpor **texture atlas** dan **animasi** dari Adobe Animate
ke scene Godot dengan **AnimationPlayer** penuh, lengkap dengan transformasi per-part.

---

## Struktur File Output Adobe Animate

Adobe Animate menghasilkan tiga file saat export **Texture Atlas**:

| File | Deskripsi |
|------|-----------|
| `spritemap1.png` | Spritesheet (atlas PNG) |
| `spritemap1.json` | Koordinat setiap sprite dalam atlas |
| `Animation.json` | Data animasi per-layer per-frame (posisi, rotasi, skala) |

---

## Instalasi

1. Copy folder `addons/adobe_animate_importer/` ke dalam folder `addons/` project Godot kamu.
2. Buka **Project → Project Settings → Plugins**.
3. Aktifkan **Adobe Animate Importer**.

---

## Cara Pakai — Via Menu (Import ke Scene File)

1. Buka **Tools → Import Adobe Animate...**
2. Isi path ke `spritemap1.json`, `Animation.json`, dan `spritemap1.png`.
3. Tentukan output path scene (`.tscn`).
4. Klik **Import & Generate Scene**.

Scene yang dihasilkan berisi:
```
AnimatedCharacter (Node2D)
├── AnimationPlayer
├── leg_arm (Sprite2D)      ← satu node per layer
├── right_arm (Sprite2D)
├── head (Sprite2D)
├── body (Sprite2D)
└── ...
```

AnimationPlayer akan memiliki satu animasi per scene di `Animation.json`.

---

## Cara Pakai — Via Script (Runtime)

Untuk karakter yang perlu di-setup saat runtime (misal: load karakter dari disk user):

```gdscript
# Pasang script adobe_animate_runtime.gd ke Node2D
extends Node2D

func _ready():
	var char_node = $MyCharacter
	char_node.setup(
		"res://assets/spritemap1.json",
		"res://assets/Animation.json",
        "res://assets/spritemap1.png"
	)
	$MyCharacter/AnimationPlayer.play("stick_man_push_w_kick")
```

Atau pakai export vars di Inspector:

```
atlas_json_path   = res://assets/spritemap1.json
animation_json_path = res://assets/Animation.json
png_path          = res://assets/spritemap1.png
auto_play         = stick_man_push_w_kick
```

---

## Beberapa Animasi (Multi-Animation)

Adobe Animate bisa export beberapa scene dalam satu `Animation.json`.
Plugin ini membaca **semua scene** dan mendaftarkan masing-masing sebagai
animasi terpisah di `AnimationPlayer`. Nama animasi = nama scene di Animate.

```gdscript
var ap = $AnimatedCharacter/AnimationPlayer
ap.get_animation_list()  # ["stick_man_push_w_kick", "idle", "walk", ...]
ap.play("idle")
```

---

## Cara Export dari Adobe Animate

1. **File → Publish Settings** (atau **File → Export → Export Video/Texture Atlas**)
2. Pilih **Texture Atlas** sebagai format.
3. Centang **JSON** dan **PNG**.
4. Klik **Publish / Export**.

Adobe Animate akan menghasilkan `spritemap1.json`, `Animation.json`, dan `spritemap1.png`.

---

## Struktur JSON Adobe Animate (Referensi)

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

### Animation.json (ringkasan)
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
				  "SI": {   // Symbol Instance (sub-symbol yang di-animate)
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
  "SD": { /* definisi sub-symbol */ }
}
```

**M3D** adalah matrix 4×4 row-major. Plugin mengurai matrix ini menjadi:
- `position` (tx, ty dari kolom 3)
- `rotation` (dari atan2 pada komponen rotasi)  
- `scale` (magnitude dari vektor baris)

---

## Catatan

- **Layer "CenterMarker"** diabaikan otomatis (layer internal Adobe Animate/EDAP Tools).
- **Sub-symbol** (tipe `SI`) dipetakan ke nama sprite atlas via path symbolnya.
- **Sprite instances** (tipe `ASI`) langsung menggunakan nama sprite dari atlas.
- `region_rect` di-keyframe per frame sehingga sprite bisa ganti gambar mid-animation.
- Skala negatif didukung (untuk flip horizontal/vertikal yang umum dipakai di 2D character animation).

---

## Kompatibilitas

- Godot 4.x (GDScript, `@tool`)
- Adobe Animate 2023+ (format JSON Texture Atlas)
- EDAP Tools / Flash POWERTOOLS compatible
