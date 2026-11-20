extends Control
## 遊戲進入點：負責切換畫面（開場 → 故事 → 第一～五關 → 終章 → 結局），並記錄每關星星

const TitleScreen = preload("res://scripts/title.gd")
const Story = preload("res://scripts/story.gd")
const Ending = preload("res://scripts/ending.gd")
const LEVELS := [
	preload("res://scripts/level1.gd"),
	preload("res://scripts/level2.gd"),
	preload("res://scripts/level3.gd"),
	preload("res://scripts/level4.gd"),
	preload("res://scripts/level5.gd"),
	preload("res://scripts/level6.gd"),
]

var current: Control
var level_stars := [0, 0, 0, 0, 0, 0]


## 像素風做法：畫面實際用 800x600 低解析度算圖、再放大成一格一格的像素。
## 所有關卡仍用 1600x1200 的座標來寫，這裡把整個遊戲縮小 0.5 倍放進 800x600 的畫面。
const PIXEL := 2.0


func _ready() -> void:
	theme = _make_theme()
	scale = Vector2(1.0 / PIXEL, 1.0 / PIXEL)
	get_viewport().size_changed.connect(_fit)
	_fit()
	show_title()


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size * PIXEL


func _swap(c: Control) -> void:
	if current:
		current.queue_free()
	current = c
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_title() -> void:
	var t = TitleScreen.new()
	t.start_pressed.connect(_new_game)
	t.level_selected.connect(show_level)
	_swap(t)


func _new_game() -> void:
	level_stars = [0, 0, 0, 0, 0, 0]
	show_story()


func show_story() -> void:
	var s = Story.new()
	s.finished.connect(show_level.bind(0))
	_swap(s)


func show_level(i: int) -> void:
	var l = LEVELS[i].new()
	l.back_to_title.connect(show_title)
	l.restart.connect(show_level.bind(i))
	l.next_level.connect(_go_next.bind(i))
	l.completed.connect(_on_completed.bind(i))
	_swap(l)


func _on_completed(stars: int, i: int) -> void:
	level_stars[i] = stars


func _go_next(i: int) -> void:
	if i + 1 < LEVELS.size():
		show_level(i + 1)
	else:
		show_ending()


func show_ending() -> void:
	var e = Ending.new()
	e.level_stars = level_stars.duplicate()
	e.title_pressed.connect(show_title)
	e.replay_pressed.connect(_new_game)
	_swap(e)


# ---------- 主題（按鈕樣式、字型） ----------
func _make_theme() -> Theme:
	var th := Theme.new()
	# 若在 fonts/ 放入中文字型（例如 NotoSansTC），會自動套用
	var f: Font = null
	for p in ["res://fonts/font.ttf", "res://fonts/font.otf", "res://fonts/unifont.otf"]:
		if ResourceLoader.exists(p):
			f = load(p)
			break
	var ff := f as FontFile
	if ff:
		# 像素字型：關掉反鋸齒和微調，字才會一格一格清楚
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.generate_mipmaps = false
		ff.multichannel_signed_distance_field = false
	if f:
		th.default_font = f
		ThemeDB.fallback_font = f
	th.default_font_size = 32

	th.set_stylebox("normal", "Button", _sb(Color("#f6e7c1"), Color("#8a5a2b")))
	th.set_stylebox("hover", "Button", _sb(Color("#fbefd0"), Color("#8a5a2b")))
	th.set_stylebox("pressed", "Button", _sb(Color("#f3c74f"), Color("#5a3a14"), 8))
	th.set_stylebox("hover_pressed", "Button", _sb(Color("#f3c74f"), Color("#5a3a14"), 8))
	th.set_stylebox("disabled", "Button", _sb(Color("#ddd3bd"), Color("#a89a80")))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		th.set_color(k, "Button", Color("#4a2f12"))
	th.set_color("font_disabled_color", "Button", Color("#9a8b70"))
	return th


func _sb(bg: Color, border: Color, bw: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 1
	s.shadow_offset = Vector2(0, 8)
	return s
