extends CharacterBody3D
## Нейт Колдер, вид от первого лица: капсула, камера, фонарь, железная кочерга.

signal footstep

var yaw := 0.0
var pitch := 0.0
var enabled := false
var move_input := Vector2.ZERO   # x — вправо, y — вперёд (длина 0..1)
var shake := 0.0
var flash_flicker := 0.0
var flash_on := true

var head: Node3D
var cam: Camera3D
var flash: SpotLight3D
var flash_lens: MeshInstance3D
var poker: Node3D

var _bob := 0.0
var _step := 0.0


func _ready() -> void:
    var cs := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.35
    cap.height = 1.7
    cs.shape = cap
    cs.position = Vector3(0, 0.85, 0)
    add_child(cs)

    head = Node3D.new()
    head.position = Vector3(0, 1.55, 0)
    add_child(head)

    cam = Camera3D.new()
    cam.fov = 75.0
    cam.near = 0.05
    cam.far = 90.0
    head.add_child(cam)
    cam.make_current()

    flash = SpotLight3D.new()
    flash.position = Vector3(0.2, -0.15, -0.3)
    flash.spot_range = 16.0
    flash.spot_angle = 30.0
    flash.spot_attenuation = 0.8
    flash.light_energy = 4.0
    flash.light_color = Color(1.0, 0.93, 0.78)
    flash.shadow_enabled = true
    cam.add_child(flash)

    # модель фонарика
    var body := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.035
    cm.bottom_radius = 0.03
    cm.height = 0.24
    body.mesh = cm
    var bm := StandardMaterial3D.new()
    bm.albedo_color = Color(0.08, 0.08, 0.09)
    bm.metallic = 0.8
    bm.roughness = 0.4
    body.material_override = bm
    body.rotation.x = deg_to_rad(90.0)
    body.position = Vector3(0.2, -0.2, -0.38)
    body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    cam.add_child(body)

    flash_lens = MeshInstance3D.new()
    var lm := CylinderMesh.new()
    lm.top_radius = 0.045
    lm.bottom_radius = 0.035
    lm.height = 0.02
    flash_lens.mesh = lm
    var em := StandardMaterial3D.new()
    em.albedo_color = Color(1.0, 0.95, 0.8)
    em.emission_enabled = true
    em.emission = Color(1.0, 0.95, 0.8)
    em.emission_energy_multiplier = 2.0
    flash_lens.material_override = em
    flash_lens.rotation.x = deg_to_rad(90.0)
    flash_lens.position = Vector3(0.2, -0.2, -0.505)
    flash_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    cam.add_child(flash_lens)

    # кочерга
    poker = Node3D.new()
    poker.visible = false
    cam.add_child(poker)
    var rod := MeshInstance3D.new()
    var rm := CylinderMesh.new()
    rm.top_radius = 0.012
    rm.bottom_radius = 0.016
    rm.height = 0.95
    rod.mesh = rm
    var im := StandardMaterial3D.new()
    im.albedo_color = Color(0.12, 0.12, 0.13)
    im.metallic = 1.0
    im.roughness = 0.35
    rod.material_override = im
    rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    poker.add_child(rod)
    var hook := MeshInstance3D.new()
    var hm := BoxMesh.new()
    hm.size = Vector3(0.07, 0.025, 0.025)
    hook.mesh = hm
    hook.material_override = im
    hook.position = Vector3(0.03, 0.47, 0)
    poker.add_child(hook)


func apply_look(d: Vector2) -> void:
    yaw -= d.x
    pitch = clampf(pitch - d.y, -1.45, 1.45)
    rotation.y = yaw
    head.rotation.x = pitch


func set_look(y: float, p: float) -> void:
    yaw = y
    pitch = p
    rotation.y = yaw
    head.rotation.x = pitch


func toggle_flash() -> void:
    flash_on = not flash_on
    flash.visible = flash_on
    flash_lens.visible = flash_on


func swing() -> void:
    poker.visible = true
    poker.position = Vector3(0.38, -0.3, -0.5)
    poker.rotation = Vector3(deg_to_rad(-15.0), deg_to_rad(30.0), deg_to_rad(-25.0))
    var tw := create_tween()
    tw.tween_property(poker, "rotation", Vector3(deg_to_rad(-75.0), deg_to_rad(-25.0), deg_to_rad(15.0)), 0.12)
    tw.parallel().tween_property(poker, "position", Vector3(-0.1, -0.25, -0.9), 0.12)
    tw.tween_interval(0.1)
    tw.tween_callback(_hide_poker)


func _hide_poker() -> void:
    poker.visible = false


func _physics_process(delta: float) -> void:
    var wish := Vector3.ZERO
    var spd := 0.0
    if enabled:
        var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
        var right := Vector3(cos(yaw), 0.0, -sin(yaw))
        wish = fwd * move_input.y + right * move_input.x
        if wish.length() > 1.0:
            wish = wish.normalized()
        spd = 4.2
    var tv := wish * spd
    velocity.x = move_toward(velocity.x, tv.x, 28.0 * delta)
    velocity.z = move_toward(velocity.z, tv.z, 28.0 * delta)
    if is_on_floor():
        velocity.y = -1.0
    else:
        velocity.y -= 18.0 * delta
    move_and_slide()

    var hs := Vector2(velocity.x, velocity.z).length()
    if hs > 0.4:
        _bob += delta * hs * 2.4
        _step += hs * delta
        if _step > 1.9:
            _step = 0.0
            footstep.emit()


func _process(delta: float) -> void:
    var hs := Vector2(velocity.x, velocity.z).length()
    var bob_y := 0.0
    var bob_x := 0.0
    if hs > 0.4:
        bob_y = sin(_bob * 2.0) * 0.035
        bob_x = cos(_bob) * 0.02
    shake = maxf(0.0, shake - delta * 0.6)
    var sh := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake * 0.08
    head.position = Vector3(bob_x, 1.55 + bob_y, 0.0) + sh
    if flash_on:
        var e := 4.0
        if flash_flicker > 0.0 and randf() < flash_flicker * 0.4:
            e = randf_range(0.0, 1.5)
        flash.light_energy = e
