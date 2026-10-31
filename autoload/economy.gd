extends Node
## Facade over EconomyCore so the running game has the Economy autoload from TECH_PLAN.


func production_of(run: RunState) -> BigNum:
	return EconomyCore.production_bn(
		Content.data, run.rank_index, run.upgrade_levels, run.karma_float(), run.shop_mult
	)


func production_float(run: RunState) -> float:
	return EconomyCore.production(
		Content.data, run.rank_index, run.upgrade_levels, run.karma_float(), run.shop_mult
	)


func cost_of(run: RunState, uid: String) -> BigNum:
	return EconomyCore.upgrade_cost_bn(Content.data, run.upgrade_levels, uid)


func next_rank(run: RunState, stage_cap: int = EconomyCore.STAGE1_CAP) -> Dictionary:
	return EconomyCore.next_rank_dict(Content.data, run.rank_index, stage_cap)


func format_qi(bn: BigNum) -> String:
	return BigNum.format(bn, Content.sci_from())
