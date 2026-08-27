# Document-first sketch (Prims Desktop)

North star: Mac user-memory container. Packs in container = durable truth.
Agents operate only what is in; approve-to-add; hierarchies OK; data + approval
surface. Viewers agent-directable via in-app ACP (user's Grok/Cursor sub).

## Face (what the user sees)

1. **Library / container** (primary sidebar, not Registry catalog)
   - Drag `.prim` in → admitted to container (agent-visible)
   - Hierarchy: folders/nodes; packs as leaves
   - Pending agent requests: "Agent asks to add X" → Approve / Deny
2. **Document stage** (center)
   - Open pack hosts citing surface/viewer (existing WKWebView path)
   - Chrome: title, kind, dirty, Open/Save/Copy — tool picker secondary
3. **Agent chat** (right or bottom sheet)
   - ACP session to Grok or Cursor agent on user subscription
   - Agent may: navigate viewer, propose edits, request-add (needs approve)
   - Agent may not: invent pack state outside container membership

## Registry

- Collapsed by default / "Catalog" disclosure for ops
- Connectors listing (incl. local overlay) remains ops proof, not the home face

## Agent control loop

```
user/agent chat (ACP)
    → commands against open viewer + container API
    → read/write only packs in container
    → request-add → approval chrome → admit or reject
    → Save writes `.prim` bytes (host_not_store)
```

## Out of scope here

- Volta / Kai control plane
- Minting prim.surface / prim.connector pack types
- Replacing registry contract (Prim owns product/registry)

## Next build slices

1. Container model on disk (library index + hierarchy) separate from open document
2. Default NavigationSplitView: library | document (registry detail-only)
3. PendingRequests approval strip in chrome
4. ACP chat panel stub (wire provider later)
