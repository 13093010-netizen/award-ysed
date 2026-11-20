extends Control
## 結局：總信任值（三關共 9 顆星）

signal title_pressed
signal replay_pressed

const Art = preload("res://scripts/art.gd")

var level_stars: Array = [0, 0, 0, 0, 0, 0]
var font: Font
var t := 0.0
var btns: Array = []


func _ready() -> void:
	font = get_theme_font("font", "Label")
	for d in [["從第一關再玩", replay_pressed], ["回到標題", title_pressed]]:
		var b := Button.new()
		b.text = d[0]
		b.custom_minimum_size = Vector2(300, 100)
		b.size = b.custom_minimum_size
		var sig: Signal = d[1]
		b.pressed.connect(func(): sig.emit())
		add_child(b)
		btns.append(b)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	btns[0].position = Vector2(size.x * 0.62 - 320, size.y - 170)
	btns[1].position = Vector2(size.x * 0.62 + 20, size.y - 170)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _total() -> int:
	var s := 0
	for v in level_stars:
		s += int(v)
	return s


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color("#f7d9a8"))
	Art.ellipse(self, Vector2(w * 0.5, h * 0.3), Vector2(220, 220), Color("#f6b25a"))
	draw_rect(Rect2(0, h * 0.62, w, h * 0.38), Color("#d9a441"))
	for i in 30:
		Art.wheat(self, Vector2(w * (i + 0.5) / 30.0, h + 10), 130 + (i % 4) * 15, Color("#e8b630"), sin(t * 1.5 + i * 0.4) * 0.12)

	var total := _total()
	Art.landlord(self, Vector2(w * 0.15, h - 60), 1.3, total >= 9)

	var cx := w * 0.62
	var pr := Rect2(cx - 520, 40, 1040, 940)
	Art.panel(self, pr, Color(1, 0.97, 0.9, 0.95), 36)
	draw_string(font, Vector2(pr.position.x, pr.position.y + 90), "阿麥伯的麥田守住了", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 64, Color("#4a2f12"))
	var names := ["第一關 麥田", "第二關 大水", "第三關 蟲害", "第四關 收成", "第五關 廚房", "終章 湯麵"]
	for i in 6:
		var y := pr.position.y + 170 + i * 82
		draw_string(font, Vector2(pr.position.x + 70, y + 14), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#5a3a14"))
		for s in 3:
			var c := Vector2(pr.position.x + 560 + s * 110, y)
			Art.star(self, c, 44, Color("#5a3a14"))
			Art.star(self, c, 38, Color("#f3c74f") if s < int(level_stars[i]) else Color("#d8ccb4"))
	draw_string(font, Vector2(pr.position.x, pr.position.y + 710), "信任值　%d / 18" % total, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 64, Color("#c0392b"))
	var msg := "還有很多要學的，明年再一起努力吧。"
	if total >= 15:
		msg = "你是我見過最可靠的農夫！這片田以後就交給你了。"
	elif total >= 9:
		msg = "你很用心，我願意繼續把田租給你。"
	draw_string(font, Vector2(pr.position.x + 40, pr.position.y + 790), "房東：" + msg, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x - 80, 32, Color("#4a2f12"))
	draw_string(font, Vector2(pr.position.x, pr.position.y + 880), "遊戲結束，謝謝遊玩！", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 32, Color("#8a5a2b"))
