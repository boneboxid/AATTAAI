@tool
extends Node2D

@export_file("*.json") var atlas_json_path: String = ""
@export_file("*.json") var animation_json_path: String = ""
@export_dir var animation_folder_path: String = ""
@export_file("*.png")  var png_path: String = ""
@export var fps_override: int = 0
@export var auto_play: String = ""

var _sprites: Dictionary = {}
var _symbol_map: Dictionary = {}
var _texture: Texture2D

func _ready() -> void:
	if atlas_json_path and png_path and (animation_json_path or animation_folder_path):
		build(atlas_json_path, animation_json_path, png_path, animation_folder_path)
		if auto_play != "" and has_node("AnimationPlayer"):
			$AnimationPlayer.play(auto_play)

func build(atlas_path: String, anim_path: String, tex_path: String, anim_folder: String = "") -> void:
	var atlas_data = _load_json(atlas_path)
	if atlas_data == null:
		push_error("[AATAIRuntime] cannot load atlas JSON")
		return

	_sprites = _parse_atlas(atlas_data)
	
	# Scan for anim files
	var anim_files: Array = []
	if not anim_path.is_empty():
		if DirAccess.dir_exists_absolute(anim_path):
			anim_files = _scan_json_files(anim_path)
		else:
			anim_files = [anim_path]
	elif not anim_folder.is_empty() and DirAccess.dir_exists_absolute(anim_folder):
		anim_files = _scan_json_files(anim_folder)

	if anim_files.is_empty():
		push_error("[AATAIRuntime] no animation JSON files found")
		return

	# Load texture
	if ResourceLoader.exists(tex_path):
		_texture = ResourceLoader.load(tex_path) as Texture2D
	
	if _texture == null:
		if FileAccess.file_exists(tex_path):
			var img := Image.new()
			if img.load(tex_path) == OK:
				_texture = ImageTexture.create_from_image(img)

	if _texture == null:
		push_error("[AdobeAnimateRuntime] Texture not found: " + tex_path)
		return

	# Clear old children except AnimationPlayer
	for c in get_children():
		if not c is AnimationPlayer: c.queue_free()
	await get_tree().process_frame  # wait for queue_free

	var ap: AnimationPlayer
	if has_node("AnimationPlayer"):
		ap = $AnimationPlayer
	else:
		ap = AnimationPlayer.new()
		ap.name = "AnimationPlayer"
		add_child(ap)
		if Engine.is_editor_hint():
			ap.owner = get_tree().edited_scene_root

	# Parse all animations and accumulate symbol map
	_symbol_map.clear()
	var all_animations: Array = []
	for json_path in anim_files:
		var anim_data = _load_json(json_path)
		if anim_data == null:
			push_warning("[AATAIRuntime] skip invalid JSON: " + json_path)
			continue
		
		# Build symbol map (accumulates)
		_build_symbol_map(anim_data)
		
		var parsed := _parse_animations(anim_data)
		var file_name := json_path.get_file().get_basename()
		for anim in parsed:
			anim["name"] = file_name
			all_animations.append(anim)

	if all_animations.is_empty():
		push_error("[AATAIRuntime] all animation JSON files failed to parse")
		return

	var lib := AnimationLibrary.new()

	# Create parts
	var layer_nodes: Dictionary = {}
	var anim_layer_key: Dictionary = {}

	for ai in range(all_animations.size()):
		var anim_names_used: Dictionary = {}
		for layer in all_animations[ai]["layers"]:
			var base := _sanitize(layer["name"])
			var node_key: String
			if base in anim_names_used:
				node_key = base + "#" + str(layer["layer_idx"])
			else:
				node_key = base
				anim_names_used[base] = true
			anim_layer_key[str(ai) + "#" + str(layer["layer_idx"])] = node_key

			if node_key in layer_nodes: continue
			var spr := Sprite2D.new()
			var fname := node_key; var c2 := 2
			while has_node(NodePath(fname)):
				fname = node_key + str(c2); c2 += 1
			spr.name = fname
			spr.texture = _texture
			spr.centered = false
			spr.region_enabled = true
			add_child(spr)
			if Engine.is_editor_hint():
				spr.owner = get_tree().edited_scene_root
			layer_nodes[node_key] = spr

	# Build animations
	for ai in range(all_animations.size()):
		var anim = all_animations[ai]
		var fps: float = anim["fps"]
		var animation := Animation.new()
		animation.loop_mode = Animation.LOOP_LINEAR
		animation.length = anim["length"]

		# Active nodes set
		var active_keys := {}
		for layer in anim["layers"]:
			var lookup := str(ai) + "#" + str(layer["layer_idx"])
			var node_key: String = anim_layer_key.get(lookup, "")
			if node_key != "":
				active_keys[node_key] = true

		# Hide inactive nodes at t = 0
		for node_key in layer_nodes:
			if not active_keys.has(node_key):
				var node: Sprite2D = layer_nodes[node_key]
				var np := get_path_to(node)
				var t_vis := animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(t_vis, NodePath(str(np) + ":visible"))
				animation.track_set_interpolation_type(t_vis, Animation.INTERPOLATION_NEAREST)
				animation.track_insert_key(t_vis, 0.0, false)

		for layer in anim["layers"]:
			var lookup := str(ai) + "#" + str(layer["layer_idx"])
			var nk: String = anim_layer_key.get(lookup, "")
			if nk == "" or not layer_nodes.has(nk): continue
			var node: Sprite2D = layer_nodes[nk]
			var np := get_path_to(node)

			var tp  := animation.add_track(Animation.TYPE_VALUE)
			var tr  := animation.add_track(Animation.TYPE_VALUE)
			var ts  := animation.add_track(Animation.TYPE_VALUE)
			var trc := animation.add_track(Animation.TYPE_VALUE)
			var to_ := animation.add_track(Animation.TYPE_VALUE)
			var t_vis := animation.add_track(Animation.TYPE_VALUE)

			animation.track_set_path(tp,  NodePath(str(np)+":position"))
			animation.track_set_path(tr,  NodePath(str(np)+":rotation"))
			animation.track_set_path(ts,  NodePath(str(np)+":scale"))
			animation.track_set_path(trc, NodePath(str(np)+":region_rect"))
			animation.track_set_path(to_, NodePath(str(np)+":offset"))
			animation.track_set_path(t_vis, NodePath(str(np)+":visible"))

			animation.track_set_interpolation_type(tr,  Animation.INTERPOLATION_LINEAR_ANGLE)
			animation.track_set_interpolation_type(trc, Animation.INTERPOLATION_NEAREST)
			animation.track_set_interpolation_type(to_, Animation.INTERPOLATION_NEAREST)
			animation.track_set_interpolation_type(t_vis, Animation.INTERPOLATION_NEAREST)

			var kf_times:  Array = []
			var kf_pos:    Array = []
			var kf_rot:    Array = []
			var kf_scl:    Array = []
			var kf_rect:   Array = []
			var kf_offset: Array = []
			var kf_vis:    Array = []

			# Lacak status visibilitas per frame
			var frame_activity := {}
			for fr in layer["frames"]:
				var fi := int(fr["index"])
				var du := int(fr["duration"])
				var active: bool = not fr["elements"].is_empty()
				for f_idx in range(fi, fi + du):
					frame_activity[f_idx] = active

			var total_frames := int(round(anim["length"] * fps))
			var last_vis_state := false
			if frame_activity.has(0):
				last_vis_state = frame_activity[0]
			else:
				last_vis_state = false
			kf_vis.append({"t": 0.0, "v": last_vis_state})

			for f_idx in range(1, total_frames):
				var current_state := false
				if frame_activity.has(f_idx):
					current_state = frame_activity[f_idx]
				else:
					current_state = false
				
				if current_state != last_vis_state:
					kf_vis.append({"t": f_idx / fps, "v": current_state})
					last_vis_state = current_state

			for fr in layer["frames"]:
				var fi := int(fr["index"])
				var t  := fi / fps
				var elems: Array = fr["elements"]
				if elems.is_empty(): continue

				for elem in elems:
					var d := _decompose(elem.get("m3d", [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]))
					kf_times.append(t)
					kf_pos.append(d["pos"])
					kf_rot.append(d["rot"])
					kf_scl.append(d["scale"])

					var sname := ""; var ox := 0.0; var oy := 0.0
					if elem.get("type") == "sprite":
						sname = elem.get("sprite_name", "")
					elif elem.get("type") == "symbol":
						var info := _resolve(elem.get("symbol_name", ""))
						if not info.is_empty():
							sname = info["sprite"]; ox = info["ox"]; oy = info["oy"]
					if sname != "" and _sprites.has(sname):
						var sp = _sprites[sname]
						kf_rect.append({"t": t, "v": Rect2(sp.x, sp.y, sp.w, sp.h)})
						kf_offset.append({"t": t, "v": Vector2(ox, oy)})

			kf_rot = _normalize_angle_sequence(kf_rot)

			for i in range(kf_times.size()):
				var t = kf_times[i]
				animation.track_insert_key(tp, t, kf_pos[i])
				animation.track_insert_key(tr, t, kf_rot[i])
				animation.track_insert_key(ts, t, kf_scl[i])
			for entry in kf_rect:
				animation.track_insert_key(trc, entry["t"], entry["v"])
			for entry in kf_offset:
				animation.track_insert_key(to_, entry["t"], entry["v"])
			for entry in kf_vis:
				animation.track_insert_key(t_vis, entry["t"], entry["v"])

		lib.add_animation(_sanim(anim["name"]), animation)

	ap.add_animation_library("", lib)
	if lib.get_animation_list().size() > 0 and auto_play.is_empty():
		ap.autoplay = lib.get_animation_list()[0]
	print("[AATAAIRuntime] Done. Parts: %d, Animations: %d" % [layer_nodes.size(), all_animations.size()])

# ── helpers ──────────────────────────────────────────────
func _load_json(path: String):
	if not FileAccess.file_exists(path): return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return null
	var text := f.get_as_text(); f.close()
	if text.begins_with("\ufeff"): text = text.substr(1)
	return JSON.parse_string(text)

func _parse_atlas(data: Dictionary) -> Dictionary:
	var r := {}
	var arr: Array = data.get("ATLAS", {}).get("SPRITES", data.get("sprites",[]))
	for e in arr:
		var sp = e.get("SPRITE", e)
		var n := str(sp.get("name",""))
		r[n] = {x=int(sp.get("x",0)), y=int(sp.get("y",0)), w=int(sp.get("w",1)), h=int(sp.get("h",1))}
	return r

func _get_fps(data: Dictionary) -> float:
	if data.has("MD") and data["MD"].has("FRT"): return float(data["MD"]["FRT"])
	if data.has("AN") and data["AN"].get("MD",{}).has("FRT"): return float(data["AN"]["MD"]["FRT"])
	return 24.0

func _build_symbol_map(data: Dictionary) -> void:
	for sym in data.get("SD", {}).get("S", []):
		var sn: String = sym.get("SN","")
		if sn.is_empty(): continue
		for layer in sym.get("TL",{}).get("L",[]):
			if layer.get("LN","") == "CenterMarker": continue
			for fr in layer.get("FR",[]):
				for elem in fr.get("E",[]):
					if not elem.has("ASI"): continue
					var asi = elem["ASI"]
					var sp_name := str(asi.get("N",""))
					if sp_name.is_empty() or not _sprites.has(sp_name): continue
					var m: Array = asi.get("M3D",[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1])
					_symbol_map[sn] = {"sprite":sp_name,"ox":float(m[12]),"oy":float(m[13])}
					break

func _resolve(sym: String) -> Dictionary:
	return _symbol_map.get(sym, {})

func _parse_animations(data: Dictionary) -> Array:
	var anims := []
	if not data.has("AN"): return anims
	var an = data["AN"]
	var parsed_layers := []
	var raw = an.get("TL",{}).get("L",[])
	for i in range(raw.size()):
		var layer = raw[i]
		if layer.get("LN","") == "CenterMarker": continue
		var frames := []
		for fr in layer.get("FR",[]):
			var elems := []
			for elem in fr.get("E",[]):
				var e := {}
				if elem.has("SI"):
					e = {"type":"symbol","symbol_name":elem["SI"].get("SN",""),"m3d":elem["SI"].get("M3D",[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1])}
				elif elem.has("ASI"):
					e = {"type":"sprite","sprite_name":str(elem["ASI"].get("N","")),"m3d":elem["ASI"].get("M3D",[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1])}
				if not e.is_empty(): elems.append(e)
			frames.append({"index":int(fr.get("I",0)),"duration":int(fr.get("DU",1)),"elements":elems})
		parsed_layers.append({"name":layer.get("LN","Layer"),"layer_idx":i,"frames":frames})
	
	var max_frame := 0
	for layer in parsed_layers:
		for fr in layer["frames"]:
			max_frame = max(max_frame, int(fr["index"]) + int(fr["duration"]))
	
	var fps := float(fps_override) if fps_override > 0 else _get_fps(data)
	anims.append({
		"name": an.get("SN", an.get("N", "animation")),
		"layers": parsed_layers,
		"fps": fps,
		"length": max_frame / fps
	})
	return anims

func _decompose(m: Array) -> Dictionary:
	var a := float(m[0]); var b := float(m[1])
	var c := float(m[4]); var d := float(m[5])
	var sx := sqrt(a*a+b*b); var sy := sqrt(c*c+d*d)
	if (a*d-b*c)<0.0: sy=-sy
	return {"pos":Vector2(float(m[12]),float(m[13])),"rot":atan2(b,a),"scale":Vector2(sx,sy)}

func _normalize_angle_sequence(angles: Array) -> Array:
	if angles.size() <= 1: return angles
	var out: Array = angles.duplicate()
	for i in range(1, out.size()):
		var prev: float = out[i - 1]
		var curr: float = out[i]
		var diff: float = fmod(curr - prev + 3.0 * PI, TAU) - PI
		out[i] = prev + diff
	return out

func _sanitize(s: String) -> String:
	var r := s.replace("/","_").replace(" ","_").replace(":","_").replace("-","_")
	if r.is_empty(): r="Part"
	if r[0].is_valid_int(): r="p_"+r
	return r

func _sanim(s: String) -> String:
	var r := s.strip_edges().replace(" ","_").replace("/","_").replace(":","_")
	if r.is_empty(): r="animation"
	if r[0].is_valid_int(): r="anim_"+r
	return r

func _scan_json_files(folder: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(folder)
	if dir == null: return result
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var lower := fname.to_lower()
			if not lower.begins_with("spritemap") and not lower.begins_with("atlas"):
				result.append(folder.path_join(fname))
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
