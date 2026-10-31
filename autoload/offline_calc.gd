extends Node
## Closed-form offline gains (FORMULAS §6). Stage 1 has no time-varying path effects.
## Content is preloaded so headless tests can compile this file before autoload globals exist.

const _Content = preload("res://autoload/content.gd")


static func efficiency(bonus: float) -> float:
	var base := float(_Content.data.balance["offline"]["efficiency"])
	return minf(1.0, base + bonus)


static func gained_float(prod: float, absent_sec: float, bonus: float) -> Dictionary:
	var off: Dictionary = _Content.data.balance["offline"]
	var eff := efficiency(bonus)
	var soft := float(off["soft_cap_hours"]) * 3600.0
	var hard := float(off["hard_cap_hours"]) * 3600.0
	var absent := minf(maxf(0.0, absent_sec), hard)
	var gained := 0.0
	if absent <= soft:
		gained = prod * absent * eff
	else:
		gained = prod * soft * eff + prod * (absent - soft) * eff * 0.5
	return {
		"absent_sec": absent,
		"raw_absent_sec": absent_sec,
		"gained": gained,
		"efficiency": eff,
		"hard_capped": absent_sec > hard + 1e-6,
		"soft_capped": absent > soft + 1e-6,
	}


static func apply_to_run(run: RunState, absent_sec: float) -> Dictionary:
	var prod := EconomyCore.production(
		_Content.data, run.rank_index, run.upgrade_levels, run.karma_float(), run.shop_mult
	)
	var info := gained_float(prod, absent_sec, run.offline_eff_bonus)
	var gained_bn := BigNum.from_float(float(info["gained"]))
	run.qi = run.qi.add(gained_bn)
	run.lifetime_qi = run.lifetime_qi.add(gained_bn)
	run.time_sec += float(info["absent_sec"])
	info["gained_text"] = BigNum.format(gained_bn, _Content.sci_from())
	info["prod"] = prod
	return info
