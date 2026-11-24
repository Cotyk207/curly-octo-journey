extends Node3D
## Дом Холлисов. Карта строится из ASCII-схемы (1 символ = клетка 2x2 м).

const Mats = preload("res://scripts/mats.gd")

const CELL := 2.0
const WALL_H := 3.0
const WALL_T := 0.4

# Легенда:
# #  стена            .  пол              S  старт игрока
# a b c  реликвии     Z  останки          X  запертая дверь подвала
# L  лампа / свеча    s  банка соли
# B кровать  W шкаф  Y книжный шкаф  D бюро  H кроватка  T стол  C диван  K кухня
const MAP := [
    "########################",
    "#BB..WW#YYYYYY#HH....L.#",
    "#a....L#......#.......c#",
    "#.........Db...........#",
    "#......#..L...#........#",
    "#......#......#.......s#",
    "###.######.#######.#####",
    "#...L......L......L....#",
    "#.....................s#",
    "###.#######.#######.####",
    "#...L..#...L...#KKK....#",
    "#......#.......#.......#",
    "#......................#",
    "#..S...#.......#...T...#",
    "#......#.C..C.s#.......#",
    "###################X####",
    "############...........#",
    "############..Z.....L..#",
    "############.L.........#",
    "########################",
]

# [колонка, строка, сторона] — окна в наружных стенах
const WINDOWS := [
    [4, 0, "N"], [19, 0, "N"], [0, 3, "W"], [23, 3, "E"], [0, 7, "W"],
    [23, 8, "E"], [0, 12, "W"], [23, 12, "E"], [3, 15, "S"],
]

var cols := 0
var rows := 0
var start_pos := Vector3.ZERO
var remains_pos := Vector3.ZERO
var interactables: Array = []
var bounds_main := Rect2(Vector2(1.6, 1.6), Vector2(44.8, 28.4))
var bounds_cellar := Rect2(Vector2(24.0, 32.0), Vector2(22.0, 6.0))
var lamps: Array = []
var window_lights: Array = []
var window_mats: Array = []
var time := 0.0
var barricade: StaticBody3D

var m_wood: StandardMaterial3D
var m_wall: StandardMaterial3D
var m_stone: StandardMaterial3D
var m_ceil: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_bone: StandardMaterial3D
var m_cloth_a: StandardMaterial3D
var m_cloth_b: StandardMaterial3D
var m_cloth_c: StandardMaterial3D


func cell_center(c: int, r: int) -> Vector3:
    return Vector3((c + 0.5) * CELL, 0.0, (r + 0.5) * CELL)


func _ch(c: int, r: int) -> String:
    if r < 0 or r >= rows or c < 0 or c >= cols:
        return "#"
    return (MAP[r] as String)[c]


func _is_wall(c: int, r: int) -> bool:
    return _ch(c, r) == "#"


func _hpiece(c: int, r: int) -> bool:
    return _is_wall(c, r) and (_is_wall(c - 1, r) or _is_wall(c + 1, r))


func _vpiece(c: int, r: int) -> bool:
    return _is_wall(c, r) and (_is_wall(c, r - 1) or _is_wall(c, r + 1))


func build() -> void:
    rows = MAP.size()
    cols = (MAP[0] as String).length()
    m_wood = Mats.wood_floor()
    m_wall = Mats.wall()
    m_stone = Mats.stone()
    m_ceil = Mats.ceiling()
    m_dark = Mats.dark_wood()
    m_metal = Mats.metal()
    m_bone = Mats.bone()
    m_cloth_a = Mats.cloth(Color(0.32, 0.14, 0.12))
    m_cloth_b = Mats.cloth(Color(0.55, 0.52, 0.45))
    m_cloth_c = Mats.cloth(Color(0.14, 0.22, 0.18))

    _build_floor_and_ceiling()
    _build_walls()

    for r in rows:
        for c in cols:
            var ch := _ch(c, r)
            match ch:
                "S":
                    start_pos = cell_center(c, r) + Vector3(0, 0.05, 0)
                "a":
                    _add_relic("locket", "Медальон", c, r)
                "b":
                    _add_relic("photo", "Фотографию", c, r)
                "c":
                    _add_relic("box", "Музыкальную шкатулку", c, r)
                "Z":
                    _add_remains(c, r)
                "X":
                    _build_barricade(c, r)
                "L":
                    _add_lamp(c, r)
                "s":
                    _add_salt(c, r)
                "B":
                    _prop_bed(c, r)
                "W":
                    _prop_wardrobe(c, r)
                "Y":
                    _prop_shelf(c, r)
                "D":
                    _prop_desk(c, r)
                "H":
                    _prop_crib(c, r)
                "T":
                    _prop_table(c, r)
                "C":
                    _prop_couch(c, r)
                "K":
                    _prop_counter(c, r)

    for w in WINDOWS:
        _add_window(int(w[0]), int(w[1]), str(w[2]))


# ---------------------------------------------------------------- геометрия

func _build_floor_and_ceiling() -> void:
    var step := 3
    for cy in range(0, rows, step):
        for cx in range(0, cols, step):
            var w := mini(step, cols - cx)
            var h := mini(step, rows - cy)
            var cellar := cy >= 15
            var size := Vector3(w * CELL, 0.2, h * CELL)
            var cxm := (cx + w * 0.5) * CELL
            var czm := (cy + h * 0.5) * CELL
            var fl := MeshInstance3D.new()
            var fm := BoxMesh.new()
            fm.size = size
            fl.mesh = fm
            fl.material_override = m_stone if cellar else m_wood
            fl.position = Vector3(cxm, -0.1, czm)
            add_child(fl)
            var ce := MeshInstance3D.new()
            var cm := BoxMesh.new()
            cm.size = size
            ce.mesh = cm
            ce.material_override = m_stone if cellar else m_ceil
            ce.position = Vector3(cxm, WALL_H + 0.1, czm)
            ce.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(ce)

    var body := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = Vector3(cols * CELL + 4.0, 1.0, rows * CELL + 4.0)
    cs.shape = bs
    body.add_child(cs)
    body.position = Vector3(cols * CELL * 0.5, -0.5, rows * CELL * 0.5)
    add_child(body)


func _build_walls() -> void:
    # горизонтальные куски (не длиннее 3 клеток — ограничение числа огней на меш)
    for r in rows:
        var c := 0
        while c < cols:
            if _hpiece(c, r):
                var c0 := c
                var n := 0
                while c < cols and _hpiece(c, r) and n < 3:
                    c += 1
                    n += 1
                _add_wall(Vector3(n * CELL, WALL_H, WALL_T),
                    Vector3((c0 + n * 0.5) * CELL, WALL_H * 0.5, (r + 0.5) * CELL), r)
            else:
                c += 1
    # вертикальные куски
    for c in cols:
        var r := 0
        while r < rows:
            if _vpiece(c, r):
                var r0 := r
                var n := 0
                while r < rows and _vpiece(c, r) and n < 3:
                    r += 1
                    n += 1
                _add_wall(Vector3(WALL_T, WALL_H, n * CELL),
                    Vector3((c + 0.5) * CELL, WALL_H * 0.5, (r0 + n * 0.5) * CELL), r0)
            else:
                r += 1


func _add_wall(size: Vector3, pos: Vector3, row: int) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = size
    cs.shape = bs
    body.add_child(cs)
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = m_stone if row >= 16 else m_wall
    body.add_child(mi)
    add_child(body)


func _mesh_box(parent: Node, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    parent.add_child(mi)
    return mi


func _static_root(pos: Vector3, rot_y: float, col_size: Vector3, col_center: Vector3) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    body.rotation.y = rot_y
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = col_size
    cs.shape = bs
    cs.position = col_center
    body.add_child(cs)
    add_child(body)
    return body


# Смещение и поворот, чтобы мебель встала спиной к ближайшей стене.
func _snap_offset(c: int, r: int, depth: float) -> Vector3:
    var off := (CELL - WALL_T * 0.5 - 0.03) - depth * 0.5
    if _is_wall(c, r - 1):
        return Vector3(0, 0, -off)
    if _is_wall(c, r + 1):
        return Vector3(0, 0, off)
    if _is_wall(c - 1, r):
        return Vector3(-off, 0, 0)
    if _is_wall(c + 1, r):
        return Vector3(off, 0, 0)
    return Vector3.ZERO


func _snap_rot(c: int, r: int) -> float:
    if _is_wall(c, r - 1):
        return 0.0
    if _is_wall(c, r + 1):
        return PI
    if _is_wall(c - 1, r):
        return PI * 0.5
    if _is_wall(c + 1, r):
        return -PI * 0.5
    return 0.0


# ---------------------------------------------------------------- мебель

func _prop_bed(c: int, r: int) -> void:
    var pos := cell_center(c, r) + _snap_offset(c, r, 2.0)
    var b := _static_root(pos, _snap_rot(c, r), Vector3(1.7, 0.8, 2.0), Vector3(0, 0.4, 0))
    _mesh_box(b, Vector3(1.7, 0.4, 2.0), Vector3(0, 0.3, 0), m_dark)
    _mesh_box(b, Vector3(1.6, 0.18, 1.9), Vector3(0, 0.58, 0), m_cloth_a)
    _mesh_box(b, Vector3(1.7, 1.0, 0.1), Vector3(0, 0.7, -0.95), m_dark)
    _mesh_box(b, Vector3(0.9, 0.12, 0.4), Vector3(0, 0.73, -0.7), m_cloth_b)


func _prop_wardrobe(c: int, r: int) -> void:
    var pos := cell_center(c, r) + _snap_offset(c, r, 0.7)
    var b := _static_root(pos, _snap_rot(c, r), Vector3(1.6, 2.4, 0.7), Vector3(0, 1.2, 0))
    _mesh_box(b, Vector3(1.6, 2.4, 0.7), Vector3(0, 1.2, 0), m_dark)
    _mesh_box(b, Vector3(0.03, 2.2, 0.03), Vector3(0, 1.2, 0.36), m_metal)
    _mesh_box(b, Vector3(0.05, 0.2, 0.05), Vector3(-0.12, 1.2, 0.38), m_metal)
    _mesh_box(b, Vector3(0.05, 0.2, 0.05), Vector3(0.12, 1.2, 0.38), m_metal)


func _prop_shelf(c: int, r: int) -> void:
    var pos := cell_center(c, r) + _snap_offset(c, r, 0.4)
    var b := _static_root(pos, _snap_rot(c, r), Vector3(1.8, 2.2, 0.4), Vector3(0, 1.1, 0))
    _mesh_box(b, Vector3(1.8, 2.2, 0.4), Vector3(0, 1.1, -0.02), m_dark)
    for i in 4:
        _mesh_box(b, Vector3(1.7, 0.04, 0.38), Vector3(0, 0.35 + i * 0.5, 0.02), m_dark)
    for i in 3:
        var col := Color(randf_range(0.08, 0.3), randf_range(0.04, 0.15), randf_range(0.03, 0.12))
        _mesh_box(b, Vector3(1.55, 0.36, 0.28), Vector3(0, 0.55 + i * 0.5, 0.05), Mats.plain(col, 0.9))


func _prop_desk(c: int, r: int) -> void:
    var pos := cell_center(c, r)
    var b := _static_root(pos, 0.0, Vector3(1.6, 0.8, 0.8), Vector3(0, 0.4, 0))
    _mesh_box(b, Vector3(1.6, 0.06, 0.8), Vector3(0, 0.77, 0), m_dark)
    for sx in [-0.72, 0.72]:
        for sz in [-0.34, 0.34]:
            _mesh_box(b, Vector3(0.07, 0.75, 0.07), Vector3(sx, 0.38, sz), m_dark)
    _mesh_box(b, Vector3(0.4, 0.02, 0.3), Vector3(-0.3, 0.81, 0.0), m_cloth_b)


func _prop_crib(c: int, r: int) -> void:
    var pos := cell_center(c, r) + _snap_offset(c, r, 1.5)
    var b := _static_root(pos, _snap_rot(c, r), Vector3(1.0, 0.9, 1.5), Vector3(0, 0.45, 0))
    _mesh_box(b, Vector3(0.95, 0.08, 1.45), Vector3(0, 0.35, 0), m_dark)
    _mesh_box(b, Vector3(0.85, 0.1, 1.35), Vector3(0, 0.43, 0), m_cloth_b)
    for sx in [-0.46, 0.46]:
        for i in 7:
            _mesh_box(b, Vector3(0.025, 0.5, 0.025), Vector3(sx, 0.6, -0.65 + i * 0.22), m_dark)
        _mesh_box(b, Vector3(0.04, 0.04, 1.45), Vector3(sx, 0.86, 0), m_dark)
    _mesh_box(b, Vector3(0.95, 0.6, 0.05), Vector3(0, 0.65, -0.72), m_dark)
    _mesh_box(b, Vector3(0.95, 0.4, 0.05), Vector3(0, 0.55, 0.72), m_dark)


func _prop_table(c: int, r: int) -> void:
    var pos := cell_center(c, r)
    var b := _static_root(pos, 0.0, Vector3(1.4, 0.8, 1.0), Vector3(0, 0.4, 0))
    _mesh_box(b, Vector3(1.4, 0.06, 1.0), Vector3(0, 0.77, 0), m_dark)
    for sx in [-0.62, 0.62]:
        for sz in [-0.42, 0.42]:
            _mesh_box(b, Vector3(0.07, 0.75, 0.07), Vector3(sx, 0.38, sz), m_dark)
    _mesh_box(b, Vector3(0.5, 0.01, 0.5), Vector3(0.1, 0.805, 0), m_cloth_b)


func _prop_couch(c: int, r: int) -> void:
    var pos := cell_center(c, r) + _snap_offset(c, r, 0.9)
    var b := _static_root(pos, _snap_rot(c, r), Vector3(1.9, 0.9, 0.9), Vector3(0, 0.45, 0))
    _mesh_box(b, Vector3(1.9, 0.4, 0.9), Vector3(0, 0.25, 0), m_cloth_c)
    _mesh_box(b, Vector3(1.9, 0.55, 0.25), Vector3(0, 0.7, -0.33), m_cloth_c)
    _mesh_box(b, Vector3(0.2, 0.3, 0.9), Vector3(-0.85, 0.55, 0), m_cloth_c)
    _mesh_box(b, Vector3(0.2, 0.3, 0.9), Vector3(0.85, 0.55, 0), m_cloth_c)


func _prop_counter(c: int, r: int) -> void:
    var pos := cell_center(c, r) + _snap_offset(c, r, 0.6)
    var b := _static_root(pos, _snap_rot(c, r), Vector3(1.9, 0.95, 0.6), Vector3(0, 0.475, 0))
    _mesh_box(b, Vector3(1.9, 0.9, 0.6), Vector3(0, 0.45, 0), m_dark)
    _mesh_box(b, Vector3(1.95, 0.05, 0.65), Vector3(0, 0.93, 0), m_stone)
    _mesh_box(b, Vector3(0.5, 0.02, 0.35), Vector3(0.3, 0.96, 0), m_metal)


# ---------------------------------------------------------------- предметы

func _add_relic(id: String, display: String, c: int, r: int) -> void:
    var p := cell_center(c, r)
    var stand := _static_root(p, 0.0, Vector3(0.6, 0.7, 0.6), Vector3(0, 0.35, 0))
    _mesh_box(stand, Vector3(0.6, 0.7, 0.6), Vector3(0, 0.35, 0), m_dark)

    var node := Node3D.new()
    node.position = Vector3(p.x, 0.8, p.z)
    add_child(node)
    match id:
        "locket":
            var mi := MeshInstance3D.new()
            var cm := CylinderMesh.new()
            cm.top_radius = 0.05
            cm.bottom_radius = 0.05
            cm.height = 0.012
            mi.mesh = cm
            mi.material_override = Mats.emissive(Color(0.9, 0.7, 0.3), 0.6)
            node.add_child(mi)
            var ch := MeshInstance3D.new()
            var tm := TorusMesh.new()
            tm.inner_radius = 0.07
            tm.outer_radius = 0.075
            ch.mesh = tm
            ch.material_override = Mats.emissive(Color(0.9, 0.7, 0.3), 0.4)
            ch.position = Vector3(0, 0.0, 0.0)
            node.add_child(ch)
        "photo":
            var mi2 := _mesh_box(node, Vector3(0.2, 0.006, 0.14), Vector3.ZERO, Mats.plain(Color(0.85, 0.82, 0.7), 0.9))
            mi2.rotation.y = 0.3
        "box":
            _mesh_box(node, Vector3(0.24, 0.12, 0.17), Vector3(0, 0.0, 0), m_dark)
            _mesh_box(node, Vector3(0.25, 0.03, 0.18), Vector3(0, 0.075, 0), Mats.emissive(Color(0.6, 0.45, 0.2), 0.4))

    var light := OmniLight3D.new()
    light.light_color = Color(0.5, 0.8, 1.0)
    light.light_energy = 0.7
    light.omni_range = 3.2
    light.position = Vector3(0, 0.2, 0)
    node.add_child(light)

    interactables.append({
        "id": id, "kind": "relic", "name": display,
        "pos": node.position, "node": node, "taken": false,
    })


func _add_salt(c: int, r: int) -> void:
    var p := cell_center(c, r)
    var node := Node3D.new()
    node.position = Vector3(p.x, 0.16, p.z)
    add_child(node)
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.09
    cm.bottom_radius = 0.1
    cm.height = 0.3
    mi.mesh = cm
    mi.material_override = Mats.plain(Color(0.85, 0.87, 0.92), 0.6)
    node.add_child(mi)
    var band := MeshInstance3D.new()
    var bm := CylinderMesh.new()
    bm.top_radius = 0.101
    bm.bottom_radius = 0.101
    bm.height = 0.1
    band.mesh = bm
    band.material_override = Mats.plain(Color(0.7, 0.1, 0.1), 0.7)
    node.add_child(band)
    var light := OmniLight3D.new()
    light.light_color = Color(0.8, 0.9, 1.0)
    light.light_energy = 0.35
    light.omni_range = 1.8
    light.position = Vector3(0, 0.3, 0)
    node.add_child(light)
    interactables.append({
        "id": "salt", "kind": "salt", "name": "Соль",
        "pos": node.position + Vector3(0, 0.3, 0), "node": node, "taken": false,
    })


func _add_remains(c: int, r: int) -> void:
    var p := cell_center(c, r)
    remains_pos = Vector3(p.x, 0.0, p.z)
    var slab := _static_root(p, 0.0, Vector3(1.6, 0.35, 0.9), Vector3(0, 0.175, 0))
    _mesh_box(slab, Vector3(1.6, 0.35, 0.9), Vector3(0, 0.175, 0), m_stone)
    _mesh_box(slab, Vector3(1.2, 0.08, 0.6), Vector3(0.1, 0.39, 0), Mats.cloth(Color(0.12, 0.1, 0.08)))
    # кости
    for i in 7:
        var mi := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.022
        cm.bottom_radius = 0.022
        cm.height = randf_range(0.3, 0.5)
        mi.mesh = cm
        mi.material_override = m_bone
        mi.position = Vector3(randf_range(-0.2, 0.55), 0.46, randf_range(-0.2, 0.2))
        mi.rotation = Vector3(randf_range(1.2, 1.9), randf_range(0.0, 3.0), randf_range(1.2, 1.9))
        slab.add_child(mi)
    var skull := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.11
    sm.height = 0.22
    skull.mesh = sm
    skull.material_override = m_bone
    skull.position = Vector3(-0.5, 0.52, 0.0)
    slab.add_child(skull)
    for sx in [-0.04, 0.04]:
        var eye := MeshInstance3D.new()
        var em := SphereMesh.new()
        em.radius = 0.025
        em.height = 0.05
        eye.mesh = em
        eye.material_override = Mats.plain(Color(0.0, 0.0, 0.0), 1.0)
        eye.position = Vector3(-0.5 - 0.09, 0.54, sx)
        slab.add_child(eye)
    var glow := OmniLight3D.new()
    glow.light_color = Color(0.6, 0.7, 1.0)
    glow.light_energy = 0.5
    glow.omni_range = 4.0
    glow.position = Vector3(p.x, 0.8, p.z)
    add_child(glow)
    interactables.append({
        "id": "remains", "kind": "remains", "name": "Останки",
        "pos": Vector3(p.x, 0.5, p.z), "node": slab, "taken": false,
    })


func _build_barricade(c: int, r: int) -> void:
    var p := cell_center(c, r)
    barricade = StaticBody3D.new()
    barricade.position = Vector3(p.x, 0.0, p.z)
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = Vector3(CELL, WALL_H, 0.3)
    cs.shape = bs
    cs.position = Vector3(0, WALL_H * 0.5, 0)
    barricade.add_child(cs)
    for i in 5:
        var plank := _mesh_box(barricade, Vector3(CELL * 0.96, 0.22, 0.1), Vector3(0, 0.4 + i * 0.55, 0), m_dark)
        plank.rotation.z = randf_range(-0.05, 0.05)
    for sgn in [-1.0, 1.0]:
        var ch := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.03
        cm.bottom_radius = 0.03
        cm.height = 3.2
        ch.mesh = cm
        ch.material_override = m_metal
        ch.position = Vector3(0, 1.5, 0.08)
        ch.rotation.z = deg_to_rad(32.0) * sgn
        barricade.add_child(ch)
    _mesh_box(barricade, Vector3(0.22, 0.28, 0.1), Vector3(0, 1.45, 0.12), m_metal)
    add_child(barricade)


func unlock_cellar() -> void:
    if barricade == null:
        return
    var tw := create_tween()
    tw.tween_property(barricade, "position:y", -3.6, 1.4)
    tw.tween_callback(barricade.queue_free)
    barricade = null


func take_item(it: Dictionary) -> void:
    it["taken"] = true
    var n := it["node"] as Node
    if n != null:
        n.queue_free()


# ---------------------------------------------------------------- свет

func _add_lamp(c: int, r: int) -> void:
    var p := cell_center(c, r)
    var light := OmniLight3D.new()
    var bulb := MeshInstance3D.new()
    var sm := SphereMesh.new()
    var d := {}
    if r >= 16:
        # свеча в подвале
        var cyl := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.04
        cm.bottom_radius = 0.045
        cm.height = 0.25
        cyl.mesh = cm
        cyl.material_override = Mats.plain(Color(0.8, 0.75, 0.6), 0.8)
        cyl.position = Vector3(p.x, 0.125, p.z)
        add_child(cyl)
        sm.radius = 0.03
        sm.height = 0.08
        bulb.position = Vector3(p.x, 0.29, p.z)
        light.position = Vector3(p.x, 0.5, p.z)
        light.light_color = Color(1.0, 0.55, 0.2)
        light.light_energy = 1.5
        light.omni_range = 6.0
        d["candle"] = true
        d["mat"] = Mats.emissive(Color(1.0, 0.6, 0.2), 4.0)
    else:
        # лампочка под потолком
        var wire := MeshInstance3D.new()
        var wm := CylinderMesh.new()
        wm.top_radius = 0.01
        wm.bottom_radius = 0.01
        wm.height = 0.4
        wire.mesh = wm
        wire.material_override = m_metal
        wire.position = Vector3(p.x, WALL_H - 0.2, p.z)
        add_child(wire)
        sm.radius = 0.09
        sm.height = 0.18
        bulb.position = Vector3(p.x, WALL_H - 0.5, p.z)
        light.position = Vector3(p.x, WALL_H - 0.55, p.z)
        light.light_color = Color(1.0, 0.8, 0.55)
        light.light_energy = 1.3
        light.omni_range = 7.0
        d["candle"] = false
        d["mat"] = Mats.emissive(Color(1.0, 0.85, 0.55), 3.0)
    light.omni_attenuation = 1.3
    bulb.mesh = sm
    bulb.material_override = d["mat"]
    bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(bulb)
    add_child(light)
    d["light"] = light
    d["base"] = light.light_energy
    d["phase"] = randf() * TAU
    lamps.append(d)


func _add_window(c: int, r: int, side: String) -> void:
    var normal := Vector3(0, 0, 1)
    match side:
        "N":
            normal = Vector3(0, 0, 1)
        "S":
            normal = Vector3(0, 0, -1)
        "W":
            normal = Vector3(1, 0, 0)
        "E":
            normal = Vector3(-1, 0, 0)
    var center := cell_center(c, r)
    var holder := Node3D.new()
    holder.position = Vector3(center.x, 1.7, center.z) + normal * (WALL_T * 0.5 + 0.01)
    holder.rotation.y = atan2(normal.x, normal.z)
    add_child(holder)

    var glass := MeshInstance3D.new()
    var qm := QuadMesh.new()
    qm.size = Vector2(1.2, 1.6)
    glass.mesh = qm
    var gm := Mats.emissive(Color(0.25, 0.38, 0.65), 0.5)
    glass.material_override = gm
    holder.add_child(glass)
    window_mats.append(gm)

    var fm := m_dark
    _mesh_box(holder, Vector3(1.4, 0.08, 0.08), Vector3(0, 0.84, 0.03), fm)
    _mesh_box(holder, Vector3(1.4, 0.08, 0.08), Vector3(0, -0.84, 0.03), fm)
    _mesh_box(holder, Vector3(0.08, 1.76, 0.08), Vector3(-0.64, 0, 0.03), fm)
    _mesh_box(holder, Vector3(0.08, 1.76, 0.08), Vector3(0.64, 0, 0.03), fm)
    _mesh_box(holder, Vector3(1.2, 0.04, 0.04), Vector3(0, 0, 0.03), fm)
    _mesh_box(holder, Vector3(0.04, 1.6, 0.04), Vector3(0, 0, 0.03), fm)

    var spot := SpotLight3D.new()
    spot.position = Vector3(0, 0.3, 0.15)
    spot.basis = Basis.looking_at(Vector3(0, -0.25, 1.0).normalized(), Vector3.UP)
    spot.spot_range = 9.0
    spot.spot_angle = 40.0
    spot.spot_attenuation = 0.7
    spot.light_color = Color(0.55, 0.7, 1.0)
    spot.light_energy = 1.4
    holder.add_child(spot)
    window_lights.append({"light": spot, "base": 1.4})


func update_lamps(delta: float, flicker: float, lightning: float) -> void:
    time += delta
    for d in lamps:
        var light: OmniLight3D = d["light"]
        var base: float = d["base"]
        var ph: float = d["phase"]
        var e := base * (0.93 + 0.07 * sin(time * 9.0 + ph))
        if d["candle"]:
            e = base * (0.8 + 0.2 * sin(time * 13.0 + ph) * sin(time * 7.3 + ph * 2.0))
        if flicker > 0.01:
            if randf() < flicker * 0.22:
                e *= randf_range(0.0, 0.35)
            e *= 1.0 - flicker * 0.3
        light.light_energy = e
        var mat: StandardMaterial3D = d["mat"]
        mat.emission_energy_multiplier = 3.0 * e / maxf(base, 0.01)
    var flash := lightning * (0.6 + 0.4 * sin(time * 45.0))
    for w in window_lights:
        var sp: SpotLight3D = w["light"]
        sp.light_energy = float(w["base"]) * (1.0 + flash * 7.0)
    for wm in window_mats:
        var gm: StandardMaterial3D = wm
        gm.emission_energy_multiplier = 0.5 + flash * 5.0
    for it in interactables:
        if it["taken"] or it["kind"] != "relic":
            continue
        var n := it["node"] as Node3D
        if n != null:
            n.rotate_y(delta * 0.9)
            n.position.y = 0.8 + sin(time * 2.0) * 0.02
