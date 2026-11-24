extends RefCounted
## Процедурные материалы: внешних текстур нет, всё генерируется шумом.


static func _albedo(freq: float, octaves: int, c0: Color, c1: Color, seed_v: int, ntype: int) -> NoiseTexture2D:
    var n := FastNoiseLite.new()
    n.noise_type = ntype
    n.frequency = freq
    n.fractal_octaves = octaves
    n.seed = seed_v
    var g := Gradient.new()
    g.set_color(0, c0)
    g.set_color(1, c1)
    var t := NoiseTexture2D.new()
    t.width = 256
    t.height = 256
    t.seamless = true
    t.noise = n
    t.color_ramp = g
    return t


static func _normal(freq: float, octaves: int, seed_v: int, ntype: int, strength: float) -> NoiseTexture2D:
    var n := FastNoiseLite.new()
    n.noise_type = ntype
    n.frequency = freq
    n.fractal_octaves = octaves
    n.seed = seed_v
    var t := NoiseTexture2D.new()
    t.width = 256
    t.height = 256
    t.seamless = true
    t.as_normal_map = true
    t.bump_strength = strength
    t.noise = n
    return t


static func _tri(albedo: Texture2D, normal: Texture2D, scale: Vector3, rough: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_texture = albedo
    m.roughness = rough
    if normal != null:
        m.normal_enabled = true
        m.normal_texture = normal
        m.normal_scale = 0.9
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = scale
    return m


static func wood_floor() -> StandardMaterial3D:
    var a := _albedo(0.03, 4, Color(0.10, 0.06, 0.035), Color(0.30, 0.19, 0.10), 11, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
    var n := _normal(0.05, 3, 12, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3.0)
    return _tri(a, n, Vector3(0.12, 0.12, 0.7), 0.55)


static func wall() -> StandardMaterial3D:
    var a := _albedo(0.02, 5, Color(0.17, 0.16, 0.12), Color(0.36, 0.33, 0.26), 21, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
    var n := _normal(0.06, 4, 22, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2.0)
    return _tri(a, n, Vector3(0.5, 0.5, 0.5), 0.92)


static func stone() -> StandardMaterial3D:
    var a := _albedo(0.04, 3, Color(0.08, 0.08, 0.09), Color(0.30, 0.29, 0.28), 31, FastNoiseLite.TYPE_CELLULAR)
    var n := _normal(0.05, 3, 32, FastNoiseLite.TYPE_CELLULAR, 6.0)
    return _tri(a, n, Vector3(0.6, 0.6, 0.6), 0.85)


static func ceiling() -> StandardMaterial3D:
    var a := _albedo(0.02, 4, Color(0.14, 0.12, 0.10), Color(0.28, 0.25, 0.20), 41, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
    return _tri(a, null, Vector3(0.4, 0.4, 0.4), 0.95)


static func dark_wood() -> StandardMaterial3D:
    var a := _albedo(0.05, 4, Color(0.04, 0.025, 0.015), Color(0.17, 0.10, 0.05), 51, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
    var n := _normal(0.08, 3, 52, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2.5)
    return _tri(a, n, Vector3(1.0, 1.0, 1.0), 0.6)


static func cloth(c: Color) -> StandardMaterial3D:
    var a := _albedo(0.06, 3, Color(0.55, 0.55, 0.55), Color(1.0, 1.0, 1.0), 61, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
    var m := _tri(a, null, Vector3(1.5, 1.5, 1.5), 0.96)
    m.albedo_color = c
    return m


static func metal() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.20, 0.20, 0.22)
    m.metallic = 0.85
    m.roughness = 0.45
    return m


static func bone() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.78, 0.74, 0.62)
    m.roughness = 0.8
    return m


static func emissive(c: Color, energy: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.emission_enabled = true
    m.emission = c
    m.emission_energy_multiplier = energy
    return m


static func plain(c: Color, rough: float = 0.8) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = rough
    return m
