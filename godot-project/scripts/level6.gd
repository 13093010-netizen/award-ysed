extends Control
## 終章：阿麥伯的手工湯麵（第五關廚房之後）
## 用自己種的小麥，煮一碗阿麥伯以前常煮給小麥吃的手工湯麵 → 帶去醫院 → 阿麥伯道謝 → 一家人團聚
## 料理小遊戲：倒材料（按住）、揉麵（連點）、擀麵（左右滑）、切麵（看準時機）、煮麵（看火候起鍋）

signal back_to_title
signal restart
signal next_level
signal completed(stars: int)

const Art = preload("res://scripts/art.gd")
const ResultPanel = preload("res://scripts/result_panel.gd")

enum Phase { INTRO, COOK, DISH, HOSPITAL, FINALE, RESULT }

const DISH := "手工麵"
const DISH_NAME := "阿麥伯的手工湯麵"
const STEPS := [["fill", "倒麵粉"], ["fill", "加水"], ["knead", "揉麵團"], ["roll", "擀平"], ["cut", "切麵條"], ["cook", "下鍋煮"]]
const HINTS := {
	"fill": "按住按鈕倒入，到綠色線放開",
	"knead": "連續點麵團（或按鈕）把麵團揉勻",
	"roll": "手指在麵團上左右來回滑動擀開",
	"cut": "刀子會左右移動，對準虛線時按「切！」",
	"cook": "看火候，顏色剛好時按「起鍋！」",
}
const INTRO_LINES := [
	["小麥", "小時候，阿公最常煮手工湯麵給我吃。"],
	["小麥", "今天換我用自己種的小麥，煮一碗帶去醫院給阿公！"]]
const MOM := {"skin": "#f6d3b0", "hair": "#5a3a22", "style": "bun", "shirt": "#e2735a"}
const DAD := {"skin": "#f1c9a0", "hair": "#3a2a1e", "style": "short", "shirt": "#4f7fbf", "beard": true}

var phase: int = Phase.INTRO
var font: Font
var anim_t := 0.0
var lines: Array = []
var line_i := 0
var chars := 0.0
var steps: Array = STEPS
var step_i := 0
var step_scores := []
var step_t := 0.0
var busy := false
var floaters := []
var ui: Control
var action_btn: Button
var fade := 0.0
# 各小遊戲狀態
var amount := 0.0
var holding := false
var taps := 0
var squash := 0.0
var roll_dist := 0.0
var last_x := 0.0
var dragging := false
var pin_x := 0.0
var cuts := []
var used_guides := []
var cut_scores := []
var doneness := 0.0
var dish_score := 0
var finale_t := 0.0
var result_shown := false


func _ready() -> void:
	font = get_theme_font("font", "Label")
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	action_btn = Button.new()
	action_btn.custom_minimum_size = Vector2(520, 130)
	action_btn.size = action_btn.custom_minimum_size
	action_btn.add_theme_font_size_override("font_size", 64)
	action_btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	action_btn.button_down.connect(_on_btn_down)
	action_btn.button_up.connect(_on_btn_up)
	action_btn.pressed.connect(_on_btn_pressed)
	ui.add_child(action_btn)
	action_btn.visible = false
	lines = INTRO_LINES
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	action_btn.position = Vector2(size.x / 2 - 260, size.y - 165)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _float(text: String, pos: Vector2, col: Color) -> void:
	floaters.append({"text": text, "pos": pos, "t": 0.0, "color": col})


func _work_center() -> Vector2:
	return Vector2(size.x / 2, 600)


func _step_type() -> String:
	if step_i >= steps.size():
		return ""
	return steps[step_i][0]


# =====================================================
# 流程
# =====================================================
func _start_cooking() -> void:
	phase = Phase.COOK
	step_i = 0
	step_scores = []
	_reset_step()


func _reset_step() -> void:
	amount = 0.0
	holding = false
	taps = 0
	squash = 0.0
	roll_dist = 0.0
	dragging = false
	pin_x = size.x / 2
	cuts = []
	used_guides = []
	cut_scores = []
	doneness = 0.0
	step_t = 0.0
	var t := _step_type()
	action_btn.visible = t != "roll"
	match t:
		"fill": action_btn.text = "按住倒入"
		"knead": action_btn.text = "揉！"
		"cut": action_btn.text = "切！"
		"cook": action_btn.text = "起鍋！"


func _step_done(score: int, text: String) -> void:
	busy = true
	holding = false
	step_scores.append(score)
	_float(text, _work_center() + Vector2(0, -200), Color("#fff7c2") if score >= 75 else Color("#ffb3a3"))
	await _wait(1.0)
	step_i += 1
	busy = false
	if step_i >= steps.size():
		_finish_dish()
	else:
		_reset_step()


func _finish_dish() -> void:
	var s := 0
	for v in step_scores:
		s += int(v)
	dish_score = int(round(float(s) / maxf(1.0, step_scores.size())))
	phase = Phase.DISH
	action_btn.visible = true
	action_btn.text = "帶去醫院給阿公"


func _go_hospital() -> void:
	action_btn.visible = false
	fade = 1.0
	phase = Phase.HOSPITAL
	var taste := "麵有點不太一樣……但這是阿公吃過最溫暖的一碗麵。"
	if dish_score >= 85:
		taste = "這個味道……跟阿公煮的一模一樣啊！"
	elif dish_score >= 60:
		taste = "嗯……好香，有阿公的味道。"
	lines = [
		["小麥", "阿公！我煮了你以前常煮給我吃的手工湯麵！"],
		["阿麥伯", taste],
		["媽媽", "爸，小麥這一年都在幫你顧麥田喔。"],
		["阿麥伯", "我都聽說了。連房東都說，田交給你他很放心。"],
		["阿麥伯", "謝謝你，小麥……謝謝你幫阿公守住這塊田。"],
		["小麥", "阿公，你安心養病。等你好了，我們一起回麥田！"],
		["爸爸", "到時候，全家一起在麥田裡吃飯吧！"]]
	line_i = 0
	chars = 0.0


func _show_result() -> void:
	if result_shown:
		return
	result_shown = true
	phase = Phase.RESULT
	var stars := 1
	if dish_score >= 85: stars = 3
	elif dish_score >= 65: stars = 2
	completed.emit(stars)
	var rp = ResultPanel.new()
	rp.title_text = "終章結算"
	rp.stars = stars
	rp.lines = ["%s：%d 分" % [DISH_NAME, dish_score],
		"阿麥伯吃得好開心",
		"一家人又團聚在一起了！"]
	rp.next_text = "看結局"
	rp.next_pressed.connect(func(): next_level.emit())
	rp.retry_pressed.connect(func(): restart.emit())
	rp.title_pressed.connect(func(): back_to_title.emit())
	add_child(rp)


# =====================================================
# 輸入
# =====================================================
func _on_btn_down() -> void:
	if phase == Phase.COOK and not busy and _step_type() == "fill":
		holding = true


func _on_btn_up() -> void:
	if phase == Phase.COOK and not busy and _step_type() == "fill" and holding:
		holding = false
		_fill_release()


func _on_btn_pressed() -> void:
	if phase == Phase.DISH:
		_go_hospital()
		return
	if phase != Phase.COOK or busy:
		return
	match _step_type():
		"knead": _knead_tap()
		"cut": _cut()
		"cook": _cook_out()


func _advance_line() -> void:
	var text: String = lines[line_i][1]
	if chars < text.length():
		chars = text.length()
		return
	line_i += 1
	chars = 0.0
	if line_i >= lines.size():
		if phase == Phase.INTRO:
			_start_cooking()
		elif phase == Phase.HOSPITAL:
			phase = Phase.FINALE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			match phase:
				Phase.INTRO, Phase.HOSPITAL:
					_advance_line()
				Phase.COOK:
					if busy:
						return
					var near: bool = event.position.distance_to(_work_center()) < 380
					match _step_type():
						"knead":
							if near: _knead_tap()
						"cut":
							if near: _cut()
						"roll":
							dragging = true
							last_x = event.position.x
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging and phase == Phase.COOK and not busy and _step_type() == "roll":
		roll_dist += absf(event.position.x - last_x)
		last_x = event.position.x
		pin_x = clampf(event.position.x, size.x / 2 - 360, size.x / 2 + 360)
		if roll_dist >= 2600.0:
			dragging = false
			if step_t <= 6.0: _step_done(100, "擀得又平又薄！")
			else: _step_done(85, "擀好了！")


func _fill_release() -> void:
	if amount < 5.0:
		return
	var diff := absf(amount - 100.0)
	if diff <= 8.0: _step_done(100, "剛剛好！")
	elif diff <= 18.0: _step_done(80, "差一點點")
	elif amount < 100.0: _step_done(50, "太少了")
	else: _step_done(50, "倒太多了")


func _knead_tap() -> void:
	taps += 1
	squash = 1.0
	if taps >= 12:
		if step_t <= 5.0: _step_done(100, "麵團光滑有彈性！")
		elif step_t <= 8.0: _step_done(85, "揉好了！")
		else: _step_done(70, "終於揉好了")


func _guides() -> Array:
	var cx := size.x / 2
	var g := []
	for i in 5:
		g.append(cx - 300 + 600.0 * (i + 1) / 6.0)
	return g


func _knife_x() -> float:
	return size.x / 2 + sin(step_t * 2.2) * 330.0


func _cut() -> void:
	var kx := _knife_x()
	var g := _guides()
	var best := -1
	var bd := 99999.0
	for i in g.size():
		if used_guides.has(i):
			continue
		var d := absf(kx - g[i])
		if d < bd:
			bd = d
			best = i
	if best < 0:
		return
	used_guides.append(best)
	cuts.append(kx)
	var err := bd / 100.0
	var sc := 45
	if err < 0.15: sc = 100
	elif err < 0.35: sc = 75
	cut_scores.append(sc)
	_float("漂亮！" if sc == 100 else ("還可以" if sc == 75 else "歪掉了"), Vector2(kx, 470), Color("#fff7c2") if sc >= 75 else Color("#ffb3a3"))
	if cuts.size() >= 5:
		var s := 0
		for v in cut_scores:
			s += int(v)
		_step_done(int(s / 5.0), "麵條切好了！")


func _cook_out() -> void:
	var diff := absf(doneness - 100.0)
	if diff <= 8.0: _step_done(100, "火候完美！")
	elif diff <= 20.0: _step_done(75, "煮熟了！")
	elif doneness < 100.0: _step_done(40, "還沒熟……")
	else: _step_done(30 if doneness >= 150.0 else 40, "煮太爛了……")


# =====================================================
# 更新
# =====================================================
func _process(delta: float) -> void:
	anim_t += delta
	chars += delta * 24.0
	fade = maxf(0.0, fade - delta * 1.2)
	if phase == Phase.COOK:
		if not busy:
			step_t += delta
			match _step_type():
				"fill":
					if holding:
						amount += 38.0 * delta
						if amount >= 140.0:
							holding = false
							_fill_release()
				"cook":
					doneness += 20.0 * delta
					if doneness >= 150.0:
						_cook_out()
		squash = move_toward(squash, 0.0, delta * 4.0)
	elif phase == Phase.FINALE:
		finale_t += delta
		if finale_t >= 5.0:
			_show_result()
	for f in floaters:
		f["t"] += delta
	floaters = floaters.filter(func(f): return f["t"] < 1.3)
	queue_redraw()


# =====================================================
# 繪圖
# =====================================================
func _draw() -> void:
	match phase:
		Phase.INTRO:
			_draw_kitchen_bg()
			Art.farmer(self, Vector2(size.x * 0.3, size.y - 300), 1.3, "determined" if line_i == 1 else "normal", anim_t)
			_draw_dialog()
		Phase.COOK, Phase.DISH:
			_draw_kitchen()
		_:
			_draw_hospital()
			if phase == Phase.HOSPITAL:
				_draw_dialog()
	for f in floaters:
		var k: float = f["t"] / 1.3
		var p: Vector2 = f["pos"] + Vector2(-250, -30 - 60 * k)
		var col: Color = f["color"]
		col.a = 1.0 - k * k
		draw_string_outline(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 500, 64, 10, Color(0.2, 0.1, 0, col.a))
		draw_string(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 500, 64, col)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, fade))


func _draw_dialog() -> void:
	if line_i >= lines.size():
		return
	var who: String = lines[line_i][0]
	var text: String = lines[line_i][1]
	var box := Rect2(size.x * 0.06, size.y - 290, size.x * 0.88, 230)
	Art.panel(self, box)
	var tag := Rect2(box.position + Vector2(30, -38), Vector2(60.0 + who.length() * 32.0, 64))
	Art.panel(self, tag, Color("#f3c74f"))
	draw_string(font, tag.position + Vector2(0, 44), who, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 32, Color("#4a2f12"))
	draw_multiline_string(font, box.position + Vector2(44, 96), text.substr(0, int(chars)), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 88, 32, 3, Color("#3a240c"))
	if chars >= text.length() and fmod(anim_t, 1.0) < 0.6:
		draw_string(font, Vector2(box.end.x - 240, box.end.y - 26), "點一下繼續", HORIZONTAL_ALIGNMENT_RIGHT, 200, 32, Color("#8a5a2b"))


func _draw_kitchen_bg() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#eef3ef"))
	for x in range(0, int(size.x), 80):
		draw_line(Vector2(x, 0), Vector2(x, 840), Color("#d7e0da"), 2)
	for y in range(0, 840, 80):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("#d7e0da"), 2)
	draw_rect(Rect2(0, 840, size.x, size.y - 840), Color("#a0703c"))
	draw_rect(Rect2(0, 840, size.x, 24), Color("#7a4f28"))
	draw_string(font, Vector2(0, 80), "終章：%s" % DISH_NAME, HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color("#4a2f12"))


func _draw_kitchen() -> void:
	_draw_kitchen_bg()
	var wc := _work_center()
	if phase == Phase.DISH:
		_draw_dish(DISH, wc + Vector2(0, 60), 2.0)
		draw_string(font, Vector2(0, 200), "湯麵煮好了！%d 分" % dish_score, HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color("#c0392b"))
		var st := 1
		if dish_score >= 85: st = 3
		elif dish_score >= 65: st = 2
		for i in 3:
			var c := Vector2(size.x / 2 + (i - 1) * 110, 290)
			Art.star(self, c, 46, Color("#5a3a14"))
			Art.star(self, c, 40, Color("#f3c74f") if i < st else Color("#d8ccb4"))
		return
	var n := steps.size()
	for i in n:
		var c := Vector2(size.x / 2 + (i - (n - 1) / 2.0) * 70, 120)
		draw_rect(Rect2(c - Vector2(16, 16), Vector2(32, 32)), Color("#7cc242") if i < step_i else (Color("#f3c74f") if i == step_i else Color("#d8ccb4")))
	if step_i < n:
		draw_string(font, Vector2(0, 200), "步驟 %d / %d：%s" % [step_i + 1, n, steps[step_i][1]], HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color("#4a2f12"))
		draw_string(font, Vector2(0, 244), HINTS[_step_type()], HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color("#5a3a14"))
	match _step_type():
		"fill": _draw_fill(wc)
		"knead": _draw_knead(wc)
		"roll": _draw_roll(wc)
		"cut": _draw_cut(wc)
		"cook": _draw_cook(wc, DISH)


# ---------- 醫院 ----------
func _grandpa_mood() -> String:
	if phase != Phase.HOSPITAL:
		return "happy"
	match line_i:
		0: return "normal"
		1: return "eat"
		3, 4: return "tear"
	return "happy"


func _draw_hospital() -> void:
	var w := size.x
	var h := size.y
	Art.checker(self, Rect2(0, 0, w, h * 0.72), Color("#e3efe9"), Color("#dbe9e2"), 64)
	draw_rect(Rect2(0, h * 0.72, w, h * 0.28), Color("#c9d3d8"))
	# 窗外看得到麥田
	var win := Rect2(w * 0.06, 120, 380, 300)
	draw_rect(win.grow(14), Color("#ffffff"))
	draw_rect(win, Color("#bfe3f2"))
	draw_rect(Rect2(win.position.x, win.position.y + win.size.y * 0.6, win.size.x, win.size.y * 0.4), Color("#d9a441"))
	for i in 8:
		Art.wheat(self, Vector2(win.position.x + 24 + i * 46, win.end.y), 64, Color("#e8b630"), sin(anim_t + i) * 0.2, 3)
	draw_rect(Rect2(win.position.x - 40, win.position.y - 30, 60, win.size.y + 60), Color("#f3c3c3"))
	draw_rect(Rect2(win.end.x - 20, win.position.y - 30, 60, win.size.y + 60), Color("#f3c3c3"))
	# 點滴架
	var iv := Vector2(w * 0.3, 0)
	draw_rect(Rect2(iv.x - 4, 180, 8, 620), Color("#9aa5ad"))
	draw_rect(Rect2(iv.x - 30, 180, 60, 90), Color(0.8, 0.9, 1, 0.8))
	# 病床與阿麥伯
	var bed := Rect2(w * 0.34, 600, w * 0.34, 260)
	draw_rect(Rect2(bed.position.x - 10, bed.position.y - 200, 30, 460), Color("#9aa5ad"))
	Art.grandpa(self, Vector2(bed.position.x + bed.size.x * 0.42, 500), 1.05, _grandpa_mood(), false, true, anim_t)
	draw_rect(Rect2(bed.position.x, bed.position.y + 30, bed.size.x, bed.size.y - 30), Color("#ffffff"))
	draw_rect(Rect2(bed.position.x, bed.position.y + 60, bed.size.x, bed.size.y - 60), Color("#8fbfe0"))
	draw_rect(Rect2(bed.position.x, bed.position.y + 60, bed.size.x, 14), Color("#b5d7ef"))
	var served := phase != Phase.HOSPITAL or line_i >= 1
	if served:
		draw_rect(Rect2(bed.position.x + 60, bed.position.y + 70, bed.size.x - 120, 20), Color("#c8a46a"))
		_draw_dish(DISH, Vector2(bed.get_center().x, bed.position.y + 50), 0.6)
	# 小麥
	var happy := phase != Phase.HOSPITAL or line_i >= 5
	var foot := Vector2(w * 0.2, h - 120)
	Art.farmer(self, foot, 1.05, "happy" if happy else "normal", anim_t)
	if not served:
		_draw_dish(DISH, foot + Vector2(80, -110), 0.5)
	# 媽媽、爸爸
	Art.person(self, Vector2(w * 0.76, 720), 0.95, MOM, "happy", anim_t)
	Art.person(self, Vector2(w * 0.9, 720), 0.95, DAD, "happy", anim_t + 1.0)

	if phase == Phase.FINALE or phase == Phase.RESULT:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.85, 0.5, 0.18))
		for i in 18:
			var q := fmod(anim_t * 0.4 + i / 18.0, 1.0)
			var hp := Vector2(w * (0.15 + 0.7 * fmod(i * 0.37, 1.0)) + sin(q * 6.0 + i) * 30, h * 0.8 - q * h * 0.7)
			Art.heart(self, hp, 22, Color(0.9, 0.3, 0.35, 1.0 - q))
		var box := Rect2(size.x * 0.1, size.y - 260, size.x * 0.8, 180)
		Art.panel(self, box, Color("#fff8e6"))
		draw_string(font, Vector2(box.position.x, box.position.y + 110), "一家人又團聚在一起了", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 64, Color("#c0392b"))


func _draw_fill(wc: Vector2) -> void:
	var label: String = steps[step_i][1]
	var liquid := Color("#fbf6ea")
	if label == "加水": liquid = Color("#8cc8f0")
	elif label == "加牛奶": liquid = Color("#fff3d6")
	var top := wc.y - 60
	var bot := wc.y + 200
	var h := bot - top
	var tw := 230.0
	var bw := 140.0
	draw_colored_polygon(PackedVector2Array([Vector2(wc.x - tw, top), Vector2(wc.x + tw, top), Vector2(wc.x + bw, bot), Vector2(wc.x - bw, bot)]), Color("#d6e4ee"))
	var f := clampf(amount / 140.0, 0.0, 1.0)
	var ly := bot - f * h
	var lw: float = lerp(bw, tw, f)
	if f > 0.0:
		draw_colored_polygon(PackedVector2Array([Vector2(wc.x - lw + 8, ly), Vector2(wc.x + lw - 8, ly), Vector2(wc.x + bw - 8, bot - 6), Vector2(wc.x - bw + 8, bot - 6)]), liquid)
	var yt1 := bot - 92.0 / 140.0 * h
	var yt2 := bot - 108.0 / 140.0 * h
	draw_rect(Rect2(wc.x + tw - 10, yt2, 70, yt1 - yt2), Color(0.4, 0.8, 0.3, 0.75))
	draw_line(Vector2(wc.x - tw - 30, (yt1 + yt2) / 2), Vector2(wc.x + tw + 60, (yt1 + yt2) / 2), Color(0.3, 0.7, 0.25, 0.8), 4)
	draw_polyline(PackedVector2Array([Vector2(wc.x - tw, top), Vector2(wc.x - bw, bot), Vector2(wc.x + bw, bot), Vector2(wc.x + tw, top)]), Color("#5d7a8c"), 8)
	# 倒的容器
	var jug := Rect2(wc.x - 70, 270, 140, 110)
	Art.panel(self, jug, Color("#e9d8b4") if label == "倒麵粉" else Color("#ffffff"), 20)
	draw_string(font, jug.position + Vector2(0, 68), {"倒麵粉": "麵粉", "加水": "水", "加牛奶": "牛奶"}.get(label, label), HORIZONTAL_ALIGNMENT_CENTER, jug.size.x, 32, Color("#4a2f12"))
	if holding:
		draw_rect(Rect2(wc.x - 12, jug.end.y, 24, ly - jug.end.y), liquid)


func _draw_knead(wc: Vector2) -> void:
	Art.ellipse(self, wc + Vector2(0, 90), Vector2(360, 120), Color("#c9a26b"))
	var rx := 170.0 + squash * 50.0
	var ry := 110.0 - squash * 35.0
	Art.ellipse(self, wc + Vector2(0, 60 + squash * 20), Vector2(rx, ry), Color("#f3e3c0"))
	Art.ellipse(self, wc + Vector2(-40, 30 + squash * 20), Vector2(rx * 0.35, ry * 0.3), Color("#fbf2dc"))
	var p := float(taps) / 12.0
	var bar := Rect2(wc.x - 250, wc.y + 230, 500, 30)
	draw_rect(bar.grow(5), Color("#4a2f12"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)), Color("#f3c74f"))
	draw_string(font, Vector2(bar.position.x, bar.end.y + 44), "%d / 12" % taps, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 32, Color("#4a2f12"))


func _draw_roll(wc: Vector2) -> void:
	var p := clampf(roll_dist / 2600.0, 0.0, 1.0)
	draw_rect(Rect2(wc.x - 420, wc.y - 40, 840, 300), Color("#c9a26b"))
	Art.ellipse(self, wc + Vector2(0, 110), Vector2(130 + 230 * p, 90 - 25 * p), Color("#f3e3c0"))
	draw_rect(Rect2(pin_x - 30, wc.y - 80, 60, 380), Color("#d9a76a"))
	draw_rect(Rect2(pin_x - 18, wc.y - 130, 36, 50), Color("#a0703c"))
	draw_rect(Rect2(pin_x - 18, wc.y + 300, 36, 50), Color("#a0703c"))
	if not dragging:
		draw_string(font, Vector2(0, wc.y - 110), "左右來回滑動", HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color("#c0392b"))
	var bar := Rect2(wc.x - 250, wc.y + 280, 500, 26)
	draw_rect(bar.grow(5), Color("#4a2f12"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)), Color("#f3c74f"))


func _draw_cut(wc: Vector2) -> void:
	var dough := Rect2(wc.x - 300, wc.y, 600, 220)
	draw_rect(dough.grow(30), Color("#c9a26b"))
	draw_rect(dough, Color("#f3e3c0"))
	var g := _guides()
	for i in g.size():
		if used_guides.has(i):
			continue
		var y := dough.position.y
		while y < dough.end.y:
			draw_line(Vector2(g[i], y), Vector2(g[i], minf(y + 16, dough.end.y)), Color("#b08a5a"), 4)
			y += 28
	for x in cuts:
		draw_line(Vector2(x, dough.position.y - 6), Vector2(x, dough.end.y + 6), Color("#7a4f28"), 6)
	var kx := _knife_x()
	draw_colored_polygon(PackedVector2Array([Vector2(kx - 4, dough.position.y - 30), Vector2(kx + 4, dough.position.y - 30), Vector2(kx + 40, dough.position.y - 170), Vector2(kx - 4, dough.position.y - 170)]), Color("#c9d1d6"))
	draw_rect(Rect2(kx - 14, dough.position.y - 250, 50, 80), Color("#4a2f12"))
	draw_string(font, Vector2(0, dough.end.y + 90), "%d / 5 刀" % cuts.size(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color("#4a2f12"))


func _cook_color(dish: String) -> Color:
	var soft := dish == "手工麵" or dish == "饅頭"
	var raw := Color("#f3e3c0")
	var done := Color("#fffdf6") if soft else Color("#e0a84a")
	var over := Color("#c8b48a") if soft else Color("#4a2a14")
	if doneness <= 100.0:
		return raw.lerp(done, doneness / 100.0)
	return done.lerp(over, clampf((doneness - 100.0) / 50.0, 0, 1))


func _draw_cook(wc: Vector2, dish: String) -> void:
	var col := _cook_color(dish)
	var c := wc + Vector2(0, 80)
	match dish:
		"蔥油餅":
			for i in 5:
				draw_colored_polygon(PackedVector2Array([c + Vector2(-60 + i * 30, 120), c + Vector2(-40 + i * 30, 120), c + Vector2(-50 + i * 30, 70 + sin(anim_t * 20 + i) * 12)]), Color("#ff8c2a"))
			Art.ellipse(self, c, Vector2(250, 90), Color("#2b2b2b"))
			draw_rect(Rect2(c.x + 240, c.y - 14, 200, 28), Color("#2b2b2b"))
			Art.ellipse(self, c + Vector2(0, -6), Vector2(190, 66), col)
			for i in 10:
				draw_circle(c + Vector2(fmod(i * 67.0, 300.0) - 150, fmod(i * 41.0, 80.0) - 46), 7, Color("#5aa83a"))
		"手工麵":
			draw_rect(Rect2(c.x - 220, c.y - 80, 440, 220), Color("#8d99a3"))
			Art.ellipse(self, c + Vector2(0, -80), Vector2(220, 50), Color("#6f7b85"))
			Art.ellipse(self, c + Vector2(0, -74), Vector2(196, 40), Color("#a9d4ee"))
			for i in 7:
				var pts := PackedVector2Array()
				for s in 12:
					pts.append(c + Vector2(-170 + s * 30, -74 + sin(s * 1.3 + i + anim_t * 3) * 12 + (i - 3) * 4))
				draw_polyline(pts, col, 6, false)
		"饅頭":
			Art.ellipse(self, c + Vector2(0, 60), Vector2(230, 60), Color("#c9a26b"))
			draw_rect(Rect2(c.x - 230, c.y - 40, 460, 100), Color("#d9b47a"))
			for i in 3:
				Art.ellipse(self, c + Vector2(-130 + i * 130, -50), Vector2(60, 45), col)
			Art.ellipse(self, c + Vector2(0, -40), Vector2(230, 60), Color(0.85, 0.7, 0.45, 0.35))
		_:
			Art.panel(self, Rect2(c.x - 280, c.y - 170, 560, 330), Color("#5a5a5a"), 24)
			draw_rect(Rect2(c.x - 220, c.y - 120, 440, 220), Color("#2b1a10"))
			draw_rect(Rect2(c.x - 220, c.y - 120, 440, 220), Color(1, 0.55, 0.2, 0.25))
			for i in 5:
				draw_circle(c + Vector2(-160 + i * 80, 0), 32, col)
	for i in 6:
		var q := fmod(anim_t * 0.6 + i / 6.0, 1.0)
		draw_circle(c + Vector2(sin(i * 2.0 + q * 4.0) * 80, -120 - q * 160), 18 + q * 14, Color(1, 1, 1, 0.5 * (1 - q)))
	var bar := Rect2(wc.x - 300, wc.y + 270, 600, 32)
	draw_rect(bar.grow(5), Color("#4a2f12"))
	draw_rect(bar, Color("#fff8e6"))
	var xmap := func(v: float) -> float: return bar.position.x + v / 150.0 * bar.size.x
	draw_rect(Rect2(xmap.call(92.0), bar.position.y, xmap.call(108.0) - xmap.call(92.0), bar.size.y), Color(0.4, 0.8, 0.3, 0.8))
	draw_rect(Rect2(bar.position, Vector2(clampf(doneness / 150.0, 0, 1) * bar.size.x, bar.size.y)), Color(0.9, 0.5, 0.2, 0.55))
	var nx: float = xmap.call(minf(doneness, 150.0))
	draw_line(Vector2(nx, bar.position.y - 12), Vector2(nx, bar.end.y + 12), Color("#3a240c"), 6)
	draw_string(font, Vector2(bar.position.x, bar.end.y + 44), "火候", HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 32, Color("#4a2f12"))


func _draw_dish(dish: String, c: Vector2, k: float) -> void:
	Art.ellipse(self, c + Vector2(0, 8 * k), Vector2(150 * k, 58 * k), Color(0, 0, 0, 0.15))
	Art.ellipse(self, c, Vector2(150 * k, 58 * k), Color("#ffffff"))
	Art.ellipse(self, c, Vector2(118 * k, 44 * k), Color("#f1f1f1"))
	match dish:
		"蔥油餅":
			Art.ellipse(self, c + Vector2(0, -6 * k), Vector2(105 * k, 38 * k), Color("#e0a84a"))
			for i in 8:
				draw_circle(c + Vector2(fmod(i * 53.0, 160.0) - 80, fmod(i * 29.0, 40.0) - 26) * k, 5 * k, Color("#5aa83a"))
			for a in [0.0, 1.05, 2.1]:
				draw_line(c + Vector2(cos(a), sin(a) * 0.36) * -100 * k + Vector2(0, -6 * k), c + Vector2(cos(a), sin(a) * 0.36) * 100 * k + Vector2(0, -6 * k), Color("#b9813a"), 3 * k)
		"手工麵":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-110, -30) * k, c + Vector2(110, -30) * k, c + Vector2(70, 30) * k, c + Vector2(-70, 30) * k]), Color("#c0392b"))
			Art.ellipse(self, c + Vector2(0, -30 * k), Vector2(110 * k, 26 * k), Color("#e8c58a"))
			for i in 5:
				var pts := PackedVector2Array()
				for s in 9:
					pts.append(c + Vector2(-90 + s * 22, -34 + sin(s * 1.4 + i) * 6 + (i - 2) * 4) * k)
				draw_polyline(pts, Color("#fff3d6"), 4 * k, false)
			for i in 6:
				draw_circle(c + Vector2(-70 + i * 28, -40 + (i % 2) * 10) * k, 5 * k, Color("#5aa83a"))
		"饅頭":
			for p in [Vector2(-55, -18), Vector2(55, -18), Vector2(0, -34)]:
				Art.ellipse(self, c + p * k, Vector2(46 * k, 34 * k), Color("#fffdf6"))
				Art.ellipse(self, c + (p + Vector2(-12, -10)) * k, Vector2(14 * k, 8 * k), Color("#ffffff"))
		_:
			for p in [Vector2(-60, -10), Vector2(0, -22), Vector2(60, -10), Vector2(-30, 8), Vector2(30, 8)]:
				draw_circle(c + p * k, 26 * k, Color("#c8873e"))
				for j in 3:
					draw_circle(c + (p + Vector2(fmod(j * 17.0, 30.0) - 12, fmod(j * 13.0, 20.0) - 8)) * k, 4 * k, Color("#4a2a14"))
