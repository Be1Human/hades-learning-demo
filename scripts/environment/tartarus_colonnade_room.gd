extends "res://scripts/environment/tartarus_entry_room.gd"
## Room 03: different circulation, four freestanding columns and a clear arena.
func build() -> void:
	super.build()
	for pos in [Vector3(-3.4,0,-.5),Vector3(3.4,0,-.5),Vector3(-3.4,0,3.3),Vector3(3.4,0,3.3)]:
		_column(pos,2.75)
	# Distinct paired sunken niches, away from central combat and circulation.
	for x in [-5.8,5.8]:
		kit.box("OfferingPlinth",Vector3(1,.35,1.35),Vector3(x,.17,.8),"black",true)
		_brazier(Vector3(x,.35,.8))

func _threshold() -> void:
	for x in [-2.25,2.25]:kit.box("ArenaInlay",Vector3(.06,.008,8.4),Vector3(x,.012,.35),"gold")
	for z in [-1.55,4.15]:kit.box("ArenaCrossInlay",Vector3(4.5,.008,.06),Vector3(0,.012,z),"gold")
