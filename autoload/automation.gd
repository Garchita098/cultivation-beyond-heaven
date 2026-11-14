extends Node
## Stage 2 automation. Decisions match EconomyCore.automation_act (the sim).

var _acc: float = 0.0


func try_act(run: RunState, delta: float) -> void:
	if run == null or not Content.valid or delta <= 0.0:
		return
	_acc += delta
	if _acc < 0.5:
		return
	_acc = 0.0
	var before_rank := run.rank_index
	var before_rebirths := run.rebirth_count
	var before_unlock := run.unlocked.duplicate()
	var sim := run.to_sim()
	EconomyCore.automation_act(Content.data, sim)
	var changed := (
		sim.rank_index != before_rank
		or sim.rebirth_count != before_rebirths
		or sim.qi != run.qi.to_float()
		or sim.upgrade_levels != run.upgrade_levels
	)
	run.apply_sim(sim, false)
	if sim.rebirth_count != before_rebirths:
		EventBus.rebirth_done.emit(run.rebirth_count)
	if sim.rank_index != before_rank:
		var rank: Dictionary = Content.data.rank_at(run.rank_index)
		EventBus.rank_up.emit(run.rank_index, str(rank.get("id", "")))
	for k in run.unlocked.keys():
		if run.unlocked[k] and not before_unlock.has(k):
			EventBus.feature_unlocked.emit(str(k))
	if changed:
		GameState.last_prod = Economy.production_float(run)
		EventBus.state_changed.emit()
