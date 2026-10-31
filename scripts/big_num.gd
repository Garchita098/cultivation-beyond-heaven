class_name BigNum
extends RefCounted
## mantissa * 10^exponent, normalized to 1 <= |mantissa| < 10 (zero is 0, 0).
## Value type — not an autoload. See docs/STAGE1_DEVIATIONS.md.

var mantissa: float = 0.0
var exponent: int = 0

const SUFFIXES: PackedStringArray = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc"]


static func zero() -> BigNum:
	return BigNum.new()


static func from_float(x: float) -> BigNum:
	if x == 0.0 or not is_finite(x):
		if x != 0.0:
			push_error("BigNum: non-finite float clamped to zero")
		return zero()
	return normalize(x, 0)


static func normalize(m: float, e: int) -> BigNum:
	var out := BigNum.new()
	if not is_finite(m):
		push_error("BigNum: non-finite mantissa clamped to zero")
		return out
	if m == 0.0:
		return out
	var sign_v := 1.0 if m > 0.0 else -1.0
	var mag := absf(m)
	if mag >= 10.0 or mag < 1.0:
		var adj := int(floor(log(mag) / log(10.0)))
		mag = mag / pow(10.0, float(adj))
		e += adj
	var guard := 0
	while mag >= 10.0 and guard < 8:
		mag /= 10.0
		e += 1
		guard += 1
	while mag < 1.0 and mag > 0.0 and guard < 16:
		mag *= 10.0
		e -= 1
		guard += 1
	if not is_finite(mag):
		push_error("BigNum: normalization produced non-finite")
		return zero()
	out.mantissa = sign_v * mag
	out.exponent = e
	return out


func dup() -> BigNum:
	var b := BigNum.new()
	b.mantissa = mantissa
	b.exponent = exponent
	return b


func is_zero() -> bool:
	return mantissa == 0.0


func to_float() -> float:
	if mantissa == 0.0:
		return 0.0
	if exponent > 300:
		return INF
	if exponent < -300:
		return 0.0
	return mantissa * pow(10.0, float(exponent))


func neg() -> BigNum:
	return BigNum.normalize(-mantissa, exponent)


func add(other: BigNum) -> BigNum:
	if mantissa == 0.0:
		return other.dup()
	if other.mantissa == 0.0:
		return dup()
	if exponent > other.exponent:
		if exponent - other.exponent > 15:
			return dup()
		var bm := other.mantissa / pow(10.0, float(exponent - other.exponent))
		return BigNum.normalize(mantissa + bm, exponent)
	if other.exponent - exponent > 15:
		return other.dup()
	var am := mantissa / pow(10.0, float(other.exponent - exponent))
	return BigNum.normalize(am + other.mantissa, other.exponent)


func sub(other: BigNum) -> BigNum:
	return add(other.neg())


func mul(other: BigNum) -> BigNum:
	if mantissa == 0.0 or other.mantissa == 0.0:
		return zero()
	return BigNum.normalize(mantissa * other.mantissa, exponent + other.exponent)


func mul_scalar(s: float) -> BigNum:
	if not is_finite(s):
		push_error("BigNum: non-finite scalar clamped to zero")
		return zero()
	if s == 0.0 or mantissa == 0.0:
		return zero()
	return BigNum.normalize(mantissa * s, exponent)


## Exponent-aligned compare (FORMULAS / TECH). Returns -1, 0, 1.
## The Python sim compares via to_float, which overflows past exponent 300.
func cmp(other: BigNum) -> int:
	if mantissa == 0.0 and other.mantissa == 0.0:
		return 0
	if mantissa == 0.0:
		return -1 if other.mantissa > 0.0 else 1
	if other.mantissa == 0.0:
		return 1 if mantissa > 0.0 else -1
	var sign_v := 1 if mantissa > 0.0 else -1
	if exponent != other.exponent:
		return sign_v if exponent > other.exponent else -sign_v
	var diff := absf(mantissa) - absf(other.mantissa)
	if absf(diff) <= 1e-9 * maxf(1.0, absf(mantissa)):
		return 0
	if diff > 0.0:
		return sign_v
	return -sign_v


func nearly(other: BigNum, rel: float = 1e-9) -> bool:
	if is_zero() or other.is_zero():
		return is_zero() and other.is_zero()
	if exponent == other.exponent:
		return absf(mantissa - other.mantissa) <= rel * maxf(absf(mantissa), absf(other.mantissa))
	var diff := exponent - other.exponent
	if absi(diff) > 1:
		return false
	var scaled := mantissa * pow(10.0, float(diff))
	return absf(scaled - other.mantissa) <= rel * maxf(absf(scaled), absf(other.mantissa))


func ratio_to(other: BigNum) -> float:
	if other.mantissa == 0.0:
		return 1.0
	if mantissa == 0.0:
		return 0.0
	if signf(mantissa) != signf(other.mantissa):
		return 0.0
	var de := exponent - other.exponent
	if de >= 8:
		return 1.0e8
	if de <= -8:
		return 0.0
	return (mantissa / other.mantissa) * pow(10.0, float(de))


static func format(bn: BigNum, sci_from: int = 33) -> String:
	var m := bn.mantissa
	var e := bn.exponent
	if m == 0.0:
		return "0"
	if e >= sci_from:
		return ("%.2f" % m) + "e" + str(e)
	var group := _group_of(e)
	if group >= 0 and group < SUFFIXES.size():
		var val := m * pow(10.0, float(posmod(e, 3)))
		if group == 0:
			if e == 0 and absf(m - round(m)) < 1e-9:
				return str(int(round(m)))
			return _trim2(val)
		return _trim2(val) + SUFFIXES[group]
	return ("%.2f" % m) + "e" + str(e)


func to_save_string() -> String:
	if mantissa == 0.0:
		return "0"
	if absi(exponent) < 15:
		return String.num(to_float(), 16)
	# Keep mantissa/exponent split so values past float range survive.
	return String.num(mantissa, 16) + "e" + str(exponent)


static func from_save_string(s: String) -> BigNum:
	s = s.strip_edges()
	if s.is_empty() or s == "0":
		return zero()
	var lower := s.to_lower()
	if lower in ["nan", "inf", "+inf", "-inf", "infinity", "+infinity", "-infinity"]:
		push_error("BigNum: non-finite save string clamped to zero")
		return zero()
	if "e" in lower and not lower.begins_with("e") and not lower.begins_with("+e") and not lower.begins_with("-e"):
		var parts := lower.split("e", false, 1)
		if parts.size() == 2 and _is_float_token(parts[0]) and _is_int_token(parts[1]):
			var exp := int(parts[1])
			# Prefer the split form so 1.23e400 does not overflow to zero.
			if absi(exp) >= 15 or absf(float(parts[0])) >= 10.0 or (absf(float(parts[0])) > 0.0 and absf(float(parts[0])) < 1.0):
				return normalize(float(parts[0]), exp)
			# Small scientific strings match from_float(float(s)) used by the sim.
			if is_finite(float(s)):
				return from_float(float(s))
			return normalize(float(parts[0]), exp)
	if not _is_float_token(s):
		push_error("BigNum: bad save string '%s'" % s)
		return zero()
	return from_float(float(s))


static func _group_of(e: int) -> int:
	if e >= 0:
		return int(e / 3)
	return int(floor(float(e) / 3.0))


static func _trim2(val: float) -> String:
	var s := "%.2f" % val
	while s.ends_with("0") and s.contains("."):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s


static func _is_float_token(s: String) -> bool:
	return s.is_valid_float()


static func _is_int_token(s: String) -> bool:
	return s.is_valid_int()
