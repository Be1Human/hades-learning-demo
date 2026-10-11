extends "res://scripts/combat_fx.gd"
## Shared FX R03 paired with the character team's damage ranges.
const DemoRules=preload("res://scripts/demo01/rules.gd")
signal attack_committed(position:Vector3,direction:Vector3,action:String)
func attack(pos:Vector3,direction:Vector3,action:String) -> void:
	if action not in DemoRules.ACTIONS:return
	var first:int=effects.size()
	super.attack(pos,direction,action)
	# Shared special was authored at a different radius. Match actual damage range.
	if action=="nova":
		var ratio:float=DemoRules.ACTIONS.nova.reach/CombatRules.ACTIONS.nova.reach
		for i in range(first,effects.size()):
			var node:MeshInstance3D=effects[i].node
			node.position.x=pos.x+(node.position.x-pos.x)*ratio
			node.position.z=pos.z+(node.position.z-pos.z)*ratio
			node.scale.x*=ratio
			node.scale.z*=ratio
	attack_committed.emit(pos,direction,action)
func afterimage(visual:ActorVisual,color:Color) -> void:
	if DisplayServer.get_name()!="headless":super.afterimage(visual,color)
