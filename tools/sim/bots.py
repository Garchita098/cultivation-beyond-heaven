"""Player strategy bots for economy simulation."""
from __future__ import annotations
from typing import List, Optional, Tuple
from economy import Economy, GameState


class Bot:
    name: str = "base"

    def decide(self, eco: Economy, state: GameState) -> None:
        """Perform zero or more purchases/breakthroughs at current instant."""
        raise NotImplementedError


def _roi(eco: Economy, state: GameState, uid: str) -> float:
    cost = eco.upgrade_cost(state, uid)
    if cost <= 0:
        return 1e18
    before = eco.production(state)
    # speculative +1
    state.upgrade_levels[uid] = state.upgrade_levels.get(uid, 0) + 1
    after = eco.production(state)
    state.upgrade_levels[uid] -= 1
    if state.upgrade_levels[uid] <= 0:
        del state.upgrade_levels[uid]
    d = after - before
    if d <= 0:
        return -1.0
    return d / cost


class GreedyCheapest(Bot):
    name = "greedy_cheapest"

    def decide(self, eco: Economy, state: GameState) -> None:
        # Prefer breakthrough if affordable and next rank is "close" (cost < 30s production)
        prod = eco.production(state)
        while eco.can_breakthrough(state):
            nxt = eco.ranks[state.rank_index + 1]
            if float(nxt["cost_qi"]) <= max(prod * 60.0, state.qi):
                eco.breakthrough(state)
                prod = eco.production(state)
            else:
                break
        changed = True
        while changed:
            changed = False
            ups = eco.unlocked_upgrades(state)
            affordable = [u for u in ups if eco.can_buy_upgrade(state, u["id"])]
            if not affordable:
                break
            affordable.sort(key=lambda u: eco.upgrade_cost(state, u["id"]))
            if eco.buy_upgrade(state, affordable[0]["id"]):
                changed = True


class BestROI(Bot):
    """Hybrid: always breakthrough when affordable; buy upgrades with short payback
    or cheap vs next rank; otherwise save for breakthrough."""
    name = "best_roi"

    def decide(self, eco: Economy, state: GameState) -> None:
        # Breakthrough first whenever we can pay
        while eco.can_breakthrough(state):
            eco.breakthrough(state)

        prod = max(eco.production(state), 1e-9)
        nxt_cost = None
        if state.rank_index + 1 < len(eco.ranks):
            nxt_cost = float(eco.ranks[state.rank_index + 1]["cost_qi"])

        for _ in range(80):
            ups = eco.unlocked_upgrades(state)
            candidates = []
            for u in ups:
                if not eco.can_buy_upgrade(state, u["id"]):
                    continue
                cost = eco.upgrade_cost(state, u["id"])
                roi = _roi(eco, state, u["id"])
                if roi <= 0:
                    continue
                payback = cost / max(roi * cost, 1e-12)  # = 1/roi
                payback = 1.0 / roi
                # buy if payback short OR cheap relative to next breakthrough
                cheap_vs_rank = nxt_cost is not None and cost <= 0.08 * nxt_cost
                near_instant = payback <= 45.0
                leftover_ok = nxt_cost is None or (state.qi - cost) >= 0.85 * nxt_cost or state.qi >= nxt_cost
                if (near_instant or cheap_vs_rank) and leftover_ok:
                    candidates.append((roi, u["id"]))
                elif near_instant and nxt_cost and state.qi < nxt_cost and cost < 0.2 * (nxt_cost - state.qi + cost):
                    candidates.append((roi * 0.5, u["id"]))
            if not candidates:
                break
            candidates.sort(reverse=True)
            if not eco.buy_upgrade(state, candidates[0][1]):
                break
            # re-check breakthrough after purchase
            while eco.can_breakthrough(state):
                eco.breakthrough(state)
            prod = max(eco.production(state), 1e-9)
            if state.rank_index + 1 < len(eco.ranks):
                nxt_cost = float(eco.ranks[state.rank_index + 1]["cost_qi"])

class RushBreakthrough(Bot):
    name = "rush_breakthrough"

    def decide(self, eco: Economy, state: GameState) -> None:
        # Save for breakthrough; only buy upgrades if cost < 10% of next rank cost
        nxt_cost = None
        if state.rank_index + 1 < len(eco.ranks):
            nxt_cost = float(eco.ranks[state.rank_index + 1]["cost_qi"])
        if eco.can_breakthrough(state):
            eco.breakthrough(state)
        ups = eco.unlocked_upgrades(state)
        ups_sorted = sorted(ups, key=lambda u: eco.upgrade_cost(state, u["id"]))
        for u in ups_sorted:
            if not eco.can_buy_upgrade(state, u["id"]):
                continue
            cost = eco.upgrade_cost(state, u["id"])
            if nxt_cost is None or cost <= 0.15 * nxt_cost or state.qi - cost >= nxt_cost:
                eco.buy_upgrade(state, u["id"])
            elif state.qi >= nxt_cost:
                break


class RebirthEarly(Bot):
    """Best-ROI play, rebirth when karma_gain is worthwhile."""
    name = "rebirth_early"
    inner = BestROI()

    def decide(self, eco: Economy, state: GameState) -> None:
        if eco.can_rebirth(state):
            gain = eco.karma_gain(state)
            # first rebirth ASAP; later require gain >= 3
            if state.rebirth_count == 0 or gain >= 3:
                eco.do_rebirth(state)
                return
        self.inner.decide(eco, state)


class RebirthLate(Bot):
    """Best-ROI, rebirth only after pushing deeper (nascent_early)."""
    name = "rebirth_late"
    inner = BestROI()

    def decide(self, eco: Economy, state: GameState) -> None:
        if eco.can_rebirth(state) and state.rank_index >= 16:
            gain = eco.karma_gain(state)
            if state.rebirth_count == 0 or gain >= 5:
                eco.do_rebirth(state)
                return
        self.inner.decide(eco, state)


class OfflineHeavy(Bot):
    """
    Models a player who checks in ~3x/day.
    Active bursts of 10 min, then offline 8 hours — handled by runner via flags.
    During active window uses BestROI.
    """
    name = "offline_heavy"
    inner = BestROI()
    # runner sets state; bot just plays actively when called
    def decide(self, eco: Economy, state: GameState) -> None:
        if eco.can_rebirth(state) and state.rank_index >= 15:
            eco.do_rebirth(state)
            return
        self.inner.decide(eco, state)


ALL_BOTS = [
    GreedyCheapest(),
    BestROI(),
    RushBreakthrough(),
    RebirthEarly(),
    RebirthLate(),
    OfflineHeavy(),
]
