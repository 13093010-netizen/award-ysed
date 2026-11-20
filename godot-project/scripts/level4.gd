extends Control
## 第四關：收成的季節
## 收割（開割麥機）→ 乾燥（控溫）→ 冷藏保鮮 → 磨粉（轉把手）→ 包裝（封袋）→ 商店販售 → 把錢交給房東評分
## 收入達到租金才算過關，沒達標要重來

signal back_to_title
signal restart
signal next_level
signal completed(stars: int)

const Art = preload("res://scripts/art.gd")
const ResultPanel = preload("res://scripts/result_panel.gd")

enum Stage { HARVEST, DRY, STORE, MILL, PACK, SHOP, LANDLORD, RESULT }
const STEP_NAMES := ["收割", "乾燥", "冷藏", "磨粉", "包裝", "販售"]
const RENT := 800                 # 房東的租金目標（元）
const HARVEST_LEN := 40.0
const DRY_LEN := 55.0
const STORE_LEN := 7.0
const MILL_LEN := 45.0
const MILL_TARGET := 10.0
const INFO := {
	0: ["第一步：收割", ["用方向鍵開割麥機，把小麥全部割完", "小心石頭！撞到會停一下", "限時 40 秒（電腦也能用鍵盤方向鍵）"]],
	1: ["第二步：乾燥", ["按住「加熱」讓溫度上升，按住「降溫」吹風", "溫度保持在綠色區（55到68度）最好", "超過 75度 會烤焦；含水量降到 13% 就完成"]],
	2: ["第三步：冷藏保鮮", ["輸送帶會把麥子送進冷藏庫", "低溫保存幾天，讓麥子保持新鮮"]],
	3: ["第四步：磨粉", ["手指按住石磨，順時針畫圈轉動把手", "速度保持在綠色區，太快麵粉會變粗", "轉滿 10 圈就完成"]],
	4: ["第五步：包裝", ["麵粉會倒進袋子裡", "麵粉到綠色線的時候按「封袋」", "越準，品質越好"]],
	5: ["第六步：到商店販售", ["把包好的麵粉拿到商店賣", "品質越好，賣得越貴"]],
}

const CUSTOMERS := [
	{"skin": "#f1c9a0", "hair": "#2e2018", "style": "short", "shirt": "#7cc242"},
	{"skin": "#f6d3b0", "hair": "#8a4b2a", "style": "bun", "shirt": "#c45bb0"},
	{"skin": "#eec39a", "hair": "#d6d6d6", "style": "bun", "shirt": "#4f8fc9", "glasses": true},
	{"skin": "#f6d3b0", "hair": "#2e2018", "style": "spiky", "shirt": "#f0c419"},
]

# 收割
const COLS := 9
const ROWS := 5
const ROCKS := [Vector2i(3, 1), Vector2i(6, 3), Vector2i(5, 0)]

var stage: int = Stage.HARVEST
var running := false
var transitioning := false
var st := 0.0
var anim_t := 0.0
var font: Font
var ui: Control
var floaters := []
var parts := []
var banner_text := ""
var banner_t := 0.0

# 收割
var tiles := []
var total_wheat := 0
var cut := 0
var cpos := Vector2i(0, 2)
var cdir := Vector2i(1, 0)
var draw_cpos := Vector2(0, 2)
var move_cd := 0.0
var stun := 0.0
var held := Vector2i.ZERO
# 乾燥
var temp := 25.0
var moisture := 25.0
var heating := false
var cooling := false
var good_t := 0.0
var burn_t := 0.0
var dry_q := 0.0
# 磨粉
var crank := 0.0
var last_ang := 0.0
var grabbing := false
var frame_turn := 0.0
var rotations := 0.0
var rps := 0.0
var mill_good := 0.0
var mill_turn_t := 0.0
var fast_cd := 0.0
var mill_q := 0.0
# 包裝
var bags := 0
var bag_i := 0
var fill := 0.0
var fill_rate := 42.0
var bag_scores := []
var sealing := false
var seal_t := 0.0
var pack_q := 0.0
# 販售
var quality := 0.0
var price := 0
var sold := 0
var sale_t := 0.0
var money := 0
var shown_money := 0.0
var give_btn: Button
# 房東
var dialog_lines := []
var dialog_idx := 0
var dialog_chars := 0.0
var landlord_in := 0.0
var stars := 0
var passed := false


func _ready() -> void:
	font = get_theme_font("font", "Label")
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for r in ROWS:
		for c in COLS:
			var rock := ROCKS.has(Vector2i(c, r))
			tiles.append(2 if rock else 0)
			if not rock:
				total_wheat += 1
	tiles[_ti(cpos)] = 1
	cut = 1
	resized.connect(_rebuild_ui)
	_begin_stage(Stage.HARVEST)


func _ti(p: Vector2i) -> int:
	return p.y * COLS + p.x


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


# =====================================================
# 階段切換
# =====================================================
func _begin_stage(s: int) -> void:
	stage = s
	running = false
	transitioning = false
	st = 0.0
	if s == Stage.PACK and bags == 0:
		_begin_stage(Stage.SHOP)
		return
	if s == Stage.SHOP:
		quality = clampf(0.35 * dry_q + 0.35 * mill_q + 0.3 * pack_q, 0.0, 1.0)
		price = int(80 + 80 * quality)
		money = bags * price
	_rebuild_ui()


func _start_stage() -> void:
	running = true
	ui.visible = true
	if stage == Stage.STORE:
		ui.visible = false


func _finish_stage(next: int, msg: String) -> void:
	if transitioning:
		return
	transitioning = true
	running = false
	ui.visible = false
	heating = false
	cooling = false
	held = Vector2i.ZERO
	grabbing = false
	_banner(msg, 1.8)
	await _wait(1.8)
	_begin_stage(next)


func _banner(t: String, d: float) -> void:
	banner_text = t
	banner_t = d


func _float(text: String, pos: Vector2, col: Color) -> void:
	floaters.append({"text": text, "pos": pos, "t": 0.0, "color": col})


# ---------- 每個階段的按鈕 ----------
func _rebuild_ui() -> void:
	for c in ui.get_children():
		c.queue_free()
	give_btn = null
	ui.visible = running
	match stage:
		Stage.HARVEST:
			var cx := size.x - 175
			var cy := size.y - 330
			var defs := [["上", Vector2i(0, -1), Vector2(cx - 60, cy - 185)], ["下", Vector2i(0, 1), Vector2(cx - 60, cy + 65)],
				["左", Vector2i(-1, 0), Vector2(cx - 185, cy - 60)], ["右", Vector2i(1, 0), Vector2(cx + 65, cy - 60)]]
			for d in defs:
				var b := _btn(d[0], d[2], Vector2(120, 120), 40)
				var dir: Vector2i = d[1]
				b.button_down.connect(func(): held = dir)
				b.button_up.connect(_release_dir.bind(dir))
		Stage.DRY:
			var b1 := _btn("加熱（按住）", Vector2(size.x / 2 - 420, size.y - 170), Vector2(400, 130), 36)
			b1.button_down.connect(func(): heating = true)
			b1.button_up.connect(func(): heating = false)
			var b2 := _btn("吹風降溫（按住）", Vector2(size.x / 2 + 20, size.y - 170), Vector2(400, 130), 36)
			b2.button_down.connect(func(): cooling = true)
			b2.button_up.connect(func(): cooling = false)
		Stage.PACK:
			var b := _btn("封袋！", Vector2(size.x / 2 - 200, size.y - 170), Vector2(400, 130), 44)
			b.pressed.connect(_seal)
		Stage.SHOP:
			give_btn = _btn("把錢交給房東", Vector2(size.x / 2 - 220, size.y - 170), Vector2(440, 120), 38)
			give_btn.visible = sold >= bags and running
			give_btn.pressed.connect(_begin_landlord)


func _release_dir(dir: Vector2i) -> void:
	if held == dir:
		held = Vector2i.ZERO


func _btn(text: String, pos: Vector2, sz: Vector2, fs: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = sz
	b.size = sz
	b.position = pos
	b.add_theme_font_size_override("font_size", fs)
	ui.add_child(b)
	return b


# =====================================================
# 輸入
# =====================================================
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if stage == Stage.LANDLORD:
				_advance_dialog()
				return
			if not running and not transitioning and stage <= Stage.SHOP:
				_start_stage()
				return
			if running and stage == Stage.MILL:
				grabbing = true
				last_ang = (event.position - _mill_center()).angle()
			elif running and stage == Stage.PACK:
				_seal()
		else:
			grabbing = false
	elif event is InputEventMouseMotion and grabbing and running and stage == Stage.MILL:
		var a: float = (event.position - _mill_center()).angle()
		var d := wrapf(a - last_ang, -PI, PI)
		last_ang = a
		if d > 0.0:
			frame_turn += d


# =====================================================
# 更新
# =====================================================
func _process(delta: float) -> void:
	anim_t += delta
	if running:
		st += delta
		match stage:
			Stage.HARVEST: _update_harvest(delta)
			Stage.DRY: _update_dry(delta)
			Stage.STORE:
				if st >= STORE_LEN:
					_finish_stage(Stage.MILL, "冷藏完成，麥子很新鮮！")
			Stage.MILL: _update_mill(delta)
			Stage.PACK: _update_pack(delta)
			Stage.SHOP: _update_shop(delta)
	if stage == Stage.LANDLORD:
		landlord_in = move_toward(landlord_in, 1.0, delta * 1.6)
		if landlord_in >= 1.0 and dialog_idx < dialog_lines.size():
			dialog_chars += delta * 26.0
	draw_cpos = draw_cpos.lerp(Vector2(cpos), minf(1.0, delta * 14.0))
	shown_money = move_toward(shown_money, sold * price, delta * 600.0)
	for f in floaters:
		f["t"] += delta
	floaters = floaters.filter(func(f): return f["t"] < 1.3)
	for p in parts:
		p["t"] += delta
		p["pos"] += p["vel"] * delta
		var v: Vector2 = p["vel"]
		v.y += 400 * delta
		p["vel"] = v
	parts = parts.filter(func(p): return p["t"] < 0.8)
	if banner_t > 0.0:
		banner_t -= delta
	queue_redraw()


func _update_harvest(delta: float) -> void:
	var dir := held
	if Input.is_key_pressed(KEY_LEFT): dir = Vector2i(-1, 0)
	elif Input.is_key_pressed(KEY_RIGHT): dir = Vector2i(1, 0)
	elif Input.is_key_pressed(KEY_UP): dir = Vector2i(0, -1)
	elif Input.is_key_pressed(KEY_DOWN): dir = Vector2i(0, 1)
	stun -= delta
	move_cd -= delta
	if dir != Vector2i.ZERO and stun <= 0.0 and move_cd <= 0.0:
		cdir = dir
		var np := cpos + dir
		if np.x >= 0 and np.y >= 0 and np.x < COLS and np.y < ROWS:
			var i := _ti(np)
			if tiles[i] == 2:
				stun = 0.7
				move_cd = 0.3
				_float("撞到石頭！", _cell_center(Vector2(np)), Color("#ffb3a3"))
			else:
				cpos = np
				move_cd = 0.16
				if tiles[i] == 0:
					tiles[i] = 1
					cut += 1
					var c := _cell_center(Vector2(np))
					for k in 8:
						parts.append({"pos": c, "vel": Vector2(randf_range(-180, 180), randf_range(-320, -120)), "t": 0.0})
	if cut >= total_wheat:
		bags = 8
		_finish_stage(Stage.DRY, "全部割完了！")
	elif st >= HARVEST_LEN:
		bags = int(cut * 8.0 / total_wheat + 0.5)
		_finish_stage(Stage.DRY, "時間到！割了 %d / %d 格" % [cut, total_wheat])


func _update_dry(delta: float) -> void:
	var rate := -7.0
	if heating: rate = 24.0
	if cooling: rate = -26.0
	temp += (rate + sin(st * 1.7) * 6.0 + sin(st * 4.3) * 3.0) * delta
	temp = clampf(temp, 15.0, 95.0)
	if temp > 30.0:
		moisture = maxf(13.0, moisture - (temp - 30.0) * 0.02 * delta)
	if temp >= 55.0 and temp <= 68.0:
		good_t += delta
	if temp > 75.0:
		burn_t += delta
	if moisture <= 13.0 or st >= DRY_LEN:
		dry_q = clampf(good_t / maxf(st, 1.0) * 1.35 - burn_t * 0.08, 0.0, 1.0)
		if moisture > 13.0:
			dry_q *= 0.6
		_finish_stage(Stage.STORE, "乾燥完成！品質 %d%%" % int(dry_q * 100))


func _update_mill(delta: float) -> void:
	var inst := frame_turn / TAU / maxf(delta, 0.001)
	crank += frame_turn
	rotations += frame_turn / TAU
	frame_turn = 0.0
	rps = lerpf(rps, inst, minf(1.0, delta * 5.0))
	fast_cd -= delta
	if rps > 0.2:
		mill_turn_t += delta
		if rps <= 1.5 and rps >= 0.45:
			mill_good += delta
		elif rps > 1.5 and fast_cd <= 0.0:
			fast_cd = 1.5
			_float("太快了，麵粉會變粗！", _mill_center() + Vector2(0, -260), Color("#ffb3a3"))
	if rotations >= MILL_TARGET or st >= MILL_LEN:
		mill_q = clampf(mill_good / maxf(mill_turn_t, 0.1), 0.0, 1.0) * minf(1.0, rotations / MILL_TARGET)
		_finish_stage(Stage.PACK, "磨好了！品質 %d%%" % int(mill_q * 100))


func _update_pack(delta: float) -> void:
	if sealing:
		seal_t += delta
		if seal_t >= 0.7:
			sealing = false
			bag_i += 1
			fill = 0.0
			fill_rate += 6.0
			if bag_i >= bags:
				var s := 0.0
				for v in bag_scores:
					s += v
				pack_q = s / maxf(1.0, bag_scores.size())
				_finish_stage(Stage.SHOP, "包裝完成！共 %d 袋" % bags)
		return
	fill += fill_rate * delta
	if fill >= 135.0:
		_seal()


func _seal() -> void:
	if not running or stage != Stage.PACK or sealing or fill < 5.0:
		return
	var diff := absf(fill - 100.0)
	var score := 0.5
	var text := ""
	if diff <= 6.0:
		score = 1.0; text = "完美！"
	elif diff <= 15.0:
		score = 0.8; text = "不錯！"
	elif fill < 100.0:
		text = "裝太少了"
	else:
		text = "裝太滿了"
	bag_scores.append(score)
	_float(text, Vector2(size.x / 2, 520), Color("#fff7c2") if score >= 0.8 else Color("#ffb3a3"))
	sealing = true
	seal_t = 0.0


func _update_shop(_delta: float) -> void:
	if sold < bags:
		sale_t += _delta
		if sale_t >= 0.9:
			sale_t = 0.0
			sold += 1
			_float("+%d 元" % price, Vector2(size.x * 0.5, 560), Color("#ffe066"))
	elif give_btn and not give_btn.visible:
		give_btn.visible = true


# =====================================================
# 房東評分
# =====================================================
func _begin_landlord() -> void:
	stage = Stage.LANDLORD
	running = false
	ui.visible = false
	passed = money >= RENT
	if money >= 1100: stars = 3
	elif money >= 950: stars = 2
	elif money >= RENT: stars = 1
	else: stars = 0
	dialog_lines = ["收成都賣完啦？讓我看看。",
		"總共賺了 %d 元……今年的租金是 %d 元。" % [money, RENT]]
	if passed:
		dialog_lines.append("很好，租金付得出來！")
		dialog_lines.append(["", "勉強過關，明年要更細心。", "做得不錯，我很滿意。", "從種到賣都做得漂亮，太厲害了！"][stars])
	else:
		dialog_lines.append("唉，連租金都不夠……")
		dialog_lines.append("這樣不行，你再重新來一次吧！")


func _advance_dialog() -> void:
	if landlord_in < 1.0:
		landlord_in = 1.0
		return
	if dialog_idx >= dialog_lines.size():
		return
	var line: String = dialog_lines[dialog_idx]
	if dialog_chars < line.length():
		dialog_chars = line.length()
		return
	dialog_idx += 1
	dialog_chars = 0.0
	if dialog_idx >= dialog_lines.size():
		_show_result()


func _show_result() -> void:
	stage = Stage.RESULT
	completed.emit(stars)
	var rp = ResultPanel.new()
	rp.title_text = "房東的最終評分"
	rp.stars = stars
	rp.lines = ["收入 %d 元，租金 %d 元" % [money, RENT],
		"麵粉 %d 袋　品質 %d%%　每袋 %d 元" % [bags, int(quality * 100), price],
		"達標！可以繼續下一關" if passed else "沒有達標……要重來一次"]
	rp.can_next = passed
	rp.next_pressed.connect(func(): next_level.emit())
	rp.retry_pressed.connect(func(): restart.emit())
	rp.title_pressed.connect(func(): back_to_title.emit())
	add_child(rp)


# =====================================================
# 繪圖
# =====================================================
func _draw() -> void:
	Art.checker(self, Rect2(Vector2.ZERO, size), Color("#efe3c8"), Color("#e8dbbd"), 64)
	draw_string(font, Vector2(0, 62), "第四關：收成的季節", HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color("#4a2f12"))
	_draw_steps()
	match stage:
		Stage.HARVEST: _draw_harvest()
		Stage.DRY: _draw_dry()
		Stage.STORE: _draw_store()
		Stage.MILL: _draw_mill()
		Stage.PACK: _draw_pack()
		Stage.SHOP: _draw_shop()
		_: _draw_shop()

	for p in parts:
		draw_circle(p["pos"], 5, Color(0.95, 0.8, 0.3, 1.0 - p["t"] / 0.8))
	for f in floaters:
		var k: float = f["t"] / 1.3
		var p: Vector2 = f["pos"] + Vector2(-250, -30 - 60 * k)
		var col: Color = f["color"]
		col.a = 1.0 - k * k
		draw_string_outline(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 500, 32, 10, Color(0.2, 0.1, 0, col.a))
		draw_string(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 500, 32, col)

	if banner_t > 0.0:
		var a := clampf(banner_t, 0, 1)
		var y := size.y * 0.45
		draw_rect(Rect2(0, y - 62, size.x, 110), Color(0.28, 0.16, 0.05, 0.8 * a))
		draw_string(font, Vector2(0, y + 12), banner_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color(1, 0.97, 0.85, a))

	if not running and not transitioning and stage <= Stage.SHOP:
		_draw_info_card()
	if stage == Stage.LANDLORD or stage == Stage.RESULT:
		_draw_landlord_scene()


func _draw_steps() -> void:
	var w := 150.0
	var gap := 14.0
	var total := STEP_NAMES.size() * w + (STEP_NAMES.size() - 1) * gap
	var x := (size.x - total) / 2
	for i in STEP_NAMES.size():
		var r := Rect2(x + i * (w + gap), 92, w, 52)
		var done := i < stage
		var cur := i == stage
		var bg := Color("#f3c74f") if cur else (Color("#9ccf6a") if done else Color("#dccfb4"))
		Art.panel(self, r, bg, 20)
		draw_string(font, r.position + Vector2(0, 37), STEP_NAMES[i], HORIZONTAL_ALIGNMENT_CENTER, w, 32, Color("#4a2f12"))


func _status(text: String, col: Color = Color("#4a2f12")) -> void:
	draw_string(font, Vector2(0, 205), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, col)


func _draw_info_card() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	var info: Array = INFO[stage]
	var r := Rect2(size.x / 2 - 470, size.y / 2 - 250, 940, 500)
	Art.panel(self, r)
	draw_string(font, Vector2(r.position.x, r.position.y + 90), info[0], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 64, Color("#4a2f12"))
	var y := r.position.y + 180
	for l in info[1]:
		draw_string(font, Vector2(r.position.x, y), l, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 32, Color("#5a3a14"))
		y += 60
	if fmod(anim_t, 1.0) < 0.65:
		draw_string(font, Vector2(r.position.x, r.end.y - 40), "點一下開始", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 32, Color("#c0392b"))


# ---------- 收割 ----------
func _field_rect() -> Rect2:
	var cell = min((size.x - 420) / COLS, (size.y - 470) / ROWS)
	return Rect2(70, 290, cell * COLS, cell * ROWS)


func _cell_center(p: Vector2) -> Vector2:
	var f := _field_rect()
	var cs := f.size.x / COLS
	return f.position + (p + Vector2(0.5, 0.5)) * cs


func _draw_harvest() -> void:
	var left := int(ceil(HARVEST_LEN - st))
	_status("剩餘 %d 秒　已割 %d / %d" % [left, cut, total_wheat], Color("#c0392b") if left <= 10 else Color("#4a2f12"))
	var f := _field_rect()
	var cs := f.size.x / COLS
	draw_rect(f.grow(14), Color("#7a4f28"))
	for r in ROWS:
		for c in COLS:
			var cr := Rect2(f.position + Vector2(c, r) * cs, Vector2(cs, cs))
			var t: int = tiles[r * COLS + c]
			if t == 2:
				draw_rect(cr, Color("#8fb85a"))
				Art.ellipse(self, cr.get_center() + Vector2(0, 8), Vector2(cs * 0.34, cs * 0.24), Color("#8d8d8d"))
				Art.ellipse(self, cr.get_center() + Vector2(-6, 0), Vector2(cs * 0.18, cs * 0.1), Color("#b5b5b5"))
			elif t == 1:
				draw_rect(cr, Color("#c9a467"))
				for k in 4:
					var x := cr.position.x + cs * (k + 0.5) / 4.0
					draw_line(Vector2(x, cr.end.y - 18), Vector2(x, cr.end.y - 30), Color("#9c7a3e"), 3)
			else:
				draw_rect(cr, Color("#d9b45a"))
				for k in 3:
					var base := cr.position + Vector2(cs * (k + 0.5) / 3.0, cs - 8)
					Art.wheat(self, base, cs * 0.7, Color("#e8b630"), sin(anim_t * 2 + r + c + k) * 0.08, 3.0)
			draw_rect(cr, Color(0.4, 0.25, 0.1, 0.25), false, 1)
	var shake := Vector2(sin(anim_t * 50) * 6, 0) if stun > 0.0 else Vector2.ZERO
	_draw_combine(f.position + (draw_cpos + Vector2(0.5, 0.5)) * cs + shake, cs)


func _draw_combine(center: Vector2, cs: float) -> void:
	var s := cs / 125.0
	var dark := Color("#2b2b2b")
	draw_set_transform(center, Vector2(cdir).angle(), Vector2(s, s))
	for p in [Vector2(-48, -46), Vector2(-48, 32), Vector2(6, -44), Vector2(6, 32)]:
		draw_rect(Rect2(p, Vector2(30, 14)), dark)
	draw_rect(Rect2(-52, -34, 84, 68), Color("#c0392b"))
	draw_rect(Rect2(-44, -22, 36, 44), Color("#9ad0ec"))
	draw_rect(Rect2(-44, -22, 36, 44), dark, false, 3)
	draw_circle(Vector2(-22, -30), 6, dark)
	draw_rect(Rect2(32, -54, 14, 108), Color("#f0c419"))
	draw_rect(Rect2(46, -54, 14, 108), Color("#d9a520"))
	for i in 6:
		var y := -52 + fmod(i * 18.0 + anim_t * 140.0, 104.0)
		draw_line(Vector2(46, y), Vector2(62, y), dark, 4)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


# ---------- 乾燥 ----------
func _draw_dry() -> void:
	_status("溫度 %d度　含水量 %.1f%%（目標 13%%）" % [int(temp), moisture], Color("#c0392b") if temp > 75 else Color("#4a2f12"))
	var c := Vector2(size.x * 0.4, 600)
	# 機身
	Art.panel(self, Rect2(c.x - 300, c.y - 300, 600, 560), Color("#b8c4cc"), 40)
	draw_circle(c + Vector2(0, -30), 190, Color("#5d6d78"))
	draw_circle(c + Vector2(0, -30), 170, Color("#2f3b45"))
	var burnt := clampf(burn_t / 8.0, 0, 1)
	var grain := Color("#e8b630").lerp(Color("#6b3d1f"), burnt)
	for i in 40:
		var a := anim_t * 2.5 + i * 0.6
		var rr := 40.0 + fmod(i * 37.0, 120.0)
		draw_circle(c + Vector2(0, -30) + Vector2(cos(a), sin(a)) * rr, 9, grain)
	draw_arc(c + Vector2(0, -30), 170, 0, TAU, 48, Color("#9aa5ad"), 10)
	# 火 / 風
	if heating:
		for i in 7:
			var x := c.x - 210 + i * 70
			var hgt := 50 + sin(anim_t * 20 + i) * 18
			draw_colored_polygon(PackedVector2Array([Vector2(x - 22, c.y + 250), Vector2(x + 22, c.y + 250), Vector2(x, c.y + 250 - hgt)]), Color("#ff8c2a"))
	if cooling:
		for i in 5:
			var y := c.y - 200 + i * 70
			var x := c.x + 320 + fmod(anim_t * 300 + i * 40, 120)
			draw_line(Vector2(x, y), Vector2(x + 50, y), Color("#7fc8f8"), 6)
	# 溫度計
	var tr := Rect2(size.x * 0.73, 260, 70, 660)
	draw_rect(tr.grow(8), Color("#4a2f12"))
	draw_rect(tr, Color("#fff8e6"))
	var tmap := func(v: float) -> float: return tr.end.y - (v - 15.0) / 80.0 * tr.size.y
	draw_rect(Rect2(tr.position.x, tmap.call(68.0), tr.size.x, tmap.call(55.0) - tmap.call(68.0)), Color(0.4, 0.8, 0.4, 0.6))
	draw_rect(Rect2(tr.position.x, tr.position.y, tr.size.x, tmap.call(75.0) - tr.position.y), Color(0.9, 0.3, 0.2, 0.35))
	var ty: float = tmap.call(temp)
	draw_rect(Rect2(tr.position.x + 20, ty, 30, tr.end.y - ty), Color("#e0533d"))
	draw_circle(Vector2(tr.get_center().x, tr.end.y + 30), 42, Color("#e0533d"))
	for v in [20, 40, 55, 68, 75, 90]:
		var y: float = tmap.call(float(v))
		draw_line(Vector2(tr.end.x, y), Vector2(tr.end.x + 16, y), Color("#4a2f12"), 3)
		draw_string(font, Vector2(tr.end.x + 22, y + 10), "%d度" % v, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#4a2f12"))
	# 含水量
	var mr := Rect2(c.x - 300, c.y + 290, 600, 34)
	draw_rect(mr.grow(5), Color("#4a2f12"))
	draw_rect(mr, Color("#fff8e6"))
	draw_rect(Rect2(mr.position, Vector2(mr.size.x * (moisture - 13.0) / 12.0, mr.size.y)), Color("#4f9fe0"))
	draw_string(font, Vector2(mr.position.x, mr.end.y + 40), "含水量（越少越乾）", HORIZONTAL_ALIGNMENT_CENTER, mr.size.x, 32, Color("#4a2f12"))


# ---------- 冷藏 ----------
func _draw_store() -> void:
	var day := mini(3, 1 + int(st / (STORE_LEN / 3.0)))
	_status("冷藏保鮮中……第 %d 天" % day if running else "冷藏保鮮", Color("#2f5d8a"))
	var belt_y := 760.0
	draw_rect(Rect2(0, belt_y, size.x * 0.7, 40), Color("#555555"))
	for i in 30:
		var x := fmod(i * 60.0 + anim_t * 120.0, size.x * 0.7)
		draw_line(Vector2(x, belt_y + 5), Vector2(x + 20, belt_y + 35), Color("#888888"), 4)
	for i in 4:
		var x := fmod(i * 260.0 + st * 150.0, size.x * 0.75) - 100
		if x < size.x * 0.62:
			draw_rect(Rect2(x, belt_y - 90, 120, 90), Color("#b9864a"))
			draw_rect(Rect2(x, belt_y - 90, 120, 90), Color("#7a4f28"), false, 4)
			Art.wheat(self, Vector2(x + 60, belt_y - 50), 60, Color("#e8b630"), 0.0, 3)
	var fr := Rect2(size.x * 0.62, 300, size.x * 0.32, 640)
	Art.panel(self, fr, Color("#d7ecf7"), 30)
	draw_rect(Rect2(fr.position + Vector2(30, 40), Vector2(fr.size.x - 60, fr.size.y - 80)), Color("#9cc9e6"))
	draw_string(font, Vector2(fr.position.x, fr.position.y + 120), "冷藏庫", HORIZONTAL_ALIGNMENT_CENTER, fr.size.x, 64, Color("#2f5d8a"))
	draw_string(font, Vector2(fr.position.x, fr.position.y + 200), "4度", HORIZONTAL_ALIGNMENT_CENTER, fr.size.x, 64, Color("#2f5d8a"))
	for i in 24:
		var p := Vector2(fmod(i * 131.0 + anim_t * 40, size.x), fmod(i * 77.0 + anim_t * 90, size.y))
		draw_circle(p, 5, Color(1, 1, 1, 0.8))
	# 日月輪替
	var a := PI + fmod(st / (STORE_LEN / 3.0), 1.0) * PI
	var sun := Vector2(size.x * 0.3, 640) + Vector2(cos(a), sin(a)) * 330
	draw_circle(sun, 40, Color("#f3c74f"))


# ---------- 磨粉 ----------
func _mill_center() -> Vector2:
	return Vector2(size.x * 0.42, 640)


func _draw_mill() -> void:
	_status("已轉 %.1f / %d 圈" % [minf(rotations, MILL_TARGET), int(MILL_TARGET)])
	var c := _mill_center()
	# 麵粉堆
	var pile := clampf(rotations / MILL_TARGET, 0, 1)
	Art.ellipse(self, c + Vector2(0, 300), Vector2(120 + 160 * pile, 30 + 70 * pile), Color("#fbf6ea"))
	draw_circle(c, 250, Color("#6f6f6f"))
	draw_circle(c, 235, Color("#9a9a9a"))
	for i in 10:
		var a := crank + i * TAU / 10
		draw_line(c + Vector2(cos(a), sin(a)) * 50, c + Vector2(cos(a + 0.4), sin(a + 0.4)) * 225, Color("#7d7d7d"), 6)
	draw_circle(c, 46, Color("#5a5a5a"))
	var hp := c + Vector2(cos(crank), sin(crank)) * 190
	draw_line(c, hp, Color("#7a4f28"), 26)
	draw_circle(hp, 40, Color("#a0703c"))
	draw_circle(hp, 26, Color("#c08a50"))
	if not grabbing and running:
		draw_arc(c, 300, -PI * 0.4, PI * 0.3, 24, Color(0.75, 0.2, 0.15, 0.7), 10)
		var tip := c + Vector2(cos(PI * 0.3), sin(PI * 0.3)) * 300
		draw_circle(tip, 16, Color(0.75, 0.2, 0.15, 0.7))
		draw_string(font, Vector2(c.x - 300, c.y - 320), "按住並順時針畫圈", HORIZONTAL_ALIGNMENT_CENTER, 600, 32, Color("#c0392b"))
	# 速度表
	var g := Vector2(size.x * 0.8, 560)
	var rr := 150.0
	var spd := func(v: float) -> float: return PI + clampf(v / 2.0, 0, 1) * PI
	draw_arc(g, rr, PI, TAU, 32, Color("#dccfb4"), 34)
	draw_arc(g, rr, spd.call(0.45), spd.call(1.5), 24, Color("#7cc242"), 34)
	draw_arc(g, rr, spd.call(1.5), TAU, 12, Color("#e0533d"), 34)
	var na: float = spd.call(rps)
	draw_line(g, g + Vector2(cos(na), sin(na)) * (rr + 10), Color("#3a240c"), 8)
	draw_circle(g, 16, Color("#3a240c"))
	draw_string(font, Vector2(g.x - 150, g.y + 70), "轉動速度", HORIZONTAL_ALIGNMENT_CENTER, 300, 32, Color("#4a2f12"))


# ---------- 包裝 ----------
func _draw_pack() -> void:
	_status("第 %d / %d 袋" % [mini(bag_i + 1, bags), bags])
	var cx := size.x / 2
	var belt_y := 900.0
	draw_rect(Rect2(0, belt_y, size.x, 40), Color("#555555"))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 160, 260), Vector2(cx + 160, 260), Vector2(cx + 40, 400), Vector2(cx - 40, 400)]), Color("#9aa5ad"))
	draw_rect(Rect2(cx - 40, 400, 80, 40), Color("#7d8a93"))
	var off := seal_t * 900.0 if sealing else 0.0
	var br := Rect2(cx - 120 + off, belt_y - 300, 240, 300)
	if not sealing and running:
		draw_rect(Rect2(cx - 16, 440, 32, br.position.y - 440 + br.size.y * (1 - fill / 135.0)), Color("#fbf6ea"))
	Art.panel(self, br, Color("#e9d8b4"), 18)
	var fh := br.size.y * clampf(fill / 135.0, 0, 1)
	draw_rect(Rect2(br.position.x + 10, br.end.y - fh, br.size.x - 20, fh - 6), Color("#fbf6ea"))
	var y95 := br.end.y - br.size.y * 95.0 / 135.0
	var y105 := br.end.y - br.size.y * 105.0 / 135.0
	draw_rect(Rect2(br.position.x - 30, y105, br.size.x + 60, y95 - y105), Color(0.4, 0.8, 0.3, 0.5))
	draw_string(font, Vector2(br.position.x, br.position.y + br.size.y * 0.75), "麵粉", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 32, Color("#7a4f28"))
	for i in bag_scores.size():
		var r := Rect2(size.x - 120 - (i % 4) * 90, belt_y - 110 - int(i / 4) * 120, 76, 100)
		Art.panel(self, r, Color("#e9d8b4"), 12)


# ---------- 商店 ----------
func _draw_shop() -> void:
	if stage == Stage.SHOP:
		_status("每袋 %d 元（品質 %d%%）" % [price, int(quality * 100)])
	var top := 300.0
	for i in 12:
		draw_rect(Rect2(size.x * 0.1 + i * size.x * 0.8 / 12.0, top - 60, size.x * 0.8 / 12.0, 80), Color("#e0533d") if i % 2 == 0 else Color("#fff8e6"))
	draw_rect(Rect2(size.x * 0.1, top + 20, size.x * 0.8, 520), Color("#f6e7c1"))
	draw_string(font, Vector2(0, top + 100), "麥田小舖", HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color("#7a4f28"))
	var counter := Rect2(size.x * 0.1, top + 380, size.x * 0.8, 160)
	if stage == Stage.SHOP and running and sold < bags:
		var x := lerpf(size.x * 0.95, size.x * 0.66, clampf(sale_t / 0.5, 0, 1))
		Art.person(self, Vector2(x, counter.position.y - 120), 0.7, CUSTOMERS[sold % CUSTOMERS.size()], "happy", anim_t)
	draw_rect(counter, Color("#a0703c"))
	for i in bags - sold:
		Art.panel(self, Rect2(size.x * 0.18 + i * 90, counter.position.y - 110, 76, 110), Color("#e9d8b4"), 12)
	draw_string(font, Vector2(0, counter.end.y + 90), "收入：%d 元" % int(shown_money), HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color("#c0392b"))


# ---------- 房東 ----------
func _draw_landlord_scene() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.42))
	var e := 1.0 - pow(1.0 - landlord_in, 3)
	Art.landlord(self, Vector2(lerpf(-260.0, size.x * 0.16, e), size.y - 30), 1.3, passed or stage == Stage.LANDLORD and dialog_idx < 2)
	if stage == Stage.LANDLORD and landlord_in >= 1.0 and dialog_idx < dialog_lines.size():
		var box := Rect2(size.x * 0.3, size.y - 310, size.x * 0.66, 250)
		Art.panel(self, box)
		var tag := Rect2(box.position + Vector2(30, -34), Vector2(190, 60))
		Art.panel(self, tag, Color("#f3c74f"), 24)
		draw_string(font, tag.position + Vector2(0, 42), "房東 陳伯", HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 32, Color("#4a2f12"))
		var line: String = dialog_lines[dialog_idx]
		draw_multiline_string(font, box.position + Vector2(44, 92), line.substr(0, int(dialog_chars)), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 88, 32, 3, Color("#3a240c"))
		if dialog_chars >= line.length() and fmod(anim_t, 1.0) < 0.6:
			draw_string(font, Vector2(box.end.x - 230, box.end.y - 26), "點一下繼續", HORIZONTAL_ALIGNMENT_RIGHT, 200, 32, Color("#8a5a2b"))
