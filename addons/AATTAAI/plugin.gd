@tool
extends EditorPlugin

var _import_dialog: Window

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
	_import_dialog.popup_centered(Vector2i(560, 420))

func _build_dialog() -> Window:
	var dlg := Window.new()
	dlg.title = "AATAAI"
	dlg.size = Vector2i(560, 420)
	dlg.exclusive = true

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	dlg.add_child(vbox)

	# ── Spritemap JSON ────────────────────────────────────
	vbox.add_child(_label("Spritemap JSON (spritemap1.json):"))
	var atlas_edit := LineEdit.new()
	atlas_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	atlas_edit.placeholder_text = "res://assets/spritemap1.json"
	var row_atlas := _browse_row(atlas_edit); vbox.add_child(row_atlas)

	# ── Folder Animation JSONs ────────────────────────────
	vbox.add_child(_label("Folder Animation JSONs (all *.json di-import):"))
	var folder_edit := LineEdit.new()
	folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder_edit.placeholder_text = "res://assets/animations/"
	var row_folder := HBoxContainer.new(); vbox.add_child(row_folder)
	row_folder.add_child(folder_edit)
	var btn_folder := Button.new(); btn_folder.text = "Browse Folder"
	row_folder.add_child(btn_folder)

	# ── Preview daftar file ───────────────────────────────
	var file_list_lbl := Label.new()
	file_list_lbl.text = "(select the folder for the list)"
	file_list_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	file_list_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(file_list_lbl)

	# ── PNG ──────────────────────────────────────────────
	vbox.add_child(_label("Spritesheet PNG (spritemap1.png):"))
	var png_edit := LineEdit.new()
	png_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	png_edit.placeholder_text = "res://assets/spritemap1.png"
	var row_png := _browse_row(png_edit); vbox.add_child(row_png)

	# ── Output scene ─────────────────────────────────────
	vbox.add_child(_label("Output scene path:"))
	var out_edit := LineEdit.new()
	out_edit.text = "res://imported_character.tscn"
	out_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(out_edit)

	# ── FPS override ─────────────────────────────────────
	var fps_row := HBoxContainer.new(); vbox.add_child(fps_row)
	fps_row.add_child(_label("FPS override (0 = dari JSON):"))
	var fps_spin := SpinBox.new()
	fps_spin.min_value = 0; fps_spin.max_value = 120; fps_spin.value = 0
	fps_row.add_child(fps_spin)

	vbox.add_child(HSeparator.new())

	# ── Status ───────────────────────────────────────────
	var status_lbl := Label.new()
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_lbl)

	# ── Import button ─────────────────────────────────────
	var btn_import := Button.new()
	btn_import.text = "⬇  Import & Generate Scene"
	vbox.add_child(btn_import)

	# ── File dialogs ─────────────────────────────────────
	var fd_atlas := _make_file_dialog(dlg, "*.json", atlas_edit)
	var fd_png   := _make_file_dialog(dlg, "*.png",  png_edit)

	# Folder dialog
	var fd_folder := FileDialog.new()
	fd_folder.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	fd_folder.access = FileDialog.ACCESS_RESOURCES
	dlg.add_child(fd_folder)

	# Hubungkan browse buttons
	_get_browse_btn(row_atlas).pressed.connect(func(): fd_atlas.popup_centered(Vector2i(700,500)))
	_get_browse_btn(row_png).pressed.connect(func():   fd_png.popup_centered(Vector2i(700,500)))
	btn_folder.pressed.connect(func(): fd_folder.popup_centered(Vector2i(700,500)))

	# Update preview saat folder dipilih
	fd_folder.dir_selected.connect(func(dir: String):
		folder_edit.text = dir
		_update_file_list(dir, file_list_lbl)
	)
	# Update preview juga saat ketik manual
	folder_edit.text_changed.connect(func(t: String):
		_update_file_list(t, file_list_lbl)
	)

	# ── Import logic ──────────────────────────────────────
	btn_import.pressed.connect(func():
		var atlas_path := atlas_edit.text.strip_edges()
		var folder_path := folder_edit.text.strip_edges()
		var png_path := png_edit.text.strip_edges()
		var out_path := out_edit.text.strip_edges()
		var fps_val := int(fps_spin.value)

		if atlas_path.is_empty() or folder_path.is_empty() or png_path.is_empty() or out_path.is_empty():
			status_lbl.text = "fill all the field."
			return

		status_lbl.text = "⏳ Importing..."
		var importer = load("res://addons/AATTAAI/importer.gd").new()
		var err: String = importer.import_folder(atlas_path, folder_path, png_path, out_path, fps_val)

		if err == "":
			# Hitung berapa file yang diimport
			var files = importer._scan_json_files(folder_path)
			status_lbl.text = "done! %d animation from %d file.\nScene: %s" % [
				files.size(), files.size(), out_path
			]
			# Refresh FileSystem di editor
			get_editor_interface().get_resource_filesystem().scan()
		else:
			status_lbl.text = " Error: " + err
	)

	dlg.close_requested.connect(func(): dlg.hide())
	return dlg

# ── Helpers UI ────────────────────────────────────────────

func _update_file_list(folder: String, lbl: Label) -> void:
	if folder.is_empty() or not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(folder) if folder.begins_with("res://") else folder):
		lbl.text = "(folder not found)"
		return
	# Scan langsung tanpa instansiasi importer
	var dir := DirAccess.open(folder)
	if dir == null:
		lbl.text = "(can't open the folder)"
		return
	var files: Array = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".json"):
			var lower := f.to_lower()
			if not lower.begins_with("spritemap") and not lower.begins_with("atlas"):
				files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort()
	if files.is_empty():
		lbl.text = "There is no Animation JSON in the folder."
	else:
		lbl.text = "%d file found:\n  • " % files.size() + "\n  • ".join(files)

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
