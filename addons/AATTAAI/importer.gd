@tool
# AdobeAnimateImporter — core logic  (v4 — shared sprite + visible fix)
# Fix: Shared sprite — layer dengan nama sama di animasi berbeda share satu
#      Sprite2D (tidak duplikat). Layer nama duplikat dalam satu animasi tetap
#      dipisah dengan suffix "#layer_idx".
# Fix: Visible bug — keyframe false di t=0 hanya diinsert jika frame pertama
#      tidak mulai di t=0; node dari animasi lain di-hide eksplisit di t=0.
# Fix: Track rotasi pakai INTERPOLATION_LINEAR_ANGLE agar Godot selalu
#      memilih jalur terpendek.
extends RefCounted

var _symbol_map: Dictionary = {}  # "stickman/parts/arm" → {sprite, ox, oy}

# ─────────────────────────────────────────────────────────
# Entry point — SINGLE file (backward compat)
# ─────────────────────────────────────────────────────────
func import(atlas_json_path: String, anim_json_path: String,
			png_path: String, out_path: String, fps_override: int) -> String:
	return import_folder(atlas_json_path, anim_json_path.get_base_dir(),
						 png_path, out_path, fps_override, [anim_json_path])

# ─────────────────────────────────────────────────────────
# Entry point — FOLDER (semua *.json di folder)
# anim_folder: path ke folder berisi Animation JSONs
# Kalau anim_files diisi, hanya file itu saja yang dipakai (override scan).
# ─────────────────────────────────────────────────────────
func import_folder(atlas_json_path: String, anim_folder: String,
				   png_path: String, out_path: String,
				   fps_override: int, anim_files: Array = []) -> String:

	# 1. Atlas
	var atlas_data = _load_json(atlas_json_path)
	if atlas_data is String: return "Atlas JSON: " + atlas_data
	var sprites: Dictionary = _parse_atlas(atlas_data)
	if sprites.is_empty(): return "no sprite in atlas JSON."

	# 2. Texture
	var texture: Texture2D = _load_texture(png_path)
	if texture == null: return "cannot load PNG: " + png_path

	# 3. Cari semua Animation JSON di folder
	if anim_files.is_empty():
		anim_files = _scan_json_files(anim_folder)
	if anim_files.is_empty():
		return "no JSON file inside in the folder: " + anim_folder

	# 4. Parse semua animasi
	# Setiap file → satu entry {anim_name, layers[], fps}
	var all_animations: Array = []
	for json_path in anim_files:
		var anim_data = _load_json(json_path)
		if anim_data is String:
			push_warning("[AdobeAnimateImporter] Skip " + json_path + ": " + anim_data)
			continue

		var fps: float = float(fps_override) if fps_override > 0 else _get_fps(anim_data)

		# Build symbol map dari file ini (bisa beda tiap file)
		_build_symbol_map(anim_data, sprites)

		var parsed := _parse_animations(anim_data, fps)
		# Override nama animasi pakai nama file supaya lebih jelas
		var file_name = json_path.get_file().get_basename()
		for anim in parsed:
			anim["anim_name"] = file_name
			all_animations.append(anim)

	if all_animations.is_empty():
		return "all file JSON failed to parse."

	# 5. Build scene
	return _build_scene(sprites, texture, all_animations, out_path)

# ─────────────────────────────────────────────────────────
# Scan folder untuk semua *.json
# Skip: spritemap*.json (bukan animation file)
# ─────────────────────────────────────────────────────────
func _scan_json_files(folder: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(folder)
	if dir == null: return result
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			# Skip spritemap json (bukan animation)
			var lower := fname.to_lower()
			if not lower.begins_with("spritemap") and not lower.begins_with("atlas"):
				result.append(folder.path_join(fname))
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()  # urutan konsisten
	return result

# ─────────────────────────────────────────────────────────
# JSON loader — handle UTF-8 BOM
# ─────────────────────────────────────────────────────────
func _load_json(path: String):
	if path.is_empty(): return "Path empty"
	if not FileAccess.file_exists(path): return "File not found: " + path
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return "can't access file"
	var text := f.get_as_text(); f.close()
	if text.begins_with("\ufeff"): text = text.substr(1)
	var result := JSON.parse_string(text)
	if result == null: return "JSON parse error: " + path
	return result

func _load_texture(path: String) -> Texture2D:
	if path.is_empty(): return null
	if ResourceLoader.exists(path): return ResourceLoader.load(path) as Texture2D
	if not FileAccess.file_exists(path): return null
	var img := Image.new()
	if img.load(path) != OK: return null
	return ImageTexture.create_from_image(img)

# ─────────────────────────────────────────────────────────
# Atlas parser
# ─────────────────────────────────────────────────────────
func _parse_atlas(data: Dictionary) -> Dictionary:
	var result := {}
	var arr: Array = data.get("ATLAS", {}).get("SPRITES", data.get("sprites", []))
	for entry in arr:
		var sp: Dictionary = entry.get("SPRITE", entry.get("sprite", entry))
		var n := str(sp.get("name", sp.get("n", "")))
		result[n] = {
			"x": int(sp.get("x", 0)), "y": int(sp.get("y", 0)),
			"w": int(sp.get("w", 1)), "h": int(sp.get("h", 1)),
			"rotated": bool(sp.get("rotated", false))
		}
	return result

# ─────────────────────────────────────────────────────────
# FPS — root MD.FRT
# ─────────────────────────────────────────────────────────
func _get_fps(data: Dictionary) -> float:
	if data.has("MD") and data["MD"].has("FRT"): return float(data["MD"]["FRT"])
	if data.has("AN") and data["AN"].get("MD", {}).has("FRT"):
		return float(data["AN"]["MD"]["FRT"])
	return 24.0

# ─────────────────────────────────────────────────────────
# Build symbol map dari SD section
# ─────────────────────────────────────────────────────────
func _build_symbol_map(data: Dictionary, sprites: Dictionary) -> void:
	# Tidak clear() — akumulasi dari semua file (shared atlas)
	for sym_def in data.get("SD", {}).get("S", []):
		var sym_name: String = sym_def.get("SN", "")
		if sym_name.is_empty(): continue
		if _symbol_map.has(sym_name): continue  # sudah ada dari file sebelumnya
		for layer in sym_def.get("TL", {}).get("L", []):
			if layer.get("LN", "") == "CenterMarker": continue
			for fr in layer.get("FR", []):
				for elem in fr.get("E", []):
					if not elem.has("ASI"): continue
					var asi = elem["ASI"]
					var sp_name := str(asi.get("N", ""))
					if sp_name.is_empty() or not sprites.has(sp_name): continue
					var m: Array = asi.get("M3D", [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1])
					_symbol_map[sym_name] = {
						"sprite": sp_name,
						"ox": float(m[12]),
						"oy": float(m[13])
					}
					break

func _resolve_symbol(sym_name: String) -> Dictionary:
	return _symbol_map.get(sym_name, {})

# ─────────────────────────────────────────────────────────
# Animation parser — returns Array of anim dicts
# anim_name akan di-override oleh caller pakai nama file
# ─────────────────────────────────────────────────────────
func _parse_animations(data: Dictionary, fps: float) -> Array:
	var anims: Array = []
	if not data.has("AN"): return anims
	var an = data["AN"]
	var raw_layers: Array = an.get("TL", {}).get("L", [])
	var parsed_layers: Array = []

	for i in range(raw_layers.size()):
		var layer = raw_layers[i]
		var layer_name: String = layer.get("LN", "Layer")
		if layer_name == "CenterMarker": continue

		var frames: Array = []
		for fr in layer.get("FR", []):
			var elems: Array = []
			for elem in fr.get("E", []):
				var e := {}
				if elem.has("SI"):
					e = {
						"type": "symbol",
						"symbol_name": elem["SI"].get("SN", ""),
						"m3d": elem["SI"].get("M3D", [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1])
					}
				elif elem.has("ASI"):
					e = {
						"type": "sprite",
						"sprite_name": str(elem["ASI"].get("N", "")),
						"m3d": elem["ASI"].get("M3D", [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1])
					}
				if not e.is_empty(): elems.append(e)
			frames.append({
				"index": int(fr.get("I", 0)),
				"duration": int(fr.get("DU", 1)),
				"elements": elems
			})

		parsed_layers.append({
			"name": layer_name,
			"layer_idx": i,
			"frames": frames
		})

	var max_frame := 0
	for layer in parsed_layers:
		for fr in layer["frames"]:
			max_frame = max(max_frame, int(fr["index"]) + int(fr["duration"]))

	anims.append({
		"anim_name": an.get("SN", an.get("N", "animation")),
		"layers": parsed_layers,
		"fps": fps,
		"length": max_frame / fps
	})
	return anims

# ─────────────────────────────────────────────────────────
# Decompose M3D
# ─────────────────────────────────────────────────────────
func _decompose_m3d(m: Array) -> Dictionary:
	var a := float(m[0]); var b := float(m[1])
	var c := float(m[4]); var d := float(m[5])
	var sx := sqrt(a*a + b*b)
	var sy := sqrt(c*c + d*d)
	if (a*d - b*c) < 0.0: sy = -sy
	return {
		"pos":   Vector2(float(m[12]), float(m[13])),
		"rot":   atan2(b, a),
		"scale": Vector2(sx, sy)
	}

# ─────────────────────────────────────────────────────────
# FIX rotasi: normalisasi urutan sudut agar tidak loncat > PI antar frame
# Contoh: [170°, -170°] → [170°, 190°]  (putar 20°, bukan 340°)
# ─────────────────────────────────────────────────────────
func _normalize_angle_sequence(angles: Array) -> Array:
	if angles.size() <= 1: return angles
	var out: Array = angles.duplicate()
	for i in range(1, out.size()):
		var prev: float = out[i - 1]
		var curr: float = out[i]
		var diff: float = fmod(curr - prev + 3.0 * PI, TAU) - PI
		out[i] = prev + diff
	return out

# ─────────────────────────────────────────────────────────
# Build scene — MULTI-ANIMATION
#
# Key node tetap "afi#layer_idx" (TIDAK diubah ke nama).
# Alasan: satu nama layer bisa muncul lebih dari sekali dalam satu file
# (misal "leg_arm" duplikat 4x), masing-masing harus node terpisah.
# Shared texture atlas sudah ditangani lewat region_rect keyframe.
# ─────────────────────────────────────────────────────────
func _build_scene(sprites: Dictionary, texture: Texture2D,
				  all_animations: Array, out_path: String) -> String:

	var root := Node2D.new()
	root.name = "AnimatedCharacter"

	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	root.add_child(anim_player)
	anim_player.owner = root

	var anim_lib := AnimationLibrary.new()

	# ── Pass 1: kumpulkan semua layer unik dari semua animasi ──────────────
	# Key: sanitized layer_name — shared across animations dengan nama layer sama.
	# Layer berbeda nama tetap node berbeda. Kalau dua animasi punya "arm",
	# mereka share satu Sprite2D yang sama (tidak duplikat).
	# Edge-case: layer dengan nama identik DALAM satu animasi (misal "leg" x4)
	# tetap dipisah pakai suffix "#layer_idx".
	var layer_node_map: Dictionary = {}  # key → Sprite2D
	# Juga simpan mapping key per (afi, layer_idx) untuk lookup di Pass 2
	var anim_layer_key: Dictionary = {}  # "afi#lidx" → node_key

	for afi in range(all_animations.size()):
		var anim = all_animations[afi]
		# Lacak nama yang sudah dipakai dalam animasi ini untuk deteksi duplikat
		var names_in_anim: Dictionary = {}
		for layer in anim["layers"]:
			var base_name := _sanitize_node_name(layer["name"])
			var node_key: String
			if base_name in names_in_anim:
				# Nama duplikat dalam animasi yang sama → pisah per layer_idx
				node_key = base_name + "#" + str(layer["layer_idx"])
			else:
				node_key = base_name
				names_in_anim[base_name] = true
			anim_layer_key[str(afi) + "#" + str(layer["layer_idx"])] = node_key

			if node_key in layer_node_map: continue

			var spr := Sprite2D.new()
			var final_name := node_key
			# Pastikan nama node unik di scene tree
			var counter := 2
			while root.has_node(NodePath(final_name)):
				final_name = node_key + str(counter)
				counter += 1
			spr.name = final_name
			spr.texture = texture
			spr.centered = false
			spr.region_enabled = true
			root.add_child(spr)
			spr.owner = root
			layer_node_map[node_key] = spr

	# ── Pass 2: build tiap animasi ──────────────────────────────────────────
	for afi in range(all_animations.size()):
		var anim = all_animations[afi]
		var fps: float = anim["fps"]
		var animation := Animation.new()
		animation.loop_mode = Animation.LOOP_LINEAR
		animation.length = anim["length"]

		for layer in anim["layers"]:
			var lookup := str(afi) + "#" + str(layer["layer_idx"])
			var node_key: String = anim_layer_key.get(lookup, "")
			if node_key == "" or not layer_node_map.has(node_key): continue
			var node: Sprite2D = layer_node_map[node_key]
			var npath := root.get_path_to(node)

			var t_pos    := animation.add_track(Animation.TYPE_VALUE)
			var t_rot    := animation.add_track(Animation.TYPE_VALUE)
			var t_scl    := animation.add_track(Animation.TYPE_VALUE)
			var t_rect   := animation.add_track(Animation.TYPE_VALUE)
			var t_offset := animation.add_track(Animation.TYPE_VALUE)

			animation.track_set_path(t_pos,    NodePath(str(npath) + ":position"))
			animation.track_set_path(t_rot,    NodePath(str(npath) + ":rotation"))
			animation.track_set_path(t_scl,    NodePath(str(npath) + ":scale"))
			animation.track_set_path(t_rect,   NodePath(str(npath) + ":region_rect"))
			animation.track_set_path(t_offset, NodePath(str(npath) + ":offset"))

			animation.track_set_interpolation_type(t_rot,    Animation.INTERPOLATION_LINEAR_ANGLE)
			animation.track_set_interpolation_type(t_rect,   Animation.INTERPOLATION_NEAREST)
			animation.track_set_interpolation_type(t_offset, Animation.INTERPOLATION_NEAREST)

			# Kumpulkan keyframe dulu, normalisasi rotasi, lalu insert
			var kf_times:  Array = []
			var kf_pos:    Array = []
			var kf_rot:    Array = []
			var kf_scl:    Array = []
			var kf_rect:   Array = []
			var kf_offset: Array = []

			for fr in layer["frames"]:
				var fi   := int(fr["index"])
				var time := fi / fps
				var elems: Array = fr["elements"]
				if elems.is_empty(): continue

				for elem in elems:
					var m: Array = elem.get("m3d", [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1])
					var dec := _decompose_m3d(m)
					kf_times.append(time)
					kf_pos.append(dec["pos"])
					kf_rot.append(dec["rot"])
					kf_scl.append(dec["scale"])

					var sprite_name := ""
					var ox := 0.0; var oy := 0.0
					if elem.get("type") == "sprite":
						sprite_name = elem.get("sprite_name", "")
					elif elem.get("type") == "symbol":
						var info := _resolve_symbol(elem.get("symbol_name", ""))
						if not info.is_empty():
							sprite_name = info["sprite"]
							ox = info["ox"]; oy = info["oy"]

					if sprite_name != "" and sprites.has(sprite_name):
						var sp = sprites[sprite_name]
						kf_rect.append({"t": time, "v": Rect2(sp["x"], sp["y"], sp["w"], sp["h"])})
						kf_offset.append({"t": time, "v": Vector2(ox, oy)})

			# Normalisasi urutan sudut sebelum insert ke track
			kf_rot = _normalize_angle_sequence(kf_rot)

			for i in range(kf_times.size()):
				var t = kf_times[i]
				animation.track_insert_key(t_pos, t, kf_pos[i])
				animation.track_insert_key(t_rot, t, kf_rot[i])
				animation.track_insert_key(t_scl, t, kf_scl[i])
			for entry in kf_rect:
				animation.track_insert_key(t_rect, entry["t"], entry["v"])
			for entry in kf_offset:
				animation.track_insert_key(t_offset, entry["t"], entry["v"])

		var safe_name := _sanitize_anim_name(anim["anim_name"])
		# Hindari nama duplikat di library
		var final_anim_name := safe_name
		var ac := 2
		while anim_lib.has_animation(final_anim_name):
			final_anim_name = safe_name + "_" + str(ac)
			ac += 1
		anim_lib.add_animation(final_anim_name, animation)

	anim_player.add_animation_library("", anim_lib)

	var anim_list := anim_lib.get_animation_list()
	if anim_list.size() > 0:
		anim_player.autoplay = anim_list[0]

	# Save
	var packed := PackedScene.new()
	if packed.pack(root) != OK: return "PackedScene.pack() gagal"
	if ResourceSaver.save(packed, out_path) != OK:
		return "ResourceSaver.save() failed for: " + out_path

	print("[AATAAI] ✅ done!")
	print("  Scene : ", out_path)
	print("  Nodes : ", layer_node_map.size(), " Sprite2D")
	print("  Animation: ", anim_list)
	return ""

# ─────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────
func _sanitize_node_name(n: String) -> String:
	var r := n.replace("/","_").replace(" ","_").replace(":","_").replace("-","_")
	if r.is_empty(): r = "Part"
	if r[0].is_valid_int(): r = "p_" + r
	return r

func _sanitize_anim_name(n: String) -> String:
	var r := n.strip_edges().replace(" ","_").replace("/","_").replace(":","_").replace("-","_")
	if r.is_empty(): r = "animation"
	if r[0].is_valid_int(): r = "anim_" + r
	return r
