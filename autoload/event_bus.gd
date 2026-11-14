extends Node
## UI subscribes; gameplay emits. Stage 1 uses rank_up, feature_unlocked, offline_summary, state_changed.

signal qi_changed(qi_text: String, rate_text: String)
signal rank_up(rank_index: int, rank_id: String)
signal rebirth_done(count: int)
signal feature_unlocked(feature_id: String)
signal offline_summary(summary: Dictionary)
signal open_rebirth_confirm
signal open_path_sheet
signal open_ascension_confirm
signal open_world_sheet
signal state_changed
signal achievement_unlocked(achievement_id: String)
