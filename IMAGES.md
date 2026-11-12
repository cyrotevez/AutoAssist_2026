# Photos to add (optional but makes the app look right)

The app works without them (neutral grey placeholders show instead). Photos go in:

    aa2026_mobile/assets/images/

Use **exactly** these file names, all `.jpg`:

| File name | Where it appears | What to search for (Unsplash.com or Pexels.com - both free to use) |
|---|---|---|
| `welcome_hero.jpg` | Welcome screen background (tall / portrait works best) | "car on road sunset", "car headlights night road", "vintage car road trip" |
| `mechanic_1.jpg` | Mechanic cards & profile | "mechanic working on engine" |
| `mechanic_2.jpg` | | "car workshop garage" |
| `mechanic_3.jpg` | | "tow truck roadside" |
| `mechanic_4.jpg` | | "tyre change mechanic" |
| `mechanic_5.jpg` | | "auto repair shop tools" |
| `mechanic_6.jpg` | | "car battery jump start" |

Tips
- Landscape or square photos are fine for the mechanic ones. Keep each file under about 500 KB
  (right-click > resize, or use squoosh.app) so the app stays light.
- If you download `.png` or `.jpeg`, convert or rename to `.jpg` (a real conversion is safer than renaming).
- After adding or changing photos, stop the app and run it again (`flutter run`) - hot reload does not pick up new assets.
- Each mechanic gets one of the six photos automatically, so people who register later still get a picture.
