# Lucky5 Godot Deck v1

Drop `cards/` into:

```text
res://skins/lucky5/cards/
```

The card filenames are backend/Godot friendly:

```text
AS.png AH.png AD.png AC.png ... 10S.png ... KC.png
bside.png
holdbside.png
```

## Sizes

- `cards/` is the high-quality deck: `626x1056` PNGs, 2x the uploaded in-game deck aspect (`313x528`).
- `cards_313x528_compat/` is the same deck downscaled to the original in-game size for a direct lightweight replacement.
- `atlas_313x528/` contains a 13x4 atlas and JSON frame map if the Godot frontend prefers region-based rendering.

## Suggested Godot import

For crisp classic-cabinet rendering, set texture filtering per project taste:

```gdscript
# load individual card texture
$CardSprite.texture = load("res://skins/lucky5/cards/AS.png")
```

Or use the included `CardSkin_Lucky5.gd` helper.

## Style

This is a first production-ready art pass: tall Lebanese arcade silhouette, cream/gold face, large fast-read indices, classic courts, custom Lucky5 back, and `holdbside.png` for held/back state.
