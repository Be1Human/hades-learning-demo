class_name CombatRules
extends RefCounted

# Seconds are tunable prototype values, not claimed measurements of Hades.
const ACTIONS := {
	"slash_1": {"windup": 0.085, "active": 0.10, "recovery": 0.16, "damage": 20.0, "reach": 2.45, "arc": 110.0, "push": 3.2, "stop": 0.045, "shake": 0.10, "lunge": 0.70},
	"slash_2": {"windup": 0.095, "active": 0.11, "recovery": 0.18, "damage": 25.0, "reach": 2.55, "arc": 130.0, "push": 3.8, "stop": 0.055, "shake": 0.14, "lunge": 0.70},
	"thrust": {"windup": 0.13, "active": 0.095, "recovery": 0.23, "damage": 40.0, "reach": 3.2, "width": 0.62, "push": 6.0, "stop": 0.073, "shake": 0.21, "lunge": 1.22},
	"dash_strike": {"windup": 0.035, "active": 0.105, "recovery": 0.17, "damage": 30.0, "reach": 2.85, "width": 0.77, "push": 4.8, "stop": 0.05, "shake": 0.15, "lunge": 1.00},
	"nova": {"windup": 0.28, "active": 0.10, "recovery": 0.27, "damage": 50.0, "reach": 3.15, "arc": 360.0, "push": 7.3, "stop": 0.085, "shake": 0.28, "lunge": 0.0},
}
const INPUT_BUFFER := 0.16
const COMBO_RESET := 0.55
const DASH_DURATION := 0.19
const DASH_INVULNERABLE := 0.145
const DASH_RECHARGE := 0.62
const DASH_SPEED := 21.0

static func duration(action: String) -> float:
	var d: Dictionary = ACTIONS[action]
	return float(d.windup + d.active + d.recovery)

static func phase(action: String, elapsed: float) -> String:
	var d: Dictionary = ACTIONS[action]
	if elapsed < float(d.windup):
		return "起手"
	if elapsed < float(d.windup + d.active):
		return "命中段"
	return "收势"

static func in_attack(action: String, origin: Vector3, forward: Vector3, target: Vector3, radius: float) -> bool:
	var d: Dictionary = ACTIONS[action]
	var offset := target - origin
	offset.y = 0.0
	var distance := offset.length()
	if distance > float(d.reach) + radius:
		return false
	if action == "nova":
		return true
	var along := offset.dot(forward)
	if d.has("width"):
		var lateral := absf(offset.dot(Vector3(forward.z, 0.0, -forward.x)))
		return along >= -radius * 0.3 and lateral <= float(d.width) + radius * 0.6
	if distance < 0.1:
		return true
	return along / distance >= cos(deg_to_rad(float(d.arc) * 0.5 + 8.0))

static func is_backstab(enemy_forward: Vector3, enemy_to_attacker: Vector3) -> bool:
	return enemy_forward.dot(enemy_to_attacker.normalized()) < -0.45
