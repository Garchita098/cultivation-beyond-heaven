"""Minimal BigNum for sim: mantissa * 10^exponent. Stdlib only."""
from __future__ import annotations
import math
from typing import Tuple

SUFFIXES = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc"]


def normalize(m: float, e: int) -> Tuple[float, int]:
    if m == 0.0 or not math.isfinite(m):
        return 0.0, 0
    sign = 1.0 if m > 0 else -1.0
    m = abs(m)
    if m >= 10.0 or m < 1.0:
        adj = math.floor(math.log10(m))
        m = m / (10.0 ** adj)
        e += int(adj)
    return sign * m, e


def from_float(x: float) -> Tuple[float, int]:
    if x == 0.0 or not math.isfinite(x):
        return 0.0, 0
    return normalize(x, 0)


def to_float(m: float, e: int) -> float:
    if m == 0.0:
        return 0.0
    # Safe for sim mid-game; late-game use log compare
    if e > 300:
        return math.inf
    if e < -300:
        return 0.0
    return m * (10.0 ** e)


def add(a: Tuple[float, int], b: Tuple[float, int]) -> Tuple[float, int]:
    am, ae = a
    bm, be = b
    if am == 0:
        return b
    if bm == 0:
        return a
    if ae > be:
        if ae - be > 15:
            return a
        bm = bm / (10.0 ** (ae - be))
        return normalize(am + bm, ae)
    if be - ae > 15:
        return b
    am = am / (10.0 ** (be - ae))
    return normalize(am + bm, be)


def mul(a: Tuple[float, int], b: Tuple[float, int]) -> Tuple[float, int]:
    return normalize(a[0] * b[0], a[1] + b[1])


def mul_scalar(a: Tuple[float, int], s: float) -> Tuple[float, int]:
    return normalize(a[0] * s, a[1])


def cmp(a: Tuple[float, int], b: Tuple[float, int]) -> int:
    af, bf = to_float(a[0], a[1]), to_float(b[0], b[1])
    if af < bf:
        return -1
    if af > bf:
        return 1
    return 0


def format_bn(m: float, e: int, sci_from: int = 33) -> str:
    if m == 0:
        return "0"
    if e >= sci_from:
        return f"{m:.2f}e{e}"
    # suffix groups of 3
    group = e // 3
    if 0 <= group < len(SUFFIXES):
        val = m * (10.0 ** (e % 3))
        if group == 0:
            if e == 0 and abs(m - round(m)) < 1e-9:
                return str(int(round(m)))
            return f"{val:.2f}".rstrip("0").rstrip(".")
        return f"{val:.2f}".rstrip("0").rstrip(".") + SUFFIXES[group]
    return f"{m:.2f}e{e}"


def to_save_str(m: float, e: int) -> str:
    if m == 0:
        return "0"
    if abs(e) < 15:
        return repr(to_float(m, e))
    return f"{m!r}e{e}"


def from_save_str(s: str) -> Tuple[float, int]:
    s = s.strip()
    if "e" in s.lower() and not s.lower().startswith("e"):
        # distinguish decimal e vs our mantissa e exponent
        if s.count("e") + s.count("E") == 1:
            try:
                return from_float(float(s))
            except ValueError:
                pass
        parts = s.replace("E", "e").split("e")
        if len(parts) == 2:
            try:
                return normalize(float(parts[0]), int(parts[1]))
            except ValueError:
                return from_float(float(s))
    return from_float(float(s))
