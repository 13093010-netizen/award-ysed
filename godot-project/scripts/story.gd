extends Control
## 開場故事：深夜電話 → 回家的車上 → 和阿麥伯在麥田的回憶 → 回到老家讀信 → 小麥決定守護麥田
## 點一下繼續，右上角可以跳過

signal finished

const Art = preload("res://scripts/art.gd")

## 每一幕：畫面種類 + 對白 [說話的人, 內容]（說話的人空白 = 旁白）
const SCENES := [
	{"bg": "night", "lines": [
		["", "某天深夜，小麥的手機突然響了起來。"],
		["媽媽（電話）", "小麥……阿公，阿麥伯他生病了，現在在醫院。"],
		["小麥", "什麼？我、我馬上回去！"]]},
	{"bg": "train", "lines": [
		["", "回家的路上，車窗外是一片又一片的麥田。"],
		["", "看著麥田，小麥想起了小時候……"]]},
	{"bg": "memory", "lines": [
		["阿麥伯", "小麥，你看！麥穗彎下腰，就代表成熟囉。"],
		["小時候的小麥", "阿公好厲害！我長大也要跟你一起種麥子！"],
		["", "從小把小麥養大的阿麥伯，總是牽著他的手，在麥田裡走來走去。"]]},
	{"bg": "train_sad", "lines": [
		["小麥", "阿公……你一定要好起來。"]]},
	{"bg": "home", "lines": [
		["", "回到老家，屋子裡靜悄悄的。"],
		["", "桌上放著一封信，信封上寫著「給小麥」。"]]},
	{"bg": "letter", "lines": [["", ""]]},
	{"bg": "field", "lines": [
		["小麥", "原來阿公早就知道自己生病了……"],
		["小麥", "阿公，你安心養病。"],
		["小麥", "這塊充滿回憶的麥田，換我來守護！"]]},
	{"bg": "titlecard", "lines": [["", ""]]},
]

const LETTER := [
	"小麥：",
	"其實阿公早就知道自己生病了。",
	"我最捨不得的，就是這塊麥田。",
	"這裡有你小時候跑來跑去的腳印，",
	"也有我們一家人滿滿的回憶。",
	"要是我沒辦法再種，",
	"房東就會把田收回去了……",
	"阿公真的不希望這塊田就這樣沒了。",
	"　　　　　　　　　　　　阿麥伯",
]

var font: Font
var t := 0.0
var scene_i := 0
var line_i := 0
var chars := 0.0
var fade := 1.0
var skip_btn: Button
var done := false


func _ready() -> void:
	font = get_theme_font("font", "Label")
	skip_btn = Button.new()
	skip_btn.text = "跳過"
	skip_btn.custom_minimum_size = Vector2(180, 80)
	skip_btn.size = skip_btn.custom_minimum_size
	skip_btn.pressed.connect(_finish)
	add_child(skip_btn)
	resized.connect(_layout)
	_layout()


func _finish() -> void:
	if done:
		return
	done = true
	finished.emit()


func _layout() -> void:
	skip_btn.position = Vector2(size.x - 210, 24)


func _process(delta: float) -> void:
	t += delta
	chars += delta * 22.0
	fade = maxf(0.0, fade - delta * 1.5)
	queue_redraw()


func _line() -> Array:
	return SCENES[scene_i]["lines"][line_i]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var text: String = _line()[1]
		if chars < text.length():
			chars = text.length()
			return
		line_i += 1
		chars = 0.0
		if line_i >= SCENES[scene_i]["lines"].size():
			line_i = 0
			scene_i += 1
			fade = 1.0
			if scene_i >= SCENES.size():
				scene_i = SCENES.size() - 1
				_finish()


# =====================================================
# 繪圖
# =====================================================
func _draw() -> void:
	var bg: String = SCENES[scene_i]["bg"]
	match bg:
		"night": _draw_night()
		"train": _draw_train(false)
		"train_sad": _draw_train(true)
		"memory": _draw_memory()
		"home": _draw_home(false)
		"letter": _draw_home(true)
		"field": _draw_field()
		"titlecard": _draw_titlecard()

	var line := _line()
	var text: String = line[1]
	if text != "":
		_draw_dialog(line[0], text)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, fade))


func _draw_dialog(who: String, text: String) -> void:
	var box := Rect2(size.x * 0.06, size.y - 290, size.x * 0.88, 230)
	Art.panel(self, box, Color("#fff8e6") if who != "" else Color("#efe6d6"))
	if who != "":
		var tw := 60.0 + who.length() * 32.0
		var tag := Rect2(box.position + Vector2(30, -38), Vector2(tw, 64))
		Art.panel(self, tag, Color("#f3c74f"))
		draw_string(font, tag.position + Vector2(0, 44), who, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 32, Color("#4a2f12"))
	var col := Color("#3a240c") if who != "" else Color("#6b5a48")
	draw_multiline_string(font, box.position + Vector2(44, 96), text.substr(0, int(chars)), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 88, 32, 3, col)
	if chars >= text.length() and fmod(t, 1.0) < 0.6:
		draw_string(font, Vector2(box.end.x - 240, box.end.y - 26), "點一下繼續", HORIZONTAL_ALIGNMENT_RIGHT, 200, 32, Color("#8a5a2b"))


func _mood_for_line(moods: Array) -> String:
	return moods[mini(line_i, moods.size() - 1)]


# ---------- 深夜接電話 ----------
func _draw_night() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color("#283050"))
	draw_rect(Rect2(0, h * 0.7, w, h * 0.3), Color("#3a3248"))
	var win := Rect2(w * 0.55, 120, 460, 340)
	draw_rect(win.grow(14), Color("#4a3a2a"))
	draw_rect(win, Color("#101836"))
	draw_circle(win.position + Vector2(340, 90), 46, Color("#f6f1c8"))
	draw_circle(win.position + Vector2(362, 76), 40, Color("#101836"))
	for i in 18:
		var p := win.position + Vector2(fmod(i * 97.0, win.size.x - 20) + 10, fmod(i * 53.0, win.size.y - 20) + 10)
		var a := 0.5 + 0.5 * sin(t * 3.0 + i)
		draw_rect(Rect2(p, Vector2(4, 4)), Color(1, 1, 0.8, a))
	draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color("#4a3a2a"), 10)
	# 書桌與檯燈
	draw_rect(Rect2(w * 0.08, h * 0.6, w * 0.4, 30), Color("#6b4a2b"))
	draw_rect(Rect2(w * 0.1, h * 0.6 + 30, 24, h * 0.1), Color("#6b4a2b"))
	draw_rect(Rect2(w * 0.44, h * 0.6 + 30, 24, h * 0.1), Color("#6b4a2b"))
	Art.ellipse(self, Vector2(w * 0.16, h * 0.6 - 100), Vector2(220, 160), Color(1, 0.85, 0.4, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.13, h * 0.6 - 150), Vector2(w * 0.19, h * 0.6 - 150), Vector2(w * 0.2, h * 0.6 - 100), Vector2(w * 0.12, h * 0.6 - 100)]), Color("#f3c74f"))
	draw_rect(Rect2(w * 0.155, h * 0.6 - 100, 10, 100), Color("#888888"))
	# 小麥拿著手機
	var foot := Vector2(w * 0.38, h * 0.82)
	Art.farmer(self, foot, 1.25, _mood_for_line(["normal", "sad", "determined"]), t)
	var phone := Rect2(foot.x + 70, foot.y - 330, 36, 64)
	draw_rect(phone, Color("#222222"))
	draw_rect(phone.grow(-5), Color("#7fd0ff") if line_i == 0 else Color("#b8e6ff"))
	if line_i == 0:
		for i in 3:
			var r := 40.0 + i * 26.0 + fmod(t * 60.0, 26.0)
			draw_arc(phone.get_center(), r, -0.8, 0.8, 8, Color(1, 1, 1, 0.7 - i * 0.2), 6)
		draw_string(font, Vector2(phone.end.x + 60, phone.position.y - 10), "鈴鈴鈴……", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#fff8e6"))


# ---------- 回家的車上 ----------
func _draw_train(sad: bool) -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color("#6b5a4a"))
	var win := Rect2(w * 0.06, 90, w * 0.88, h * 0.5)
	# 窗外：夕陽、山、往後跑的麥田
	draw_rect(win, Color("#f4b36b"))
	draw_rect(Rect2(win.position, Vector2(win.size.x, win.size.y * 0.3)), Color("#f08a5d"))
	draw_circle(win.position + Vector2(win.size.x * 0.75, win.size.y * 0.45), 60, Color("#fff1a8"))
	Art.ellipse(self, win.position + Vector2(win.size.x * 0.3, win.size.y * 0.75), Vector2(500, 120), Color("#b37a54"))
	draw_rect(Rect2(win.position.x, win.position.y + win.size.y * 0.7, win.size.x, win.size.y * 0.3), Color("#d9a441"))
	for i in 26:
		var x := win.position.x + fmod(i * 60.0 - t * 260.0, win.size.x + 60.0)
		if x < win.position.x - 10 or x > win.end.x - 30:
			continue
		Art.wheat(self, Vector2(x + 20, win.end.y), 96, Color("#e8b630"), 0.0, 3)
	for i in 4:
		var x := win.position.x + fmod(i * 420.0 - t * 600.0, win.size.x + 420.0) - 40
		if x > win.position.x and x < win.end.x - 30:
			draw_rect(Rect2(x, win.position.y, 24, win.size.y), Color(0.3, 0.2, 0.1, 0.5))
	# 窗框
	draw_rect(win.grow(18), Color("#3a2a1c"), false, 28)
	draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color("#3a2a1c"), 16)
	# 座椅與小麥（側邊看著窗外）
	draw_rect(Rect2(w * 0.55, h * 0.62, w * 0.4, h * 0.38), Color("#2f5d8a"))
	Art.farmer(self, Vector2(w * 0.74, h * 0.95), 1.5, "sad" if sad else "normal", t)


# ---------- 回憶 ----------
func _draw_memory() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color("#f3dca2"))
	draw_circle(Vector2(w * 0.8, h * 0.18), 80, Color("#fff4d2"))
	draw_rect(Rect2(0, h * 0.5, w, h * 0.5), Color("#d9a441"))
	Art.grandpa(self, Vector2(w * 0.38, h * 0.5), 1.3, "happy" if line_i != 1 else "normal", true, false, t)
	Art.farmer(self, Vector2(w * 0.6, h * 0.82), 0.75, "happy", t)
	for i in 28:
		var x := (i + 0.5) * w / 28.0
		Art.wheat(self, Vector2(x, h * 0.86 + (i % 2) * 16), 150, Color("#e8b630"), sin(t * 1.5 + i * 0.5) * 0.2, 3)
	# 舊照片的感覺
	draw_rect(Rect2(0, 0, w, h), Color(0.55, 0.38, 0.15, 0.18))
	draw_rect(Rect2(0, 0, w, h), Color("#5a3a14"), false, 40)
	Art.panel(self, Rect2(50, 50, 180, 72), Color("#fff4d2"))
	draw_string(font, Vector2(50, 100), "回憶", HORIZONTAL_ALIGNMENT_CENTER, 180, 32, Color("#7a4f28"))


# ---------- 老家與信 ----------
func _draw_home(letter: bool) -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color("#a5774a"))
	for i in int(w / 80.0) + 1:
		draw_line(Vector2(i * 80, 0), Vector2(i * 80, h * 0.7), Color("#8d6339"), 6)
	draw_rect(Rect2(0, h * 0.7, w, h * 0.3), Color("#6b4a2b"))
	# 牆上的照片：阿麥伯和小時候的小麥
	var ph := Rect2(w * 0.12, 120, 300, 230)
	draw_rect(ph.grow(14), Color("#4a2f12"))
	draw_rect(ph, Color("#f3dca2"))
	Art.grandpa(self, ph.position + Vector2(110, 110), 0.55, "happy", true, false, t)
	Art.farmer(self, ph.position + Vector2(220, 226), 0.38, "happy", t)
	# 窗
	var win := Rect2(w * 0.62, 120, 360, 260)
	draw_rect(win.grow(12), Color("#4a2f12"))
	draw_rect(win, Color("#bfe3f2"))
	draw_rect(Rect2(win.position.x, win.position.y + win.size.y * 0.6, win.size.x, win.size.y * 0.4), Color("#d9a441"))
	# 桌子與信
	var table := Rect2(w * 0.35, h * 0.6, w * 0.4, 40)
	draw_rect(table, Color("#5a3a1e"))
	draw_rect(Rect2(table.position.x + 20, table.end.y, 30, 140), Color("#5a3a1e"))
	draw_rect(Rect2(table.end.x - 50, table.end.y, 30, 140), Color("#5a3a1e"))
	var env := Rect2(table.get_center().x - 70, table.position.y - 50, 140, 50)
	draw_rect(env, Color("#fff8e6"))
	draw_circle(env.get_center(), 12, Color("#c0392b"))
	Art.farmer(self, Vector2(w * 0.22, h * 0.86), 1.2, "sad", t)
	if letter:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.5))
		var paper := Rect2(w / 2 - 520, 70, 1040, 930)
		Art.panel(self, paper, Color("#fbf3dc"))
		for i in 13:
			var y := paper.position.y + 150 + i * 62
			draw_line(Vector2(paper.position.x + 50, y + 14), Vector2(paper.end.x - 50, y + 14), Color("#e3d3ad"), 2)
		for i in LETTER.size():
			draw_string(font, Vector2(paper.position.x + 70, paper.position.y + 140 + i * 82), LETTER[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#4a2f12"))
		if fmod(t, 1.0) < 0.6:
			draw_string(font, Vector2(paper.position.x, paper.end.y - 30), "點一下繼續", HORIZONTAL_ALIGNMENT_RIGHT, paper.size.x - 50, 32, Color("#8a5a2b"))


# ---------- 夕陽下的麥田：下定決心 ----------
func _draw_field() -> void:
	var w := size.x
	var h := size.y
	var bands := [Color("#f08a5d"), Color("#f4a261"), Color("#f6bd60"), Color("#f7d488")]
	for i in bands.size():
		draw_rect(Rect2(0, i * h * 0.13, w, h * 0.13 + 2), bands[i])
	draw_circle(Vector2(w * 0.5, h * 0.5), 110, Color("#fff1a8"))
	draw_rect(Rect2(0, h * 0.52, w, h * 0.48), Color("#d9a441"))
	for i in 30:
		var x := (i + 0.5) * w / 30.0
		Art.wheat(self, Vector2(x, h * 0.62), 110, Color("#e3a72f"), sin(t * 1.5 + i * 0.4) * 0.2, 3)
	Art.farmer(self, Vector2(w * 0.5, h * 0.78), 1.35, _mood_for_line(["sad", "normal", "determined"]), t)
	for i in 30:
		var x := (i + 0.25) * w / 30.0
		Art.wheat(self, Vector2(x, h * 0.8 + (i % 2) * 20), 150, Color("#e8b630"), sin(t * 1.5 + i * 0.5) * 0.2, 3)


func _draw_titlecard() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color("#1e1610"))
	for i in 24:
		var x := (i + 0.5) * w / 24.0
		Art.wheat(self, Vector2(x, h + 10), 160, Color("#a67c2a"), sin(t * 1.2 + i * 0.4) * 0.15, 3)
	var ty := h * 0.42
	draw_string_outline(font, Vector2(0, ty), "守護阿麥伯的麥田", HORIZONTAL_ALIGNMENT_CENTER, w, 96, 32, Color("#f3c74f"))
	draw_string_outline(font, Vector2(0, ty), "守護阿麥伯的麥田", HORIZONTAL_ALIGNMENT_CENTER, w, 96, 16, Color("#3a240c"))
	draw_string(font, Vector2(0, ty), "守護阿麥伯的麥田", HORIZONTAL_ALIGNMENT_CENTER, w, 96, Color("#fff8e6"))
	draw_string(font, Vector2(0, ty + 110), "第一關：第一片麥田", HORIZONTAL_ALIGNMENT_CENTER, w, 64, Color("#f3c74f"))
	if fmod(t, 1.0) < 0.6:
		draw_string(font, Vector2(0, ty + 220), "點一下開始", HORIZONTAL_ALIGNMENT_CENTER, w, 32, Color("#fff8e6"))
