extends Node
class_name CardSkin_Lucky5

const CARD_BASE_PATH := "res://skins/lucky5/cards/"
const BACK := CARD_BASE_PATH + "bside.png"
const HOLD_BACK := CARD_BASE_PATH + "holdbside.png"

static func card_path(rank: String, suit: String) -> String:
	# rank: "2".."10", "J", "Q", "K", "A"; suit: "C", "D", "H", "S"
	return CARD_BASE_PATH + rank + suit + ".png"

static func card_texture(rank: String, suit: String) -> Texture2D:
	return load(card_path(rank, suit)) as Texture2D

static func back_texture(held := false) -> Texture2D:
	return load(HOLD_BACK if held else BACK) as Texture2D
