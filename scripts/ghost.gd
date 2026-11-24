extends Node3D
## Эдит Холлис. Призрак проходит сквозь стены; соль и железо — единственная защита.
## Модель собрана из примитивов. Её можно заменить любой .glb-моделью (см. README).

signal manifested
signal hit_player
signal stunned

const ST_DORMANT := 0
const ST_FADED := 1      # невидима, бродит рядом, пугает
const ST_MANIFEST := 2   # проявилась и охотится
const ST_STUNNED := 3    # оглушена железом или солью

var state := ST_DORMANT
var target: Node3D
var aggression := 0      # 0..3, растёт с каждой реликвией
var enraged := false     # финал: охотится без пауз
var bounds_main := Rect2()
var bounds_cellar := Rect2()

var _timer := 0.0
var _attack_cd := 0.0
var _alpha := 0.0
var _target_alpha := 0.0
var _t := 0.0

var _mat: StandardMaterial3D
var _hair_mat: StandardMaterial3D
var _body: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _light: OmniLight3D


func _ready() -> void:
    _mat = StandardMaterial3D.new()
    _mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mat.albedo_color = Color(0.84, 0.89, 0.96, 0.0)
    _mat.emission_enabled = true
    _mat.emission = Color(0.45, 0.6, 0.9)
    _mat.emission_energy_multiplier = 0.4
    _mat.roughness = 0.9
    _mat.cull_mode = BaseMaterial3D.CULL_DISABLED

    _hair_mat = StandardMaterial3D.new()
    _hair_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _hair_mat.albedo_color = Color(0.02, 0.02, 0.03, 0.0)
    _hair_mat.roughness = 1.0

    _body = Node3D.new()
    add_child(_body)

    # платье
    var dress := CylinderMesh.new()
    dress.top_radius = 0.17
    dress.bottom_radius = 0.5
    dress.height = 1.2
    dress.radial_segments = 16
    dress.rings = 1
    _part(dress, Vector3(0, 0.75, 0), _mat, _body)
    # торс
    var torso := CylinderMesh.new()
    torso.top_radius = 0.14
    torso.bottom_radius = 0.17
    torso.height = 0.5
    _part(torso, Vector3(0, 1.5, 0), _mat, _body)
    # голова
    var head := SphereMesh.new()
    head.radius = 0.12
    head.height = 0.25
    _part(head, Vector3(0, 1.86, 0), _mat, _body)
    # волосы (сзади и сверху) и пряди на лицо
    var hair := SphereMesh.new()
    hair.radius = 0.14
    hair.height = 0.3
    _part(hair, Vector3(0, 1.89, 0.04), _hair_mat, _body)
    var hair_long := CapsuleMesh.new()
    hair_long.radius = 0.11
    hair_long.height = 0.95
    _part(hair_long, Vector3(0, 1.45, 0.1), _hair_mat, _body)
    var strand := CapsuleMesh.new()
    strand.radius = 0.02
    strand.height = 0.55
    _part(strand, Vector3(0.04, 1.8, -0.115), _hair_mat, _body)
    _part(strand, Vector3(-0.05, 1.75, -0.11), _hair_mat, _body)
    # чёрные глаза
    var eye := SphereMesh.new()
    eye.radius = 0.022
    eye.height = 0.044
    _part(eye, Vector3(0.045, 1.87, -0.105), _hair_mat, _body)
    _part(eye, Vector3(-0.045, 1.87, -0.105), _hair_mat, _body)

    # руки, вытянутые вперёд
    _arm_l = Node3D.new()
    _arm_l.position = Vector3(-0.2, 1.62, 0)
    _body.add_child(_arm_l)
    _arm_r = Node3D.new()
    _arm_r.position = Vector3(0.2, 1.62, 0)
    _body.add_child(_arm_r)
    var arm := CylinderMesh.new()
    arm.top_radius = 0.03
    arm.bottom_radius = 0.022
    arm.height = 0.9
    _part(arm, Vector3(0, -0.45, 0), _mat, _arm_l)
    _part(arm, Vector3(0, -0.45, 0), _mat, _arm_r)

    _light = OmniLight3D.new()
    _light.light_color = Color(0.5, 0.65, 1.0)
    _light.light_energy = 0.0
    _light.omni_range = 5.0
    _light.position = Vector3(0, 1.2, 0)
    add_child(_light)
    visible = false


func _part(mesh: Mesh, pos: Vector3, m: Material, parent: Node3D) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = m
    mi.position = pos
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi


# ------------------------------------------------------------------ управление

func start(delay: float) -> void:
    state = ST_FADED
    _timer = delay
    _alpha = 0.0
    _target_alpha = 0.0
    var tp := target.global_position
    global_position = _clamp_to_zone(Vector3(tp.x + 12.0, 0.0, tp.z + 4.0))
    visible = false


func dissolve() -> void:
    state = ST_DORMANT
    visible = false


func provoke(delay: float) -> void:
    # реликвию забрали — Эдит скоро проявится
    if state == ST_FADED:
        _timer = minf(_timer, delay)


func manifest() -> void:
    state = ST_MANIFEST
    _timer = 9.0 + aggression * 3.0
    if enraged:
        _timer = 9999.0
    var tp := target.global_position
    var here := Vector3(tp.x, 0.0, tp.z)
    var spot := _clamp_to_zone(Vector3(tp.x + 9.0, 0.0, tp.z))
    for i in 10:
        var a := randf() * TAU
        var dd := randf_range(7.0, 11.0)
        var cand := _clamp_to_zone(Vector3(tp.x + cos(a) * dd, 0.0, tp.z + sin(a) * dd))
        if cand.distance_to(here) > 4.5:
            spot = cand
            break
    global_position = spot
    manifested.emit()


func fade_out() -> void:
    state = ST_FADED
    _timer = _faded_time()


func stun(duration: float, from: Vector3) -> void:
    if state == ST_DORMANT:
        return
    state = ST_STUNNED
    _timer = duration
    var away := global_position - from
    away.y = 0.0
    if away.length() < 0.1:
        away = Vector3(1, 0, 0)
    global_position = _clamp_to_zone(global_position + away.normalized() * 3.0)
    stunned.emit()


func _faded_time() -> float:
    if enraged:
        return 2.5
    return maxf(5.0, 16.0 - aggression * 3.5) + randf_range(0.0, 5.0)


func _speed() -> float:
    if enraged:
        return 4.2
    return 2.3 + aggression * 0.45


func _clamp_to_zone(p: Vector3) -> Vector3:
    var tp := target.global_position
    var b := bounds_cellar if tp.z > 31.0 else bounds_main
    return Vector3(
        clampf(p.x, b.position.x, b.position.x + b.size.x),
        0.0,
        clampf(p.z, b.position.y, b.position.y + b.size.y))


# ------------------------------------------------------------------ каждый кадр

func _process(delta: float) -> void:
    _t += delta
    if state == ST_DORMANT or target == null:
        visible = false
        return

    _attack_cd = maxf(0.0, _attack_cd - delta)
    var tp := target.global_position
    var to_p := Vector3(tp.x - global_position.x, 0.0, tp.z - global_position.z)
    var dist := to_p.length()
    var dir := Vector3.ZERO
    if dist > 0.01:
        dir = to_p / dist

    # призрак остаётся в той же «зоне» (дом / подвал), что и игрок
    global_position = _clamp_to_zone(global_position)

    match state:
        ST_FADED:
            _target_alpha = 0.0
            _timer -= delta
            if dist > 7.0:
                global_position += dir * _speed() * 0.6 * delta
            if _timer <= 0.0:
                manifest()
        ST_MANIFEST:
            _target_alpha = 0.62
            global_position += dir * _speed() * delta
            if dist < 1.3 and _attack_cd <= 0.0:
                _attack_cd = 1.6
                hit_player.emit()
            _timer -= delta
            if _timer <= 0.0 and not enraged:
                fade_out()
        ST_STUNNED:
            _target_alpha = 0.25 + 0.25 * sin(_t * 30.0)
            _timer -= delta
            if _timer <= 0.0:
                state = ST_FADED
                _timer = _faded_time()

    if dist > 0.01:
        rotation.y = atan2(-dir.x, -dir.z)

    _alpha = move_toward(_alpha, _target_alpha, delta * 2.5)
    visible = _alpha > 0.02

    var flick := 1.0
    if state == ST_MANIFEST and randf() < 0.08:
        flick = randf_range(0.3, 1.0)
    var c := _mat.albedo_color
    c.a = _alpha * flick
    _mat.albedo_color = c
    var hc := _hair_mat.albedo_color
    hc.a = _alpha * flick
    _hair_mat.albedo_color = hc
    _mat.emission_energy_multiplier = 0.2 + _alpha
    _light.light_energy = _alpha * 1.4

    _body.position.y = 0.25 + sin(_t * 1.8) * 0.08
    _body.rotation.z = sin(_t * 1.1) * 0.05
    _arm_l.rotation.x = 1.1 + sin(_t * 2.0) * 0.2
    _arm_r.rotation.x = 1.1 + sin(_t * 2.0 + 1.0) * 0.2
