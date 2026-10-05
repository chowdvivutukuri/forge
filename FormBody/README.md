# FormBody: realistic 3D body form guides (beta)

Offline pages shown from an exercise's form guide ("See it on a 3D body"). Each page is self-contained:

- `curl.html` – dumbbell curl: live elbow/shoulder angles, range of motion, primary and secondary muscle highlights, male or female body (`?sex=female`), 360° view.
- `forge-body.js` – the body model (base64 glb) as `window.FORGE_BODY`. MakeHuman base body, CC0, from github.com/kblood/CharacterCreator (`output/base_body.glb`).
- `three.min.js`, `GLTFLoader.js` – three.js r147 (MIT).

The viewer bakes the body-shape morphs on load, re-fits the skeleton to the reshaped skin, and bakes the fist round the handle once, so the hands stay solid while the arm moves.
Add an exercise by adding its page here and its id to `BodyForm.pages` in `iOS/Views/BodyFormView.swift`.
