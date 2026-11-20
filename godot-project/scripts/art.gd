extends RefCounted
## 共用繪圖小工具（全部用程式畫，不需要美術素材）

const DARK := Color("#3a240c")


static func ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


## ---------------- 像素圖 ----------------
## 用字元畫像素圖：每個字元代表一種顏色，"." 是透明
const WHEAT_SPR := [
	"....k....",
	"...klk...",
	"..kgkgk..",
	"..klgdk..",
	"..kgkgk..",
	"..klgdk..",
	"..kgkgk..",
	"...kgk...",
	"....s....",
	".k..s....",
	"ksk.s..k.",
	".kss.skk.",
	"....ss...",
	"....s....",
	"....s....",
	"....s....",
]
const SPROUT_SPR := [
	"..kk.....",
	".kggk.kk.",
	".kgggkggk",
	"..kgkggk.",
	"...kgkk..",
	"....g....",
	"....g....",
	"...kgk...",
]


## 畫字元像素圖。pos = 左上角，px = 一格像素的大小（要用 2 的倍數）
## shear = 每一行往右偏移的格數（用來做彎垂）
static func sprite(ci: CanvasItem, pos: Vector2, rows: Array, pal: Dictionary, px: float, shear: Array = []) -> void:
	for r in rows.size():
		var line: String = rows[r]
		var off := 0.0
		if r < shear.size():
			off = shear[r]
		for c in line.length():
			var ch := line[c]
			if ch == "." or not pal.has(ch):
				continue
			ci.draw_rect(Rect2(pos + Vector2((c + off) * px, r * px), Vector2(px, px)), pal[ch])


static func _px_for(h: float, rows: int) -> float:
	return maxf(2.0, floorf(h / rows / 2.0) * 2.0)


## 畫一根像素麥穗（底部中心在 base，高度約 h）。droop = 彎垂程度（長不好的麥子會垂下來）
static func wheat(ci: CanvasItem, base: Vector2, h: float, col: Color, droop: float = 0.0, _width: float = 4.0) -> void:
	var px := _px_for(h, WHEAT_SPR.size())
	var pal := {"k": col.darkened(0.55), "g": col, "l": col.lightened(0.3), "d": col.darkened(0.2), "s": col.darkened(0.35)}
	var shear := []
	for r in WHEAT_SPR.size():
		var k := 1.0 - r / float(WHEAT_SPR.size() - 1)
		shear.append(roundf(droop * 5.0 * k * k))
	var w := 9 * px
	sprite(ci, base - Vector2(w / 2.0, WHEAT_SPR.size() * px), WHEAT_SPR, pal, px, shear)


## 像素嫩芽
static func sprout(ci: CanvasItem, base: Vector2, h: float, col: Color) -> void:
	var px := _px_for(h, SPROUT_SPR.size())
	var pal := {"k": col.darkened(0.5), "g": col}
	sprite(ci, base - Vector2(9 * px / 2.0, SPROUT_SPR.size() * px), SPROUT_SPR, pal, px)


## 把字元像素圖做成按鈕圖示
static func icon_tex(rows: Array, pal: Dictionary, sc: int = 4) -> ImageTexture:
	var h := rows.size()
	var w: int = (rows[0] as String).length()
	var img := Image.create(w * sc, h * sc, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for r in h:
		var line: String = rows[r]
		for c in line.length():
			var ch := line[c]
			if ch == "." or not pal.has(ch):
				continue
			img.fill_rect(Rect2i(c * sc, r * sc, sc, sc), pal[ch])
	return ImageTexture.create_from_image(img)


const ICONS := {
	"hoe": [
		"............",
		"..kkkkk.....",
		".kssssk.....",
		"..kkkkk.....",
		"....kwk.....",
		".....kwk....",
		"......kwk...",
		".......kwk..",
		"........kwk.",
		".........kwk",
		"..........kk",
		"............"],
	"bag": [
		"....kkkk....",
		"...kbbbbk...",
		"....kkkk....",
		"...kbbbbk...",
		"..kbbbbbbk..",
		".kbbyybbbbk.",
		".kbyyyybbbk.",
		".kbbyybbbbk.",
		".kbbbbbbbbk.",
		".kbbbbbbbbk.",
		"..kkkkkkkk..",
		"............"],
	"can": [
		"............",
		"...kkkkk....",
		"..k.....k...",
		".kkkkkkkkk..",
		"kbkbbbbbbk.k",
		".kbbbbbbbkkb",
		"..kbllbbbkb.",
		"..kblbbbbk..",
		"..kbbbbbbk..",
		"..kkkkkkkk..",
		"............",
		"............"],
	"pile": [
		"............",
		"............",
		"......g.....",
		".....kgk....",
		"....kbbbk...",
		"...kbdbbbk..",
		"..kbbbdbbbk.",
		".kbdbbbbdbbk",
		".kbbbdbbbbbk",
		".kkkkkkkkkkk",
		"............",
		"............"],
	"bottle": [
		"....kkkk....",
		"....kwwk....",
		"...kkkkkk...",
		"..kbbbbbbk..",
		"..kbllbbbk..",
		"..kblbbbbk..",
		"..kbbbbbbk..",
		"..kbbbbbbk..",
		"..kbbbbbbk..",
		"..kkkkkkkk..",
		"............",
		"............"],
	"ladybug": [
		"............",
		"....kkkk....",
		"...kkkkkk...",
		"..krrkkrrk..",
		".krrrkkrrrk.",
		".krkrkkrkrk.",
		".krrrkkrrrk.",
		".krkrkkrkrk.",
		"..krrkkrrk..",
		"...kkkkkk...",
		"............",
		"............"],
}


## 取得工具圖示。kind: hoe / bag / can / pile / bottle / ladybug，col = 主色
static func icon(kind: String, col: Color) -> ImageTexture:
	var pal := {"k": Color("#2b1d10"), "s": Color("#b8c2c8"), "w": Color("#a0703c"), "b": col,
		"y": Color("#f0c419"), "l": col.lightened(0.45), "d": col.darkened(0.3), "g": Color("#5aa83a"), "r": Color("#e23b2e")}
	return icon_tex(ICONS[kind], pal, 4)


## 格子草地背景（像參考圖那種一格一格的地磚）
static func checker(ci: CanvasItem, rect: Rect2, c1: Color, c2: Color, tile: float = 64.0) -> void:
	ci.draw_rect(rect, c1)
	var cols := int(ceil(rect.size.x / tile))
	var rows := int(ceil(rect.size.y / tile))
	for r in rows:
		for c in cols:
			var p := rect.position + Vector2(c, r) * tile
			if (r + c) % 2 == 1:
				ci.draw_rect(Rect2(p, Vector2(minf(tile, rect.end.x - p.x), minf(tile, rect.end.y - p.y))), c2)
			# 小草點
			var h := (r * 7 + c * 13) % 5
			if h < 2 and p.x + tile * 0.7 < rect.end.x and p.y + tile * 0.7 < rect.end.y:
				var q := p + Vector2(tile * (0.2 + h * 0.3), tile * (0.3 + h * 0.2))
				ci.draw_rect(Rect2(q, Vector2(4, 8)), c1.darkened(0.18))
				ci.draw_rect(Rect2(q + Vector2(6, 2), Vector2(4, 6)), c1.darkened(0.18))


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)


static func heart(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-r * 0.5, -r * 0.2), r * 0.55, col)
	ci.draw_circle(c + Vector2(r * 0.5, -r * 0.2), r * 0.55, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.03, -r * 0.05), c + Vector2(r * 1.03, -r * 0.05), c + Vector2(0, r * 1.05)]), col)


## 像素風面板：方角、粗邊框、硬陰影、上緣亮線
static func panel(ci: CanvasItem, rect: Rect2, bg: Color = Color("#fff8e6"), _radius: int = 0) -> void:
	ci.draw_rect(Rect2(rect.position + Vector2(0, 8), rect.size), Color(0, 0, 0, 0.28))
	ci.draw_rect(rect, Color("#4a2f12"))
	var inner := rect.grow(-6)
	ci.draw_rect(inner, bg)
	ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 4)), bg.lightened(0.4))
	ci.draw_rect(Rect2(inner.position.x, inner.end.y - 4, inner.size.x, 4), bg.darkened(0.12))


static func hp_bar(ci: CanvasItem, font: Font, rect: Rect2, ratio: float, title: String, value_text: String) -> void:
	panel(ci, rect, Color("#fff8e6"), 22)
	ci.draw_string(font, rect.position + Vector2(26, 48), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#4a2f12"))
	ci.draw_string(font, rect.position + Vector2(0, 48), value_text, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 26, 32, Color("#4a2f12"))
	var bar := Rect2(rect.position.x + 26, rect.position.y + 64, rect.size.x - 52, 28)
	ci.draw_rect(bar, Color("#4a2f12"))
	var inner := bar.grow(-4)
	var col := Color("#4caf50") if ratio > 0.5 else (Color("#f0b429") if ratio > 0.2 else Color("#e0533d"))
	ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(ratio, 0, 1), inner.size.y)), col)


## 四季盤：sp = 0~4（0 春初、1 夏初、2 秋初、3 冬初）
static func season_wheel(ci: CanvasItem, font: Font, c: Vector2, r: float, sp: float) -> void:
	var names := ["春", "夏", "秋", "冬"]
	var cols := [Color("#9ed36a"), Color("#f5c242"), Color("#e5853a"), Color("#9cc3e0")]
	var base := -PI / 2 - sp * PI / 2
	ci.draw_circle(c, r + 8, Color("#5a3a14"))
	for i in 4:
		var a0 := base + i * PI / 2
		var a1 := a0 + PI / 2
		var pts := PackedVector2Array([c])
		for j in 17:
			var a: float = lerp(a0, a1, j / 16.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		ci.draw_colored_polygon(pts, cols[i])
		ci.draw_line(c, c + Vector2(cos(a0), sin(a0)) * r, Color("#5a3a14"), 3, false)
		var mid := a0 + PI / 4
		var lp := c + Vector2(cos(mid), sin(mid)) * r * 0.64
		ci.draw_string(font, lp + Vector2(-30, 13), names[i], HORIZONTAL_ALIGNMENT_CENTER, 60, 32, DARK)
	ci.draw_circle(c, r * 0.24, Color("#fff4d2"))
	ci.draw_arc(c, r * 0.24, 0, TAU, 24, Color("#5a3a14"), 3, false)
	var tip := c + Vector2(0, -r + 18)
	ci.draw_colored_polygon(PackedVector2Array([tip, c + Vector2(-16, -r - 22), c + Vector2(16, -r - 22)]), Color("#c0392b"))


## 房東陳伯
static func landlord(ci: CanvasItem, foot: Vector2, k: float, happy: bool) -> void:
	var shirt := Color("#5f8a4a")
	var skin := Color("#f1c9a0")
	ci.draw_rect(Rect2(foot.x - 95 * k, foot.y - 240 * k, 190 * k, 240 * k), shirt)
	ellipse(ci, foot + Vector2(0, -240 * k), Vector2(95 * k, 36 * k), shirt)
	ci.draw_line(foot + Vector2(-50 * k, -270 * k), foot + Vector2(-40 * k, 0), Color("#7a4f28"), 14 * k)
	ci.draw_line(foot + Vector2(50 * k, -270 * k), foot + Vector2(40 * k, 0), Color("#7a4f28"), 14 * k)
	var hc := foot + Vector2(0, -320 * k)
	ci.draw_circle(hc, 72 * k, skin)
	ellipse(ci, hc + Vector2(0, -78 * k), Vector2(62 * k, 46 * k), Color("#e2bd5f"))
	ellipse(ci, hc + Vector2(0, -52 * k), Vector2(64 * k, 12 * k), Color("#a0522d"))
	ellipse(ci, hc + Vector2(0, -44 * k), Vector2(125 * k, 26 * k), Color("#ecc96f"))
	ci.draw_circle(hc + Vector2(-26 * k, -2 * k), 7 * k, DARK)
	ci.draw_circle(hc + Vector2(26 * k, -2 * k), 7 * k, DARK)
	ci.draw_circle(hc + Vector2(-42 * k, 22 * k), 11 * k, Color(1, 0.5, 0.5, 0.35))
	ci.draw_circle(hc + Vector2(42 * k, 22 * k), 11 * k, Color(1, 0.5, 0.5, 0.35))
	ellipse(ci, hc + Vector2(-17 * k, 26 * k), Vector2(22 * k, 9 * k), Color("#8d8d8d"))
	ellipse(ci, hc + Vector2(17 * k, 26 * k), Vector2(22 * k, 9 * k), Color("#8d8d8d"))
	if happy:
		ci.draw_arc(hc + Vector2(0, 34 * k), 14 * k, 0.3, PI - 0.3, 12, DARK, 4 * k)
	else:
		ci.draw_arc(hc + Vector2(0, 54 * k), 14 * k, PI + 0.4, TAU - 0.4, 12, DARK, 4 * k)


## 主角小麥（男生）。mood: "normal" / "happy" / "cry" / "sad" / "determined"
static func farmer(ci: CanvasItem, foot: Vector2, k: float, mood: String, t: float) -> void:
	var skin := Color("#f6d3b0")
	var hair := Color("#3a2618")
	var shirt := Color("#5b8fd0")
	var pants := Color("#3b4f7a")
	var shoe := Color("#4a2f12")
	ci.draw_rect(Rect2(foot.x - 44 * k, foot.y - 92 * k, 38 * k, 92 * k), pants)
	ci.draw_rect(Rect2(foot.x + 6 * k, foot.y - 92 * k, 38 * k, 92 * k), pants)
	ci.draw_rect(Rect2(foot.x - 52 * k, foot.y - 14 * k, 48 * k, 14 * k), shoe)
	ci.draw_rect(Rect2(foot.x + 4 * k, foot.y - 14 * k, 48 * k, 14 * k), shoe)
	ci.draw_rect(Rect2(foot.x - 64 * k, foot.y - 188 * k, 128 * k, 104 * k), shirt)
	ci.draw_rect(Rect2(foot.x - 88 * k, foot.y - 182 * k, 26 * k, 84 * k), shirt)
	ci.draw_rect(Rect2(foot.x + 62 * k, foot.y - 182 * k, 26 * k, 84 * k), shirt)
	ci.draw_circle(foot + Vector2(-75 * k, -94 * k), 14 * k, skin)
	ci.draw_circle(foot + Vector2(75 * k, -94 * k), 14 * k, skin)
	ci.draw_colored_polygon(PackedVector2Array([foot + Vector2(-24 * k, -188 * k), foot + Vector2(24 * k, -188 * k), foot + Vector2(0, -160 * k)]), Color("#fff8e6"))
	ci.draw_rect(Rect2(foot.x - 64 * k, foot.y - 100 * k, 128 * k, 10 * k), Color("#7a4f28"))
	var hc := foot + Vector2(0, -240 * k)
	ci.draw_circle(hc + Vector2(-56 * k, 12 * k), 13 * k, skin)
	ci.draw_circle(hc + Vector2(56 * k, 12 * k), 13 * k, skin)
	ci.draw_circle(hc, 60 * k, hair)
	ci.draw_circle(hc + Vector2(0, 8 * k), 55 * k, skin)
	ellipse(ci, hc + Vector2(0, -36 * k), Vector2(60 * k, 26 * k), hair)
	for i in 4:
		var x := -46.0 + i * 26.0
		ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(x, -32) * k, hc + Vector2(x + 30, -32) * k, hc + Vector2(x + 12, -6) * k]), hair)
	ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-6, -58) * k, hc + Vector2(8, -58) * k, hc + Vector2(14, -84) * k]), hair)
	ci.draw_circle(hc + Vector2(-36 * k, 26 * k), 10 * k, Color(1, 0.45, 0.45, 0.3))
	ci.draw_circle(hc + Vector2(36 * k, 26 * k), 10 * k, Color(1, 0.45, 0.45, 0.3))
	match mood:
		"cry":
			ci.draw_polyline(PackedVector2Array([hc + Vector2(-34 * k, 2 * k), hc + Vector2(-18 * k, 10 * k), hc + Vector2(-34 * k, 18 * k)]), DARK, 4 * k)
			ci.draw_polyline(PackedVector2Array([hc + Vector2(34 * k, 2 * k), hc + Vector2(18 * k, 10 * k), hc + Vector2(34 * k, 18 * k)]), DARK, 4 * k)
			for side in [-1, 1]:
				var ex := hc + Vector2(side * 26 * k, 20 * k)
				for j in 3:
					var ph := fmod(t * 1.4 + j / 3.0, 1.0)
					ci.draw_circle(ex + Vector2(side * 8 * k * ph, ph * 95 * k), (7 - ph * 3) * k, Color(0.4, 0.7, 1, 1 - ph))
			ellipse(ci, hc + Vector2(0, 38 * k), Vector2(15 * k, (11 + sin(t * 9) * 3) * k), DARK)
		"happy":
			ci.draw_arc(hc + Vector2(-22 * k, 12 * k), 10 * k, PI + 0.3, TAU - 0.3, 10, DARK, 4 * k)
			ci.draw_arc(hc + Vector2(22 * k, 12 * k), 10 * k, PI + 0.3, TAU - 0.3, 10, DARK, 4 * k)
			ci.draw_arc(hc + Vector2(0, 28 * k), 16 * k, 0.25, PI - 0.25, 12, DARK, 4 * k)
		"sad":
			ci.draw_line(hc + Vector2(-34, -6) * k, hc + Vector2(-14, -12) * k, DARK, 4 * k)
			ci.draw_line(hc + Vector2(34, -6) * k, hc + Vector2(14, -12) * k, DARK, 4 * k)
			ci.draw_circle(hc + Vector2(-22 * k, 12 * k), 6 * k, DARK)
			ci.draw_circle(hc + Vector2(22 * k, 12 * k), 6 * k, DARK)
			ci.draw_arc(hc + Vector2(0, 46 * k), 10 * k, PI + 0.5, TAU - 0.5, 10, DARK, 4 * k)
			var ph := fmod(t * 0.5, 1.0)
			ci.draw_circle(hc + Vector2(24 * k, (22 + ph * 40) * k), 6 * k, Color(0.4, 0.7, 1, 1 - ph))
		"determined":
			ci.draw_line(hc + Vector2(-34, -14) * k, hc + Vector2(-12, -6) * k, DARK, 5 * k)
			ci.draw_line(hc + Vector2(34, -14) * k, hc + Vector2(12, -6) * k, DARK, 5 * k)
			ci.draw_circle(hc + Vector2(-22 * k, 8 * k), 7 * k, DARK)
			ci.draw_circle(hc + Vector2(22 * k, 8 * k), 7 * k, DARK)
			ci.draw_arc(hc + Vector2(0, 28 * k), 14 * k, 0.3, PI - 0.3, 12, DARK, 4 * k)
		_:
			ci.draw_circle(hc + Vector2(-22 * k, 8 * k), 7 * k, DARK)
			ci.draw_circle(hc + Vector2(22 * k, 8 * k), 7 * k, DARK)
			ci.draw_arc(hc + Vector2(0, 30 * k), 10 * k, 0.4, PI - 0.4, 10, DARK, 4 * k)


## 阿麥伯（爺爺）半身。hc = 頭的中心；mood: "normal" / "happy" / "eat" / "tear"
## hat = 戴斗笠（回憶裡的樣子）；gown = 穿病人服（醫院）
static func grandpa(ci: CanvasItem, hc: Vector2, k: float, mood: String, hat: bool, gown: bool, t: float) -> void:
	var skin := Color("#eec39a")
	var white := Color("#f4f4f4")
	var cloth := Color("#a9d2e8") if gown else Color("#7a5a3a")
	ellipse(ci, hc + Vector2(0, 125 * k), Vector2(100 * k, 55 * k), cloth)
	ci.draw_rect(Rect2(hc.x - 100 * k, hc.y + 125 * k, 200 * k, 110 * k), cloth)
	if gown:
		for i in 4:
			ci.draw_circle(hc + Vector2(-60 + i * 40, 160) * k, 6 * k, Color("#7fb3d1"))
	else:
		ci.draw_rect(Rect2(hc.x - 30 * k, hc.y + 80 * k, 60 * k, 155 * k), Color("#e9dcc0"))
	ci.draw_circle(hc + Vector2(-54 * k, 14 * k), 13 * k, skin)
	ci.draw_circle(hc + Vector2(54 * k, 14 * k), 13 * k, skin)
	ci.draw_circle(hc + Vector2(0, 6 * k), 58 * k, skin)
	ci.draw_circle(hc + Vector2(-50 * k, -6 * k), 18 * k, white)
	ci.draw_circle(hc + Vector2(50 * k, -6 * k), 18 * k, white)
	if hat:
		ellipse(ci, hc + Vector2(0, -62 * k), Vector2(58 * k, 40 * k), Color("#e2bd5f"))
		ellipse(ci, hc + Vector2(0, -40 * k), Vector2(60 * k, 10 * k), Color("#c0392b"))
		ellipse(ci, hc + Vector2(0, -32 * k), Vector2(120 * k, 24 * k), Color("#ecc96f"))
	else:
		ellipse(ci, hc + Vector2(-16 * k, -34 * k), Vector2(16 * k, 8 * k), skin.lightened(0.25))
	ci.draw_rect(Rect2(hc.x - 36 * k, hc.y - 14 * k, 26 * k, 8 * k), white)
	ci.draw_rect(Rect2(hc.x + 10 * k, hc.y - 14 * k, 26 * k, 8 * k), white)
	match mood:
		"happy", "eat", "tear":
			ci.draw_arc(hc + Vector2(-22 * k, 8 * k), 10 * k, PI + 0.3, TAU - 0.3, 10, DARK, 4 * k)
			ci.draw_arc(hc + Vector2(22 * k, 8 * k), 10 * k, PI + 0.3, TAU - 0.3, 10, DARK, 4 * k)
		_:
			ci.draw_circle(hc + Vector2(-22 * k, 6 * k), 6 * k, DARK)
			ci.draw_circle(hc + Vector2(22 * k, 6 * k), 6 * k, DARK)
	ci.draw_line(hc + Vector2(-40, 2) * k, hc + Vector2(-46, -4) * k, DARK, 2 * k)
	ci.draw_line(hc + Vector2(40, 2) * k, hc + Vector2(46, -4) * k, DARK, 2 * k)
	ellipse(ci, hc + Vector2(0, 46 * k), Vector2(38 * k, 26 * k), white)
	ellipse(ci, hc + Vector2(-16 * k, 26 * k), Vector2(20 * k, 8 * k), white)
	ellipse(ci, hc + Vector2(16 * k, 26 * k), Vector2(20 * k, 8 * k), white)
	if mood == "eat":
		ellipse(ci, hc + Vector2(0, 38 * k), Vector2(10 * k, (3 + absf(sin(t * 10)) * 7) * k), DARK)
	else:
		ci.draw_arc(hc + Vector2(0, 30 * k), 12 * k, 0.4, PI - 0.4, 10, DARK, 3 * k)
	if mood == "tear":
		var ph := fmod(t * 0.5, 1.0)
		ci.draw_circle(hc + Vector2(26 * k, (18 + ph * 30) * k), 5 * k, Color(0.4, 0.7, 1, 1 - ph))


static func ladybug(ci: CanvasItem, c: Vector2, r: float) -> void:
	var px := maxf(2.0, floorf(r / 6.0 / 2.0) * 2.0 + 2.0)
	var pal := {"k": Color("#2b1d10"), "r": Color("#e23b2e")}
	sprite(ci, c - Vector2(6, 5) * px, ICONS["ladybug"].slice(1, 11), pal, px)



## 家人（坐在餐桌後的半身）。hc = 頭的中心；mood: "normal" / "happy" / "eat"
## o 需要 skin、hair、shirt；可選 style（short / bun / spiky）、glasses、beard
static func person(ci: CanvasItem, hc: Vector2, k: float, o: Dictionary, mood: String, t: float) -> void:
	var skin := Color(o["skin"])
	var hair := Color(o["hair"])
	var shirt := Color(o["shirt"])
	var style: String = o.get("style", "short")
	ellipse(ci, hc + Vector2(0, 125 * k), Vector2(100 * k, 55 * k), shirt)
	ci.draw_rect(Rect2(hc.x - 100 * k, hc.y + 125 * k, 200 * k, 110 * k), shirt)
	if style == "bun":
		ci.draw_circle(hc + Vector2(0, -70 * k), 30 * k, hair)
	ci.draw_circle(hc, 64 * k, hair)
	ci.draw_circle(hc + Vector2(0, 8 * k), 58 * k, skin)
	match style:
		"spiky":
			for i in 5:
				var x := -48.0 + i * 24.0
				ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(x - 16, -36) * k, hc + Vector2(x + 16, -36) * k, hc + Vector2(x + 4, -84) * k]), hair)
			ellipse(ci, hc + Vector2(0, -36 * k), Vector2(60 * k, 22 * k), hair)
		_:
			ellipse(ci, hc + Vector2(0, -36 * k), Vector2(60 * k, 26 * k), hair)
	ci.draw_circle(hc + Vector2(-36 * k, 26 * k), 10 * k, Color(1, 0.45, 0.45, 0.35))
	ci.draw_circle(hc + Vector2(36 * k, 26 * k), 10 * k, Color(1, 0.45, 0.45, 0.35))
	match mood:
		"eat":
			ci.draw_arc(hc + Vector2(-22 * k, 10 * k), 10 * k, PI + 0.3, TAU - 0.3, 10, DARK, 4 * k)
			ci.draw_arc(hc + Vector2(22 * k, 10 * k), 10 * k, PI + 0.3, TAU - 0.3, 10, DARK, 4 * k)
			ellipse(ci, hc + Vector2(0, 34 * k), Vector2(13 * k, (4 + absf(sin(t * 10)) * 9) * k), DARK)
		"happy":
			ci.draw_arc(hc + Vector2(-22 * k, 10 * k), 10 * k, PI + 0.3, TAU - 0.3, 10, DARK, 4 * k)
			ci.draw_arc(hc + Vector2(22 * k, 10 * k), 10 * k, PI + 0.3, TAU - 0.3, 10, DARK, 4 * k)
			ci.draw_arc(hc + Vector2(0, 26 * k), 16 * k, 0.25, PI - 0.25, 12, DARK, 4 * k)
		_:
			ci.draw_circle(hc + Vector2(-22 * k, 6 * k), 6 * k, DARK)
			ci.draw_circle(hc + Vector2(22 * k, 6 * k), 6 * k, DARK)
			ci.draw_arc(hc + Vector2(0, 30 * k), 9 * k, 0.4, PI - 0.4, 10, DARK, 4 * k)
	if o.get("glasses", false):
		ci.draw_arc(hc + Vector2(-22 * k, 8 * k), 17 * k, 0, TAU, 20, DARK, 3 * k)
		ci.draw_arc(hc + Vector2(22 * k, 8 * k), 17 * k, 0, TAU, 20, DARK, 3 * k)
		ci.draw_line(hc + Vector2(-5 * k, 8 * k), hc + Vector2(5 * k, 8 * k), DARK, 3 * k)
	if o.get("beard", false):
		ellipse(ci, hc + Vector2(-14 * k, 24 * k), Vector2(17 * k, 7 * k), hair)
		ellipse(ci, hc + Vector2(14 * k, 24 * k), Vector2(17 * k, 7 * k), hair)
