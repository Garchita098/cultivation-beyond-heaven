class_name Ledger
extends RefCounted
## Qi and lifetime stay raw floats until they pass 1e300, then mantissa * 10^exponent.


const SOFT := 1e300
const PROMOTE_AT := 1e290


static func add_both(state: SimState, delta: float) -> void:
	_add(state, true, delta, 0)
	_add(state, false, delta, 0)


static func add_qi_parts(state: SimState, mantissa: float, exponent: int) -> void:
	_add(state, true, mantissa, exponent)


static func spend_qi(state: SimState, cost: float) -> void:
	if state.qi_e == 0 and absf(cost) < PROMOTE_AT and absf(state.qi) < PROMOTE_AT:
		state.qi -= cost
		if state.qi < 0.0 and state.qi > -1e-6:
			state.qi = 0.0
		_promote(state, true)
		return
	_add(state, true, -cost, 0)
	if state.qi_e == 0 and state.qi < 0.0:
		state.qi = 0.0


static func spend_both(state: SimState, cost: float) -> void:
	spend_qi(state, cost)
	_add(state, false, -cost, 0)
	if state.life_e == 0 and state.lifetime_qi < 0.0:
		state.lifetime_qi = 0.0


static func ge_qi(state: SimState, cost: float) -> bool:
	if state.qi_e == 0:
		return state.qi >= cost
	if cost <= 0.0:
		return state.qi >= 0.0
	var qlog := log(maxf(absf(state.qi), 1e-30)) / log(10.0) + float(state.qi_e)
	return qlog + 1e-9 >= log(cost) / log(10.0)


static func set_qi_float(state: SimState, value: float) -> void:
	state.qi = value
	state.qi_e = 0
	_promote(state, true)


static func set_qi_parts(state: SimState, mantissa: float, exponent: int) -> void:
	_assign(state, true, mantissa, exponent)


static func to_bn(state: SimState, life: bool = false) -> BigNum:
	var mag := state.lifetime_qi if life else state.qi
	var e := state.life_e if life else state.qi_e
	if e == 0:
		return BigNum.from_float(mag)
	return BigNum.normalize(mag, e)


static func from_bn(state: SimState, bn: BigNum, life: bool = false) -> void:
	if bn == null or bn.is_zero():
		_assign(state, not life, 0.0, 0)
		return
	if bn.exponent > 300 or bn.exponent < -280:
		_assign(state, not life, bn.mantissa, bn.exponent)
	else:
		_assign(state, not life, bn.to_float(), 0)


static func log10_life(state: SimState) -> float:
	if state.life_e > 0:
		if state.lifetime_qi <= 0.0:
			return 0.0
		return log(state.lifetime_qi) / log(10.0) + float(state.life_e)
	return log(maxf(1.0, state.lifetime_qi)) / log(10.0)


static func sanitize(state: SimState) -> void:
	if state.qi_e == 0:
		if not is_finite(state.qi) or state.qi < 0.0:
			state.qi = 0.0
		else:
			_promote(state, true)
	if state.life_e == 0:
		if not is_finite(state.lifetime_qi) or state.lifetime_qi < 0.0:
			state.lifetime_qi = 0.0
		else:
			_promote(state, false)


static func _promote(state: SimState, qi: bool) -> void:
	var cur := state.qi if qi else state.lifetime_qi
	var e := state.qi_e if qi else state.life_e
	if e != 0 or cur <= SOFT or not is_finite(cur):
		return
	var log10 := log(cur) / log(10.0)
	var exp := int(floor(log10))
	var mag := pow(10.0, log10 - float(exp))
	if qi:
		state.qi = mag
		state.qi_e = exp
	else:
		state.lifetime_qi = mag
		state.life_e = exp


static func _add(state: SimState, qi: bool, delta: float, delta_e: int) -> void:
	var cur := state.qi if qi else state.lifetime_qi
	var cur_e := state.qi_e if qi else state.life_e
	if delta == 0.0 and delta_e == 0:
		return
	if cur_e == 0 and delta_e == 0 and absf(cur) < PROMOTE_AT and absf(delta) < PROMOTE_AT:
		var s := cur + delta
		if is_finite(s) and absf(s) <= SOFT:
			if qi:
				state.qi = s
			else:
				state.lifetime_qi = s
			return
	if cur == 0.0 and cur_e == 0:
		_assign(state, qi, delta, delta_e)
		return
	var v1 := cur
	var e1 := cur_e
	var v2 := delta
	var e2 := delta_e
	if e1 < e2:
		var sv := v1
		var se := e1
		v1 = v2
		e1 = e2
		v2 = sv
		e2 = se
	var diff := e1 - e2
	if diff > 15:
		v2 = 0.0
	elif diff > 0:
		v2 = v2 / pow(10.0, float(diff))
	_assign(state, qi, v1 + v2, e1)


static func _assign(state: SimState, qi: bool, mantissa: float, exponent: int) -> void:
	var mag := 0.0
	var e := 0
	if mantissa == 0.0 or not is_finite(mantissa):
		mag = 0.0
		e = 0
	elif exponent == 0 or (exponent <= 300 and exponent >= -280):
		var val := mantissa * pow(10.0, float(exponent)) if exponent != 0 else mantissa
		if is_finite(val) and absf(val) <= SOFT:
			mag = val
			e = 0
		else:
			var pair := _normalize(mantissa, exponent)
			mag = pair[0]
			e = int(pair[1])
	else:
		var pair2 := _normalize(mantissa, exponent)
		mag = pair2[0]
		e = int(pair2[1])
	if qi:
		state.qi = mag
		state.qi_e = e
	else:
		state.lifetime_qi = mag
		state.life_e = e


static func _normalize(mantissa: float, exponent: int) -> Array:
	var sign_v := 1.0 if mantissa >= 0.0 else -1.0
	var m := absf(mantissa)
	var e := exponent
	if m == 0.0 or not is_finite(m):
		return [0.0, 0]
	if m >= 10.0 or m < 1.0:
		var adj := int(floor(log(m) / log(10.0)))
		m = m / pow(10.0, float(adj))
		e += adj
	return [sign_v * m, e]
