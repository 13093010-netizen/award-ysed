extends Control
## 關卡結算面板（第二、三關共用）：標題、星星、說明文字、三個按鈕

signal next_pressed
signal retry_pressed
signal title_pressed

const Art = preload("res://scripts/art.gd")

var title_text := ""
var stars := 0
var lines: Array = []
var can_next := true
var next_text := "下一關"
var font: Font
var btns: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = get_theme_font("font", "Label")
	var defs := [["再玩一次", retry_pressed], ["回到標題", title_pressed], [next_text, next_pressed]]
	for d in defs:
		var b := Button.new()
		b.text = d[0]
		b.custom_minimum_size = Vector2(240, 96)
		b.size = b.custom_minimum_size
		var sig: Signal = d[1]
		b.pressed.connect(func(): sig.emit())
		add_child(b)
		btns.append(b)
	btns[2].disabled = not can_next
	resized.connect(_layout)
	_layout()


func _panel_rect() -> Rect2:
	return Rect2(size.x / 2 - 450, size.y / 2 - 320, 900, 640)


func _layout() -> void:
	var r := _panel_rect()
	var total := 3 * 240 + 2 * 24
	for i in btns.size():
		btns[i].position = Vector2(r.get_center().x - total / 2.0 + i * 264, r.end.y - 130)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var r := _panel_rect()
	Art.panel(self, r, Color("#fff8e6"), 32)
	draw_string(font, Vector2(r.position.x, r.position.y + 84), title_text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 64, Color("#4a2f12"))
	for i in 3:
		var c := Vector2(r.get_center().x + (i - 1) * 150, r.position.y + 190)
		Art.star(self, c, 62, Color("#5a3a14"))
		Art.star(self, c, 54, Color("#f3c74f") if i < stars else Color("#d8ccb4"))
	var y := r.position.y + 305
	for l in lines:
		draw_string(font, Vector2(r.position.x + 30, y), l, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 60, 32, Color("#5a3a14"))
		y += 50
