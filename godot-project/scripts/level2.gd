extends Control
## 第二關：冬天的大水
## 開場：麥田淹水，主角哭著說「幫幫我」
## 拼圖：九宮格排水道，左上「入口」和右下「出口」固定，交換其他 7 塊，讓水從田裡流到河裡

signal back_to_title
signal restart
signal next_level
signal completed(stars: int)

const Art = preload("res://scripts/art.gd")
const ResultPanel = preload("res://scripts/result_panel.gd")

enum Phase { INTRO, PUZZLE, DRAIN, RESULT }

# 水道方向（用位元表示）
const N := 1
const E := 2
const S := 4
const W := 8
const DIRS := {1: Vector2i(0, -1), 2: Vector2i(1, 0), 4: Vector2i(0, 1), 8: Vector2i(-1, 0)}
const OPP := {1: 4, 2: 8, 4: 1, 8: 2}

const WINTER_LEN := 90.0   # 冬季秒數：要在冬天結束前排完水
const TOP_H := 230.0
const HEAD := 0            # 入口（左上，固定）
const TAIL := 8            # 出口（右下，固定）
const INTRO_LINES := ["嗚嗚……一場大雨，我的麥田全都淹水了！", "幫幫我！把排水道拼好，把水引到河裡去！"]

var phase: int = Phase.INTRO
var intro_idx := 0
var intro_chars := 0.0
var t_phase := 0.0
var anim_t := 0.0
var moves := 0
var tiles := []
var selected := -1
var press_idx := -1
var dragging := false
var drag_pos := Vector2.ZERO
var path := []
var flow := 0.0
var flood := 1.0
var drain_done_t := 0.0
var floaters := []
var font: Font


func _ready() -> void:
	font = get_theme_font("font", "Label")
	_setup_tiles()


func _setup_tiles() -> void:
	# 正解：入口 ─ ┐ │ └ ─ 出口（其他是干擾用的碎片）
	var pieces := [W | S, N | S, N | E, W | E, N | W, E | S, N | S]
	while true:
		pieces.shuffle()
		tiles = [W | E] + pieces + [W | E]
		if _solve_path().is_empty():
			break


# ---------- 連通判斷 ----------
func _connected() -> Dictionary:
	var parent := {HEAD: -1}
	var q := [HEAD]
	while q.size() > 0:
		var i: int = q.pop_front()
		var r := i / 3
		var c := i % 3
		for d in DIRS:
			if (tiles[i] & d) == 0:
				continue
			var v: Vector2i = DIRS[d]
			var nc := c + v.x
			var nr := r + v.y
			if nc < 0 or nc > 2 or nr < 0 or nr > 2:
				continue
			var j := nr * 3 + nc
			if parent.has(j) or (tiles[j] & OPP[d]) == 0:
				continue
			parent[j] = i
			q.append(j)
	return parent


func _solve_path() -> Array:
	var parent := _connected()
	if not parent.has(TAIL):
		return []
	var p := []
	var cur: int = TAIL
	while cur != -1:
		p.push_front(cur)
		cur = parent[cur]
	return p


# ---------- 流程 ----------
func _process(delta: float) -> void:
	anim_t += delta
	match phase:
		Phase.INTRO:
			intro_chars += delta * 24.0
		Phase.PUZZLE:
			t_phase += delta
			if t_phase >= WINTER_LEN:
				_finish(false)
		Phase.DRAIN:
			if flow < path.size() + 1.0:
				flow += delta * 3.0
			else:
				flood = move_toward(flood, 0.0, delta * 0.45)
				if flood <= 0.0:
					drain_done_t += delta
					if drain_done_t > 1.2:
						_finish(true)
	for f in floaters:
		f["t"] += delta
	floaters = floaters.filter(func(f): return f["t"] < 1.3)
	queue_redraw()


func _advance_intro() -> void:
	var line: String = INTRO_LINES[intro_idx]
	if intro_chars < line.length():
		intro_chars = line.length()
		return
	intro_idx += 1
	intro_chars = 0.0
	if intro_idx >= INTRO_LINES.size():
		phase = Phase.PUZZLE


func _finish(success: bool) -> void:
	phase = Phase.RESULT
	var stars := 0
	var lines := []
	if success:
		if moves <= 8: stars = 3
		elif moves <= 14: stars = 2
		else: stars = 1
		lines = ["排水道接通了，積水都流進河裡！",
			"交換次數：%d 次　用時：%d 秒" % [moves, int(t_phase)],
			["", "房東：水是排掉了，就是慢了點。", "房東：不錯，田保住了！", "房東：又快又準，真可靠！"][stars]]
	else:
		lines = ["冬天結束了，田還泡在水裡……", "提示：水要從入口一路接到出口，中間不能斷"]
	completed.emit(stars)
	var rp = ResultPanel.new()
	rp.title_text = "第二關結算"
	rp.stars = stars
	rp.lines = lines
	rp.can_next = success
	rp.next_pressed.connect(func(): next_level.emit())
	rp.retry_pressed.connect(func(): restart.emit())
	rp.title_pressed.connect(func(): back_to_title.emit())
	add_child(rp)


# ---------- 操作拼圖 ----------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if phase == Phase.INTRO:
			if event.pressed:
				_advance_intro()
			return
		if phase != Phase.PUZZLE:
			return
		if event.pressed:
			var i := _cell_at(event.position)
			if i < 0:
				return
			if i == HEAD or i == TAIL:
				_float("入口和出口是固定的", event.position, Color("#ffb3a3"))
				return
			press_idx = i
			dragging = true
			drag_pos = event.position
		elif dragging:
			dragging = false
			var j := _cell_at(event.position)
			if j == press_idx:
				# 點一下：選取 → 再點另一塊交換
				if selected == -1:
					selected = j
				elif selected == j:
					selected = -1
				else:
					_swap(selected, j)
					selected = -1
			elif j >= 0 and j != HEAD and j != TAIL:
				_swap(press_idx, j)   # 拖曳到另一塊上直接交換
				selected = -1
			press_idx = -1
	elif event is InputEventMouseMotion and dragging:
		drag_pos = event.position


func _swap(a: int, b: int) -> void:
	var tmp = tiles[a]
	tiles[a] = tiles[b]
	tiles[b] = tmp
	moves += 1
	path = _solve_path()
	if not path.is_empty():
		phase = Phase.DRAIN
		flow = 0.0
		var g := _grid_rect()
		_float("接通了！", g.get_center(), Color("#bfe4ff"))


func _float(text: String, pos: Vector2, col: Color) -> void:
	floaters.append({"text": text, "pos": pos, "t": 0.0, "color": col})


func _grid_rect() -> Rect2:
	var avail_h := size.y - TOP_H - 60
	var s = min(avail_h, size.x * 0.5)
	return Rect2((size.x - s) / 2, TOP_H + (avail_h - s) / 2, s, s)


func _cell_rect(i: int) -> Rect2:
	var g := _grid_rect()
	var cs := g.size.x / 3.0
	return Rect2(g.position.x + (i % 3) * cs, g.position.y + (i / 3) * cs, cs, cs)


func _cell_at(pos: Vector2) -> int:
	var g := _grid_rect()
	if not g.has_point(pos):
		return -1
	var cs := g.size.x / 3.0
	return clampi(int((pos.y - g.position.y) / cs), 0, 2) * 3 + clampi(int((pos.x - g.position.x) / cs), 0, 2)


# =====================================================
# 繪圖
# =====================================================
func _draw() -> void:
	Art.checker(self, Rect2(Vector2.ZERO, size), Color("#aab8a4"), Color("#a1b09b"), 64)
	draw_rect(Rect2(0, 0, size.x, TOP_H - 20), Color("#c9d6df"))
	var sp := 3.0 + (t_phase / WINTER_LEN if phase != Phase.INTRO else 0.0)
	Art.season_wheel(self, font, Vector2(140, 115), 95, minf(sp, 3.99))
	draw_string(font, Vector2(0, 70), "第二關：冬天的大水", HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color("#2f3b45"))

	if phase == Phase.INTRO:
		_draw_intro()
	else:
		_draw_puzzle_scene()

	_draw_rain(0.5 if phase == Phase.INTRO else 0.25)

	for f in floaters:
		var k: float = f["t"] / 1.3
		var p: Vector2 = f["pos"] + Vector2(-220, -30 - 60 * k)
		var col: Color = f["color"]
		col.a = 1.0 - k * k
		draw_string_outline(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 440, 32, 10, Color(0.1, 0.1, 0.2, col.a))
		draw_string(font, p, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 440, 32, col)


func _draw_rain(strength: float) -> void:
	var n := int(70 * strength)
	for i in n:
		var x := fmod(i * 97.3 + anim_t * 120.0, size.x + 100) - 50
		var y := fmod(i * 53.7 + anim_t * (520.0 + (i % 5) * 60.0), size.y)
		draw_line(Vector2(x, y), Vector2(x - 8, y + 26), Color(0.85, 0.92, 1, 0.55), 2)


func _draw_field(r: Rect2, water: float) -> void:
	draw_rect(r.grow(10), Color("#7a4f28"))
	draw_rect(r, Color("#6b4a2b"))
	for i in 9:
		var cs := r.size.x / 3.0
		var cr := Rect2(r.position.x + (i % 3) * cs + 5, r.position.y + (i / 3) * cs + 5, cs - 10, cs - 10)
		draw_rect(cr, Color("#7d5634"))
		for j in 3:
			var base := cr.position + Vector2(cr.size.x * (j + 0.5) / 3.0, cr.size.y * 0.8)
			Art.wheat(self, base, cr.size.y * 0.45, Color("#9a9a55"), 0.7 * water + 0.1, 3.0)
	if water > 0.01:
		draw_rect(r, Color(0.35, 0.6, 0.85, 0.72 * water))
		for k in 6:
			var y := r.position.y + r.size.y * (k + 0.5) / 6.0
			var pts := PackedVector2Array()
			for s in 13:
				var x := r.position.x + r.size.x * s / 12.0
				pts.append(Vector2(x, y + sin(anim_t * 2.5 + s * 0.9 + k) * 5))
			draw_polyline(pts, Color(1, 1, 1, 0.45 * water), 3, false)


func _draw_intro() -> void:
	var fr := Rect2(size.x * 0.42, 250, 560, 560)
	_draw_field(fr, 1.0)
	Art.farmer(self, Vector2(size.x * 0.2, size.y - 40), 1.35, "cry", anim_t)
	if intro_idx < INTRO_LINES.size():
		var box := Rect2(size.x * 0.33, size.y - 300, size.x * 0.63, 240)
		Art.panel(self, box)
		var tag := Rect2(box.position + Vector2(30, -34), Vector2(150, 60))
		Art.panel(self, tag, Color("#f3c74f"), 24)
		draw_string(font, tag.position + Vector2(0, 42), "小麥", HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 32, Color("#4a2f12"))
		var line: String = INTRO_LINES[intro_idx]
		draw_multiline_string(font, box.position + Vector2(44, 92), line.substr(0, int(intro_chars)), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 88, 32, 3, Color("#3a240c"))
		if intro_chars >= line.length() and fmod(anim_t, 1.0) < 0.6:
			draw_string(font, Vector2(box.end.x - 230, box.end.y - 26), "點一下繼續", HORIZONTAL_ALIGNMENT_RIGHT, 200, 32, Color("#8a5a2b"))


func _draw_puzzle_scene() -> void:
	var g := _grid_rect()
	var hint := "點兩塊拼圖交換位置（也可以直接拖曳），讓水從入口流到出口"
	if phase != Phase.PUZZLE:
		hint = "水流出去了！"
	draw_string(font, Vector2(0, 122), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color("#2f3b45"))
	if phase == Phase.PUZZLE:
		var left := int(ceil(WINTER_LEN - t_phase))
		draw_string(font, Vector2(0, 172), "冬季剩餘 %d 秒　交換 %d 次" % [left, moves], HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color("#c0392b") if left <= 15 else Color("#2f3b45"))

	# 左邊：淹水的麥田
	var fw := g.position.x - 100
	var fr := Rect2(40, g.position.y, fw, fw)
	_draw_field(fr, flood)
	Art.farmer(self, Vector2(fr.get_center().x, size.y - 30), 0.72, "happy" if flood < 0.5 else "cry", anim_t)

	# 右邊：河
	var river := Rect2(g.end.x + 80, TOP_H - 20, size.x - g.end.x - 80, size.y)
	draw_rect(river, Color("#4f8fc9"))
	for k in 14:
		var y := fmod(k * 90.0 + anim_t * 60.0, river.size.y) + river.position.y
		draw_line(Vector2(river.position.x + 20 + (k % 3) * 40, y), Vector2(river.position.x + 80 + (k % 3) * 40, y), Color(1, 1, 1, 0.4), 4)
	draw_string(font, Vector2(river.position.x, river.position.y + 60), "河", HORIZONTAL_ALIGNMENT_CENTER, river.size.x, 32, Color.WHITE)

	# 入口水道（田 → 拼圖），出口水道（拼圖 → 河）
	var cs := g.size.x / 3.0
	var hw := cs * 0.17
	var y_in := g.position.y + cs * 0.5
	var y_out := g.position.y + cs * 2.5
	draw_line(Vector2(fr.end.x + 10, y_in), Vector2(g.position.x, y_in), Color("#a9b3b8"), hw * 2 + 12)
	draw_line(Vector2(fr.end.x + 10, y_in), Vector2(g.position.x, y_in), Color(0.3, 0.55, 0.85, 0.4 + 0.6 * flood), hw * 2)
	var out_on := phase == Phase.DRAIN and flow >= path.size() or phase == Phase.RESULT and not path.is_empty()
	draw_line(Vector2(g.end.x, y_out), Vector2(river.position.x, y_out), Color("#a9b3b8"), hw * 2 + 12)
	draw_line(Vector2(g.end.x, y_out), Vector2(river.position.x, y_out), Color("#3b78c4") if out_on else Color("#5b4632"), hw * 2)

	# 拼圖
	draw_rect(g.grow(14), Color("#5a3a14"))
	var reach := _connected()
	for i in 9:
		var water := 0.0
		if phase == Phase.PUZZLE:
			water = 0.55 if reach.has(i) else 0.0
		else:
			var k := path.find(i)
			if k >= 0:
				water = clampf(flow - k, 0.0, 1.0)
			elif reach.has(i):
				water = 0.55
		var r := _cell_rect(i)
		if dragging and i == press_idx and _cell_at(drag_pos) != press_idx:
			draw_rect(r.grow(-4), Color("#3e2a17"))
		else:
			_draw_tile(r.grow(-4), tiles[i], water)
		if i == HEAD or i == TAIL:
			var tag := Rect2(r.position + Vector2(10, 10), Vector2(90, 40))
			draw_rect(tag, Color("#2f3b45"))
			draw_string(font, tag.position + Vector2(0, 30), "入口" if i == HEAD else "出口", HORIZONTAL_ALIGNMENT_CENTER, 90, 32, Color.WHITE)
		if i == selected:
			var a := 0.6 + 0.4 * sin(anim_t * 8.0)
			draw_rect(r.grow(-6), Color(1, 0.85, 0.2, a), false, 8)

	if dragging and _cell_at(drag_pos) != press_idx:
		var dr := Rect2(drag_pos - Vector2(cs, cs) * 0.45, Vector2(cs, cs) * 0.9)
		_draw_tile(dr, tiles[press_idx], 0.0)
		draw_rect(dr, Color(1, 0.85, 0.2), false, 6)


func _draw_tile(r: Rect2, mask: int, water: float) -> void:
	draw_rect(r, Color("#7b5a3a"))
	for k in 5:
		var p := r.position + Vector2(fmod(k * 61.0 + mask * 17.0, r.size.x - 20) + 10, fmod(k * 43.0 + mask * 29.0, r.size.y - 20) + 10)
		draw_circle(p, 5, Color("#6a4c30"))
	var c := r.get_center()
	var hw := r.size.x * 0.17
	var stone := Color("#a9b3b8")
	var bed := Color("#5b4632")
	for d in DIRS:
		if (mask & d) != 0:
			var e := c + Vector2(DIRS[d]) * r.size.x * 0.5
			draw_line(c, e, stone, hw * 2 + 12)
	draw_circle(c, hw + 6, stone)
	for d in DIRS:
		if (mask & d) != 0:
			draw_line(c, c + Vector2(DIRS[d]) * r.size.x * 0.5, bed, hw * 2)
	draw_circle(c, hw, bed)
	if water > 0.0:
		var wc := Color(0.23, 0.5, 0.85, water)
		for d in DIRS:
			if (mask & d) != 0:
				draw_line(c, c + Vector2(DIRS[d]) * r.size.x * 0.5, wc, hw * 1.6)
		draw_circle(c, hw * 0.8, wc)
	draw_rect(r, Color(0.2, 0.12, 0.05, 0.7), false, 3)
