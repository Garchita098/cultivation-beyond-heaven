extends Node
## Facade over EconomyCore so the running game has the Economy autoload from TECH_PLAN.


func production_of(run: RunState) -> BigNum:
	return BigNum.from_float(production_float(run))


func production_float(run: RunState) -> float:
	return EconomyCore.production_state(Content.data, run.to_sim())


func cost_of(run: RunState, uid: String) -> BigNum:
	return BigNum.from_float(EconomyCore.upgrade_cost_state(Content.data, run.to_sim(), uid))


func breakthrough_cost_of(run: RunState) -> float:
	return EconomyCore.breakthrough_cost(Content.data, run.to_sim())


func next_rank(run: RunState, stage_cap: int = EconomyCore.STAGE_CAP) -> Dictionary:
	return EconomyCore.next_rank_dict(Content.data, run.rank_index, stage_cap)


func format_qi(bn: BigNum) -> String:
	return BigNum.format(bn, Content.sci_from())
