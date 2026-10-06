# FormBody: realistic 3D body form guides (beta)

Offline pages shown from an exercise's form guide ("See it on a 3D body"). Each page is self-contained:

- `body.html` – every other exercise with a form animation. The app injects `window.FORGE_FORM` (the exercise's frames from `Shared/forms.json`, muscles, cues, equipment); the page poses the body from the figure's joints (pelvis turned to the hips and shoulders, then each limb aimed at the next joint), adds the barbell, dumbbells, kettlebell, ab wheel, cables and the pattern's benches and bars, paints the primary and secondary muscles, and shows the two joints that move most with their live angle and range.
- `curl.html` – dumbbell curl (hand-tuned): live elbow/shoulder angles, range of motion, primary and secondary muscle highlights, male body, 360° view.
- `forge-body.js` – the body model (base64 glb) as `window.FORGE_BODY`. MakeHuman base body, CC0, from github.com/kblood/CharacterCreator (`output/base_body.glb`).
- `three.min.js`, `GLTFLoader.js` – three.js r147 (MIT).

The viewer bakes the body-shape morphs on load, re-fits the skeleton to the reshaped skin, and bakes the fist round the handle once, so the hands stay solid while the arm moves.
New exercises get a 3D body automatically once they have a pattern in `tools/forms/forms.py`. A hand-tuned page can still replace it: add the page here and its id to `BodyForm.pages` in `iOS/Views/BodyFormView.swift`.
