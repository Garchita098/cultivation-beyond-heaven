class_name SimParity
extends RefCounted
## Replays tools/sim RebirthEarly (bots.py + check_golden.py sampler).


static func run_rebirth_early_until(data: EconData, max_sec: float) -> SimState:
	return run_rebirth_early(data, max_sec, false)["state"]


static func run_rebirth_early(data: EconData, max_sec: float, collect: bool = true) -> Dictionary:
	var state := SimState.new()
	var dt := float(data.balance["tick_seconds"])
	var acc := 0.0
	var samples: Array = []
	while state.time_sec < max_sec - 1e-9:
		EconomyCore.tick(data, state, dt)
		acc += dt
		var decided := false
		if acc >= 0.5 - 1e-12:
			acc = 0.0
			EconomyCore.play_rebirth_policy(data, state, "early", 15, 3)
			decided = true
		if collect:
			var t := state.time_sec
			var on_grid := absf(t - dt) < 1e-9 or _near_multiple(t, 30.0)
			if on_grid and (decided or absf(t - dt) < 1e-9):
				samples.append(_sample(data, state))
	return {"state": state, "samples": samples, "milestones": state.milestones}


static func _sample(data: EconData, state: SimState) -> Dictionary:
	return {
		"t": state.time_sec,
		"qi": state.qi,
		"prod": EconomyCore.production_state(data, state),
		"rank_index": state.rank_index,
		"rank_id": str(data.rank_at(state.rank_index)["id"]),
		"rebirths": state.rebirth_count,
		"karma": state.karma_shards,
		"talents": state.talents_owned.size(),
		"artifacts": state.artifacts_owned.size(),
		"shop_mult": state.shop_mult,
	}


static func _near_multiple(t: float, step: float) -> bool:
	var m := fmod(t, step)
	if m < 0.0:
		m += step
	return m < 1e-6 or absf(m - step) < 1e-6
