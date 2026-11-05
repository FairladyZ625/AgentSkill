#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Pull all accessible haiknow wiki spaces into a local staging tree."""
import json, subprocess, os, sys, re, pathlib

STAGE = pathlib.Path("/tmp/hk-pull/stage")
MANIFEST = []

def run(args, check=True):
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode != 0:
        return {"ok": False, "raw": r.stderr[:500]}
    try:
        return json.loads(r.stdout)
    except Exception:
        return {"ok": False, "raw": r.stdout[:300]}

def safe(s):
    s = re.sub(r'[/\\:*?"<>|]', '_', s)
    return s.strip().strip('.') or "untitled"

def node_list(space, parent=None):
    cmd = ["lark-cli","wiki","+node-list","--space-id",space,"--page-all","--page-limit","0","--json"]
    if parent: cmd += ["--parent-node-token", parent]
    d = run(cmd)
    return d.get("data",{}).get("nodes",[]) if d.get("ok") else []

def fetch_doc(token):
    d = run(["lark-cli","docs","+fetch","--doc",token,"--doc-format","markdown","--json"])
    if not d.get("ok"): return None, d.get("error",{}).get("message","?")
    return d["data"]["document"].get("content",""), None

def download_file(node_token, out):
    d = run(["lark-cli","drive","+download","--wiki-token",node_token,"--output",str(out),"--overwrite","--json"])
    return d.get("ok"), d.get("error",{}).get("message","") if not d.get("ok") else ""

def dump_sheet(obj_token, outdir, title):
    info = run(["lark-cli","sheets","+workbook-info","--spreadsheet-token",obj_token,"--json"])
    if not info.get("ok"): return False, "workbook-info failed"
    for sh in info["data"].get("sheets",[]):
        if sh.get("is_hidden"): continue
        name = safe(sh["sheet_name"])
        cells = run(["lark-cli","sheets","+cells-get","--spreadsheet-token",obj_token,
                     "--sheet-name",sh["sheet_name"],
                     "--range",f"A1:{sh['column_count'] and 'ZZ'}{min(sh['row_count'],500)}",
                     "--output-path",str(outdir/f"{name}.json")])
        if not cells.get("ok"):
            # fall back to smaller range
            run(["lark-cli","sheets","+cells-get","--spreadsheet-token",obj_token,
                 "--sheet-name",sh["sheet_name"],"--range","A1:Z200",
                 "--output-path",str(outdir/f"{name}.json")])
    return True, ""

def dump_bitable(obj_token, outdir):
    tl = run(["lark-cli","base","+table-list","--base-token",obj_token,"--json"])
    if not tl.get("ok"): return False, "table-list failed"
    for t in tl["data"].get("tables",[]):
        tid = t["id"]; tname = safe(t["name"])
        run(["lark-cli","base","+record-list","--base-token",obj_token,"--table-id",tid,
             "--format","ndjson","--output",str(outdir/f"{tname}.ndjson")])
    return True, ""

def walk(space_id, space_name, parent=None, rel=pathlib.Path(".")):
    for n in node_list(space_id, parent):
        title = safe(n["title"])
        typ = n["obj_type"]
        ntok = n["node_token"]
        objtok = n["obj_token"]
        here = rel / title
        rec = {"space": space_name, "path": str(here), "type": typ, "title": n["title"],
               "node_token": ntok, "obj_token": objtok}
        if typ in ("docx","doc"):
            content, err = fetch_doc(ntok)
            if content is None:
                rec["status"] = f"FAILED: {err}"
            else:
                p = STAGE / space_name / here.parent / (title + ".md")
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(content, encoding="utf-8")
                rec["status"] = "ok"; rec["bytes"] = p.stat().st_size
        elif typ == "file":
            p = STAGE / space_name / here
            p.parent.mkdir(parents=True, exist_ok=True)
            ok, err = download_file(ntok, p)
            rec["status"] = "ok" if ok else f"FAILED: {err}"
            if ok: rec["bytes"] = p.stat().st_size
        elif typ == "sheet":
            d = STAGE / space_name / here
            d.mkdir(parents=True, exist_ok=True)
            ok, err = dump_sheet(objtok, d, title)
            rec["status"] = "ok" if ok else f"FAILED: {err}"
        elif typ == "bitable":
            d = STAGE / space_name / here
            d.mkdir(parents=True, exist_ok=True)
            ok, err = dump_bitable(objtok, d)
            rec["status"] = "ok" if ok else f"FAILED: {err}"
        else:
            rec["status"] = f"SKIPPED type={typ}"
        MANIFEST.append(rec)
        print(f"{rec['status']:<10} {typ:<8} {here}  {rec.get('bytes','')}", flush=True)
        if n.get("has_child"):
            walk(space_id, space_name, ntok, here)

spaces = run(["lark-cli","wiki","+space-list","--json"])
for s in spaces["data"]["spaces"]:
    if "示例知识库" in s["name"]:
        print(f"--- SKIP sample space: {s['name']}")
        continue
    print(f"\n===== SPACE: {s['name']} ({s['space_id']}) =====", flush=True)
    walk(s["space_id"], safe(s["name"]))

pathlib.Path("/tmp/hk-pull/manifest.json").write_text(
    json.dumps(MANIFEST, ensure_ascii=False, indent=2), encoding="utf-8")
ok = sum(1 for m in MANIFEST if m["status"]=="ok")
bad = [m for m in MANIFEST if m["status"]!="ok"]
print(f"\n=== DONE: {ok}/{len(MANIFEST)} ok, {len(bad)} problems ===")
for m in bad: print("  ", m["status"], m["path"])
