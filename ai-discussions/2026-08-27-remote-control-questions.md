# Remote control — 20 questions

Date: 2026-08-27
By: Prims
Source questions: Daniel, via the PrimsDesktop thread, used to lock the remote-control product (not just a screen).

These answers are from what Daniel already locked in the 2026-08-27 product conversation. **Locked** means his words. **Call** means Prims deciding from those locks. This file is the discussion record. It is not a stamp until Daniel says so.

Related locks already on disk:

- Remote controls are live control of other AIs, not a data pipe. Not a connector. Paseo-as-connector is dead.
- Remote controls are their own named block under Connectors, empty until set up. Copy: "Drive other AIs."
- Remotes do not open from Chat. Chat directs the open pack.
- Connectors stay first. Local on the person's computer. Cloud later is fine.
- A profile points at a Prims folder. Connectors, remotes, settings, and prims live in that folder. FDA stays on `Prims Desktop.app`.
- `prim.person` records are people in the world. They live under the active profile's `person/` tree.

---

## 1. What exactly is a remote control in Prims: an AI agent, a connection to an AI, a live session, or a durable capability?

**Locked:** live control of other AIs. Not a data pipe. Not a connector.

**Call:** a durable capability. A named remote you keep: the way this profile drives that other AI. The agent is the target. The connection is how you reach it. The session is one run. The remote is the thing that stays in the profile when the session ends.

## 2. Can one remote control point to many sessions, or is each remote control itself one persistent session?

**Call:** one remote, many sessions over time. Same pattern as a connector: iMessage is one connector with many threads. Alfred (or a Paseo cell, or a cloud agent) is one remote with many runs. Do not mint a new remote per session.

## 3. Is Alfred the remote control, while Claude Code is merely the target Alfred can drive?

**Call:** yes, when Alfred is what you are driving. The remote is the thing you hold. The target is what it operates. If the person is driving Claude Code directly, Claude Code is the remote. Do not invent a required middleman so every target has an Alfred.

## 4. Can Prims Desktop itself directly drive Claude Code/Codex/etc., or must it always go through something like Alfred?

**Call:** Desktop can drive a target directly when that target is on this Mac and addressable (a local CLI, a local controller). A controller (Alfred, Paseo, a cell catalog) is for many targets or a fleet. "Must always go through Alfred" is the same wrong noun as "must always be a connector."

## 5. Should a remote control exist only when the target is currently reachable, or can it remain installed/offline and reconnect later?

**Locked:** connectors stay set up when they need sign-in. Live is a status, not existence.

**Call:** the remote remains installed and offline, then reconnects. Same as Dally Needs sign-in. Unreachable does not delete the remote.

## 6. What should the user see as the primary status vocabulary: Ready / Busy / Offline / Failed, or something different?

**Locked:** connector subtitles are Live / Needs sign-in. Not last-message preview. Not catalog slugs.

**Call:** use that same vocabulary. Live, Needs sign-in, Offline. Busy is a subtitle on a Live remote, not a first-class state. Failed is a one-shot on a run, not the rail word.

## 7. When I click a remote control, is the main experience fundamentally a chat, a command console, an activity timeline, or a hybrid?

**Locked:** remotes do not open from Chat. Chat directs the open pack.

**Call:** hybrid. You give intent in language and you watch it work live. It is not the Chat door. It is not a terminal costume. The prove is seeing the other AI move, then taking the wheel.

## 8. How much of the remote AI's internal activity should Prims expose: every tool call, just milestones, or only final results unless expanded?

**Call:** milestones on the face. Expand for tool calls. Final-results-only is a log, not a remote. Every-tool-call as the default is a debugger, and Debug already has a window.

## 9. Do you want the user to be able to interrupt, pause, resume, and redirect a running remote AI from this screen?

**Call:** yes. Interrupt and redirect are the product. Pause/resume if the target can. If you cannot take the wheel, it is not a remote control.

## 10. Can a single remote control command another AI to work on any arbitrary location, or should each session have an explicit scope such as /desktop, a repository, a browser, or a Prim?

**Locked:** a profile is a folder. Drag-in / approve is how agents see things.

**Call:** each session has an explicit scope: a folder, a repo, a Prim, a browser, a machine area they granted. Arbitrary whole-disk is a grant, not the default.

## 11. Should Prims enforce the scope technically, or is scope merely descriptive metadata?

**Locked:** FDA on the wrong binary was the anti-pattern. The running `.app` is the TCC client. First shot has to work.

**Call:** enforce it. Descriptive scope is how we granted the helper and called it done.

## 12. What permissions should be visible before connecting a remote control—for example read files, write files, execute commands, use browser, contact other agents?

**Locked:** FDA happens when they set up a connector, not on first launch, and it must work on the first shot.

**Call:** same moment for remotes. Before connect, show what it can read, write, run, browse, and who else it can talk to. No silent extra identity.

## 13. Is "Set up remote control" primarily about entering an endpoint/protocol, discovering something already running locally, signing into a service, or all three?

**Call:** all three, in that order of commonness: discover what is already on this Mac, then sign in, then paste an endpoint. The empty Remote block is "Drive other AIs," not "paste a URL."

## 14. Should Prims automatically discover available AI controllers on the Mac, the same way Connectors discovers local capabilities?

**Locked:** Connectors discovers local capabilities on this Mac.

**Call:** yes. Discover local controllers the same way. First shot. Do not make them type a socket unless discovery missed.

## 15. Do you expect remote controls to be mostly local-machine targets, mostly cloud agents, or equally both?

**Locked:** secret sauce is local on the person's computer. Cloud later is fine. Not the point.

**Call:** local-first. Cloud remotes are allowed later. "Equally both" on day one is how Connectors dies.

## 16. When Alfred tells Claude Code to inspect /desktop, who owns the resulting history: Alfred, Claude Code, the session, Prims Desktop, or a Prim?

**Locked:** packs are durable truth. Agents operate packs. A profile folder holds that profile's prims. `prim.product` is where product decisions live.

**Call:** a Prim in the active profile owns the history. Alfred and Claude do not. The session is not the store. Desktop is the host, not a second database.

## 17. Should every meaningful remote-control run automatically generate a durable Prim/audit artifact, or only when the user explicitly saves one?

**Call:** a meaningful run writes a Prim in the profile. The user can discard. Explicit-save-only trains the habit of losing the work in a chat transcript.

## 18. Can remote controls talk to each other—for example Alfred delegates to Codex, Codex asks a browser operator, and Prims shows the whole chain?

**Locked:** live control of other AIs. Remote controls are the next named thing after connectors.

**Call:** yes. Chains are allowed. Prims shows the chain on that remote. Each hop is not a new connector and not a new sidebar door.

## 19. What is the single moment that should make a first-time user say "oh, this is different": discovering an AI automatically, issuing one natural-language command, watching another AI execute live, taking control mid-run, or something else?

**Call:** watching another AI execute live on their machine from this app, then taking the wheel. Discovery is setup. A command box is Chat. The remote is the live take.

## 20. Five years from now, what do you want the Remote Controls section to have become: a universal remote for every AI, an agent operating system, a command center for fleets, or something even broader?

**Locked:** connectors are the first of many things we add, not the only surface forever. Remote controls are next and different.

**Call:** a universal remote for the AIs this person uses. Not an agent OS. Not a fleet command center first. Local remotes, then cloud, then a chain. The OS fantasy is how we skip the face again.

---

## Still open

Daniel has not stamped this file. E–I paper frames are still a proposal. Remote stays the named empty block under Connectors until he says otherwise.
