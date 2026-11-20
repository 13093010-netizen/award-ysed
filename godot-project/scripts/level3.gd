extends Control
## 第三關：蟲蟲大戰（回合制對戰）
## 第一戰：巨大蚜蟲 → 派出瓢蟲最有效
## 大魔王：瘟神（帶來白粉病）→ 小蘇打水最有效
## 麥田有血條，主角有 3 條命；剩幾條命就拿幾顆星

signal back_to_title
signal restart
signal next_level
signal completed(stars: int)
signal tapped

const Art = preload("res://scripts/art.gd")
const ResultPanel = preload("res://scripts/result_panel.gd")

enum Phase { STORY, PLAYER, BUSY, RESULT }
const MAX_HP := 100.0
const HEAL := 30.0
const ENEMIES := [
	{"name": "巨大蚜蟲", "hp": 120.0, "weak": "ladybug", "atk_min": 10, "atk_max": 16, "atk_name": "吸食麥子的汁液"},
	{"name": "瘟神（白粉病）", "hp": 180.0, "weak": "soda", "atk_min": 13, "atk_max": 19, "atk_name": "散播白粉病"},
]

var phase: int = Phase.STORY
var font: Font
var anim_t := 0.0
var player_hp := MAX_HP
var shown_player_hp := MAX_HP
var lives := 3
var compost_left := 3
var enemy_idx := 0
var enemy_hp: float = ENEMIES[0]["hp"]
var shown_enemy_hp: float = ENEMIES[0]["hp"]
var enemy_in := 0.0
var enemy_entering := false
var enemy_k := 1.0
var enemy_dying := false
var enemy_shake := 0.0
var enemy_lunge := 0.0
var player_shake := 0.0
var sky_dark := 0.0
var won := false
var turn := 0
var msg := ""
var msg_chars := 0.0
var waiting_tap := false
var fx := []
var floaters := []
var buttons := {}
var bar: HBoxContainer


func _ready() -> void:
	font = get_theme_font("font", "Label")
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 30)
	add_child(bar)
	for d in [["ladybug", "派出瓢蟲", Color("#e23b2e")], ["soda", "小蘇打水", Color("#9fd3f0")], ["compost", "堆肥補給", Color("#6b8e3d")]]:
		var b := Button.new()
		b.text = d[1]
		b.icon = Art.icon({"ladybug": "ladybug", "soda": "bottle", "compost": "pile"}[d[0]], d[2])
		b.custom_minimum_size = Vector2(360, 120)
		b.add_theme_font_size_override("font_size", 32)
		b.pressed.connect(_on_action.bind(d[0]))
		bar.add_child(b)
		buttons[d[0]] = b
	_set_buttons(false)
	resized.connect(_layout)
	_layout()
	_intro()


func _layout() -> void:
	var w := 3 * 360 + 2 * 30
	bar.size = Vector2(w, 120)
	bar.position = Vector2((size.x - w) / 2, size.y - 150)


func _make_icon(col: Color) -> ImageTexture:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 48:
		for x in 48:
			var d := Vector2(x - 23.5, y - 23.5).length()
			if d <= 19.0:
				img.set_pixel(x, y, col)
			elif d <= 22.0:
				img.set_pixel(x, y, col.darkened(0.5))
	return ImageTexture.create_from_image(img)


func _set_buttons(on: bool) -> void:
	for k in buttons:
		buttons[k].disabled = not on
	buttons["compost"].text = "堆肥補給（%d）" % compost_left
	if compost_left <= 0:
		buttons["compost"].disabled = true


# =====================================================
# 劇情 / 回合流程（用 await 依序播放）
# =====================================================
func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _say(text: String, wait_tap: bool = false) -> void:
	msg = text
	msg_chars = 0.0
	if wait_tap:
		waiting_tap = true
		await tapped
	else:
		await _wait(0.7 + text.length() * 0.045)


func _intro() -> void:
	await _say("春天到了，麥子長得綠油油的……", false)
	enemy_entering = true
	await _wait(1.0)
	await _say("咦？田裡出現了一隻巨大的蚜蟲！", false)
	await _say("蚜蟲會吸麥子的汁液。選個方法保護麥田吧！", false)
	_start_player_turn()


func _start_player_turn() -> void:
	phase = Phase.PLAYER
	msg = "要怎麼保護麥田？"
	msg_chars = 999.0
	_set_buttons(true)


func _on_action(kind: String) -> void:
	if phase != Phase.PLAYER:
		return
	phase = Phase.BUSY
	_set_buttons(false)
	var e: Dictionary = ENEMIES[enemy_idx]
	match kind:
		"ladybug":
			_add_fx("ladybug", 1.1)
			await _say("派出瓢蟲小隊！")
			if e["weak"] == "ladybug":
				_hit_enemy(randi_range(30, 38))
				await _say("瓢蟲大口吃掉蚜蟲！效果絕佳！")
			else:
				_hit_enemy(randi_range(4, 8))
				await _say("瓢蟲對黴菌沒辦法……效果不大")
		"soda":
			_add_fx("soda", 1.1)
			await _say("噴灑小蘇打水！")
			if e["weak"] == "soda":
				_hit_enemy(randi_range(30, 38))
				await _say("小蘇打水抑制了白粉病！效果絕佳！")
			else:
				_hit_enemy(randi_range(4, 8))
				await _say("小蘇打水對蚜蟲沒什麼用……")
		"compost":
			compost_left -= 1
			_add_fx("heal", 1.1)
			await _say("撒上堆肥，麥子恢復了元氣！")
			player_hp = minf(MAX_HP, player_hp + HEAL)
			_float("+%d" % int(HEAL), _field_rect().get_center(), Color("#9be37a"))
			await _wait(0.4)

	if enemy_hp <= 0.0:
		await _enemy_defeated()
		return

	await _enemy_turn()
	if player_hp <= 0.0:
		lives -= 1
		if lives <= 0:
			await _say("麥田全倒了……", false)
			_finish(false)
			return
		await _say("麥田撐不住了，失去一條命！還剩 %d 條命" % lives, false)
		player_hp = MAX_HP
	_start_player_turn()


func _enemy_turn() -> void:
	turn += 1
	var e: Dictionary = ENEMIES[enemy_idx]
	var dmg := randi_range(e["atk_min"], e["atk_max"])
	var text := "%s %s！" % [e["name"], e["atk_name"]]
	if enemy_idx == 1 and turn % 3 == 0:
		dmg = randi_range(26, 32)
		text = "瘟神深吸一口氣……白粉孢子大爆發！"
	enemy_lunge = 1.0
	_add_fx("aphid_atk" if enemy_idx == 0 else "mildew_atk", 1.1)
	await _say(text)
	player_hp = maxf(0.0, player_hp - dmg)
	player_shake = 0.45
	_float("-%d" % dmg, _field_rect().get_center(), Color("#ff8a7a"))
	await _wait(0.6)


func _enemy_defeated() -> void:
	enemy_dying = true
	if enemy_idx == 0:
		await _say("蚜蟲被瓢蟲吃光，落荒而逃！", false)
		await _say("……天空突然變得灰濛濛的", false)
		enemy_idx = 1
		enemy_hp = ENEMIES[1]["hp"]
		shown_enemy_hp = enemy_hp
		enemy_in = 0.0
		enemy_k = 1.0
		enemy_dying = false
		turn = 0
		await _wait(1.2)
		await _say("大魔王「瘟神」出現了！它帶來會讓麥葉發白的白粉病！", false)
		_start_player_turn()
	else:
		won = true
		await _say("瘟神被小蘇打水打敗，白粉病消失了！", false)
		_finish(true)


func _finish(win: bool) -> void:
	phase = Phase.RESULT
	bar.visible = false
	var stars := lives if win else 0
	completed.emit(stars)
	var rp = ResultPanel.new()
	rp.title_text = "第三關結算"
	rp.stars = stars
	if win:
		rp.lines = ["麥田守住了！剩下 %d 條命" % lives,
			"房東：用瓢蟲和小蘇打水，不靠農藥，",
			"這種照顧土地的方法我很欣賞！"]
	else:
		rp.lines = ["麥田被病蟲害打倒了……", "提示：蚜蟲怕瓢蟲，白粉病怕小蘇打水", "血不夠時記得用堆肥補給"]
	rp.can_next = win
	rp.next_pressed.connect(func(): next_level.emit())
	rp.retry_pressed.connect(func(): restart.emit())
	rp.title_pressed.connect(func(): back_to_title.emit())
	add_child(rp)


func _hit_enemy(dmg: int) -> void:
	enemy_hp = maxf(0.0, enemy_hp - dmg)
	enemy_shake = 0.45
	_float("-%d" % dmg, _enemy_center(), Color("#fff07a"))


func _add_fx(kind: String, dur: float) -> void:
	fx.append({"kind": kind, "t": 0.0, "dur": dur})


func _float(text: String, pos: Vector2, col: Color) -> void:
	floaters.append({"text": text, "pos": pos, "t": 0.0, "color": col})


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if waiting_tap:
			if msg_chars < msg.length():
				msg_chars = msg.length()
			else:
				waiting_tap = false
				tapped.emit()


func _process(delta: float) -> void:
	anim_t += delta
	msg_chars += delta * 30.0
	if enemy_entering:
		enemy_in = move_toward(enemy_in, 1.0, delta * 1.2)
	if enemy_dying:
		enemy_k = move_toward(enemy_k, 0.0, delta * 1.6)
	enemy_shake = maxf(0.0, enemy_shake - delta)
	player_shake = maxf(0.0, player_shake - delta)
	enemy_lunge = move_toward(enemy_lunge, 0.0, delta * 2.0)
	shown_enemy_hp = move_toward(shown_enemy_hp, enemy_hp, delta * 90.0)
	shown_player_hp = move_toward(shown_player_hp, player_hp, delta * 90.0)
	sky_dark = move_toward(sky_dark, 1.0 if enemy_idx == 1 and not won else 0.0, delta * 0.5)
	for f in fx:
		f["t"] += delta
	fx = fx.filter(func(f): return f["t"] < f["dur"])
	for f in floaters:
		f["t"] += delta
	floaters = floaters.filter(func(f): return f["t"] < 1.3)
	queue_redraw()


# =====================================================
# 繪圖
# =====================================================
func _field_rect() -> Rect2:
	return Rect2(300, 520, 380, 360)


func _enemy_center() -> Vector2:
	var e := 1.0 - pow(1.0 - enemy_in, 3)
	var c := Vector2(size.x * 0.68 + (1.0 - e) * size.x * 0.6, 380 + sin(anim_t * 2.0) * 10)
	c.x += sin(anim_t * 60.0) * 14.0 * enemy_shake
	c += Vector2(-90, 50) * enemy_lunge
	return c


func _draw() -> void:
	var sky := Color("#cfe9f5").lerp(Color("#7d7590"), sky_dark)
	var grass := Color("#9fc46a").lerp(Color("#7f8f6a"), sky_dark)
	Art.checker(self, Rect2(Vector2.ZERO, size), grass, grass.darkened(0.06), 64)
	draw_rect(Rect2(0, 0, size.x, 470), sky)
	draw_string(font, Vector2(0, 66), "第三關：蟲蟲大戰", HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color("#4a2f12") if sky_dark < 0.5 else Color("#f3eefc"))

	# 敵人
	if enemy_in > 0.0 and enemy_k > 0.01:
		if enemy_idx == 0:
			_draw_aphid(_enemy_center(), enemy_k)
		else:
			_draw_boss(_enemy_center(), enemy_k)
		var e: Dictionary = ENEMIES[enemy_idx]
		Art.hp_bar(self, font, Rect2(60, 110, 560, 112), shown_enemy_hp / e["hp"], e["name"], "%d / %d" % [int(ceil(shown_enemy_hp)), int(e["hp"])])

	# 我方：麥田 + 主角
	_draw_my_field()
	var mood := "normal"
	if won: mood = "happy"
	elif player_hp < 35.0: mood = "cry"
	Art.farmer(self, Vector2(160, 880), 0.85, mood, anim_t)
	var pr := Rect2(size.x - 660, 640, 600, 168)
	Art.hp_bar(self, font, pr, shown_player_hp / MAX_HP, "我的麥田", "%d / %d" % [int(ceil(shown_player_hp)), int(MAX_HP)])
	draw_string(font, pr.position + Vector2(26, 140), "生命", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#4a2f12"))
	for i in 3:
		var hc := pr.position + Vector2(130 + i * 56, 128)
		Art.heart(self, hc, 22, Color("#e0533d") if i < lives else Color("#d8ccb4"))

	_draw_fx()

	# 訊息框
	if phase != Phase.RESULT:
		var box := Rect2(40, size.y - 300, size.x - 80, 128)
		Art.panel(self, box)
		draw_string(font, box.position + Vector2(40, 78), msg.substr(0, int(msg_chars)), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 140, 32, Color("#3a240c"))
		if waiting_tap and msg_chars >= msg.length() and fmod(anim_t, 1.0) < 0.6:
			draw_string(font, Vector2(box.end.x - 200, box.end.y - 30), "點一下繼續", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#8a5a2b"))

	for f in floaters:
		var k: float = f["t"] / 1.3
		var p: Vector2 = f["pos"] + Vector2(-150, -40 - 70 * k)
		var col: Color = f["color"]
		col.a = 1.0 - k * k
		draw_string_outline(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 300, 64, 12, Color(0.2, 0.1, 0, col.a))
		draw_string(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 300, 64, col)


func _draw_my_field() -> void:
	var r := _field_rect()
	r.position.x += sin(anim_t * 60.0) * 10.0 * player_shake
	draw_rect(r.grow(12), Color("#7a4f28"))
	draw_rect(r, Color("#8a5a33"))
	var dmg := 1.0 - shown_player_hp / MAX_HP
	var idx := 0
	for row in 3:
		for col in 3:
			var base := r.position + Vector2(r.size.x * (col + 0.5) / 3.0, r.size.y * (row + 1) / 3.0 - 8)
			var sway := sin(anim_t * 2.0 + row + col) * 0.06
			var c := Color("#5aa83a").lerp(Color("#a6a46a"), dmg * 0.7)
			Art.wheat(self, base, 95, c, sway + dmg * 0.5, 4.0)
			# 受傷痕跡：蚜蟲是綠點，白粉病是白斑
			var spots := int(dmg * 6.0 + 0.5)
			for s in spots:
				var off := Vector2(fmod(s * 23.0 + idx * 7.0, 30.0) - 15.0, -20.0 - fmod(s * 31.0 + idx * 13.0, 70.0))
				if enemy_idx == 0:
					draw_circle(base + off, 4.5, Color("#3f7d1c"))
				else:
					draw_circle(base + off, 7.0, Color(1, 1, 1, 0.9))
			idx += 1


func _draw_fx() -> void:
	var from := _field_rect().get_center()
	var to := _enemy_center()
	for f in fx:
		var p: float = f["t"] / f["dur"]
		match f["kind"]:
			"ladybug":
				for i in 6:
					var q := clampf(p * 1.4 - i * 0.07, 0.0, 1.0)
					if q <= 0.0 or q >= 1.0:
						continue
					var pos: Vector2 = from.lerp(to, q) + Vector2(0, -sin(q * PI) * (120 + i * 25)) + Vector2(i * 14 - 35, i * 10 - 25)
					Art.ladybug(self, pos, 18)
			"soda":
				var hand := Vector2(220, 700)
				for i in 26:
					var q := fmod(p * 2.0 + i / 26.0, 1.0)
					if p > 0.85:
						continue
					var pos: Vector2 = hand.lerp(to, q) + Vector2(sin(i * 3.1) * 40 * q, cos(i * 1.7) * 40 * q)
					draw_circle(pos, 9 - q * 3, Color(0.85, 0.95, 1, 0.9))
			"heal":
				var r := _field_rect()
				for i in 16:
					var x := r.position.x + fmod(i * 47.0, r.size.x)
					var y := r.end.y - p * r.size.y * (0.6 + fmod(i * 0.37, 0.5))
					Art.star(self, Vector2(x, y), 12, Color(0.6, 1, 0.4, 1 - p))
			"aphid_atk":
				for i in 8:
					var q := clampf(p * 1.3 - i * 0.05, 0.0, 1.0)
					if q <= 0.0 or q >= 1.0:
						continue
					var pos: Vector2 = to.lerp(from, q) + Vector2(i * 12 - 40, -sin(q * PI) * 90)
					draw_circle(pos, 10, Color("#7cc242"))
			"mildew_atk":
				for i in 36:
					var q := clampf(p * 1.2 - (i % 6) * 0.04, 0.0, 1.0)
					var pos: Vector2 = to.lerp(from, q) + Vector2(sin(i * 2.3 + anim_t * 3) * 70, cos(i * 1.9) * 60)
					draw_circle(pos, 8 + (i % 3) * 3, Color(1, 1, 1, 0.85 * (1.0 - absf(q - 0.6))))


func _draw_aphid(c: Vector2, k: float) -> void:
	var body := Color("#8cc63f")
	var dark := Color("#4f7a1f")
	for i in 3:
		var lx := c.x + (-60 + i * 60) * k
		draw_line(Vector2(lx, c.y + 60 * k), Vector2(lx - 30 * k, c.y + 135 * k + sin(anim_t * 8 + i) * 6 * k), dark, 9 * k, false)
		draw_line(Vector2(lx + 12 * k, c.y + 60 * k), Vector2(lx + 45 * k, c.y + 135 * k + cos(anim_t * 8 + i) * 6 * k), dark, 9 * k, false)
	draw_line(c + Vector2(90, -40) * k, c + Vector2(140, -115) * k, dark, 16 * k)
	draw_line(c + Vector2(50, -60) * k, c + Vector2(80, -135) * k, dark, 16 * k)
	Art.ellipse(self, c + Vector2(30, 0) * k, Vector2(155, 112) * k, body)
	Art.ellipse(self, c + Vector2(60, -40) * k, Vector2(80, 34) * k, body.lightened(0.3))
	for i in 3:
		draw_arc(c + Vector2(-10 + i * 50, 10) * k, 95 * k, -0.5, 0.5, 10, dark, 4 * k)
	var hc := c + Vector2(-125, 15) * k
	Art.ellipse(self, hc, Vector2(72, 62) * k, body.darkened(0.08))
	var ant1 := PackedVector2Array()
	var ant2 := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		ant1.append(hc + Vector2(-20 - 90 * t, -50 - 120 * t + sin(t * 3 + anim_t * 3) * 12) * k)
		ant2.append(hc + Vector2(10 - 40 * t, -55 - 140 * t + cos(t * 3 + anim_t * 3) * 12) * k)
	draw_polyline(ant1, dark, 6 * k, false)
	draw_polyline(ant2, dark, 6 * k, false)
	for ex in [-28.0, 14.0]:
		draw_circle(hc + Vector2(ex, -12) * k, 19 * k, Color.WHITE)
		draw_circle(hc + Vector2(ex - 5, -10) * k, 10 * k, Color("#222222"))
		draw_line(hc + Vector2(ex - 20, -40) * k, hc + Vector2(ex + 16, -30) * k if ex < 0 else hc + Vector2(ex + 20, -40) * k, Color("#222222"), 6 * k)
	draw_line(hc + Vector2(-40, 40) * k, hc + Vector2(-65, 95) * k, dark, 8 * k)


func _draw_boss(c: Vector2, k: float) -> void:
	var col := Color("#8a7fa3")
	for i in 18:
		var a := anim_t * 0.8 + i * TAU / 18.0
		var rr := (175 + sin(anim_t * 3 + i) * 18) * k
		draw_circle(c + Vector2(cos(a), sin(a) * 0.7) * rr, (6 + (i % 3) * 3) * k, Color(1, 1, 1, 0.85))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-70, 80) * k, c + Vector2(70, 80) * k, c + Vector2(sin(anim_t * 3) * 30, 210) * k]), col.darkened(0.15))
	for p in [Vector2(-95, 20), Vector2(95, 20), Vector2(0, -45), Vector2(-55, 75), Vector2(55, 75), Vector2(0, 30)]:
		draw_circle(c + p * k, 88 * k, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-70, -100) * k, c + Vector2(-30, -110) * k, c + Vector2(-90, -190) * k]), Color("#4b3f63"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(70, -100) * k, c + Vector2(30, -110) * k, c + Vector2(90, -190) * k]), Color("#4b3f63"))
	for i in 10:
		draw_circle(c + Vector2(fmod(i * 53.0, 220.0) - 110, fmod(i * 37.0, 160.0) - 60) * k, 9 * k, Color(1, 1, 1, 0.75))
	var glow := 0.7 + 0.3 * sin(anim_t * 5)
	Art.ellipse(self, c + Vector2(-42, -10) * k, Vector2(26, 16) * k, Color(1, 0.9, 0.3, glow))
	Art.ellipse(self, c + Vector2(42, -10) * k, Vector2(26, 16) * k, Color(1, 0.9, 0.3, glow))
	draw_circle(c + Vector2(-42, -10) * k, 8 * k, Color("#c0392b"))
	draw_circle(c + Vector2(42, -10) * k, 8 * k, Color("#c0392b"))
	draw_line(c + Vector2(-75, -45) * k, c + Vector2(-20, -28) * k, Color("#2d2540"), 8 * k)
	draw_line(c + Vector2(75, -45) * k, c + Vector2(20, -28) * k, Color("#2d2540"), 8 * k)
	var mouth := PackedVector2Array()
	for i in 9:
		mouth.append(c + Vector2(-60 + i * 15, 45 + (12 if i % 2 == 0 else -4)) * k)
	draw_polyline(mouth, Color("#2d2540"), 7 * k, false)
