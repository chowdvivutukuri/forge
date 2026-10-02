"""Builds tools/forms/preview.html: a browser page that plays every form animation.

Usage: python3 tools/forms/preview.py   (run forms.py first)
"""
import json, os, re

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, "..", ".."))
data = json.load(open(os.path.join(root, "Shared", "forms.json")))
lib_src = open(os.path.join(root, "Shared", "ExerciseLibrary.swift")).read()

GROUP = {"chest": "Chest", "frontDelts": "Shoulders", "sideDelts": "Shoulders", "rearDelts": "Shoulders",
         "triceps": "Arms", "biceps": "Arms", "forearms": "Arms", "abs": "Core", "obliques": "Core",
         "traps": "Back", "upperBack": "Back", "lats": "Back", "lowerBack": "Back",
         "glutes": "Legs", "quads": "Legs", "hamstrings": "Legs", "adductors": "Legs", "calves": "Legs"}
MUSCLE = {"frontDelts": "Front delts", "sideDelts": "Side delts", "rearDelts": "Rear delts", "upperBack": "Upper back",
          "lowerBack": "Lower back"}
EQUIP = {"barbell": "Barbell", "dumbbell": "Dumbbells", "kettlebell": "Kettlebell", "bench": "Bench", "pullupBar": "Pull-up bar",
         "dipStation": "Dip station", "bands": "Band", "bodyweight": "Bodyweight", "cable": "Cable", "smith": "Smith machine",
         "legPress": "Leg press", "hackSquat": "Hack squat", "legExtension": "Leg extension", "legCurl": "Leg curl",
         "chestPress": "Chest press", "pecDeck": "Pec deck", "shoulderPress": "Shoulder press", "latPulldown": "Lat pulldown",
         "cableRow": "Cable row", "rowMachine": "Row machine", "assistedPullup": "Assisted pull-up", "preacher": "Preacher bench",
         "abductor": "Abduction machine", "adductor": "Adduction machine", "calfMachine": "Calf machine", "abCrunch": "Ab machine",
         "backExtension": "Roman chair"}

rows = re.findall(r'ex\("(\w+)", "([^"]+)", \[([^\]]*)\], \[([^\]]*)\], \[([^\]]*)\]', lib_src)
meta = []
for ex_id, name, prim, sec, equip in rows:
    prim = [m.strip(" .") for m in prim.split(",") if m.strip()]
    equip = [e.strip(" .") for e in equip.split(",") if e.strip()]
    meta.append(dict(id=ex_id, name=name, group=GROUP[prim[0]],
                     muscles=[MUSCLE.get(m, m.capitalize()) for m in prim],
                     equip=[EQUIP[e] for e in equip if e != "bodyweight"] or ["Bodyweight"]))

html = open(os.path.join(here, "preview_template.html")).read()
html = html.replace("/*DATA*/null", json.dumps(data, separators=(",", ":")))
html = html.replace("/*META*/null", json.dumps(meta, separators=(",", ":")))
out = os.path.join(here, "preview.html")
open(out, "w").write(html)
print("wrote", out, len(html), "bytes,", len(meta), "exercises")
