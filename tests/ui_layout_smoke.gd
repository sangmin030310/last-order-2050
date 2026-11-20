extends SceneTree

var issues: Array[String] = []
var inspected := 0

func _initialize() -> void:
	run.call_deferred()

func audit(node: Node, context: String) -> void:
	if node is Panel and node.is_visible_in_tree():
		var content: Array[Control] = []
		for child in node.get_children():
			if (child is Label or child is Button or child is TextureRect) and child.is_visible_in_tree():
				content.append(child)
		for first in range(content.size()):
			for second in range(first + 1, content.size()):
				if Rect2(content[first].position, content[first].size).intersects(Rect2(content[second].position, content[second].size)):
					var description := "%s <> %s" % [content[first].get("text"), content[second].get("text")]
					if not issues.has(description):
						issues.append(description)
	if node is Label and node.is_visible_in_tree():
		inspected += 1
		node.fit_text()
		if node.get_minimum_size().y > node.layout_size.y + 1:
			issues.append(context + ": paragraph too tall: " + node.text)
		if node.get_parent() is Panel:
			var parent: Control = node.get_parent()
			if not Rect2(Vector2.ZERO, parent.size).encloses(Rect2(node.position, node.size)):
				issues.append(context + ": outside panel: " + node.text)
	if node is Button and node.is_visible_in_tree() and node.get_parent() is Panel:
		if not Rect2(Vector2.ZERO, node.get_parent().size).encloses(Rect2(node.position, node.size)):
			issues.append(context + ": button outside panel: " + node.text)
	if node is Button and node.is_visible_in_tree():
		var normal: StyleBoxFlat = node.get_theme_stylebox("normal")
		var focus: StyleBoxFlat = node.get_theme_stylebox("focus")
		var expected_fill := Color("#aaffea") if node.get_meta("archive_selected", false) else Color("#183441")
		if normal.bg_color != expected_fill or focus.bg_color != Color.TRANSPARENT:
			issues.append(context + ": button starts highlighted: " + node.text)
	for child in node.get_children():
		audit(child, context)

func load_scene(scene_name: String) -> Node:
	var scene = load("res://%s.tscn" % scene_name).instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	return scene

func run() -> void:
	var menu = load_scene("main_menu")
	audit(menu, "main menu")
	menu.show_controls()
	audit(menu, "controls")
	menu.close_information()
	menu.show_description()
	audit(menu, "description")
	menu.close_information()
	menu.show_settings()
	audit(menu, "settings")
	menu.free()
	var intro = load_scene("intro")
	intro.show_selection()
	for index in range(intro.character_cards.size()):
		var card: Panel = intro.character_cards[index]
		var expected := "조달이" if index == 0 else "조달호"
		for child in card.get_children():
			if child is TextureRect:
				child.mouse_entered.emit()
				assert(intro.role_heading.text.begins_with(expected), "Image hover must update the role")
			if child is Button:
				child.focus_entered.emit()
				assert(intro.role_heading.text.begins_with(expected), "Keyboard focus must update the role")
	audit(intro, "character selection")
	intro.free()
	for scene_name in ["prologue", "chapter_one", "hospital", "recovery", "archive_room", "stockroom", "dispatch_room"]:
		var scene = load_scene(scene_name)
		audit(scene, scene_name)
		if scene_name == "prologue":
			scene.show_signal_tuning()
			audit(scene, "signal tuning")
		# Exercise every literal dialogue from the source, including late-game branches.
		for script_name in ["prologue", "chapter_one", "hospital", "recovery"]:
			var source := FileAccess.get_file_as_string("res://%s.gd" % script_name)
			var pattern := RegEx.new()
			pattern.compile('(show_overlay|simple_dialog)\\(\\s*"((?:[^"\\\\]|\\\\.)*)",\\s*"((?:[^"\\\\]|\\\\.)*)",\\s*"((?:[^"\\\\]|\\\\.)*)"')
			for matched in pattern.search_all(source):
				scene.show_overlay(matched.get_string(2), matched.get_string(3), matched.get_string(4).c_unescape(), "확인", func(): pass)
				audit(scene, scene_name + "/dialogue")
		if scene_name == "chapter_one":
			scene.show_procurement_terminal()
			audit(scene, "procurement terminal")
			for mission in range(4):
				scene.mission = mission
				scene.selected_route = &"warehouse"
				scene.refresh_mission()
				audit(scene, "chapter HUD")
			for route in [ &"warehouse", &"depot" ]:
				scene.show_offers(route)
				audit(scene, "offers")
				var notice = scene.write_label(scene.overlay, "", Vector2.ZERO, Vector2(632, 55), 15, Color.WHITE, true)
				for item in scene.OFFERS[route]["items"]:
					scene.check_offer(route, item, notice)
					audit(scene, "offer response")
		if scene_name == "hospital":
			for restored in [false, true]:
				root.get_node("Story").hospital_restored = restored
				scene.unlocked = true
				scene.refresh_hospital()
				audit(scene, "hospital HUD")
			root.get_node("Story").hospital_restored = false
			for route in [&"warehouse", &"depot"]:
				root.get_node("Story").hospital_route = route
				scene.player.position = scene.DESK
				scene.interact()
				audit(scene, "hospital delivery " + str(route))
				scene.close_request()
		if scene_name in ["recovery", "archive_room", "stockroom", "dispatch_room"]:
			for stage in range(4):
				scene.stage = stage
				scene.refresh()
				audit(scene, "recovery HUD")
			scene.stage = 2
		if scene_name == "archive_room":
			scene.show_archive()
			audit(scene, "archive")
			scene.select_archive_evidence(0, &"supplier")
			audit(scene, "archive selection")
			scene.show_supply_strategy()
			audit(scene, "supply strategy")
			scene.confirm_diversification()
			audit(scene, "risk notice decision")
			scene.send_risk_notice()
			audit(scene, "risk notice result")
		if scene_name == "stockroom":
			root.get_node("Story").factory_checked = true
			scene.show_reserve_terminal()
			audit(scene, "reserve terminal")
			scene.check_reserve_request()
			audit(scene, "reserve conditions checked")
			scene.approve_reserve_request()
			audit(scene, "reserve approval dialogue")
			scene.show_power_panel()
			var power_guidance_found := false
			for label in scene.circuit_panel.find_children("*", "Label", true, false):
				if "현재 연결:" in label.text and "숫자키 1·2·3" in label.text:
					power_guidance_found = true
			assert(power_guidance_found, "Power routing must explain the current connection and keyboard controls")
			audit(scene, "power panel")
			scene.select_circuit(scene.Circuit.RACK)
			audit(scene, "power handoff notice")
		if scene_name == "dispatch_room":
			scene.dispatch_action(scene.WATER_PORT)
			audit(scene, "dispatch field radio")
			scene.preview_dispatch()
			audit(scene, "dispatch")
			for outcome in [[&"dawn", false], [&"field", false], [&"prepared", true], [&"prepared", false], [&"partial", true], [&"partial", false], [&"evacuation", true]]:
				root.get_node("Story").ending = outcome[0]
				scene.water_offline = outcome[1]
				scene.comms_offline = outcome[0] == &"evacuation" or (outcome[0] in [&"prepared", &"partial"] and not outcome[1])
				scene.show_ending()
				audit(scene, "ending")
				scene.show_policy_summary()
				audit(scene, "policy summary")
		scene.free()
	for issue in issues:
		printerr(issue)
	print("Checked ", inspected, " labels; layout issues: ", issues.size())
	quit(0 if issues.is_empty() else 1)
