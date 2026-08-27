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
ASKED_APP = Path("/Applications") / "Prims Desktop.app"
OLD_APP = HOME / "Applications" / "Prim.app"
OLD_USER_APP = HOME / "Applications" / "Prims Desktop.app"
APP_BIN = ASKED_APP / "Contents" / "MacOS" / "Prim"
HELPER = ASKED_APP / "Contents" / "Helpers" / "prims-desktop"
CHATDB_HELPER = ASKED_APP / "Contents" / "Helpers" / "imessage-chatdb-receive"
TRAMPOLINE = HOME / ".local" / "bin" / "prims-desktop"
TRAMPOLINE_SRC = ROOT / "scripts" / "prims-desktop-trampoline.sh"
APP_EXEC_SNIP = "/Applications/Prims Desktop.app/Contents/MacOS/Prim"
HELPER_EXEC_SNIP = "/Applications/Prims Desktop.app/Contents/Helpers/prims-desktop"
TEAM = "Y6CQ4SWPWM"
FDA_NOTE = "Prims Desktop needs Full Disk Access to read Messages on this Mac."
OLD_CLI_FDA = "Grant Full Disk Access to prims-desktop (~/.local/bin/prims-desktop)"
BUNDLE_ID = "sh.prims.desktop"
PACK_UTI = "com.eidosagi.prim"
HEALTH = "http://127.0.0.1:7749/health"
REGISTRY = "http://127.0.0.1:7700"

PASSED: list[str] = []
FAILED: list[tuple[str, str]] = []
SKIPPED: list[tuple[str, str]] = []


def run(cmd: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["PATH"] = str(HOME / ".local/bin") + ":" + str(HOME / ".asmp/bin") + ":" + env.get("PATH", "")
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)
    except FileNotFoundError as e:
        return subprocess.CompletedProcess(cmd, 127, "", str(e))


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


def check_source_identity() -> None:
    plist = (ROOT / "Info.plist").read_text()
    if f"<string>{BUNDLE_ID}</string>" in plist and "<key>CFBundleIdentifier</key>" in plist:
        id_block = plist.split("<key>CFBundleIdentifier</key>", 1)[1]
        if f"<string>{BUNDLE_ID}</string>" in id_block.split("<key>", 1)[0]:
            ok("info_plist_bundle_id", BUNDLE_ID)
        else:
            fail("info_plist_bundle_id", "CFBundleIdentifier is not sh.prims.desktop")
    else:
        fail("info_plist_bundle_id", "Info.plist missing sh.prims.desktop")
    if PACK_UTI in plist and "<string>prim</string>" in plist:
        ok("exported_uti_prim")
    else:
        fail("exported_uti_prim", "Info.plist missing UTI com.eidosagi.prim / .prim")
    if f"<string>{PACK_UTI}</string>" in plist.split("<key>CFBundleIdentifier</key>", 1)[0]:
        fail("pack_uti_is_not_bundle_id", "pack UTI used as CFBundleIdentifier")
    else:
        ok("pack_uti_is_not_bundle_id")

    profile = ROOT / "deploy" / "prims-desktop.fulldisk.mobileconfig"
    if not profile.is_file():
        fail("pppc_mobileconfig", "missing deploy/prims-desktop.fulldisk.mobileconfig")
    else:
        text = profile.read_text()
        need = [
            "<key>Identifier</key>",
            f"<string>{BUNDLE_ID}</string>",
            "<key>IdentifierType</key>",
            "<string>bundleID</string>",
            "<key>SystemPolicyAllFiles</key>",
            "<key>Allowed</key>",
        ]
        missing = [n for n in need if n not in text]
        if missing:
            fail("pppc_mobileconfig", f"missing {missing}")
        elif "identifier \"" in text and "anchor apple generic" in text:
            fail("pppc_mobileconfig", "invented a fake CodeRequirement — leave a fill-from-codesign-dr placeholder")
        elif "codesign -dr" in text and "FILL_FROM_codesign" in text:
            ok("pppc_mobileconfig")
        else:
            fail("pppc_mobileconfig", "CodeRequirement is not a fill-from-codesign-dr placeholder")

    tramp = TRAMPOLINE_SRC.read_text()
    if (
        "exec " in tramp
        and HELPER_EXEC_SNIP in tramp
        and APP_EXEC_SNIP not in tramp
        and "chat.db" not in tramp
        and "ChatDB" not in tramp
        and "sqlite" not in tramp
    ):
        ok("trampoline_source_no_chatdb")
    else:
        fail("trampoline_source_no_chatdb", "trampoline must exec the XPC client helper and not read chat.db")

    old_hits: list[str] = []
    exact_ok = False
    for rel in [
        "Sources/PrimMacCore/DesktopCLI.swift",
        "Sources/PrimMacCore/ChatDB.swift",
        "Sources/PrimMacCore/ProductIdentity.swift",
        "Sources/PrimMac/HostView.swift",
        "Sources/PrimMac/UI/StageView.swift",
        "tools/imessage-chatdb-receive.swift",
    ]:
        text = (ROOT / rel).read_text()
        if OLD_CLI_FDA in text or "~/.local/bin/prims-desktop)" in text:
            old_hits.append(rel)
        if FDA_NOTE in text:
            exact_ok = True
    if old_hits:
        fail("fda_note_not_cli_tcc", ", ".join(old_hits))
    else:
        ok("fda_note_not_cli_tcc")
    if exact_ok:
        ok("fda_note_exact")
    else:
        fail("fda_note_exact", "locked FDA sentence missing")


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
    if OLD_USER_APP.exists() and OLD_USER_APP.resolve() != ASKED_APP.resolve():
        fail("app_not_in_user_applications", f"leftover {OLD_USER_APP}; install is {ASKED_APP}")
    elif ASKED_APP.is_dir():
        ok("app_not_in_user_applications")

    check_source_identity()

    which = run(["which", "prims-desktop"])
    path = which.stdout.strip()
    if which.returncode == 0 and Path(path).name == "prims-desktop":
        ok("cli_name", path)
    else:
        fail("cli_name", path or "prims-desktop not on PATH")


def check_asked() -> None:
    help_txt = run(["prims-desktop", "--help"]).stdout
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

    # Display / Dock / About is Prims Desktop. Internal Mach-O may stay Prim.
    plist = ASKED_APP / "Contents" / "Info.plist"
    if plist.is_file():
        dumped = run(["plutil", "-p", str(plist)]).stdout
        if '"CFBundleDisplayName" => "Prims Desktop"' in dumped:
            ok("bundle_display_name")
        else:
            fail("bundle_display_name", dumped)
        if '"CFBundleIdentifier" => "sh.prims.desktop"' in dumped:
            ok("bundle_identifier", BUNDLE_ID)
        else:
            fail("bundle_identifier", dumped)
        if '"CFBundleExecutable" => "Prim"' in dumped or '"CFBundleExecutable" => "Prims Desktop"' in dumped:
            ok("bundle_executable_name")
        else:
            fail("bundle_executable_name", dumped)
    else:
        skip("bundle_display_name", "app not installed")
        skip("bundle_identifier", "app not installed")
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
        (re.compile(r"~/Applications/Prims Desktop\.app"), "user Applications leftover"),
        (re.compile(r'open -a Prim([^\s"]|$)'), "old open -a Prim"),
        (re.compile(r"~/repos-eidos-agi/prim-mac-v1"), "old tree as a path"),
        (re.compile(r"https?://desktop\.prims\.sh"), "wrong live face"),
        (re.compile(re.escape(OLD_CLI_FDA)), "CLI as TCC client"),
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

    if HELPER.is_file():
        c2 = run(["codesign", "-dv", str(HELPER)], timeout=20)
        blob = c2.stdout + c2.stderr
        if TEAM in blob:
            ok("helper_signed_team_id", TEAM)
        else:
            fail("helper_signed_team_id", blob.replace("\n", " ")[:200])
    else:
        skip("helper_signed_team_id", "bundle helper not installed")
    tramp = run(["which", "prims-desktop"]).stdout.strip()
    if tramp:
        kind = run(["file", tramp]).stdout
        body = Path(tramp).read_text(errors="replace")
        if "Mach-O" in kind:
            fail("path_cli_is_trampoline", f"{tramp} is a Mach-O TCC principal; want a trampoline script")
        elif "exec " in body and HELPER_EXEC_SNIP in body and APP_EXEC_SNIP not in body:
            ok("path_cli_is_trampoline", tramp)
        else:
            fail("path_cli_is_trampoline", f"{tramp} must exec the XPC client {HELPER_EXEC_SNIP}")

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

    serve = run(["pgrep", "-f", "Prims Desktop.app/Contents/MacOS/Prim"])
    if serve.returncode == 0 and serve.stdout.strip():
        ok("health_serve_process_alive", serve.stdout.splitlines()[0])
    else:
        try:
            hj = http_json(HEALTH)
            if hj.get("service") == "prims-desktop":
                ok("health_serve_process_alive", "health up")
            else:
                fail("health_serve_process_alive", "no LS-launched app process; health will go stale")
        except Exception:
            fail("health_serve_process_alive", "no LS-launched app process; health will go stale")

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
    if OLD_CLI_FDA in note or "~/.local/bin" in note:
        fail("fda_copy_not_cli_path", "status still names a loose-bin TCC client")
    elif im and (note == FDA_NOTE or "chat.db readable" in note or "chat.db locked" in note):
        ok("fda_copy_not_cli_path")
    elif im:
        fail("fda_copy_not_cli_path", note[:160])
    chat = im.get("chat_db") or ""
    if chat.endswith("Library/Messages/chat.db"):
        ok("chat_db_path")
    elif im:
        fail("chat_db_path", chat or "missing")

    try:
        doctor = cli_json(["doctor"])
        need_d = {
            "overlay", "app", "cli", "asmp", "chat_db", "fda", "helper",
            "cli_is_trampoline", "principal", "running", "tcc_reader",
        }
        if need_d <= set(doctor):
            ok("doctor_json_schema")
        else:
            fail("doctor_json_schema", f"missing {sorted(need_d - set(doctor))}")
        if doctor.get("bundle_identifier") == BUNDLE_ID and str(doctor.get("app", "")).startswith("/Applications/"):
            ok("doctor_app_identity")
        else:
            fail("doctor_app_identity", f"app={doctor.get('app')} id={doctor.get('bundle_identifier')}")
        principal = str(doctor.get("principal") or "")
        running = str(doctor.get("running") or "")
        reader = str(doctor.get("tcc_reader") or "")
        if doctor.get("cli_is_trampoline") and APP_EXEC_SNIP in principal:
            ok("trampoline_and_bundle_helper")
        else:
            fail(
                "trampoline_and_bundle_helper",
                "doctor must report PATH trampoline + principal Contents/MacOS/Prim",
            )
        if reader == "app" and APP_EXEC_SNIP in running:
            ok("doctor_running_principal_is_app", running)
        else:
            fail(
                "doctor_running_principal_is_app",
                f"tcc_reader={reader} running={running} — reader must be the LS-launched app",
            )
    except Exception as e:
        fail("doctor_json_schema", str(e))

    app_blob = codesign_blob(ASKED_APP) if ASKED_APP.is_dir() else ""
    prim_blob = codesign_blob(APP_BIN) if APP_BIN.is_file() else ""
    if "flags=0x10000(runtime)" in app_blob and "flags=0x10000(runtime)" in prim_blob:
        ok("hardened_runtime")
    elif ASKED_APP.is_dir():
        fail("hardened_runtime", "app or MacOS/Prim missing runtime harden")
    else:
        fail("hardened_runtime", "app not installed — cannot prove hardened runtime")
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
    if PACK_UTI in plist and "<string>prim</string>" in plist:
        ok("exported_uti_prim")
    else:
        fail("exported_uti_prim", "Info.plist missing UTI com.eidosagi.prim / .prim")
    if "<string>sh.prims.desktop</string>" in plist:
        ok("info_plist_bundle_id_deep", BUNDLE_ID)
    else:
        fail("info_plist_bundle_id_deep", "Info.plist CFBundleIdentifier is not sh.prims.desktop")

    build = (ROOT / "scripts" / "build.sh").read_text()
    if 'APP="/Applications/Prims Desktop.app"' in build and TEAM in build:
        ok("build_sh_target_app")
    else:
        fail("build_sh_target_app", "build.sh does not assemble /Applications/Prims Desktop.app with Y6CQ4SWPWM")
    if 'Contents/Helpers/prims-desktop' in build and "--product prims-desktop" in build:
        ok("build_sh_embeds_cli_helper")
    else:
        fail("build_sh_embeds_cli_helper", "build.sh must copy prims-desktop into Contents/Helpers")
    if 'Contents/MacOS/Prim' in build and "--product PrimMac" in build:
        ok("build_sh_internal_prim")
    else:
        fail("build_sh_internal_prim", "internal binary may stay Prim; copy PrimMac → MacOS/Prim")
    if ".app.bak" in build or "Prims Desktop.app.bak" in build:
        fail("build_sh_no_bak_ghosts", "build.sh still mints /Applications bak apps")
    else:
        ok("build_sh_no_bak_ghosts")

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
    if '.executable(name: "imessage-chatdb-receive"' in pkg:
        ok("package_has_chatdb_helper")
    else:
        fail("package_has_chatdb_helper", "Package.swift missing imessage-chatdb-receive helper product")

    install = (ROOT / "scripts" / "install-cli.sh").read_text()
    if re.search(r"^\s*codesign\b", install, re.M):
        fail("install_cli_does_not_sign_trampoline", "install-cli.sh must not codesign the PATH trampoline as a TCC client")
    elif "prims-desktop-trampoline.sh" in install and "Mach-O" in install:
        ok("install_cli_does_not_sign_trampoline")
    else:
        fail("install_cli_does_not_sign_trampoline", "install-cli.sh must install the trampoline script")

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


def codesign_field(blob: str, key: str) -> str:
    prefix = key + "="
    for line in blob.splitlines():
        if line.startswith(prefix):
            return line.split("=", 1)[1].strip()
    return ""


def codesign_dr(path: Path) -> str:
    p = run(["codesign", "-dr", "-", str(path)], timeout=20)
    return (p.stderr + "\n" + p.stdout).strip()


def leftover_bak_apps() -> list[str]:
    ghosts: list[str] = []
    user = HOME / "Applications" / "Prims Desktop.app"
    if user.exists():
        ghosts.append(str(user))
    for root in (Path("/Applications"), HOME / "Applications"):
        if not root.is_dir():
            continue
        try:
            names = list(root.iterdir())
        except OSError:
            continue
        for p in names:
            n = p.name
            if n.startswith("Prims Desktop.app.bak") or n.startswith("Prim.app.bak"):
                ghosts.append(str(p))
    return ghosts


def build_sign_commands(text: str) -> list[str]:
    joined = text.replace("\\\n", " ")
    out: list[str] = []
    for line in joined.splitlines():
        s = line.strip()
        if s.startswith("#"):
            continue
        if "codesign" in s:
            out.append(s)
    return out


def check_tcc_identity() -> None:
    """Fail-closed identity / TCC gates. Run from --pro, --deep, and the full litmus."""
    app_src = (ROOT / "Sources" / "PrimMac" / "App.swift").read_text()
    main_path = ROOT / "Sources" / "PrimMac" / "PrimDesktopMain.swift"
    main_src = main_path.read_text() if main_path.is_file() else ""
    if re.search(r"(?m)^@main\b", app_src):
        fail("cli_entry_before_swiftui", "PrimApp still has @main — GUI starts before CLI")
    elif "DesktopCLI" in app_src:
        fail("cli_entry_before_swiftui", "App.swift talks to DesktopCLI — that is an init() peek")
    elif (
        "@main" in main_src
        and "ProcessEntry.shouldRunCLI" in main_src
        and "PrimsDesktopXPCClient.run" in main_src
        and "flushAndExit" in main_src
        and "PrimApp.main()" in main_src
        and "DesktopCLI.run" not in main_src
        and main_src.find("flushAndExit") < main_src.find("PrimApp.main()")
    ):
        ok("cli_entry_before_swiftui")
    else:
        fail(
            "cli_entry_before_swiftui",
            "need @main PrimDesktopMain that XPC-clients + flushAndExit before PrimApp.main()",
        )

    tramp_src = TRAMPOLINE_SRC.read_text() if TRAMPOLINE_SRC.is_file() else ""
    if HELPER_EXEC_SNIP in tramp_src and "exec " in tramp_src and APP_EXEC_SNIP not in tramp_src:
        ok("trampoline_source_execs_app")
    else:
        fail("trampoline_source_execs_app", "trampoline must exec the XPC client helper, not MacOS/Prim")

    client_src = (ROOT / "Sources" / "PrimsDesktopCLI" / "main.swift").read_text()
    if (
        "PrimsDesktopXPCClient" in client_src
        and "flushAndExit" in client_src
        and "ChatDB" not in client_src
        and "sqlite3_open" not in client_src
    ):
        ok("path_client_no_chatdb")
    else:
        fail("path_client_no_chatdb", "PrimsDesktopCLI must be an XPC client with no ChatDB/sqlite3_open")

    chatdb_src = (ROOT / "Sources" / "PrimMacCore" / "ChatDB.swift").read_text()
    if "isLaunchServicesAppProcess" in chatdb_src:
        ok("chatdb_refuses_shell_exec")
    else:
        fail("chatdb_refuses_shell_exec", "ChatDB.openDB must refuse unless parent is launchd")

    which = run(["which", "prims-desktop"]).stdout.strip()
    if not which:
        fail("path_cli_execs_macos_prim", "prims-desktop not on PATH")
    else:
        kind = run(["file", which]).stdout
        body = Path(which).read_text(errors="replace") if Path(which).is_file() else ""
        if "Mach-O" in kind:
            fail("path_cli_execs_macos_prim", f"{which} is a Mach-O")
        elif HELPER_EXEC_SNIP in body and APP_EXEC_SNIP not in body and "exec " in body:
            ok("path_cli_execs_macos_prim", which)
        else:
            fail("path_cli_execs_macos_prim", f"{which} must exec the XPC client, not MacOS/Prim")

    build = (ROOT / "scripts" / "build.sh").read_text()
    deep_stomp = [cmd for cmd in build_sign_commands(build) if "--deep" in cmd and "--verify" not in cmd]
    if deep_stomp:
        fail("build_sh_no_deep_stomp", " ; ".join(deep_stomp[:3]))
    elif "--identifier" in build and BUNDLE_ID in build:
        ok("build_sh_no_deep_stomp")
    else:
        fail("build_sh_no_deep_stomp", "build.sh must sign with --identifier sh.prims.desktop and no --deep")

    if ".app.bak" in build or "Prims Desktop.app.bak" in build:
        fail("build_sh_no_bak_success_path", "build.sh still writes bak apps")
    else:
        ok("build_sh_no_bak_success_path")

    ghosts = leftover_bak_apps()
    if ghosts:
        fail("no_leftover_app_tcc_ghosts", ", ".join(ghosts))
    else:
        ok("no_leftover_app_tcc_ghosts")

    tcc_note = ROOT / "scripts" / "TCC.md"
    if tcc_note.is_file():
        note = tcc_note.read_text()
        if (
            "client_type" in note
            and "LaunchServices" in note
            and "XPC" in note
            and "posix_spawn" in note
            and "in-app Messages" in note
        ):
            ok("tcc_model_written")
        else:
            fail("tcc_model_written", "scripts/TCC.md must say LS app is type 0; shell-exec Prim is type 1; PATH is XPC; FDA prove is in-app Messages")
    else:
        fail("tcc_model_written", "missing scripts/TCC.md")

    if not APP_BIN.is_file():
        fail("prim_identifier_sh_prims_desktop", f"missing {APP_BIN}")
        fail("prim_info_plist_bound", f"missing {APP_BIN}")
        fail("prim_dr_matches_app", f"missing {APP_BIN}")
    else:
        prim_blob = codesign_blob(APP_BIN)
        ident = codesign_field(prim_blob, "Identifier")
        if ident == BUNDLE_ID:
            ok("prim_identifier_sh_prims_desktop", ident)
        else:
            fail("prim_identifier_sh_prims_desktop", ident or prim_blob.replace("\n", " ")[:180])
        plist = codesign_field(prim_blob, "Info.plist")
        if plist and plist != "not bound":
            ok("prim_info_plist_bound", plist)
        else:
            fail("prim_info_plist_bound", plist or "Info.plist=not bound")
        prim_dr = codesign_dr(APP_BIN)
        app_dr = codesign_dr(ASKED_APP) if ASKED_APP.is_dir() else ""
        if (
            f'identifier "{BUNDLE_ID}"' in prim_dr
            and TEAM in prim_dr
            and f'identifier "{BUNDLE_ID}"' in app_dr
        ):
            ok("prim_dr_matches_app")
        else:
            fail("prim_dr_matches_app", f"prim={prim_dr[:180]} app={app_dr[:180]}")

    for helper, cid in (
        (HELPER, "helper_identifier_sh_prims_desktop"),
        (CHATDB_HELPER, "chatdb_helper_identifier_sh_prims_desktop"),
    ):
        if not helper.is_file():
            skip(cid, f"{helper.name} not installed (PATH is the XPC client helper)")
            continue
        blob = codesign_blob(helper)
        ident = codesign_field(blob, "Identifier")
        if ident in {helper.name, "prims-desktop", "imessage-chatdb-receive"} and ident != BUNDLE_ID:
            fail(cid, f"Identifier={ident} — --deep stomp or unsigned filename")
        elif ident == BUNDLE_ID:
            ok(cid, ident)
        else:
            fail(cid, ident or blob.replace("\n", " ")[:160])

    xpc = (ROOT / "Sources" / "PrimMacCore" / "PrimsDesktopXPC.swift").read_text()
    agent = (ROOT / "LaunchAgents" / "sh.prims.desktop.xpc.plist").read_text() if (ROOT / "LaunchAgents" / "sh.prims.desktop.xpc.plist").is_file() else ""
    if (
        "NSXPCListener(machServiceName:" in xpc
        and "NSXPCConnection(machServiceName:" in xpc
        and "registerAppEndpoint" in xpc
        and "SMAppService" in xpc
        and "XPCPeerTrust" in xpc
        and "NSKeyedArchiver" not in xpc
        and "archivedData(withRootObject:" not in xpc
        and "sockaddr_un" not in xpc
        and "MachServices" in agent
        and "Y6CQ4SWPWM.sh.prims.desktop.xpc" in agent
        and "sqlite3_open" not in client_src
    ):
        ok("xpc_named_service_not_archived_endpoint")
    else:
        fail(
            "xpc_named_service_not_archived_endpoint",
            "TASK-0015: named mach service + NSXPCConnection + codesign; no file-archive endpoint",
        )

    install = (ROOT / "scripts" / "install-cli.sh").read_text()
    if "grep -v" in install and "chat\\.db" in install:
        ok("install_cli_ignores_chatdb_comments")
    else:
        fail("install_cli_ignores_chatdb_comments", "install-cli.sh must not fail on comments that mention chat.db")

    # FDA prove is the in-app Messages stage (Connected / first rows), not
    # piped `prims-desktop doctor --json` chat_db_readable. Independent of XPC.
    stage = (ROOT / "Sources" / "PrimMac" / "UI" / "StageView.swift").read_text()
    settings = (ROOT / "Sources" / "PrimMac" / "UI" / "DeskSettings.swift").read_text()
    desk = (ROOT / "Sources" / "PrimMac" / "DeskModel.swift").read_text()
    host = (ROOT / "Sources" / "PrimMac" / "HostView.swift").read_text()
    rail = (ROOT / "Sources" / "PrimMac" / "UI" / "WorkRail.swift").read_text()
    if (
        "MessageTranscript" in stage
        and "ChatDB.health()" in stage
        and "iMessage is connected" in stage
        and "ProductIdentity.fdaNote" in stage
        and 'ChatDB.health() ? "Connected"' in settings
        and "ChatDB.receive" in desk
        and "tryRevealMessages" in desk
        and "beginWatchingGrant" in desk
        and "didBecomeActiveNotification" in desk
        and "PrimsDesktopXPC" not in desk
        and "FDARequestSheet" in host
        and "ProductIdentity.fdaNote" in host
        and "enum DeskDoor" in desk
        and "case viewer" in desk
        and "case connectors" in desk
        and "case chat" in desk
        and "ForEach(DeskDoor.allCases)" in rail
        and "sqlite3_open" not in client_src
    ):
        ok("fda_prove_is_in_app_messages")
    else:
        fail(
            "fda_prove_is_in_app_messages",
            "FDA prove must be StageView/DeskSettings Messages in the app process (no XPC, three doors)",
        )


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
    if args.pro or args.deep or (not args.asked and not args.naming):
        check_tcc_identity()

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
