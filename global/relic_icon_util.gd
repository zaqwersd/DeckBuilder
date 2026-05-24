class_name RelicIconUtil
extends RefCounted

## 基于不透明像素轮廓的外描边宽度（Chebyshev 距离）。
const OUTLINE_WIDTH := 2
const OUTLINE_ALPHA := 0.55
const ALPHA_THRESHOLD := 0.01

static var _cache: Dictionary = {}


static func get_colored_icon(source: Texture2D, rarity: Relic.Rarity) -> Texture2D:
	if source == null:
		return null
	var path := source.resource_path if source.resource_path else str(source.get_rid().get_id())
	var cache_key := "%s|%d|stroke2a%.2f" % [path, rarity, OUTLINE_ALPHA]
	if _cache.has(cache_key):
		return _cache[cache_key] as Texture2D

	var img := _extract_image(source)
	if img == null:
		return source

	var outline_color: Color = Relic.RARITY_COLORS.get(rarity, Color.WHITE)
	var stroked := _apply_outer_stroke(img, outline_color, OUTLINE_WIDTH)
	if stroked == null:
		_cache[cache_key] = source
		return source

	var tex := ImageTexture.create_from_image(stroked)
	_cache[cache_key] = tex
	return tex


static func _extract_image(source: Texture2D) -> Image:
	if source is AtlasTexture:
		var atlas_tex := source as AtlasTexture
		if atlas_tex.atlas == null:
			return null
		var atlas_img := atlas_tex.atlas.get_image()
		if atlas_img == null:
			return null
		atlas_img.decompress()
		var region := Rect2i(
			int(atlas_tex.region.position.x),
			int(atlas_tex.region.position.y),
			int(atlas_tex.region.size.x),
			int(atlas_tex.region.size.y)
		)
		return atlas_img.get_region(region)
	return source.get_image()


## 在不透明轮廓外侧绘制 width 像素描边；原不透明像素（含 #3e2723 棕边）保持不变。
static func _apply_outer_stroke(img: Image, outline_color: Color, width: int) -> Image:
	if img == null or img.get_width() < 1 or img.get_height() < 1:
		return null

	var work := img.duplicate() as Image
	work.decompress()
	if work.get_format() != Image.FORMAT_RGBA8:
		work.convert(Image.FORMAT_RGBA8)

	var src_w := work.get_width()
	var src_h := work.get_height()
	var pad_w := src_w + width * 2
	var pad_h := src_h + width * 2
	var padded := Image.create(pad_w, pad_h, false, Image.FORMAT_RGBA8)
	padded.fill(Color(0.0, 0.0, 0.0, 0.0))
	padded.blit_rect(work, Rect2i(0, 0, src_w, src_h), Vector2i(width, width))

	var opaque := PackedByteArray()
	opaque.resize(pad_w * pad_h)
	var has_opaque := false
	for y in range(pad_h):
		for x in range(pad_w):
			var is_op := padded.get_pixel(x, y).a >= ALPHA_THRESHOLD
			opaque[y * pad_w + x] = 1 if is_op else 0
			if is_op:
				has_opaque = true
	if not has_opaque:
		return null

	var stroke_color := outline_color
	stroke_color.a = OUTLINE_ALPHA
	var result := Image.create(pad_w, pad_h, false, Image.FORMAT_RGBA8)
	result.fill(Color(0.0, 0.0, 0.0, 0.0))

	for y in range(pad_h):
		for x in range(pad_w):
			var idx := y * pad_w + x
			if opaque[idx] == 1:
				result.set_pixel(x, y, padded.get_pixel(x, y))
				continue
			var dist := _min_chebyshev_to_opaque(opaque, pad_w, pad_h, x, y, width)
			if dist >= 1 and dist <= width:
				result.set_pixel(x, y, stroke_color)

	return result


static func _min_chebyshev_to_opaque(
	opaque: PackedByteArray,
	w: int,
	h: int,
	x: int,
	y: int,
	max_r: int
) -> int:
	var best := max_r + 1
	for dy in range(-max_r, max_r + 1):
		for dx in range(-max_r, max_r + 1):
			if dx == 0 and dy == 0:
				continue
			var dist := maxi(absi(dx), absi(dy))
			if dist > max_r:
				continue
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			if opaque[ny * w + nx] == 1:
				best = mini(best, dist)
	return best
