class_name MatchRunner
extends Node
## Ticks the CombatSim at the fixed physics rate. Each tick it collects one HeroCommand
## per hero from its controller, quantises it, steps the simulation and re-emits the
## tick's SimEvents for presentation.

signal sim_event(event: SimEvent)
signal tick_completed(tick: int)

var sim: CombatSim
var controllers: Array[HeroController] = []
var running := false


func setup(p_sim: CombatSim, p_controllers: Array[HeroController]) -> void:
	sim = p_sim
	controllers = p_controllers
	for i in controllers.size():
		controllers[i].hero_index = i


func state() -> MatchState:
	return sim.state


func step_once() -> void:
	var commands: Array[HeroCommand] = []
	var next_tick := sim.state.tick + 1
	for ctrl in controllers:
		var cmd := ctrl.build_command(next_tick, sim.state)
		cmd.quantize()
		commands.append(cmd)
	sim.step(commands)
	for ev in sim.state.events:
		sim_event.emit(ev)
	tick_completed.emit(sim.state.tick)


func _physics_process(_delta: float) -> void:
	if running and sim != null:
		step_once()
