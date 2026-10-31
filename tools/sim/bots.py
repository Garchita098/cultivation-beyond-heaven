"""Player strategy bots. Stage 2 adds talent, artifact, and offline policies.

Stage 3 path bots join one path at rebirth 5 and ascend once the gate is open.
"""
from __future__ import annotations

import stage3
from economy import Economy, GameState


class Bot:
    name: str = "base"

    def decide(self, eco: Economy, state: GameState) -> None:
        raise NotImplementedError


class GreedyCheapest(Bot):
    name = "greedy_cheapest"

    def decide(self, eco: Economy, state: GameState) -> None:
        eco.act_cheapest(state, breakthroughs=True)


class BestROI(Bot):
    """Manual play: breakthrough when affordable, short-payback or cheap upgrades."""

    name = "best_roi"

    def decide(self, eco: Economy, state: GameState) -> None:
        eco.act_best_roi(state, breakthroughs=True)


class RushBreakthrough(Bot):
    name = "rush_breakthrough"

    def decide(self, eco: Economy, state: GameState) -> None:
        eco.act_rush(state)


class RebirthEarly(Bot):
    """Rebirth at Core Peak. Later runs want at least 3 karma. Uses automation once it exists."""

    name = "rebirth_early"

    def decide(self, eco: Economy, state: GameState) -> None:
        eco.play_rebirth_policy(state, style="early", min_rank=15, min_gain=3)


class RebirthLate(Bot):
    """Pushes to Nascent Soul before rebirth. Gain must be at least 5 after the first."""

    name = "rebirth_late"

    def decide(self, eco: Economy, state: GameState) -> None:
        eco.play_rebirth_policy(state, style="late", min_rank=16, min_gain=5)


class TalentFocused(Bot):
    """Same rebirth timing as early, but karma goes into roots and a reroll first."""

    name = "talent_focused"

    def decide(self, eco: Economy, state: GameState) -> None:
        eco.play_rebirth_policy(state, style="talent", min_rank=15, min_gain=3)


class ArtifactFocused(Bot):
    """Same rebirth timing as early, and spends spare Qi on relic levels."""

    name = "artifact_focused"

    def decide(self, eco: Economy, state: GameState) -> None:
        eco.play_rebirth_policy(state, style="artifact", min_rank=15, min_gain=3)


class PathBot(Bot):
    """One cultivation path from the moment the five paths open."""

    def __init__(self, path_id: str):
        self.path_id = path_id
        self.name = "path_" + path_id

    def decide(self, eco: Economy, state: GameState) -> None:
        if state.rebirth_count >= 5 and not state.path_joined:
            stage3.choose_path(eco, state, self.path_id)
        if stage3.can_ascend(eco, state):
            stage3.do_ascension(eco, state)
            return
        if state.rebirth_count >= 25:
            stage3.maintain(eco, state)
            eco.act_best_roi(state, breakthroughs=True)
            if stage3.can_ascend(eco, state):
                stage3.do_ascension(eco, state)
            return
        stage3.maintain(eco, state)
        eco.play_rebirth_policy(state, style="early", min_rank=15, min_gain=3)


class MixedSwitch(Bot):
    """Sword until the tenth rebirth, then pay to become a Time Lord."""

    name = "mixed_switch"

    def decide(self, eco: Economy, state: GameState) -> None:
        want = "time_lord" if state.rebirth_count >= 10 else "heavenly_sword"
        if state.rebirth_count >= 5 and (not state.path_joined or state.path_id != want):
            stage3.choose_path(eco, state, want)
        if stage3.can_ascend(eco, state):
            stage3.do_ascension(eco, state)
            return
        if state.rebirth_count >= 25:
            stage3.maintain(eco, state)
            eco.act_best_roi(state, breakthroughs=True)
            if stage3.can_ascend(eco, state):
                stage3.do_ascension(eco, state)
            return
        stage3.maintain(eco, state)
        eco.play_rebirth_policy(state, style="early", min_rank=15, min_gain=3)


class MixedWorld(Bot):
    """Immortal path, and once in the Spirit World keeps a heavy essence channel."""

    name = "mixed_world"

    def decide(self, eco: Economy, state: GameState) -> None:
        if state.rebirth_count >= 5 and not state.path_joined:
            stage3.choose_path(eco, state, "immortal")
        if state.world_id == "spirit_world":
            state.essence_ratio = 0.5
            state.stance = "guard"
        if stage3.can_ascend(eco, state):
            stage3.do_ascension(eco, state)
            return
        if state.rebirth_count >= 25:
            stage3.maintain(eco, state)
            eco.act_best_roi(state, breakthroughs=True)
            if stage3.can_ascend(eco, state):
                stage3.do_ascension(eco, state)
            return
        stage3.maintain(eco, state)
        eco.play_rebirth_policy(state, style="offline", min_rank=15, min_gain=2)


class OfflineHeavy(Bot):
    """Check-in play. Automation, when unlocked, also runs during the offline window."""

    name = "offline_heavy"

    def decide(self, eco: Economy, state: GameState) -> None:
        eco.play_rebirth_policy(state, style="offline", min_rank=15, min_gain=1)


PATH_BOTS = [PathBot(path_id) for path_id in stage3.PATH_IDS]

ALL_BOTS = [
    GreedyCheapest(),
    BestROI(),
    RushBreakthrough(),
    RebirthEarly(),
    RebirthLate(),
    TalentFocused(),
    ArtifactFocused(),
    OfflineHeavy(),
    *PATH_BOTS,
    MixedSwitch(),
    MixedWorld(),
]
