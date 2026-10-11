extends RefCounted
## One asymmetrical brush-shaped sweep. Outer edge stays inside CombatRules reach.
static func build(radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 80
	var bands := 8
	for i in range(steps):
		for j in range(bands):
			for corner in [Vector2(i,j),Vector2(i+1,j),Vector2(i+1,j+1),Vector2(i,j),Vector2(i+1,j+1),Vector2(i,j+1)]:
				var u: float = corner.x/steps
				var v: float = corner.y/bands
				var a := lerpf(-1.35,1.20,u)
				var taper := pow(maxf(sin(PI*u),0.0),0.65)*(0.30+u*1.15)
				var edge := radius*(0.92+0.08*sin(PI*u))
				var r := edge - 1.2*taper*v
				var height := 0.15*cos(PI*u)+0.05*sin(u*TAU)*v
				st.set_uv(Vector2(u,v))
				st.add_vertex(Vector3(sin(a)*r,height,cos(a)*r))
	st.generate_normals()
	return st.commit()
