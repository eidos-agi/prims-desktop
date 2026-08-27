#!/usr/bin/env python3
"""Adversarial prove for Prims Desktop.

Rerun: ./scripts/litmus.py
Also:  ./scripts/litmus.py --asked | --naming | --pro | --deep

Fails when what Daniel asked for does not work, names are leftover/illogical,
or the ship does not look like a professional Mac + ASMP product.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOME = Path.home()
ASKED_REMOTE = "eidos-agi/prims-desktop"
ASKED_DIR = "prims-desktop"
ASKED_APP = HOME / "Applications" / "Prims Desktop.app"
OLD_APP = HOME / "Applications" / "Prim.app"
TEAM = "Y6CQ4SWPWM"
HEALTH = "http://127.0.0.1:7749/health"
REGISTRY = "http://127.0.0.1:7700"

PASSED: list[str] = []
FAILED: list[tuple[str, str]] = []
SKIPPED: list[tuple[str, str]] = []


def run(cmd: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["PATH"] = str(HOME / ".local/bin") + ":" + str(HOME / ".asmp/bin") + ":" + env.get("PATH", "")
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)


def ok(cid: str, detail: str = "") -> None:
    PASSED.append(cid)
    print(f"PASS  {cid}" + (f"  {detail}" if detail else ""))


def fail(cid: str, detail: str) -> None:
    FAILED.append((cid, detail))
    print(f"FAIL  {cid}  {detail}")


def skip(cid: str, detail: str) -> None:
    SKIPPED.append((cid, detail))
    print(f"SKIP  {cid}  {detail}")


def git(*args: str) -> str:
    return run(["git", "-C", str(ROOT), *args]).stdout.strip()


def cli_json(args: list[str]) -> dict:
    p = run(["prims-desktop", "--json", *args])
    if p.returncode != 0 and not p.stdout.strip():
        raise RuntimeError(p.stderr.strip() or f"exit {p.returncode}")
    return json.loads(p.stdout)


def http_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=5) as resp:
        return json.loads(resp.read().decode())


def scan_files() -> list[Path]:
    skip_dirs = {
        ".git", ".build", ".learn", ".shipr", ".testr", ".secondlook",
        ".lessons", ".telos", "node_modules",
    }
    out: list[Path] = []
    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        if any(part in skip_dirs for part in p.parts):
            continue
        if p.suffix in {".png", ".jpg", ".zip", ".wasm", ".o", ".dylib"}:
            continue
        out.append(p)
    return out


def check_identity() -> None:
    if ROOT.name == ASKED_DIR:
        ok("local_tree_name", str(ROOT))
    else:
        fail("local_tree_name", f"{ROOT} is not named {ASKED_DIR}")

    # A real directory at the old name is wrong; a symlink is the compatibility bridge.
    old = HOME / "repos-eidos-agi" / "prim-mac-v1"
    if old.is_symlink() or not old.exists():
        ok("old_tree_is_not_canonical", "prim-mac-v1 symlink or absent")
    elif old.resolve() == ROOT:
        ok("old_tree_is_not_canonical", "prim-mac-v1 points here")
    else:
        fail("old_tree_is_not_canonical", f"{old} is a real second tree")

    remote = git("remote", "get-url", "origin")
    if ASKED_REMOTE in remote and remote.endswith("prims-desktop.git"):
        ok("origin_remote", remote)
    else:
        fail("origin_remote", f"{remote} is not {ASKED_REMOTE}")

    if ASKED_APP.is_dir() and not OLD_APP.exists():
        ok("app_bundle", str(ASKED_APP))
    elif ASKED_APP.is_dir() and OLD_APP.exists():
        fail("app_bundle", f"live {ASKED_APP} but leftover {OLD_APP} still exists")
    else:
        fail("app_bundle", f"missing {ASKED_APP}")

    which = run(["which", "prims-desktop"])
    path = which.stdout.strip()
    if which.returncode == 0 and Path(path).name == "prims-desktop":
        ok("cli_name", path)
    else:
        fail("cli_name", path or "prims-desktop not on PATH")


def check_asked() -> None:
    help_txt = run(["prims-desktop"]).stdout
    if re.search(r"^\s+prims-desktop asmp\s*$", help_txt, re.M):
        ok("cli_has_asmp_verb")
    else:
        fail("cli_has_asmp_verb", "usage does not list prims-desktop asmp")

    yaml = ROOT / "asmp.yaml"
    if yaml.is_file() and re.search(r"^name:\s*prims-desktop\s*$", yaml.read_text(), re.M):
        ok("asmp_yaml_identity")
    else:
        fail("asmp_yaml_identity", "asmp.yaml missing or name is not prims-desktop")

    try:
        announce = cli_json(["asmp"])
    except Exception as e:
        fail("asmp_announce_ok", str(e))
        return
    if announce.get("ok") is True:
        ok("asmp_announce_ok")
    else:
        fail("asmp_announce_ok", json.dumps(announce)[:200])

    try:
        connectors = cli_json(["connectors"]).get("connectors") or []
        names = [r["name"] for r in connectors]
    except Exception as e:
        fail("cli_lists_connectors", str(e))
        return
    if names:
        ok("cli_lists_connectors", ", ".join(names))
    else:
        fail("cli_lists_connectors", "empty")
        return

    announced = set(announce.get("announced") or [])
    missing = [n for n in names if n not in announced]
    if missing:
        fail("asmp_announces_each_connector", f"not announced: {missing}")
    else:
        ok("asmp_announces_each_connector", ", ".join(names))

    caps_p = run(["asmp", "caps"])
    caps = caps_p.stdout
    missing_caps = [n for n in names if f"connector.{n}" not in caps]
    if caps_p.returncode != 0:
        fail("asmp_caps_live", caps_p.stderr.strip() or "asmp caps failed")
    elif missing_caps:
        fail("asmp_caps_live", f"missing caps: {missing_caps}")
    else:
        ok("asmp_caps_live")

    got = run(["asmp", "get", "prims-desktop"])
    if got.returncode == 0 and "prims-desktop" in got.stdout:
        ok("asmp_get_host")
    else:
        fail("asmp_get_host", (got.stderr or got.stdout)[:200])

    eamd = run(["eamd", "asmp"])
    if eamd.returncode != 0:
        skip("eamd_lists_connectors_active", "eamd asmp failed")
    else:
        bad = []
        for n in ["prims-desktop", *names]:
            line = next((ln for ln in eamd.stdout.splitlines() if re.search(rf"\b{re.escape(n)}\b", ln)), "")
            if "active" not in line or "health healthy" not in line:
                bad.append(n)
        if bad:
            fail("eamd_lists_connectors_active", f"not active/healthy: {bad}")
        else:
            ok("eamd_lists_connectors_active")

    try:
        doctor = cli_json(["doctor"])
        asmp = doctor.get("asmp") or {}
        if asmp.get("registered") and asmp.get("health") and asmp.get("caps_match"):
            ok("doctor_asmp_honest")
        else:
            fail("doctor_asmp_honest", json.dumps(asmp)[:200])
    except Exception as e:
        # doctor --json may nest differently; fall back to text
        txt = run(["prims-desktop", "doctor"]).stdout
        if "asmp        registered" in txt and "health=ok" in txt and "caps_match=yes" in txt:
            ok("doctor_asmp_honest")
        else:
            fail("doctor_asmp_honest", str(e) + " " + txt.replace("\n", " | "))

    try:
        body = http_json(HEALTH)
        if body.get("ok") or body.get("status") == "ok":
            ok("health_loopback_up", HEALTH)
        else:
            fail("health_loopback_up", str(body))
    except Exception as e:
        fail("health_loopback_up", str(e))

    # Do not mint pack types.
    if "prim.connector" in help_txt or "prim.surface" in help_txt:
        fail("no_minted_pack_types", "CLI usage mentions prim.connector/surface")
    else:
        ok("no_minted_pack_types")


def check_naming() -> None:
    try:
        names = [r["name"] for r in cli_json(["connectors"]).get("connectors") or []]
    except Exception as e:
        fail("connector_services_namespaced", f"cannot list connectors: {e}")
        names = []

    bare = []
    for n in names:
        # Pro ASMP: child services are namespaced to the host. Bare tool
        # names collide with leftover airport services (messages-imessage).
        if n and not n.startswith("prims-desktop."):
            # announced name is the service name today
            got = run(["asmp", "get", n])
            if got.returncode == 0:
                bare.append(n)
    if names and not bare:
        ok("connector_services_namespaced")
    elif names:
        fail(
            "connector_services_namespaced",
            "ASMP services use bare tool names "
            + ", ".join(bare)
            + " — want prims-desktop.<name> so they cannot collide",
        )

    # Shared host health advertised as each connector's endpoint is a lie.
    lying = []
    for n in names:
        got = run(["asmp", "--json", "get", n])
        raw = got.stdout
        if "127.0.0.1:7749" in raw or "7749" in raw:
            lying.append(n)
    if names and lying:
        fail(
            "connector_health_is_not_host_probe",
            f"{lying} all claim {HEALTH} (that JSON is service=prims-desktop, not the connector)",
        )
    elif names:
        ok("connector_health_is_not_host_probe")

    pkg = (ROOT / "Package.swift").read_text()
    m = re.search(r'Package\(\s*name:\s*"([^"]+)"', pkg, re.S)
    pkg_name = m.group(1) if m else ""
    if pkg_name == "prims-desktop":
        ok("package_name", pkg_name)
    else:
        fail("package_name", f'Package.swift package name is {pkg_name!r}, want "prims-desktop"')

    # Bundle display name is the product; executable "Prim" is leftover.
    plist = ASKED_APP / "Contents" / "Info.plist"
    if plist.is_file():
        dumped = run(["plutil", "-p", str(plist)]).stdout
        if '"CFBundleDisplayName" => "Prims Desktop"' in dumped:
            ok("bundle_display_name")
        else:
            fail("bundle_display_name", dumped)
        if '"CFBundleExecutable" => "Prims Desktop"' in dumped or '"CFBundleExecutable" => "prims-desktop"' in dumped:
            ok("bundle_executable_name")
        else:
            fail("bundle_executable_name", "CFBundleExecutable is still Prim")
    else:
        skip("bundle_display_name", "app not installed")
        skip("bundle_executable_name", "app not installed")

    # Operational leftovers — not charter history, the live how-to.
    operational = [
        ROOT / "README.md",
        ROOT / "AGENTS.md",
        ROOT / "LEARN.md",
        ROOT / "asmp.yaml",
        *[p for p in (ROOT / "scripts").glob("*") if p.name not in {"litmus.py"}],
    ]
    leftover_hits: list[str] = []
    pats = [
        (re.compile(r"~/Applications/Prim\.app"), "old app path"),
        (re.compile(r'open -a Prim([^\s"]|$)'), "old open -a Prim"),
        (re.compile(r"~/repos-eidos-agi/prim-mac-v1"), "old tree as a path"),
        (re.compile(r"https?://desktop\.prims\.sh"), "wrong live face"),
    ]
    for path in operational:
        if not path.is_file():
            continue
        text = path.read_text(errors="replace")
        for i, line in enumerate(text.splitlines(), 1):
            if re.search(r"anti_route|do not use|forget and do not|was `prim-mac", line, re.I):
                continue
            for pat, why in pats:
                if pat.search(line):
                    leftover_hits.append(f"{path.relative_to(ROOT)}:{i} {why}: {line.strip()}")
    if leftover_hits:
        fail("operational_leftover_names", " | ".join(leftover_hits[:6]))
    else:
        ok("operational_leftover_names")

    # Product-facing docs still calling the ship Prim.app.
    product_docs = [ROOT / "ACCEPTANCE.md", ROOT / "GREAT.md", ROOT / "CHARTER.md"]
    prim_app_hits = []
    for path in product_docs:
        if not path.is_file():
            continue
        for i, line in enumerate(path.read_text().splitlines(), 1):
            if "Prim.app" in line:
                prim_app_hits.append(f"{path.name}:{i}")
    if prim_app_hits:
        fail(
            "product_docs_say_prims_desktop",
            f"still say Prim.app: {', '.join(prim_app_hits[:8])}",
        )
    else:
        ok("product_docs_say_prims_desktop")


def check_pro() -> None:
    codesign = run(["codesign", "-dv", str(ASKED_APP)], timeout=20)
    blob = (codesign.stdout + codesign.stderr)
    if TEAM in blob:
        ok("signed_team_id", TEAM)
    else:
        fail("signed_team_id", blob.replace("\n", " ")[:200])

    cli = run(["which", "prims-desktop"]).stdout.strip()
    if cli:
        c2 = run(["codesign", "-dv", cli], timeout=20)
        blob = c2.stdout + c2.stderr
        if TEAM in blob:
            ok("cli_signed_team_id", TEAM)
        else:
            fail("cli_signed_team_id", blob.replace("\n", " ")[:200])

    readme = (ROOT / "README.md").read_text()
    if "github.com/eidos-agi/prims-desktop" in readme and "~/repos-eidos-agi/prims-desktop" in readme:
        ok("readme_points_at_canonical")
    else:
        fail("readme_points_at_canonical", "README missing GitHub or local tree")

    acc = (ROOT / "ACCEPTANCE.md").read_text()
    if "AC-22" in acc and "ASMP" in acc:
        ok("acceptance_has_asmp")
    else:
        fail("acceptance_has_asmp", "ACCEPTANCE.md missing AC-22 ASMP")

    prove = (ROOT / "scripts" / "prove.sh").read_text()
    if "litmus.py" in prove:
        ok("prove_runs_litmus")
    else:
        fail("prove_runs_litmus", "scripts/prove.sh does not invoke scripts/litmus.py")

    # Live face is prims.sh/desktop, never desktop.prims.sh as a positive URL.
    bad_face = []
    for p in scan_files():
        if p.suffix not in {".md", ".swift", ".yml", ".yaml", ".sh", ".py", ""}:
            continue
        for i, line in enumerate(p.read_text(errors="replace").splitlines(), 1):
            if re.search(r"https?://desktop\.prims\.sh", line) and not re.search(
                r"anti_route|do not|never|forget|not ", line, re.I
            ):
                bad_face.append(f"{p.relative_to(ROOT)}:{i}")
    if bad_face:
        fail("live_face_is_prims_sh_desktop", ", ".join(bad_face[:6]))
    else:
        ok("live_face_is_prims_sh_desktop")


def asmp_json_get(name: str) -> dict:
    p = run(["asmp", "--json", "get", name])
    if p.returncode != 0:
        raise RuntimeError(p.stderr.strip() or p.stdout.strip() or f"asmp get {name}")
    return json.loads(p.stdout)


def codesign_blob(path: Path) -> str:
    return run(["codesign", "-dv", "--verbose=4", str(path)], timeout=20).stderr + run(
        ["codesign", "-dv", "--verbose=4", str(path)], timeout=20
    ).stdout


def check_deep() -> None:
    """Honesty, drift, TCC, schema, sign. The checks that catch a pretty lie."""
    try:
        connectors = cli_json(["connectors"]).get("connectors") or []
        names = [r["name"] for r in connectors]
        by_name = {r["name"]: r for r in connectors}
    except Exception as e:
        fail("connector_json_schema", str(e))
        connectors, names, by_name = [], [], {}

    required = {"name", "kind", "direction", "cites", "as", "in_host", "bin"}
    schema_bad = []
    minted = []
    for r in connectors:
        missing = required - set(r)
        if missing:
            schema_bad.append(f"{r.get('name','?')} missing {sorted(missing)}")
        if r.get("kind") not in {"connector"}:
            schema_bad.append(f"{r.get('name')} kind={r.get('kind')}")
        if str(r.get("kind", "")).startswith("prim."):
            minted.append(r.get("name"))
        if r.get("name") in {"prim.connector", "prim.surface"}:
            minted.append(r.get("name"))
    if connectors and not schema_bad:
        ok("connector_json_schema", f"{len(connectors)} rows")
    elif connectors:
        fail("connector_json_schema", "; ".join(schema_bad[:6]))
    if minted:
        fail("catalog_no_minted_pack_types", str(minted))
    elif connectors:
        ok("catalog_no_minted_pack_types")

    try:
        status_doc = cli_json(["status"])
        statuses = status_doc.get("status") or []
        status_by = {s["name"]: s for s in statuses}
    except Exception as e:
        fail("status_json_schema", str(e))
        statuses, status_by = [], {}

    if statuses:
        s_bad = [s.get("name") for s in statuses if "ok" not in s or "name" not in s]
        if s_bad:
            fail("status_json_schema", f"rows missing ok/name: {s_bad}")
        else:
            ok("status_json_schema", f"{len(statuses)} rows")

    # A connector is not operable just because ASMP pinged the host health port.
    liars = []
    for s in statuses:
        operable = bool(s.get("in_host")) or bool(s.get("bin_exists")) or bool(s.get("chat_db_readable"))
        if s.get("ok") and not operable:
            liars.append(s.get("name"))
    if liars:
        fail(
            "status_ok_implies_operable",
            f"{liars} report ok=true with no in-host, no bin, no chat.db — status is a costume",
        )
    elif statuses:
        ok("status_ok_implies_operable")

    # Airport map must not call a down connector healthy.
    eamd = run(["eamd", "asmp"])
    laundered = []
    if eamd.returncode == 0:
        for n in names:
            line = next((ln for ln in eamd.stdout.splitlines() if re.search(rf"\b{re.escape(n)}\b", ln)), "")
            st = status_by.get(n) or {}
            if "health healthy" in line and st.get("ok") is False:
                laundered.append(n)
        if laundered:
            fail(
                "asmp_does_not_launder_down_connectors",
                f"eamd says healthy, status.ok=false: {laundered}",
            )
        elif names:
            ok("asmp_does_not_launder_down_connectors")
    else:
        skip("asmp_does_not_launder_down_connectors", "eamd asmp failed")

    overlay_path = HOME / ".prim" / "registry.local.json"
    if overlay_path.is_file():
        overlay = json.loads(overlay_path.read_text())
        tools = overlay.get("tools") or []
        ot = [t.get("name") for t in tools]
        missing = [n for n in ot if n not in names]
        if missing:
            fail("overlay_tools_in_catalog", f"overlay not in connectors: {missing}")
        else:
            ok("overlay_tools_in_catalog", ", ".join(ot))
        need = {"imessage-chatdb-receive", "opff-dally-receive"}
        if need <= set(ot):
            ok("overlay_keeps_imessage_and_opff")
        else:
            fail("overlay_keeps_imessage_and_opff", f"overlay={ot}")
        kind_bad = [t.get("name") for t in tools if t.get("kind") not in {"connector"}]
        type_mint = [t.get("name") for t in tools if str(t.get("kind", "")).startswith("prim.")]
        if kind_bad or type_mint:
            fail("overlay_kinds_are_connector", f"{kind_bad or type_mint}")
        else:
            ok("overlay_kinds_are_connector")
    else:
        fail("overlay_tools_in_catalog", f"missing {overlay_path}")

    yaml = ROOT / "asmp.yaml"
    if yaml.is_file() and names:
        text = yaml.read_text()
        missing_y = [n for n in names if f"connector.{n}" not in text]
        extras = re.findall(r"connector\.([A-Za-z0-9._-]+)", text)
        extra_y = [e for e in extras if e not in names]
        if missing_y or extra_y:
            fail("yaml_caps_match_live_connectors", f"missing={missing_y} extra={extra_y}")
        else:
            ok("yaml_caps_match_live_connectors")
    elif names:
        fail("yaml_caps_match_live_connectors", "asmp.yaml missing")

    try:
        host = asmp_json_get("prims-desktop")
        provides = (host.get("capabilities") or {}).get("provides") or []
        live_caps = {f"connector.{n}" for n in names}
        got_caps = {c for c in provides if str(c).startswith("connector.")}
        if live_caps == got_caps:
            ok("asmp_registry_caps_match_live")
        else:
            fail(
                "asmp_registry_caps_match_live",
                f"registry={sorted(got_caps)} live={sorted(live_caps)}",
            )
        infra = host.get("infra") or {}
        if str(infra.get("repo", "")).endswith("/prims-desktop"):
            ok("asmp_infra_repo")
        else:
            fail("asmp_infra_repo", str(infra.get("repo")))
    except Exception as e:
        fail("asmp_registry_caps_match_live", str(e))

    fake_http = []
    parent_bad = []
    for n in names:
        try:
            m = asmp_json_get(n)
        except Exception:
            continue
        if m.get("parent") != "prims-desktop":
            parent_bad.append(n)
        eps = m.get("endpoints") or []
        if any(e.get("protocol") == "http" and e.get("port") == 7749 for e in eps):
            row = by_name.get(n) or {}
            if row.get("as") != "http":
                fake_http.append(n)
    if names and not parent_bad:
        ok("connector_asmp_parent")
    elif names:
        fail("connector_asmp_parent", f"parent != prims-desktop: {parent_bad}")
    if fake_http:
        fail(
            "connector_asmp_not_fake_http",
            f"{fake_http} advertise protocol=http :7749 but they are not HTTP services",
        )
    elif names:
        ok("connector_asmp_not_fake_http")

    rec = run(["prims-desktop", "--json", "receive", "no-such-connector"])
    try:
        body = json.loads(rec.stdout or "{}")
    except json.JSONDecodeError:
        body = {}
    if rec.returncode != 0 and body.get("ok") is False:
        ok("receive_unknown_fails")
    else:
        fail("receive_unknown_fails", f"exit={rec.returncode} {rec.stdout[:160]}")

    rec2 = run(["prims-desktop", "--json", "receive", "opff-dally-receive"])
    try:
        body2 = json.loads(rec2.stdout or "{}")
    except json.JSONDecodeError:
        body2 = {}
    if rec2.returncode != 0 and body2.get("ok") is False:
        ok("receive_non_imessage_fails")
    else:
        fail("receive_non_imessage_fails", f"exit={rec2.returncode} {rec2.stdout[:160]}")

    link = HOME / ".local/bin/prim-desktop"
    target = HOME / ".local/bin/prims-desktop"
    if link.is_symlink() and link.resolve() == target.resolve():
        ok("cli_compat_symlink")
    else:
        fail("cli_compat_symlink", f"{link} -> {link.resolve() if link.exists() else 'missing'}")

    serve = run(["pgrep", "-f", "prims-desktop asmp serve"])
    if serve.returncode == 0 and serve.stdout.strip():
        ok("health_serve_process_alive", serve.stdout.splitlines()[0])
    else:
        fail("health_serve_process_alive", "no prims-desktop asmp serve; health will go stale")

    try:
        hj = http_json(HEALTH)
        if hj.get("service") == "prims-desktop":
            ok("health_json_is_host")
        else:
            fail("health_json_is_host", str(hj))
    except Exception as e:
        fail("health_json_is_host", str(e))

    im = status_by.get("imessage-chatdb-receive") or {}
    note = im.get("note") or ""
    if "separate" in note.lower() and "prims-desktop" in note and "Prims Desktop.app" in note:
        ok("tcc_split_documented")
    elif im:
        fail("tcc_split_documented", "iMessage status note does not name both TCC principals")
    chat = im.get("chat_db") or ""
    if chat.endswith("Library/Messages/chat.db"):
        ok("chat_db_path")
    elif im:
        fail("chat_db_path", chat or "missing")

    try:
        doctor = cli_json(["doctor"])
        need_d = {"overlay", "app", "cli", "asmp", "chat_db", "fda"}
        if need_d <= set(doctor):
            ok("doctor_json_schema")
        else:
            fail("doctor_json_schema", f"missing {sorted(need_d - set(doctor))}")
        if doctor.get("cli") != doctor.get("app") and doctor.get("cli_exists") and doctor.get("app_exists"):
            ok("two_tcc_principals", "app and CLI are different binaries")
        else:
            fail("two_tcc_principals", "app/cli collapsed or missing")
    except Exception as e:
        fail("doctor_json_schema", str(e))

    app_blob = codesign_blob(ASKED_APP)
    cli_blob = codesign_blob(HOME / ".local/bin/prims-desktop")
    if "flags=0x10000(runtime)" in app_blob and "flags=0x10000(runtime)" in cli_blob:
        ok("hardened_runtime")
    else:
        fail("hardened_runtime", "app or CLI missing runtime harden")
    if "Developer ID Application: Eidos AGI LLC" in app_blob and "Adhoc" not in app_blob:
        ok("developer_id_not_adhoc")
    else:
        fail("developer_id_not_adhoc", app_blob.replace("\n", " ")[:180])

    sp_app = run(["spctl", "-a", "-v", str(ASKED_APP)])
    sp_txt = (sp_app.stdout + sp_app.stderr).strip()
    if "accepted" in sp_txt.lower() and "unnotarized" not in sp_txt.lower():
        ok("notarized")
    else:
        fail("notarized", sp_txt.replace("\n", " ") + " — shipr blocks; notarize before a binary leaves this Mac")

    plist = (ROOT / "Info.plist").read_text()
    if "com.eidosagi.prim" in plist and "<string>prim</string>" in plist:
        ok("exported_uti_prim")
    else:
        fail("exported_uti_prim", "Info.plist missing UTI com.eidosagi.prim / .prim")

    build = (ROOT / "scripts" / "build.sh").read_text()
    if 'APP="$HOME/Applications/Prims Desktop.app"' in build and TEAM in build:
        ok("build_sh_target_app")
    else:
        fail("build_sh_target_app", "build.sh does not assemble Prims Desktop.app with Y6CQ4SWPWM")
    if "--product prims-desktop" in build or "--product PrimsDesktop" in build:
        ok("build_sh_product_name")
    else:
        fail("build_sh_product_name", "build.sh still `swift build --product PrimMac` and copies to MacOS/Prim")

    if (ROOT / "Prim.entitlements").is_file() or (ROOT / "PrimsDesktop.entitlements").is_file():
        ok("entitlements_file")
    else:
        fail("entitlements_file", "no entitlements file next to build.sh")

    prove = (ROOT / "scripts" / "prove.sh").read_text()
    if "status imessage-chatdb-receive || true" in prove:
        fail("prove_does_not_swallow_status", "prove.sh uses || true on iMessage status")
    else:
        ok("prove_does_not_swallow_status")

    tests = (ROOT / "Tests" / "PrimMacTests" / "HostTests.swift").read_text() if (ROOT / "Tests" / "PrimMacTests" / "HostTests.swift").is_file() else ""
    filters = re.findall(r"HostTests\.(test[A-Za-z0-9]+)", prove)
    missing_t = [f for f in filters if f"func {f}(" not in tests]
    if filters and not missing_t:
        ok("prove_filters_exist_as_tests", f"{len(filters)} filters")
    elif filters:
        fail("prove_filters_exist_as_tests", f"prove filters with no test: {missing_t}")
    else:
        fail("prove_filters_exist_as_tests", "prove.sh has no HostTests filters")

    remotes = git("remote")
    if remotes.split() == ["origin"]:
        ok("single_origin_remote")
    else:
        fail("single_origin_remote", remotes.replace("\n", " "))

    pkg = (ROOT / "Package.swift").read_text()
    if '.executable(name: "prims-desktop"' in pkg:
        ok("package_has_cli_product")
    else:
        fail("package_has_cli_product", "Package.swift missing prims-desktop executable product")
    if '.executable(name: "PrimMac"' in pkg:
        fail("package_still_ships_primmac_product", "Package.swift still products PrimMac as the app executable name")
    else:
        ok("package_still_ships_primmac_product")

    leftovers = []
    for rel in ["Sources/PrimMac/RegistrySidebar.swift", "Sources/PrimMac/ToolWebView.swift"]:
        if (ROOT / rel).is_file() and "RegistrySidebar" in rel:
            leftovers.append(rel)
    # ChatGPT-costume chrome still sitting in the app target.
    chrome = []
    for rel in ["Sources/PrimMac/DeskModel.swift", "Sources/PrimMac/HostView.swift"]:
        fp = ROOT / rel
        if not fp.is_file():
            continue
        txt = fp.read_text(errors="replace")
        if re.search(r"composer|Hide Sidebar|Them\b|Accounts rail", txt):
            chrome.append(rel)
    if leftovers:
        fail("no_leftover_lab_sidebar", ", ".join(leftovers))
    else:
        ok("no_leftover_lab_sidebar")
    if chrome:
        fail("no_chatgpt_costume_chrome", ", ".join(chrome))
    else:
        ok("no_chatgpt_costume_chrome")



def main() -> int:
    ap = argparse.ArgumentParser(description="Adversarial Prims Desktop litmus")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--asked", action="store_true", help="only 'does what was asked work'")
    g.add_argument("--naming", action="store_true", help="only naming / leftover identity")
    g.add_argument("--pro", action="store_true", help="only professional-ship checks")
    g.add_argument("--deep", action="store_true", help="only honesty / drift / TCC / sign")
    args = ap.parse_args()

    print(f"litmus  {ROOT}")
    if not args.naming and not args.pro and not args.deep:
        check_identity()
        check_asked()
    if not args.asked and not args.pro and not args.deep:
        if args.naming:
            check_identity()
        check_naming()
    if not args.asked and not args.naming and not args.deep:
        check_pro()
    if args.deep or (not args.asked and not args.naming and not args.pro):
        check_deep()

    print()
    print(f"{len(PASSED)} passed, {len(FAILED)} failed, {len(SKIPPED)} skipped")
    if FAILED:
        print("next:")
        for cid, detail in FAILED:
            print(f"  - {cid}: {detail}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
