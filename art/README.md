# Artwork

Drop an image in here named after the thing it belongs to, and the game uses it. No
code to change, no resource files to edit.

| Folder | File name | Replaces |
|---|---|---|
| `art/heroes/` | the hero's id | the coloured shape drawn for that hero |
| `art/skills/` | the skill's id | the lettered disc on that skill's button |
| `art/arena/` | the arena's id | the flat arena floor colour |

The ids as they stand:

- Heroes: `knight`, `ranger`
- Skills: `shield_charge`, `cleave`, `power_shot`, `frost_arrow`, `tumble`
- Arena: `duel_arena`

So `art/heroes/knight.png` becomes the Knight, and `art/skills/cleave.png` becomes the
Cleave button icon. `.png`, `.svg`, `.webp`, `.jpg` and `.jpeg` all work; `.png` wins if
two files share a name.

## After adding or changing a file

Godot has to import an image before it can use it. Either open the project in the editor
once, or run:

```bash
godot --headless --path . --import
```

Until then, and whenever a name does not match, the placeholder shape is drawn instead.
Nothing breaks.

## Size

Hero art is scaled automatically so its longest side is 72 pixels — the hero's body is
56 pixels across — so an image of any size drops in sensibly. Square images sit best.
Transparent PNGs look much better than ones with a background.

To change the size of one hero, edit `art_fit_px` on that hero in
`data/heroes/<id>.tres`, or set it to 0 to use the image's own pixel size.

Drawn facing right, please: the hero is rotated or flipped to face its target.

## Doing it the other way

If you would rather point a hero at a particular file, or share one image between
several, open `data/heroes/<id>.tres` in the Godot editor and drag an image into the
**Sprite** field under Look. Anything set there wins over the file-name match above.

For an animated hero, build a **SpriteFrames** resource in the editor and put it in the
**Sprite Frames** field; an animation named `idle` plays automatically.

## What stays

The coloured ring under each hero and the bar over their head are drawn by the game, not
by the art, so you can always tell the two players apart whatever pictures you use.
