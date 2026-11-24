extends Control
## Интерфейс и мультитач-управление, всё рисуется в одном Control.
## Левая часть экрана — джойстик, правая — обзор, справа внизу — кнопки.

signal action_down(action_name: String)
signal action_up(action_name: String)

const JOY_R := 90.0

var mode := "loading"   # loading, title, cards, play, dead, winning
var move_vec := Vector2.ZERO
var look_accum := Vector2.ZERO
var health := 100.0
var salt := 0
var relics := 0
var emf := 0.0
var prompt := ""
var objective := ""
var subtitle := ""
var card_text := ""
var card_opaque := false
var hurt := 0.0
var fade := 0.0
var whiteout := 0.0
var burn := 0.0
var loading := 0.0

var _touch_ui := false
var _joy_idx := -1
var _joy_center := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_idx := -1
var _btn_down := {}


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _touch_ui = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func _buttons(sz: Vector2) -> Dictionary:
    return {
        "interact": {"pos": Vector2(sz.x - 120.0, sz.y - 120.0), "r": 66.0, "label": "ДЕЙСТВИЕ"},
        "poker": {"pos": Vector2(sz.x - 275.0, sz.y - 80.0), "r": 48.0, "label": "КОЧЕРГА"},
        "salt": {"pos": Vector2(sz.x - 255.0, sz.y - 215.0), "r": 48.0, "label": "СОЛЬ"},
        "flash": {"pos": Vector2(sz.x - 105.0, sz.y - 255.0), "r": 40.0, "label": "ФОНАРЬ"},
    }


func _input(event: InputEvent) -> void:
    if mode != "play":
        return
    if event is InputEventScreenTouch:
        var te: InputEventScreenTouch = event
        var sz := get_viewport_rect().size
        if te.pressed:
            var hit := ""
            var b := _buttons(sz)
            for k in b:
                var d: Dictionary = b[k]
                var bp: Vector2 = d["pos"]
                var br: float = d["r"]
                if te.position.distance_to(bp) <= br * 1.2:
                    hit = str(k)
                    break
            if hit != "":
                _btn_down[te.index] = hit
                action_down.emit(hit)
            elif te.position.x < sz.x * 0.45 and _joy_idx == -1:
                _joy_idx = te.index
                _joy_center = te.position
                _joy_pos = te.position
            elif _look_idx == -1:
                _look_idx = te.index
        else:
            if te.index == _joy_idx:
                _joy_idx = -1
                move_vec = Vector2.ZERO
            elif te.index == _look_idx:
                _look_idx = -1
            if _btn_down.has(te.index):
                var act: String = _btn_down[te.index]
                _btn_down.erase(te.index)
                action_up.emit(act)
    elif event is InputEventScreenDrag:
        var de: InputEventScreenDrag = event
        if de.index == _joy_idx:
            _joy_pos = de.position
            var v := (_joy_pos - _joy_center) / JOY_R
            if v.length() > 1.0:
                v = v.normalized()
            if v.length() < 0.12:
                v = Vector2.ZERO
            move_vec = Vector2(v.x, -v.y)
        elif de.index == _look_idx:
            look_accum += de.relative


func _process(delta: float) -> void:
    hurt = move_toward(hurt, 0.0, delta * 1.5)
    if mode != "play":
        _joy_idx = -1
        _look_idx = -1
        move_vec = Vector2.ZERO
        _btn_down.clear()
    queue_redraw()


# ------------------------------------------------------------------ рисование

func _text(font: Font, pos: Vector2, text: String, fsize: int, color: Color,
        align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
    draw_string_outline(font, pos, text, align, width, fsize, 6, Color(0, 0, 0, color.a * 0.9))
    draw_string(font, pos, text, align, width, fsize, color)


func _box_text(font: Font, sz: Vector2, text: String, fsize: int, y_base: float, color: Color) -> void:
    var w := sz.x * 0.72
    var x := (sz.x - w) * 0.5
    var tsz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, w, fsize)
    draw_rect(Rect2(x - 16.0, y_base - fsize - 4.0, w + 32.0, tsz.y + 20.0), Color(0, 0, 0, 0.55))
    draw_multiline_string(font, Vector2(x, y_base), text, HORIZONTAL_ALIGNMENT_CENTER, w, fsize, -1, color)


func _draw() -> void:
    var sz := get_viewport_rect().size
    var font: Font = get_theme_default_font()
    var full := Rect2(Vector2.ZERO, sz)
    var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 350.0)

    match mode:
        "loading":
            draw_rect(full, Color(0, 0, 0, 1))
            _text(font, Vector2(0, sz.y * 0.45), "Собираем дом Холлисов…", 32, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
            draw_rect(Rect2(sz.x * 0.3, sz.y * 0.52, sz.x * 0.4, 8.0), Color(0.15, 0.15, 0.18))
            draw_rect(Rect2(sz.x * 0.3, sz.y * 0.52, sz.x * 0.4 * loading, 8.0), Color(0.7, 0.1, 0.1))
        "title":
            draw_rect(full, Color(0, 0, 0, 0.55))
            _text(font, Vector2(0, sz.y * 0.38), "СОЛЬ И ЖЕЛЕЗО", 76, Color(0.9, 0.2, 0.18), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
            _text(font, Vector2(0, sz.y * 0.48), "Охота на сверхъестественное", 28, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
            _text(font, Vector2(0, sz.y * 0.75), "Коснитесь экрана, чтобы начать", 26, Color(1, 1, 1, pulse), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
        "cards":
            draw_rect(full, Color(0, 0, 0, 1.0 if card_opaque else 0.82))
            var w := sz.x * 0.74
            var tsz := font.get_multiline_string_size(card_text, HORIZONTAL_ALIGNMENT_CENTER, w, 30)
            draw_multiline_string(font, Vector2((sz.x - w) * 0.5, sz.y * 0.5 - tsz.y * 0.5 + 24.0), card_text, HORIZONTAL_ALIGNMENT_CENTER, w, 30, -1, Color(0.92, 0.92, 0.95))
            _text(font, Vector2(0, sz.y - 50.0), "Коснитесь, чтобы продолжить", 20, Color(1, 1, 1, pulse * 0.8), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
        _:
            _draw_play(sz, font, pulse)

    if whiteout > 0.0:
        draw_rect(full, Color(1, 1, 1, whiteout))
    if fade > 0.0:
        draw_rect(full, Color(0, 0, 0, fade))
    if mode == "dead":
        _text(font, Vector2(0, sz.y * 0.45), "ЭДИТ ДОБРАЛАСЬ ДО ТЕБЯ", 54, Color(0.85, 0.12, 0.1), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
        _text(font, Vector2(0, sz.y * 0.58), "Коснитесь экрана, чтобы подняться", 24, Color(1, 1, 1, pulse), HORIZONTAL_ALIGNMENT_CENTER, sz.x)


func _draw_play(sz: Vector2, font: Font, pulse: float) -> void:
    # здоровье
    draw_rect(Rect2(24, 24, 224, 18), Color(0, 0, 0, 0.55))
    draw_rect(Rect2(26, 26, 220.0 * clampf(health / 100.0, 0.0, 1.0), 14), Color(0.75, 0.1, 0.1))
    # EMF
    _text(font, Vector2(24, 76), "EMF", 18, Color(0.8, 0.85, 0.9))
    var lit := int(ceil(emf * 5.0))
    for i in 5:
        var c := Color(0.15, 0.15, 0.17, 0.7)
        if i < lit:
            c = Color(0.2 + 0.16 * i, 0.9 - 0.16 * i, 0.25, 0.95)
        draw_rect(Rect2(72.0 + i * 24.0, 56, 20, 26), c)
    # соль и реликвии
    _text(font, Vector2(0, 40), "Соль: %d     Реликвии: %d/3" % [salt, relics], 22, Color(0.92, 0.92, 0.95), HORIZONTAL_ALIGNMENT_RIGHT, sz.x - 24.0)
    if objective != "":
        _text(font, Vector2(24, 116), objective, 20, Color(0.95, 0.85, 0.5), HORIZONTAL_ALIGNMENT_LEFT, sz.x * 0.55)
    # прицел
    draw_circle(sz * 0.5, 2.5, Color(1, 1, 1, 0.6))
    # подсказка действия
    if prompt != "":
        _text(font, Vector2(0, sz.y * 0.64), prompt, 26, Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
    # прогресс сжигания
    if burn > 0.0:
        var bw := sz.x * 0.36
        draw_rect(Rect2((sz.x - bw) * 0.5, sz.y * 0.69, bw, 14), Color(0, 0, 0, 0.6))
        draw_rect(Rect2((sz.x - bw) * 0.5 + 2.0, sz.y * 0.69 + 2.0, (bw - 4.0) * burn, 10), Color(1.0, 0.55, 0.1))
    # субтитры / сюжет
    if subtitle != "":
        _box_text(font, sz, subtitle, 24, sz.y - 90.0 - 28.0 * floorf(subtitle.length() / 70.0), Color(1, 1, 1))
    # кровавая вспышка
    if hurt > 0.0:
        draw_rect(Rect2(Vector2.ZERO, sz), Color(0.7, 0, 0, hurt * 0.4))
    # сенсорное управление
    if _touch_ui and mode == "play":
        var jc := _joy_center if _joy_idx != -1 else Vector2(150.0, sz.y - 150.0)
        draw_arc(jc, JOY_R, 0.0, TAU, 40, Color(1, 1, 1, 0.28), 3.0)
        var knob := jc
        if _joy_idx != -1:
            knob = jc + (_joy_pos - jc).limit_length(JOY_R)
        draw_circle(knob, 34.0, Color(1, 1, 1, 0.22))
        var b := _buttons(sz)
        for k in b:
            var d: Dictionary = b[k]
            var bp: Vector2 = d["pos"]
            var br: float = d["r"]
            draw_circle(bp, br, Color(0.05, 0.05, 0.07, 0.45))
            draw_arc(bp, br, 0.0, TAU, 32, Color(1, 1, 1, 0.5), 2.5)
            draw_string(font, Vector2(bp.x - br, bp.y + 6.0), str(d["label"]), HORIZONTAL_ALIGNMENT_CENTER, br * 2.0, 15, Color(1, 1, 1, 0.9))
