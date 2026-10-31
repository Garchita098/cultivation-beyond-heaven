"""Player strategy bots. Stage 2 adds talent, artifact, and offline policies."""
from __future__ import annotations

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


class OfflineHeavy(Bot):
    """Check-in play. Automation, when unlocked, also runs during the offline window."""

    name = "offline_heavy"

    def decide(self, eco: Economy, state: GameState) -> None:
        eco.play_rebirth_policy(state, style="offline", min_rank=15, min_gain=1)


ALL_BOTS = [
    GreedyCheapest(),
    BestROI(),
    RushBreakthrough(),
    RebirthEarly(),
    RebirthLate(),
    TalentFocused(),
    ArtifactFocused(),
    OfflineHeavy(),
]
