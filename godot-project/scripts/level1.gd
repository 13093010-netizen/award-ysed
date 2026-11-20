extends Control
## 第一關：九宮格麥田
## 春季：翻土 → 播種 → 澆水 / 施肥（時間到就鎖定）
## 夏季：發芽長大　秋季：麥穗轉黃　秋季結束：房東來評分（信任值 ★）

signal back_to_title
signal restart
signal next_level
signal completed(stars: int)

const Art = preload("res://scripts/art.gd")

enum Phase { SPRING, SUMMER, AUTUMN, LANDLORD, RESULT }

# ---- 可調整的關卡參數 ----
const SPRING_LEN := 60.0   # 春季秒數（你要在這段時間內弄完）
const SUMMER_LEN := 14.0
const AUTUMN_LEN := 14.0
const TOP_H := 230.0
const BAR_H := 140.0

const TOOLS := [
	{"id": "hoe", "name": "鋤頭", "color": Color("#a0703c")},
	{"id": "seed_local", "name": "在地麥種", "color": Color("#d9b56a")},
	{"id": "seed_high", "name": "高產麥種", "color": Color("#f0c419")},
	{"id": "water", "name": "澆水", "color": Color("#4f9fe0")},
	{"id": "compost", "name": "堆肥", "color": Color("#6b8e3d")},
	{"id": "quick", "name": "速效肥", "color": Color("#c45bb0")},
]
const TOOL_HINT := {
	"hoe": "鋤頭：先把荒地翻鬆，才能播種",
	"seed_local": "在地麥種：好照顧，不需要太多水和肥",
	"seed_high": "高產麥種：收成多，但要更多水和肥料",
	"water": "澆水：點一次澆一次，太少會乾、太多會爛根",
	"compost": "堆肥：溫和養土，效果慢但不傷土",
	"quick": "速效肥：效果強，但用太多會傷土",
}
const SEASON_NAMES := ["春", "夏", "秋", "冬"]
const SEASON_COLORS := [Color("#9ed36a"), Color("#f5c242"), Color("#e5853a"), Color("#9cc3e0")]
const GRADE_TEXT := {"good": "長得好", "ok": "普通", "poor": "長不好", "dead": "枯死", "empty": "荒廢"}
const GRADE_COLOR := {"good": Color("#3c8d2f"), "ok": Color("#b08a1e"), "poor": Color("#b5651d"), "dead": Color("#7a4a2a"), "empty": Color("#777777")}

var phase: int = Phase.SPRING
var phase_time := 0.0
var speed := 1.0
var tool := "hoe"
var plots := []
var floaters := []
var banner_text := ""
var banner_t := 0.0
var anim_t := 0.0
var font: Font

var toolbar: HBoxContainer
var speed_btn: Button
var end_btn: Button
var dragging := false
var last_drag_idx := -1

# 房東
var dialog_lines := []
var dialog_idx := 0
var dialog_chars := 0.0
var landlord_in := 0.0
var stars := 0
var counts := {}


func _ready() -> void:
	font = get_theme_font("font", "Label")
	for i in 9:
		plots.append({"tilled": false, "seed": "", "water": 0, "compost": 0, "quick": 0, "score": 0, "grade": "empty"})
	_build_ui()
	resized.connect(_layout)
	_layout()
	_show_banner("春天來了！在春季結束前整好你的田", 3.5)


# =====================================================
# UI
# =====================================================
func _build_ui() -> void:
	toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 14)
	add_child(toolbar)
	var group := ButtonGroup.new()
	for t in TOOLS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = t["name"]
		b.icon = Art.icon({"hoe": "hoe", "seed_local": "bag", "seed_high": "bag", "water": "can", "compost": "pile", "quick": "bottle"}[t["id"]], t["color"])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(170, 116)
		b.add_theme_font_size_override("font_size", 32)
		b.pressed.connect(_select_tool.bind(t["id"]))
		toolbar.add_child(b)
		if t["id"] == "hoe":
			b.button_pressed = true

	speed_btn = Button.new()
	speed_btn.text = "快轉 x1"
	speed_btn.custom_minimum_size = Vector2(210, 80)
	speed_btn.pressed.connect(_toggle_speed)
	add_child(speed_btn)

	end_btn = Button.new()
	end_btn.text = "結束春耕"
	end_btn.custom_minimum_size = Vector2(210, 80)
	end_btn.pressed.connect(_on_end_pressed)
	add_child(end_btn)


func _on_end_pressed() -> void:
	if phase == Phase.SPRING:
		_end_spring()


func _layout() -> void:
	var tb_w := TOOLS.size() * 170 + (TOOLS.size() - 1) * 14
	toolbar.size = Vector2(tb_w, 116)
	toolbar.position = Vector2((size.x - tb_w) / 2, size.y - BAR_H + 6)
	speed_btn.position = Vector2(size.x - 240, 30)
	end_btn.position = Vector2(size.x - 240, 124)


func _make_icon(col: Color) -> ImageTexture:
	var img := Image.create(44, 44, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 44:
		for x in 44:
			var d := Vector2(x - 21.5, y - 21.5).length()
			if d <= 17.5:
				img.set_pixel(x, y, col)
			elif d <= 20.5:
				img.set_pixel(x, y, col.darkened(0.45))
	return ImageTexture.create_from_image(img)


func _select_tool(id: String) -> void:
	tool = id


func _toggle_speed() -> void:
	speed = 4.0 if speed == 1.0 else 1.0
	speed_btn.text = "快轉 x%d" % int(speed)


# =====================================================
# 流程
# =====================================================
func _process(delta: float) -> void:
	anim_t += delta
	var d := delta * speed
	match phase:
		Phase.SPRING:
			phase_time += d
			if phase_time >= SPRING_LEN:
				_end_spring()
		Phase.SUMMER:
			phase_time += d
			if phase_time >= SUMMER_LEN:
				phase = Phase.AUTUMN
				phase_time = 0.0
				_show_banner("秋天到了，麥穗漸漸轉黃", 3.0)
		Phase.AUTUMN:
			phase_time += d
			if phase_time >= AUTUMN_LEN:
				_start_landlord()
		Phase.LANDLORD:
			landlord_in = move_toward(landlord_in, 1.0, delta * 1.6)
			if landlord_in >= 1.0 and dialog_idx < dialog_lines.size():
				dialog_chars += delta * 26.0

	for f in floaters:
		f["t"] += delta
	floaters = floaters.filter(func(f): return f["t"] < 1.3)
	if banner_t > 0.0:
		banner_t -= delta
	queue_redraw()


func _end_spring() -> void:
	for p in plots:
		_evaluate(p)
	phase = Phase.SUMMER
	phase_time = 0.0
	end_btn.visible = false
	_show_banner("夏天到了！麥子開始長大", 3.0)


func _start_landlord() -> void:
	phase = Phase.LANDLORD
	toolbar.visible = false
	speed_btn.visible = false
	end_btn.visible = false
	_build_dialog()


func _show_banner(text: String, dur: float) -> void:
	banner_text = text
	banner_t = dur


# =====================================================
# 操作田地
# =====================================================
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if phase == Phase.LANDLORD:
				_advance_dialog()
				return
			dragging = true
			last_drag_idx = -1
			_try_plot_at(event.position)
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		_try_plot_at(event.position)   # 可以用手指滑過多格連續操作


func _grid_rect() -> Rect2:
	var avail_h := size.y - BAR_H - TOP_H - 20
	var s = min(avail_h, size.x * 0.6)
	return Rect2((size.x - s) / 2, TOP_H + (avail_h - s) / 2, s, s)


func _cell_rect(i: int) -> Rect2:
	var g := _grid_rect()
	var cs := g.size.x / 3.0
	var pad := 8.0
	return Rect2(g.position.x + (i % 3) * cs + pad, g.position.y + (i / 3) * cs + pad, cs - pad * 2, cs - pad * 2)


func _plot_index_at(pos: Vector2) -> int:
	var g := _grid_rect()
	if not g.has_point(pos):
		return -1
	var cs := g.size.x / 3.0
	var c := clampi(int((pos.x - g.position.x) / cs), 0, 2)
	var r := clampi(int((pos.y - g.position.y) / cs), 0, 2)
	return r * 3 + c


func _try_plot_at(pos: Vector2) -> void:
	var idx := _plot_index_at(pos)
	if idx < 0 or idx == last_drag_idx:
		return
	last_drag_idx = idx
	if phase != Phase.SPRING:
		_float("春天已過，只能等它長大了", pos, Color.WHITE)
		return
	_apply_tool(idx, pos)


func _apply_tool(idx: int, pos: Vector2) -> void:
	var p = plots[idx]
	var ok := Color("#fff7c2")
	var warn := Color("#ffb3a3")
	match tool:
		"hoe":
			if p["seed"] != "":
				_float("已經播種了", pos, warn)
			elif p["tilled"]:
				_float("已經翻好了", pos, warn)
			else:
				p["tilled"] = true
				_float("翻土完成", pos, ok)
		"seed_local", "seed_high":
			if not p["tilled"]:
				_float("要先用鋤頭翻土！", pos, warn)
			elif p["seed"] != "":
				_float("這格已經播種", pos, warn)
			else:
				p["seed"] = "local" if tool == "seed_local" else "high"
				_float("播下在地麥種" if tool == "seed_local" else "播下高產麥種", pos, ok)
		"water":
			if not p["tilled"]:
				_float("先翻土再澆水", pos, warn)
			elif p["water"] >= 6:
				_float("土已經泡爛了…", pos, warn)
			else:
				p["water"] += 1
				_float("澆水x%d" % p["water"], pos, Color("#bfe4ff"))
		"compost", "quick":
			if not p["tilled"]:
				_float("先翻土再施肥", pos, warn)
			elif p[tool] >= 5:
				_float("放不下了", pos, warn)
			else:
				p[tool] += 1
				_float(("堆肥x%d" if tool == "compost" else "速效肥x%d") % p[tool], pos, ok)


func _float(text: String, pos: Vector2, col: Color) -> void:
	floaters.append({"text": text, "pos": pos, "t": 0.0, "color": col})


# =====================================================
# 評分邏輯：種子x 水量x 肥料 → 長得好 / 普通 / 長不好 / 枯死
# =====================================================
func _evaluate(p: Dictionary) -> void:
	if p["seed"] == "":
		p["score"] = 0
		p["grade"] = "empty"
		return
	var w_lo := 2
	var w_hi := 3
	var n_lo := 1.0
	var n_hi := 2.5
	if p["seed"] == "high":
		w_lo = 3; w_hi = 4; n_lo = 2.0; n_hi = 3.5
	var s := 100.0
	var w: int = p["water"]
	if w < w_lo:
		s -= (w_lo - w) * 30
	elif w > w_hi:
		s -= (w - w_hi) * 25
	var n: float = p["compost"] * 1.0 + p["quick"] * 1.5
	if n < n_lo:
		s -= (n_lo - n) * 25
	elif n > n_hi:
		s -= (n - n_hi) * (10.0 if p["quick"] == 0 else 25.0)
	if p["quick"] >= 3:
		s -= 30
	s = clampf(s, 0, 100)
	p["score"] = s
	if s >= 80: p["grade"] = "good"
	elif s >= 50: p["grade"] = "ok"
	elif s >= 20: p["grade"] = "poor"
	else: p["grade"] = "dead"


func _build_dialog() -> void:
	counts = {"good": 0, "ok": 0, "poor": 0, "dead": 0, "empty": 0}
	var points := 0
	var high_good := 0
	var dry := 0
	var wet := 0
	var burned := 0
	var compost_total := 0
	for p in plots:
		counts[p["grade"]] += 1
		points += {"good": 3, "ok": 2, "poor": 1, "dead": 0, "empty": 0}[p["grade"]]
		compost_total += p["compost"]
		if p["seed"] == "":
			continue
		if p["seed"] == "high" and p["grade"] == "good":
			high_good += 1
			points += 1
		var lo := 3 if p["seed"] == "high" else 2
		var hi := 4 if p["seed"] == "high" else 3
		if p["water"] < lo: dry += 1
		if p["water"] > hi: wet += 1
		if p["quick"] >= 3: burned += 1

	if points >= 24: stars = 3
	elif points >= 15: stars = 2
	elif points >= 7: stars = 1
	else: stars = 0

	dialog_lines = ["嗯…讓我看看你這一季的成果。"]
	if counts["empty"] >= 5:
		dialog_lines.append("九塊田竟然有 %d 塊空著，你是來度假的嗎？" % counts["empty"])
	elif counts["empty"] > 0:
		dialog_lines.append("還有 %d 塊田沒種東西，太可惜了。" % counts["empty"])
	if counts["good"] >= 6:
		dialog_lines.append("麥穗又飽滿又金黃，做得很好！")
	elif counts["good"] >= 3:
		dialog_lines.append("有幾塊長得不錯，看得出你有用心。")
	if dry > 0:
		dialog_lines.append("有 %d 塊田太乾了，麥子渴得長不高。" % dry)
	if wet > 0:
		dialog_lines.append("有 %d 塊水澆太多，根都泡爛了。" % wet)
	if burned > 0:
		dialog_lines.append("速效肥用太兇，土地會受傷的。")
	elif compost_total >= 5:
		dialog_lines.append("你用堆肥慢慢養土，這點我很欣賞。")
	if high_good > 0:
		dialog_lines.append("高產麥種照顧得好，收成多了不少。")
	dialog_lines.append(["這樣我很難信任你啊……", "勉強及格，下一季要更認真。", "還不錯，下一季繼續加油。", "這片田交給你，我很放心！"][stars])


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


func _result_rect() -> Rect2:
	var w := 820.0
	var h := 560.0
	return Rect2(size.x / 2 - w / 2 + 120, size.y / 2 - h / 2 - 40, w, h)


func _show_result() -> void:
	phase = Phase.RESULT
	completed.emit(stars)
	var r := _result_rect()
	var defs := [["再玩一次", restart], ["回到標題", back_to_title], ["下一關", next_level]]
	for i in 3:
		var b := Button.new()
		b.text = defs[i][0]
		b.custom_minimum_size = Vector2(240, 96)
		b.size = b.custom_minimum_size
		b.position = Vector2(r.get_center().x - 372 + i * 264, r.end.y - 125)
		var sig: Signal = defs[i][1]
		b.pressed.connect(func(): sig.emit())
		add_child(b)


# =====================================================
# 繪圖
# =====================================================
func _draw() -> void:
	var w := size.x
	Art.checker(self, Rect2(0, 0, w, size.y), Color("#9fc46a"), Color("#93ba5f"), 64)
	draw_rect(Rect2(0, 0, w, TOP_H - 20), Color("#cfe9f5"))

	_draw_header()
	_draw_season_wheel(Vector2(140, 115), 95)
	_draw_grid()

	for f in floaters:
		var k: float = f["t"] / 1.3
		var p: Vector2 = f["pos"] + Vector2(-200, -30 - 60 * k)
		var col: Color = f["color"]
		col.a = 1.0 - k * k
		draw_string_outline(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 400, 32, 10, Color(0.2, 0.1, 0, col.a))
		draw_string(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 400, 32, col)

	if banner_t > 0.0:
		var a := clampf(banner_t, 0, 1)
		var g := _grid_rect()
		var y := g.position.y + g.size.y * 0.45
		draw_rect(Rect2(0, y - 62, w, 110), Color(0.28, 0.16, 0.05, 0.78 * a))
		draw_string(font, Vector2(0, y + 12), banner_text, HORIZONTAL_ALIGNMENT_CENTER, w, 64, Color(1, 0.97, 0.85, a))

	if phase == Phase.LANDLORD or phase == Phase.RESULT:
		_draw_landlord_scene()


func _draw_header() -> void:
	var w := size.x
	draw_string(font, Vector2(0, 70), "第一關：第一片麥田", HORIZONTAL_ALIGNMENT_CENTER, w, 64, Color("#4a2f12"))
	var hint := ""
	match phase:
		Phase.SPRING: hint = TOOL_HINT[tool]
		Phase.SUMMER: hint = "麥子正在生長…"
		Phase.AUTUMN: hint = "麥穗轉黃了，房東快來了"
		_: hint = "房東來看你的成果"
	draw_string(font, Vector2(0, 122), hint, HORIZONTAL_ALIGNMENT_CENTER, w, 32, Color("#5a3a14"))
	if phase == Phase.SPRING:
		var left := int(ceil(SPRING_LEN - phase_time))
		var col := Color("#c0392b") if left <= 10 else Color("#4a2f12")
		draw_string(font, Vector2(0, 172), "春季剩餘 %d 秒" % left, HORIZONTAL_ALIGNMENT_CENTER, w, 32, col)


func _season_pos() -> float:
	match phase:
		Phase.SPRING: return phase_time / SPRING_LEN
		Phase.SUMMER: return 1.0 + phase_time / SUMMER_LEN
		Phase.AUTUMN: return 2.0 + phase_time / AUTUMN_LEN
	return 3.0


## 四季盤：盤面緩慢旋轉，上方指針指著目前季節
func _draw_season_wheel(c: Vector2, r: float) -> void:
	var sp := _season_pos()
	var base := -PI / 2 - sp * PI / 2
	draw_circle(c, r + 8, Color("#5a3a14"))
	for i in 4:
		var a0 := base + i * PI / 2
		var a1 := a0 + PI / 2
		var pts := PackedVector2Array([c])
		for j in 17:
			var a = lerp(a0, a1, j / 16.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, SEASON_COLORS[i])
		draw_line(c, c + Vector2(cos(a0), sin(a0)) * r, Color("#5a3a14"), 3, false)
		var mid := a0 + PI / 4
		var lp := c + Vector2(cos(mid), sin(mid)) * r * 0.64
		draw_string(font, lp + Vector2(-30, 13), SEASON_NAMES[i], HORIZONTAL_ALIGNMENT_CENTER, 60, 32, Color("#3a240c"))
	draw_circle(c, r * 0.24, Color("#fff4d2"))
	draw_arc(c, r * 0.24, 0, TAU, 24, Color("#5a3a14"), 3, false)
	# 指針
	var tip := c + Vector2(0, -r + 18)
	draw_colored_polygon(PackedVector2Array([tip, c + Vector2(-16, -r - 22), c + Vector2(16, -r - 22)]), Color("#c0392b"))


func _draw_grid() -> void:
	var g := _grid_rect()
	draw_rect(g.grow(18), Color("#7a4f28"))
	draw_rect(g.grow(8), Color("#a8733f"))
	for i in 9:
		_draw_plot(i, _cell_rect(i))


func _draw_plot(i: int, r: Rect2) -> void:
	var p = plots[i]
	if not p["tilled"]:
		draw_rect(r, Color("#8fb85a"))
		for k in 7:
			var x := r.position.x + fmod(37.0 * (k + 1) + i * 23.0, r.size.x - 20) + 10
			var y := r.position.y + fmod(53.0 * (k + 2) + i * 31.0, r.size.y - 30) + 20
			draw_line(Vector2(x, y), Vector2(x - 6, y - 16), Color("#5f8a35"), 3, false)
			draw_line(Vector2(x, y), Vector2(x + 5, y - 14), Color("#5f8a35"), 3, false)
	else:
		var soil := Color("#8a5a33").darkened(min(p["water"], 6) * 0.07)
		draw_rect(r, soil)
		for k in range(1, 4):
			var y := r.position.y + r.size.y * k / 3.0 - 10
			draw_line(Vector2(r.position.x + 10, y), Vector2(r.end.x - 10, y), soil.darkened(0.3), 6, false)
		if p["quick"] >= 3:
			draw_rect(r, Color(1, 1, 1, 0.12))   # 化肥燒土泛白

	if phase == Phase.SPRING:
		if p["seed"] != "":
			var sc := Color("#f0c419") if p["seed"] == "high" else Color("#e6cf9a")
			for rr in 3:
				for cc in 3:
					var bp := r.position + Vector2(r.size.x * (cc + 0.5) / 3.0, r.size.y * (rr + 1) / 3.0 - 12)
					Art.ellipse(self, bp, Vector2(7, 5), sc)
		_draw_indicators(r, p)
	else:
		_draw_crop(r, p)
		if phase == Phase.LANDLORD or phase == Phase.RESULT:
			var gt: String = GRADE_TEXT[p["grade"]]
			var tag := Rect2(r.position + Vector2(8, 8), Vector2(116, 44))
			draw_rect(tag, GRADE_COLOR[p["grade"]])
			draw_string(font, tag.position + Vector2(0, 32), gt, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 32, Color.WHITE)
	draw_rect(r, Color(0.25, 0.15, 0.05, 0.6), false, 3)


func _draw_indicators(r: Rect2, p: Dictionary) -> void:
	if p["seed"] != "":
		var tag := Rect2(r.position + Vector2(8, 8), Vector2(80, 38))
		draw_rect(tag, Color(1, 1, 1, 0.85))
		draw_string(font, tag.position + Vector2(0, 28), "高產" if p["seed"] == "high" else "在地", HORIZONTAL_ALIGNMENT_CENTER, 80, 32, Color("#4a2f12"))
	for k in p["water"]:
		var c := Vector2(r.position.x + 20 + k * 22, r.end.y - 18)
		draw_circle(c, 8, Color("#4f9fe0"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -3), c + Vector2(7, -3), c + Vector2(0, -16)]), Color("#4f9fe0"))
	var x := r.end.x - 22
	for k in p["quick"]:
		draw_rect(Rect2(x - 7, r.end.y - 25, 14, 14), Color("#c45bb0"))
		x -= 20
	for k in p["compost"]:
		draw_rect(Rect2(x - 7, r.end.y - 25, 14, 14), Color("#5d7f32"))
		x -= 20


func _draw_crop(r: Rect2, p: Dictionary) -> void:
	var prog := 2.0
	if phase == Phase.SUMMER: prog = phase_time / SUMMER_LEN
	elif phase == Phase.AUTUMN: prog = 1.0 + phase_time / AUTUMN_LEN
	var g: String = p["grade"]
	if g == "empty":
		if prog > 0.3:   # 沒種的田長滿雜草
			for k in 6:
				var bx := r.position.x + 25 + fmod(k * 47.0, r.size.x - 50)
				var by := r.position.y + r.size.y * (0.35 + 0.1 * (k % 3))
				draw_line(Vector2(bx, by), Vector2(bx - 10, by - 30), Color("#4e7d2a"), 4, false)
				draw_line(Vector2(bx, by), Vector2(bx + 12, by - 26), Color("#4e7d2a"), 4, false)
		return
	var vigor: float = {"good": 1.0, "ok": 0.78, "poor": 0.55, "dead": 0.4}[g]
	var max_h := r.size.y * 0.34 * vigor
	for rr in 3:
		for cc in 3:
			var base := r.position + Vector2(r.size.x * (cc + 0.5) / 3.0, r.size.y * (rr + 1) / 3.0 - 6)
			var sway := sin(anim_t * 2.0 + rr * 0.7 + cc) * 0.06
			if g == "dead" and prog > 0.7:
				draw_line(base, base + Vector2(-8, -18), Color("#7a5230"), 4, false)
				draw_line(base, base + Vector2(6, -14), Color("#7a5230"), 4, false)
				continue
			var h := max_h * clampf(prog, 0.15, 1.0)
			if prog < 1.0:
				var green := Color("#5aa83a") if g != "poor" else Color("#8fae4a")
				Art.sprout(self, base, maxf(h, 24.0), green)
			else:
				var k := clampf(prog - 1.0, 0, 1)
				var target: Color = {"good": Color("#e8b630"), "ok": Color("#d4b45e"), "poor": Color("#b3a066"), "dead": Color("#8a6d45")}[g]
				var col := Color("#6aa83f").lerp(target, k)
				var droop: float = {"good": 0.1, "ok": 0.25, "poor": 0.6, "dead": 0.8}[g] * k
				Art.wheat(self, base, h, col, droop + sway, 4.0)


func _draw_landlord_scene() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.42))
	var e := 1.0 - pow(1.0 - landlord_in, 3)
	var foot := Vector2(lerp(-260.0, size.x * 0.16, e), size.y - 30)
	_draw_landlord(foot, 1.3)

	if phase == Phase.LANDLORD and landlord_in >= 1.0 and dialog_idx < dialog_lines.size():
		var box := Rect2(size.x * 0.3, size.y - 310, size.x * 0.66, 250)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#fff8e6")
		sb.border_color = Color("#7a4f28")
		sb.set_border_width_all(6)
		sb.set_corner_radius_all(0)
		draw_style_box(sb, box)
		var tag := Rect2(box.position + Vector2(30, -34), Vector2(190, 60))
		var sb2: StyleBoxFlat = sb.duplicate()
		sb2.bg_color = Color("#f3c74f")
		draw_style_box(sb2, tag)
		draw_string(font, tag.position + Vector2(0, 42), "房東 陳伯", HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 32, Color("#4a2f12"))
		var line: String = dialog_lines[dialog_idx]
		var shown := line.substr(0, int(dialog_chars))
		draw_multiline_string(font, box.position + Vector2(44, 90), shown, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 88, 32, 3, Color("#3a240c"))
		if dialog_chars >= line.length() and fmod(anim_t, 1.0) < 0.6:
			draw_string(font, Vector2(box.end.x - 230, box.end.y - 26), "點一下繼續", HORIZONTAL_ALIGNMENT_RIGHT, 200, 32, Color("#8a5a2b"))

	if phase == Phase.RESULT:
		var pr := _result_rect()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#fff8e6")
		sb.border_color = Color("#7a4f28")
		sb.set_border_width_all(6)
		sb.set_corner_radius_all(0)
		draw_style_box(sb, pr)
		draw_string(font, Vector2(pr.position.x, pr.position.y + 80), "房東信任值", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 64, Color("#4a2f12"))
		for i in 3:
			var c := Vector2(pr.get_center().x + (i - 1) * 150, pr.position.y + 185)
			_star(c, 62, Color("#5a3a14"))
			_star(c, 54, Color("#f3c74f") if i < stars else Color("#d8ccb4"))
		var s1 := "長得好 %d　普通 %d　長不好 %d" % [counts["good"], counts["ok"], counts["poor"]]
		var s2 := "枯死 %d　荒廢 %d" % [counts["dead"], counts["empty"]]
		draw_string(font, Vector2(pr.position.x, pr.position.y + 305), s1, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 32, Color("#5a3a14"))
		draw_string(font, Vector2(pr.position.x, pr.position.y + 350), s2, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 32, Color("#5a3a14"))
		var msg := "獲得 %d 顆信任星！" % stars if stars > 0 else "沒有拿到信任星…再試一次吧"
		draw_string(font, Vector2(pr.position.x, pr.position.y + 400), msg, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 32, Color("#c0392b"))


func _draw_landlord(foot: Vector2, k: float) -> void:
	var shirt := Color("#5f8a4a")
	var skin := Color("#f1c9a0")
	var dark := Color("#3a240c")
	draw_rect(Rect2(foot.x - 95 * k, foot.y - 240 * k, 190 * k, 240 * k), shirt)
	Art.ellipse(self, foot + Vector2(0, -240 * k), Vector2(95 * k, 36 * k), shirt)
	draw_line(foot + Vector2(-50 * k, -270 * k), foot + Vector2(-40 * k, 0), Color("#7a4f28"), 14 * k)
	draw_line(foot + Vector2(50 * k, -270 * k), foot + Vector2(40 * k, 0), Color("#7a4f28"), 14 * k)
	var hc := foot + Vector2(0, -320 * k)
	draw_circle(hc, 72 * k, skin)
	Art.ellipse(self, hc + Vector2(0, -78 * k), Vector2(62 * k, 46 * k), Color("#e2bd5f"))
	Art.ellipse(self, hc + Vector2(0, -52 * k), Vector2(64 * k, 12 * k), Color("#a0522d"))
	Art.ellipse(self, hc + Vector2(0, -44 * k), Vector2(125 * k, 26 * k), Color("#ecc96f"))
	draw_circle(hc + Vector2(-26 * k, -2 * k), 7 * k, dark)
	draw_circle(hc + Vector2(26 * k, -2 * k), 7 * k, dark)
	draw_circle(hc + Vector2(-42 * k, 22 * k), 11 * k, Color(1, 0.5, 0.5, 0.35))
	draw_circle(hc + Vector2(42 * k, 22 * k), 11 * k, Color(1, 0.5, 0.5, 0.35))
	Art.ellipse(self, hc + Vector2(-17 * k, 26 * k), Vector2(22 * k, 9 * k), Color("#8d8d8d"))
	Art.ellipse(self, hc + Vector2(17 * k, 26 * k), Vector2(22 * k, 9 * k), Color("#8d8d8d"))
	var happy := phase == Phase.LANDLORD or stars >= 2
	if happy:
		draw_arc(hc + Vector2(0, 34 * k), 14 * k, 0.3, PI - 0.3, 12, dark, 4 * k)
	else:
		draw_arc(hc + Vector2(0, 54 * k), 14 * k, PI + 0.4, TAU - 0.4, 12, dark, 4 * k)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
