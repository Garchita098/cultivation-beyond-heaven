class_name EconData
extends RefCounted
## Parsed content tables. Owned by the Content autoload after load.

var balance: Dictionary = {}
var ranks: Array = []
var ranks_by_id: Dictionary = {}
var upgrades: Dictionary = {}
var upgrade_order: Array[String] = []
var rebirth: Dictionary = {}
var worlds: Dictionary = {}
var talents: Dictionary = {}
var artifacts: Dictionary = {}
var paths: Dictionary = {}
var automation: Dictionary = {}


func rank_at(index: int) -> Dictionary:
	if index < 0 or index >= ranks.size():
		return {}
	return ranks[index]
