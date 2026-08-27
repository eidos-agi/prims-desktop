## Philosophy

Prim is the file. A Prim Tool cites that file. The Mac app is a host, not a
second store and not a pile of one-off editors. That split is the product.
Preview does not become the PDF. Pages does not become the document. Prim.app
does not become the pack.

Double-click a `.prim`. The host reads the category registry, detects the type,
and opens a surface tool that cites it. Open, view, edit, Save, Save As, Copy,
Export. Every registered type. Every registered tool. A new type or tool appears
in `registry/registry.json` and this app hosts it — it does not grow a native
face per profile. If the catalog moves and the app does not, the app is wrong.

The pack stays the file. Views are not the source of truth. Do not mint
`prim.surface` or `prim.connector` as pack types. Invite is not attendance.
OSF is not the thin session file. A connector is not a pack. The toolbar is
how you pick a citing tool, not a place to invent a seventeenth format.

## The Friction

The web viewers lab can resize a real tool, but it is a browser tab. The work
lives on disk as `.prim`. Finder, Mail, Messages, and “send me the prim” need
an app that owns the type — the way Preview owns PDF and Pages owns a document.
A tab cannot be the default handler. A tab cannot Save As next to the file
that arrived as an attachment. A tab cannot be the thing a colleague double-clicks.

Without a host, every new profile tempts a Swift rewrite. That cannot cover
all types and all tools. The registry already lists them. The web already
renders the surface tools. The Mac app must be the document shell around that
contract. The pain is not missing chrome. The pain is the file having no
owner on the computer where the work actually sits.

## The Cost of Not

If Prim has no Mac document app, `.prim` stays a zip people rename. Tools stay
trapped in a demo tab. Edit and Save never meet the file. New profiles ship
as paper faces. The category claim — a file, and tools that cite it — is a
website, not a computer. Each launch then grows a one-off viewer, and the
registry becomes a brochure instead of a catalog the OS can open. People
send PDFs again because the pack cannot land.

The compounding cost is attention. Every session that cannot open the file
rebuilds a viewer. Every attachment that cannot Save trains the habit of
exporting a slide instead. Agents invent another HTML face. Humans stop
believing the pack is the work. Once that happens, Prim is a format people
talk about and a folder of zips they do not use.

## Why Not The Alternatives

- **One native Swift UI per type.** — insufficient because the registry will
  keep growing. Sixteen editors today, then a seventeenth, then a connector.
  The host would always be behind. A native face per profile is how we lose
  “all tools.” The cost is not the first editor. It is the promise that the
  next type ships with a Mac rewrite. That promise fails the week a new
  profile lands in `registry.json` and nobody ports chrome. (research:
  registry.json is the catalog)
- **Wrap only prim.eidosagi.com.** — insufficient because the pack must work
  local, offline, and on a dropped file that is not a sample. The site is a
  view. The app opens the file. A live URL cannot be the Save path. Network
  failure, a private pack, or a draft that must not leave the machine all
  break a hosted-only wrapper. The public site stays a view. It is not the
  document app.
- **A Finder Quick Look plugin only.** — insufficient because Quick Look is
  not edit, Save, or tool switching. Previewing a zip is not hosting a tool.
  Quick Look cannot pick `log-editor` versus `prim-sim`, cannot Save As, and
  cannot be the default handler people mean when they say “open this prim.”
  It is a glance. Prim.app is the owner.

## The Unique Offer

Prim.app is the way a `.prim` opens on a Mac. It does not invent a UI per type.
It reads the category registry, detects the file, and hosts every citing surface
tool. Open, view, edit, Save, Copy, Export — one document app, every registered
kind. The website remains a view. The simulator remains a tool. This app is
where a `.prim` lands on a Mac and stays a file.

What nothing else offers is that loop closed: Finder, Mail, and “send me the
prim” resolve to one host; the catalog can grow without a Swift rewrite; Save
writes the pack, not a sidecar. A person can work the same file they attached.
An agent can point at a path and mean the document, not a tab.

World-class is Preview for `.prim`. Double-click, Mail, Messages, and
`open -a "Prims Desktop"` all land on the citing tool — not a zip preview, not a browser
tab, not the fallback line “This tool runs locally.” Every registered type
hosts. Every citing surface and connector is choosable; process tools stay
local. File → Save writes the zip and Detect still returns the same kind.
In-memory editor mutations export into `document.data` before Save, or the
app must not pretend the editor already is the file.

The hosted surface is a place, not a CMS. For a brand pack (OBIF) that means
one scrolling book — cover, mark, type, voice, ground — in the real Prim.app
window, first screen holding, no COVER stamp, no tab chrome. Harbor and other
thin packs keep their own plates; Prim.app does not invent Prim plates for
them. Docket, deck, invoice, session, arcade, log, and the OKF lineage packs
each open the tool that cites them. The public site at prim.eidosagi.com is
still a view. It is not the owner.

The score of that destination lives in `GREAT.md` and is measured by
`scripts/learn`. Ninety of a hundred is the heading: land, host, file, and
place proven on this Mac. One hundred adds notarize, Mail, and Messages.
Pixel proof is a Prim.app window (`scripts/capture-window` / `screencapture -l`).
A Paseo tab or a local HTTP demo is not the document app. The learn loop in
`LEARN.md` repeats: score, close the largest remaining gap, prove it in the
real window, tick this charter. Telos steers. A `pivot` means integrate what
already works. A `stop` means checkpoint, not grind.


## Branding

**Product:** Prims Desktop (plural — matches prims.sh; the container).
**File / category noun:** Prim (singular pack). Do not invent Prunes/Print or
`desktop.prims.sh` — live face is https://prims.sh/desktop/ on prim-web.

## TCC / Full Disk Access

The Messages grant is on the **app bundle** (`sh.prims.desktop`, TCC
`client_type` 0). A helper Mach-O exec'd from a shell is `client_type` 1 —
same Identifier is not enough. PATH `prims-desktop` must `exec`
`/Applications/Prims Desktop.app/Contents/MacOS/Prim`. Process entry is
`PrimDesktopMain`: CLI verbs call `DesktopCLI` and `_exit` before
`NSApplication`. Do not use `~/Applications/Prims Desktop.app`. Do not
leave bak apps in `/Applications`. Do not resign Helpers to "fix" FDA.
The durable note is `scripts/TCC.md`.

## Drive sync (provisional)

**Not stamped.** Daniel dismissed the Drive-as-sync stamp widget — this is a
lean / recommendation from Prim/Kai, not a product lock. Do not cement it until
he stamps.

Working lean: Prims *feel* like Google Drive docs. Drive is a *candidate*
natural sync root (same `.prim` / `.prim.zip` on Mac and in Drive). Company
dockets already live that way. If adopted: Drive stores/shares pack files; the
**Prims Desktop** container (admit / approve / hierarchy) remains the
agent-visibility ACL. Being in Drive alone would not make a pack agent-operable.
Packs stay durable truth; Drive would not be a second schema.

## Prim Secrets · Prim Approvals (exploratory)

**Not charter locks.** Soft product nouns for frames and /desktop/ copy only
until Daniel stamps:

- **Prim Secrets** — encrypted secrets surface; Knox is the engine underneath.
- **Prim Approvals** — human approvals / sign queue; Hancock is the engine underneath.

OK to show on https://prims.sh/desktop/ as soft frames. Engines stay under the
hood. Container admit/approve still gates what agents may see or act on. Do not
treat these as locked product surfaces in this charter yet.

## Memory Container

Prims Desktop is the user's memory container on this Mac — not a registry lab
and not a second store. Prim packs in the container are durable truth. Agents
operate those packs; they do not invent state in chat.

1. **In container ⇒ visible.** A prim dragged into Prims Desktop (or added with
   user approval) is what agents may see and operate. Not in the container,
   agents cannot.
2. **Approve to add.** Agents may request new packs or hierarchy nodes; the
   user approves. Prims Desktop is the approval surface as well as the data
   surface.
3. **Hierarchies OK.** The container may nest packs; flat junk-drawer is not
   the product.
4. **Document / pack first.** Opening and working a memory pack is the face.
   Registry / tool-catalog chrome is secondary (ops proof, not product face).
5. **Directed viewers.** A Prim viewer can be steered by an agent. ACP inside
   the app talks to the user's Grok or Cursor agent on their regular AI
   subscription. Chat lives in the app; the pack stays the file.

No Volta. No Kai control plane. This app hosts tools and connectors for open
packs; product/registry contract stays with Prim.

The product shape is a **personal memory pack**: it maintains Prims, Viewers,
Connectors, and Applets, and chats in the vein of Paseo. The user's regular AI
subscription drives the desk — grok cli, cursor-agent, or claude-code stay under
the hood; the user does not babysit those drivers. That design makes cloud
backup a natural business, and keeps Prims Desktop a sellable product if the
machine moves to offline AI — the container and packs are the offer, not the
model vendor.

## How It Grows

A new type or tool enters `registry.json`. The host lists it. The existing
surface tools render it. Edit-export of in-memory mutations is the next
milestone, not a new editor. Growth is catalog coverage and honest Save, not
more chrome. When a tool can export the zip it cited, Save starts writing
mutations. Until then the app must not pretend the editor’s memory is already
the file.

Each build registers the UTI with Launch Services. Quick Look can stay a
glance beside the app (not instead of it). iCloud documents can follow if the
pack should move with the person. None of those replace the registry. None of
those mint a new pack type. The measure stays: every registered type opens in
a citing tool, and Save still writes a `.prim`.

## Serves

parent: root

## Metric

name: great_score
kind: numeric
target: 90

Scored by `scripts/learn` against `GREAT.md`. 90 is Preview-grade land,
host, file, and place on this Mac. 100 adds notarize, Mail, and Messages.
`registry_types_hosted` (16) remains an invariant under Requirements, not
this loop's heading.

## Invariants

### host_not_store
must: The app writes the `.prim`. It does not become a second authority.
case: Save / Save As emit zip bytes; no parallel sidecar store
irreversible: true

### registry_is_the_catalog
must: Types and tools come from `registry/registry.json`.
case: unit test — every sample pack detects a kind and at least one citing surface tool
irreversible: true

### no_minted_tool_types
must: Do not register `prim.surface` or `prim.connector` as pack types.
case: grep Sources for prim.surface / prim.connector returns empty
irreversible: true

## Constraints

### host_not_store
must: The app writes the `.prim`. It does not become a second authority.
case: Save / Save As emit zip bytes; no parallel sidecar store
irreversible: true

### registry_is_the_catalog
must: Types and tools come from `registry/registry.json`. No hardcoded type list
  in the host chrome except seed files for New.
case: unit test — every sample pack detects a kind and at least one citing surface tool
irreversible: true

### no_minted_tool_types
must: Do not register `prim.surface` or `prim.connector` as pack types.
case: grep Sources for prim.surface / prim.connector returns empty
irreversible: true

## Requirements

### open_any_prim
must: File → Open and double-click open a `.prim` in Prim.app.
case: open -a "Prims Desktop" a sample pack; window shows the citing tool

### view_edit_save
must: The citing surface tool is on screen. File → Save writes the pack.
case: Open intent.emf.prim; Save As a temp path; Detect.open still returns emf

### all_registered_tools
must: For a detected kind, every citing surface and connector is choosable.
case: docket pack offers docket-editor and docket-webmcp; log pack offers log-editor and prim-sim

## Preferences

- Prefer WKWebView of the existing surface tools over rewriting them in Swift
- Prefer PrimSimCore for detect, zip, and registry
- Prefer a local scheme handler over a network port
