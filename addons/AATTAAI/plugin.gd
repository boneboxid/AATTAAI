@tool
extends EditorPlugin

var _import_dialog: Window
var _atlas_edit: LineEdit
var _folder_edit: LineEdit
var _png_edit: LineEdit
var _out_edit: LineEdit
var _fps_spin: SpinBox
var _file_list_lbl: Label
var _status_lbl: Label
var _btn_import: Button

var _atlas_val_lbl: Label
var _folder_val_lbl: Label
var _png_val_lbl: Label

const SETTINGS_PATH = "res://.godot/aattaai_settings.cfg"

func _enter_tree() -> void:
	add_tool_menu_item("Import Adobe Animate...", _on_import_menu_pressed)
	print("[AdobeAnimateImporter] Plugin loaded.")

func _exit_tree() -> void:
	remove_tool_menu_item("Import Adobe Animate...")
	if _import_dialog:
		_import_dialog.queue_free()

func _on_import_menu_pressed() -> void:
	if not _import_dialog:
		_import_dialog = _build_dialog()
		get_editor_interface().get_base_control().add_child(_import_dialog)
	
	# Populate selection from FileSystem Dock before showing the window
	_populate_from_selection()
	_import_dialog.popup_centered(Vector2i(600, 520))

func _populate_from_selection() -> void:
	if not get_editor_interface():
		return
	var selected_paths := get_editor_interface().get_selected_paths()
	if selected_paths.is_empty():
		return
	
	for path in selected_paths:
		if path.ends_with(".json"):
			var fname := path.get_file().to_lower()
			if fname.contains("spritemap") or fname.contains("atlas") or fname.contains("spritesheet"):
				_atlas_edit.text = path
				_auto_predict_from_atlas(path)
			else:
				# Assume it might be an animation file, select its folder
				_folder_edit.text = path.get_base_dir()
		elif path.ends_with(".png"):
			_png_edit.text = path
			# Try to predict atlas and folder if they are empty
			if _atlas_edit.text.strip_edges().is_empty():
				var predicted_atlas := path.get_base_dir().path_join(path.get_file().get_basename() + ".json")
				if FileAccess.file_exists(predicted_atlas):
					_atlas_edit.text = predicted_atlas
					_auto_predict_from_atlas(predicted_atlas)
		elif DirAccess.dir_exists_absolute(path):
			_folder_edit.text = path
	
	_validate_all()

func _auto_predict_from_atlas(atlas_path: String) -> void:
	if atlas_path.is_empty():
		return
	var base_dir := atlas_path.get_base_dir()
	var atlas_basename := atlas_path.get_file().get_basename()
	
	# 1. Predict PNG
	var predicted_png := base_dir.path_join(atlas_basename + ".png")
	if FileAccess.file_exists(predicted_png):
		_png_edit.text = predicted_png
	else:
		var spritemap_png := base_dir.path_join("spritemap1.png")
		if FileAccess.file_exists(spritemap_png):
			_png_edit.text = spritemap_png
		else:
			var dir := DirAccess.open(base_dir)
			if dir != null:
				dir.list_dir_begin()
				var f := dir.get_next()
				var pngs := []
				while f != "":
					if not dir.current_is_dir() and f.ends_with(".png"):
						pngs.append(f)
					f = dir.get_next()
				dir.list_dir_end()
				if pngs.size() == 1:
					_png_edit.text = base_dir.path_join(pngs[0])
				elif pngs.size() > 1:
					_png_edit.text = base_dir.path_join(pngs[0])

	# 2. Predict Animation Folder
	var predicted_anim_folder := base_dir.path_join("animations")
	if DirAccess.dir_exists_absolute(predicted_anim_folder):
		_folder_edit.text = predicted_anim_folder
	else:
		predicted_anim_folder = base_dir.path_join("animation")
		if DirAccess.dir_exists_absolute(predicted_anim_folder):
			_folder_edit.text = predicted_anim_folder
		else:
			_folder_edit.text = base_dir

	# 3. Predict Output Scene Path
	var character_name := "imported_character"
	if atlas_basename != "spritemap1" and atlas_basename != "spritesheet" and atlas_basename != "atlas":
		character_name = atlas_basename
	_out_edit.text = base_dir.path_join(character_name + ".tscn")

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "atlas_path", _atlas_edit.text.strip_edges())
	config.set_value("settings", "folder_path", _folder_edit.text.strip_edges())
	config.set_value("settings", "png_path", _png_edit.text.strip_edges())
	config.set_value("settings", "out_path", _out_edit.text.strip_edges())
	config.set_value("settings", "fps_override", int(_fps_spin.value))
	
	var dir := DirAccess.open("res://")
	if dir != null and not dir.dir_exists(".godot"):
		dir.make_dir(".godot")
	config.save(SETTINGS_PATH)

func _load_settings() -> Dictionary:
	var res := {
		"atlas_path": "",
		"folder_path": "",
		"png_path": "",
		"out_path": "res://imported_character.tscn",
		"fps_override": 0
	}
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		res["atlas_path"] = config.get_value("settings", "atlas_path", "")
		res["folder_path"] = config.get_value("settings", "folder_path", "")
		res["png_path"] = config.get_value("settings", "png_path", "")
		res["out_path"] = config.get_value("settings", "out_path", "res://imported_character.tscn")
		res["fps_override"] = int(config.get_value("settings", "fps_override", 0))
	return res

func _validate_all() -> void:
	if not _atlas_edit: return
	var atlas_ok := false
	var folder_ok := false
	var png_ok := false
	
	# Validate Atlas
	var atlas_path := _atlas_edit.text.strip_edges()
	if atlas_path.is_empty():
		_atlas_val_lbl.text = "❌ Path is empty."
		_atlas_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	elif not FileAccess.file_exists(atlas_path):
		_atlas_val_lbl.text = "❌ File does not exist."
		_atlas_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	elif not atlas_path.ends_with(".json"):
		_atlas_val_lbl.text = "⚠️ Must be a .json file."
		_atlas_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	else:
		_atlas_val_lbl.text = "✅ File exists."
		_atlas_val_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		atlas_ok = true

	# Validate PNG
	var png_path := _png_edit.text.strip_edges()
	if png_path.is_empty():
		_png_val_lbl.text = "❌ Path is empty."
		_png_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	elif not FileAccess.file_exists(png_path):
		_png_val_lbl.text = "❌ File does not exist."
		_png_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	elif not png_path.ends_with(".png"):
		_png_val_lbl.text = "⚠️ Must be a .png file."
		_png_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	else:
		_png_val_lbl.text = "✅ File exists."
		_png_val_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		png_ok = true

	# Validate Folder/File & preview animations list
	var folder_path := _folder_edit.text.strip_edges()
	_update_file_list(folder_path, _file_list_lbl)
	
	var is_valid_input := false
	if not folder_path.is_empty():
		var path_to_check := ProjectSettings.globalize_path(folder_path) if folder_path.begins_with("res://") else folder_path
		if DirAccess.dir_exists_absolute(path_to_check) or FileAccess.file_exists(path_to_check):
			is_valid_input = true
		
	if not is_valid_input:
		_folder_val_lbl.text = "❌ Path does not exist."
		_folder_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		var files := _get_anim_files_in_folder(folder_path)
		if files.is_empty():
			_folder_val_lbl.text = "⚠️ Path exists, but no animation JSON files found."
			_folder_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		else:
			_folder_val_lbl.text = "✅ Path exists with %d animations." % files.size()
			_folder_val_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			folder_ok = true

	_btn_import.disabled = not (atlas_ok and folder_ok and png_ok)

func _get_anim_files_in_folder(folder: String) -> Array:
	var result: Array = []
	if folder.is_empty():
		return result
	
	var path_to_check := ProjectSettings.globalize_path(folder) if folder.begins_with("res://") else folder
	if FileAccess.file_exists(path_to_check) and folder.ends_with(".json"):
		result.append(folder.get_file())
		return result
		
	if not DirAccess.dir_exists_absolute(path_to_check):
		return result
		
	var dir := DirAccess.open(folder)
	if dir == null:
		return result
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".json"):
			var lower := f.to_lower()
			if not lower.begins_with("spritemap") and not lower.begins_with("atlas"):
				result.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

func _update_file_list(folder: String, lbl: Label) -> void:
	var files := _get_anim_files_in_folder(folder)
	var path_to_check := ProjectSettings.globalize_path(folder) if folder.begins_with("res://") else folder
	var is_file := FileAccess.file_exists(path_to_check)
	var is_dir := DirAccess.dir_exists_absolute(path_to_check)
	if folder.is_empty() or (not is_file and not is_dir):
		lbl.text = "(path not found)"
		return
	if files.is_empty():
		lbl.text = "There is no Animation JSON in the path."
	else:
		lbl.text = "%d file(s) found:\n  • " % files.size() + "\n  • ".join(files)

func _build_dialog() -> Window:
	var dlg := Window.new()
	dlg.title = "Adobe Animate Importer (AATAAI)"
	dlg.size = Vector2i(600, 520)
	dlg.exclusive = true

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	dlg.add_child(vbox)

	# ── Header Information ───────────────────────────────
	var header := Label.new()
	header.text = "ℹ️ Select the Spritemap JSON to auto-predict other paths."
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())

	# ── Spritemap JSON ────────────────────────────────────
	vbox.add_child(_label("Spritemap JSON (spritemap1.json):"))
	_atlas_edit = LineEdit.new()
	_atlas_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_atlas_edit.placeholder_text = "res://assets/spritemap1.json"
	var row_atlas := _browse_row(_atlas_edit); vbox.add_child(row_atlas)
	
	_atlas_val_lbl = Label.new()
	_atlas_val_lbl.text = "❌ No file selected."
	_atlas_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(_atlas_val_lbl)

	# ── Spritesheet PNG ──────────────────────────────────
	vbox.add_child(_label("Spritesheet PNG (spritemap1.png):"))
	_png_edit = LineEdit.new()
	_png_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_png_edit.placeholder_text = "res://assets/spritemap1.png"
	var row_png := _browse_row(_png_edit); vbox.add_child(row_png)
	
	_png_val_lbl = Label.new()
	_png_val_lbl.text = "❌ No file selected."
	_png_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(_png_val_lbl)

	# ── Animation JSON File or Folder ─────────────────────
	vbox.add_child(_label("Animation JSON File or Folder:"))
	_folder_edit = LineEdit.new()
	_folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_folder_edit.placeholder_text = "res://assets/Animation.json or res://assets/animations/"
	var row_folder := HBoxContainer.new(); vbox.add_child(row_folder)
	row_folder.add_child(_folder_edit)
	
	var btn_folder_file := Button.new(); btn_folder_file.text = "Browse File"
	row_folder.add_child(btn_folder_file)
	
	var btn_folder := Button.new(); btn_folder.text = "Browse Folder"
	row_folder.add_child(btn_folder)
	
	_folder_val_lbl = Label.new()
	_folder_val_lbl.text = "❌ No file or folder selected."
	_folder_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(_folder_val_lbl)

	# ── Preview daftar file (Scrollable) ──────────────────
	var scroll_preview := ScrollContainer.new()
	scroll_preview.custom_minimum_size = Vector2(0, 100)
	scroll_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll_preview)

	_file_list_lbl = Label.new()
	_file_list_lbl.text = "(select the folder for the list)"
	_file_list_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_file_list_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_file_list_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_preview.add_child(_file_list_lbl)

	# ── Output scene ─────────────────────────────────────
	vbox.add_child(_label("Output scene path:"))
	_out_edit = LineEdit.new()
	_out_edit.text = "res://imported_character.tscn"
	_out_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_out_edit)

	# ── FPS override ─────────────────────────────────────
	var fps_row := HBoxContainer.new(); vbox.add_child(fps_row)
	fps_row.add_child(_label("FPS override (0 = dari JSON):"))
	_fps_spin = SpinBox.new()
	_fps_spin.min_value = 0; _fps_spin.max_value = 120; _fps_spin.value = 0
	fps_row.add_child(_fps_spin)

	vbox.add_child(HSeparator.new())

	# ── Status ───────────────────────────────────────────
	_status_lbl = Label.new()
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_lbl)

	# ── Import button ─────────────────────────────────────
	_btn_import = Button.new()
	_btn_import.text = "⬇️ Import & Generate Scene"
	vbox.add_child(_btn_import)

	# ── File dialogs ─────────────────────────────────────
	var fd_atlas := _make_file_dialog(dlg, "*.json", _atlas_edit)
	var fd_png   := _make_file_dialog(dlg, "*.png",  _png_edit)
	var fd_anim_file := _make_file_dialog(dlg, "*.json", _folder_edit)

	# Folder dialog
	var fd_folder := FileDialog.new()
	fd_folder.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	fd_folder.access = FileDialog.ACCESS_RESOURCES
	dlg.add_child(fd_folder)

	# Hubungkan browse buttons
	_get_browse_btn(row_atlas).pressed.connect(func(): fd_atlas.popup_centered(Vector2i(700,500)))
	_get_browse_btn(row_png).pressed.connect(func():   fd_png.popup_centered(Vector2i(700,500)))
	btn_folder_file.pressed.connect(func(): fd_anim_file.popup_centered(Vector2i(700,500)))
	btn_folder.pressed.connect(func(): fd_folder.popup_centered(Vector2i(700,500)))

	# Load settings on start
	var settings := _load_settings()
	_atlas_edit.text = settings["atlas_path"]
	_folder_edit.text = settings["folder_path"]
	_png_edit.text = settings["png_path"]
	_out_edit.text = settings["out_path"]
	_fps_spin.value = settings["fps_override"]

	# Connect signals for validation and prediction
	_atlas_edit.text_changed.connect(func(t: String):
		_auto_predict_from_atlas(t.strip_edges())
		_validate_all()
	)
	_png_edit.text_changed.connect(func(t: String):
		_validate_all()
	)
	_folder_edit.text_changed.connect(func(t: String):
		_validate_all()
	)
	_out_edit.text_changed.connect(func(t: String):
		_validate_all()
	)

	# File Dialog selections trigger validation and prediction
	fd_atlas.file_selected.connect(func(path: String):
		_atlas_edit.text = path
		_auto_predict_from_atlas(path)
		_validate_all()
	)
	fd_png.file_selected.connect(func(path: String):
		_png_edit.text = path
		_validate_all()
	)
	fd_folder.dir_selected.connect(func(dir: String):
		_folder_edit.text = dir
		_validate_all()
	)

	# Run initial validation
	_validate_all()

	# ── Import logic ──────────────────────────────────────
	_btn_import.pressed.connect(func():
		var atlas_path := _atlas_edit.text.strip_edges()
		var folder_path := _folder_edit.text.strip_edges()
		var png_path := _png_edit.text.strip_edges()
		var out_path := _out_edit.text.strip_edges()
		var fps_val := int(_fps_spin.value)

		if atlas_path.is_empty() or folder_path.is_empty() or png_path.is_empty() or out_path.is_empty():
			_status_lbl.text = "⚠️ Fill all fields."
			return

		_status_lbl.text = "⏳ Importing..."
		var importer = load("res://addons/AATTAAI/importer.gd").new()
		
		# If folder_path is actually a single JSON file, pass it in the anim_files array override!
		var anim_files_override := []
		var base_folder := folder_path
		if folder_path.ends_with(".json"):
			anim_files_override.append(folder_path)
			base_folder = folder_path.get_base_dir()

		var err: String = importer.import_folder(atlas_path, base_folder, png_path, out_path, fps_val, anim_files_override)

		if err == "":
			_status_lbl.text = "✅ Done! Imported animations successfully.\nScene: %s" % out_path
			_save_settings()
			get_editor_interface().get_resource_filesystem().scan()
		else:
			_status_lbl.text = "❌ Error: " + err
	)

	dlg.close_requested.connect(func(): dlg.hide())
	return dlg

func _label(text: String) -> Label:
	var l := Label.new(); l.text = text; return l

func _browse_row(edit: LineEdit) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(edit)
	var btn := Button.new(); btn.text = "Browse"
	row.add_child(btn)
	return row

func _get_browse_btn(row: HBoxContainer) -> Button:
	return row.get_child(1) as Button

func _make_file_dialog(parent: Window, filter: String, target: LineEdit) -> FileDialog:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.filters = [filter]
	parent.add_child(fd)
	fd.file_selected.connect(func(path: String): target.text = path)
	return fd
