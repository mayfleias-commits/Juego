extends Node3D
var f := 0
func _ready():
	var cam := Camera3D.new(); add_child(cam); cam.position = Vector3(6, 7, 10); cam.look_at(Vector3(0, 1, 0))
	var l := DirectionalLight3D.new(); add_child(l); l.rotation_degrees = Vector3(-50, 30, 0)
	var mi := MeshInstance3D.new(); mi.mesh = Models.get_mesh("casa_piedra")
	var m := ShaderMaterial.new(); m.shader = load("res://game/shaders/building.gdshader"); m.set_shader_parameter("use_instance", false)
	mi.material_override = m; add_child(mi)
	var mi2 := MeshInstance3D.new(); mi2.mesh = Models.get_mesh("carpa"); mi2.material_override = m; mi2.position = Vector3(-6, 0, 0); add_child(mi2)
	var we := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.5,0.6,0.7); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6,0.65,0.75); e.ambient_light_energy = 0.5; we.environment = e; add_child(we)
func _process(_d):
	f += 1
	if f == 5:
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		get_tree().quit()
