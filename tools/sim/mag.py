"""Scaled Qi. Exponent 0 stores the raw float so early ticks match float64.

True value is v * 10**e. Past 1e300 the value is promoted instead of clamped.
"""
from __future__ import annotations

import math

SOFT = 1e300
PROMOTE_AT = 1e290


class Mag:
    __slots__ = ("v", "e")

    def __init__(self, v: float = 0.0, e: int = 0) -> None:
        self.v = float(v)
        self.e = int(e)

    @staticmethod
    def zero() -> "Mag":
        return Mag(0.0, 0)

    @staticmethod
    def of(value) -> "Mag":
        if isinstance(value, Mag):
            return Mag(value.v, value.e)
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            return Mag.zero()
        x = float(value)
        if not math.isfinite(x) or x == 0.0:
            return Mag.zero()
        if abs(x) <= SOFT:
            return Mag(x, 0)
        return Mag._signed_large(x)

    @staticmethod
    def _signed_large(x: float) -> "Mag":
        sign = 1.0 if x > 0.0 else -1.0
        m = Mag.from_large(abs(x))
        m.v *= sign
        return m

    @staticmethod
    def from_large(x: float) -> "Mag":
        log10 = math.log10(x)
        e = int(math.floor(log10))
        v = 10.0 ** (log10 - e)
        return Mag(v, e)

    @staticmethod
    def from_parts(mantissa: float, exponent: int) -> "Mag":
        if mantissa == 0.0 or not math.isfinite(mantissa):
            return Mag.zero()
        sign = 1.0 if mantissa > 0.0 else -1.0
        m = abs(float(mantissa))
        e = int(exponent)
        if m >= 10.0 or m < 1.0:
            adj = math.floor(math.log10(m))
            m = m / (10.0 ** adj)
            e += int(adj)
        if -300 <= e <= 300:
            val = sign * m * (10.0 ** e)
            if math.isfinite(val) and abs(val) <= SOFT:
                return Mag(val, 0)
        return Mag(sign * m, e)

    def copy(self) -> "Mag":
        return Mag(self.v, self.e)

    def as_float(self) -> float:
        if self.v == 0.0:
            return 0.0
        if self.e == 0:
            return self.v
        if self.e > 300:
            return math.inf if self.v > 0.0 else -math.inf
        if self.e < -300:
            return 0.0
        return self.v * (10.0 ** self.e)

    def log10(self) -> float:
        if self.v <= 0.0:
            return 0.0
        if self.e == 0:
            return math.log(self.v) / math.log(10.0)
        return math.log(abs(self.v)) / math.log(10.0) + float(self.e)

    def plain(self):
        if self.e == 0:
            return self.v
        return f"{self.v:.16g}e{self.e}"

    def _other(self, other) -> tuple:
        if isinstance(other, Mag):
            return other.v, other.e
        if isinstance(other, bool) or not isinstance(other, (int, float)):
            return 0.0, 0
        x = float(other)
        if not math.isfinite(x) or x == 0.0:
            return 0.0, 0
        if abs(x) <= SOFT:
            return x, 0
        m = Mag._signed_large(x)
        return m.v, m.e

    def _store(self, v: float, e: int) -> None:
        out = Mag.from_parts(v, e)
        self.v = out.v
        self.e = out.e

    def __iadd__(self, other):
        ov, oe = self._other(other)
        if self.e == 0 and oe == 0:
            if abs(self.v) < PROMOTE_AT and abs(ov) < PROMOTE_AT:
                s = self.v + ov
                if math.isfinite(s) and abs(s) <= SOFT:
                    self.v = s
                    return self
        if self.v == 0.0 and self.e == 0:
            got = Mag.of(other) if not isinstance(other, Mag) else other.copy()
            self.v, self.e = got.v, got.e
            return self
        if ov == 0.0:
            return self
        v1, e1, v2, e2 = self.v, self.e, ov, oe
        if e1 < e2:
            v1, e1, v2, e2 = v2, e2, v1, e1
        diff = e1 - e2
        if diff > 15:
            self.v, self.e = v1, e1
            return self
        if diff > 0:
            v2 = v2 / (10.0 ** diff)
        self._store(v1 + v2, e1)
        return self

    def __isub__(self, other):
        if isinstance(other, Mag):
            return self.__iadd__(Mag(-other.v, other.e))
        return self.__iadd__(-float(other))

    def __imul__(self, other):
        ov, oe = self._other(other)
        if self.v == 0.0 or ov == 0.0:
            self.v, self.e = 0.0, 0
            return self
        if self.e == 0 and oe == 0:
            if abs(self.v) < 1e154 and abs(ov) < 1e154:
                s = self.v * ov
                if math.isfinite(s) and abs(s) <= SOFT:
                    self.v = s
                    return self
        logv = math.log(abs(self.v)) / math.log(10.0) + self.e
        logv += math.log(abs(ov)) / math.log(10.0) + oe
        sign = 1.0 if (self.v > 0.0) == (ov > 0.0) else -1.0
        e = int(math.floor(logv))
        self._store(sign * (10.0 ** (logv - e)), e)
        return self

    def __add__(self, other):
        tmp = self.copy()
        tmp += other
        return tmp.v if tmp.e == 0 else tmp

    def __radd__(self, other):
        return self.__add__(other)

    def __sub__(self, other):
        tmp = self.copy()
        tmp -= other
        return tmp.v if tmp.e == 0 else tmp

    def __rsub__(self, other):
        base = Mag.of(other)
        base -= self
        return base.v if base.e == 0 else base

    def __mul__(self, other):
        tmp = self.copy()
        tmp *= other
        return tmp.v if tmp.e == 0 else tmp

    def __rmul__(self, other):
        return self.__mul__(other)

    def _cmp(self, other) -> int:
        ov, oe = self._other(other)
        if self.v == 0.0 and ov == 0.0:
            return 0
        if self.e == 0 and oe == 0:
            if self.v < ov:
                return -1
            if self.v > ov:
                return 1
            return 0
        if (self.v > 0.0) != (ov > 0.0):
            return 1 if self.v > 0.0 else -1
        sign = 1 if self.v > 0.0 else -1
        if self.e != oe:
            return sign if self.e > oe else -sign
        if abs(self.v) > abs(ov):
            return sign
        if abs(self.v) < abs(ov):
            return -sign
        return 0

    def __lt__(self, other) -> bool:
        return self._cmp(other) < 0

    def __le__(self, other) -> bool:
        return self._cmp(other) <= 0

    def __gt__(self, other) -> bool:
        return self._cmp(other) > 0

    def __ge__(self, other) -> bool:
        return self._cmp(other) >= 0

    def __eq__(self, other) -> bool:
        return self._cmp(other) == 0

    def __ne__(self, other) -> bool:
        return self._cmp(other) != 0

    def __float__(self) -> float:
        return self.as_float()

    def __abs__(self):
        if self.v < 0.0:
            tmp = Mag(abs(self.v), self.e)
            return tmp.v if tmp.e == 0 else tmp
        return self.v if self.e == 0 else Mag(self.v, self.e)

    def __bool__(self) -> bool:
        return self.v != 0.0

    def __repr__(self) -> str:
        if self.e == 0:
            return repr(self.v)
        return f"Mag({self.v!r}, {self.e})"

    def __format__(self, spec: str) -> str:
        if self.e == 0:
            return format(self.v, spec)
        return self.plain()


def log10_qty(value) -> float:
    """Matches math.log(max(1, x)) / math.log(10) while x fits in a float."""
    if isinstance(value, Mag):
        if value.e > 0:
            return value.log10() if value.v > 0.0 else 0.0
        if value.v <= 1.0:
            return 0.0
        return math.log(value.v) / math.log(10.0)
    x = float(value)
    if not math.isfinite(x) or x <= 1.0:
        return 0.0
    return math.log(x) / math.log(10.0)


def is_finite_qty(value) -> bool:
    if isinstance(value, Mag):
        return math.isfinite(value.v)
    return math.isfinite(float(value))


def plain_qty(value):
    if isinstance(value, Mag):
        return value.plain()
    return value
