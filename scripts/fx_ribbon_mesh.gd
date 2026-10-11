extends RefCounted
## An uncached transient path: vertices carry arc-length UVs, never count as gameplay geometry.
static func build(points: Array[Vector3], width: float, camera_facing := Vector3.UP) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lengths: Array[float] = [0.0]
	for i in range(1,points.size()): lengths.append(lengths[-1]+points[i].distance_to(points[i-1]))
	var total := maxf(lengths[-1],0.001)
	for i in range(points.size()-1):
		for corner in [Vector2(i,0),Vector2(i,1),Vector2(i+1,1),Vector2(i,0),Vector2(i+1,1),Vector2(i+1,0)]:
			var index := int(corner.x)
			var tangent := (points[mini(index+1,points.size()-1)]-points[maxi(index-1,0)]).normalized()
			var side := tangent.cross(camera_facing).normalized()
			if side.is_zero_approx(): side = Vector3.RIGHT
			var u := lengths[index]/total
			st.set_uv(Vector2(u,corner.y))
			st.add_vertex(points[index]+side*(corner.y-0.5)*width)
	st.generate_normals()
	return st.commit()
