#!/usr/bin/env python3
"""Generate compile-only SwiftUI view stubs from re/swift-interface.txt.

Each stub keeps the exact stored-property order/names/types recovered from the
binary so memberwise initializers match across files. Bodies are placeholders
that the reconstruction replaces.

usage: gen_view_stubs.py <swift-interface.txt> <out_dir> <plan.tsv>
plan.tsv: "<TypeName>\t<relative/file.swift>" (types not listed are skipped)
"""
import os
import re
import sys
from collections import OrderedDict

iface, out_dir, plan_path = sys.argv[1:4]
plan = OrderedDict()
for line in open(plan_path):
    if line.strip() and not line.startswith("#"):
        t, f = line.rstrip("\n").split("\t")
        plan[t] = f

KEYS = {"settingStore": "mirror", "isHidingNotch": "hideNotch", "backgroundUrlSession": "background_url_session",
        "useBackgroundSession": "background_url_session"}
# per-view defaults observed at construction sites (re/appstorage-keys.tsv)
DEFAULTS = {
    ("HomeView", "remoteVersion"): '"0.0.0"',
    ("ProfileView", "autoplayNextEpisode"): "true",
    ("DetailsViewComponent", "remoteVersion"): '""',
}
TYPE_DEFAULT = {
    "Bool": "false", "Int": "1", "String": '""', "CGFloat": "0", "Double": "0",
    "MovieVoiceActing": 'MovieVoiceActing(id: "", name: "", translatorId: "", isCamrip: "", isAds: "", isDirector: "", isSelected: false, isPremium: false, url: nil)',
    "MovieSeason": 'MovieSeason(id: "", name: "", episodes: [], isSelected: false, url: nil)',
    "MovieEpisode": 'MovieEpisode(id: "", name: "", isSelected: false, url: nil)',
    "MovieSubtitles": 'MovieSubtitles(name: "", link: "", lang: "")',
    "MovieList": 'MovieList(id: "", name: "", moviePosition: 0)',
    "Bookmark": 'Bookmark(id: 0, name: "")',
    "ShareMenuVariation": ".url", "StartupPageVariation": ".watching",
    "PlayerQualityPreference": ".ask", "DownloadDestination": ".app",
}
ENV = {"Binding<PresentationMode>": r"\.presentationMode", "DismissAction": r"\.dismiss", "ScenePhase": r"\.scenePhase",
       "ColorScheme": r"\.colorScheme", "OpenURLAction": r"\.openURL"}


def default_for(t, view, name):
    if (view, name) in DEFAULTS:
        return DEFAULTS[(view, name)]
    if t.endswith("?"):
        return "nil"
    if t.startswith("["):
        return "[:]" if (" : " in t or ": " in t) else "[]"
    return TYPE_DEFAULT.get(t)


def swift_type(t):
    return re.sub(r"\[(\w+) : (\w+)\]", r"[\1: \2]", t).replace("CoreGraphics.", "")


types = OrderedDict()
cur = None
for line in open(iface):
    m = re.match(r"^(struct|class|enum) HDrezka\.([\w.()]+?)(<generic>)? ?(?::(.*))? \{$", line.rstrip())
    if m:
        name = m.group(2).replace("(private).", "")
        cur = types.setdefault(name, {"kind": m.group(1), "protos": (m.group(4) or "").strip(), "fields": []}) if name not in types else None
        continue
    if line.startswith("}"):
        cur = None
        continue
    fm = re.match(r"^\s+(var|let) (\w+): (.+)$", line.rstrip())
    if fm and cur is not None:
        cur["fields"].append((fm.group(1), fm.group(2), fm.group(3)))

files = OrderedDict()
for tname, rel in plan.items():
    t = types[tname]
    lines = [f"struct {tname}: View {{"]
    for kw, name, ty in t["fields"]:
        ty = swift_type(ty)
        w = re.match(r"^(State|Binding|EnvironmentObject|StateObject|AppStorage|Environment|FocusState)<(.+)>$", ty)
        if w and name.startswith("_"):
            wrap, inner, prop = w.group(1), w.group(2), name[1:]
            if wrap == "State":
                d = default_for(inner, tname, prop)
                lines.append(f"    @State var {prop}: {inner}" + (f" = {d}" if d else ""))
            elif wrap == "Binding":
                lines.append(f"    @Binding var {prop}: {inner}")
            elif wrap == "EnvironmentObject":
                lines.append(f"    @EnvironmentObject var {prop}: {inner}")
            elif wrap == "StateObject":
                lines.append(f"    @StateObject var {prop} = {inner}()")
            elif wrap == "AppStorage":
                key = KEYS.get(prop, prop)
                d = "DefaultSettings.mirror" if prop == "settingStore" else default_for(inner, tname, prop)
                if prop == "remoteVersion" and (tname, prop) not in DEFAULTS:
                    d = '""'
                if inner == "Bool" and prop in ("saveHistory",):
                    d = "true"
                lines.append(f'    @AppStorage("{key}") var {prop}: {inner} = {d}')
            elif wrap == "Environment":
                lines.append(f"    @Environment({ENV[inner]}) var {prop}")
            elif wrap == "FocusState":
                lines.append(f"    @FocusState var {prop}: {inner}")
        else:
            d = '[GridItem(.adaptive(minimum: 100), spacing: 10)]' if name == "columns" else None
            lines.append(f"    var {name}: {ty}" + (f" = {d}" if d else ""))
    lines.append("")
    lines.append(f'    var body: some View {{ Text(verbatim: "{tname}") }}  // RECONSTRUCT')
    lines.append("}")
    files.setdefault(rel, []).append("\n".join(lines))

for rel, chunks in files.items():
    path = os.path.join(out_dir, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("import SwiftUI\n\n" + "\n\n".join(chunks) + "\n")
    print("wrote", rel)
