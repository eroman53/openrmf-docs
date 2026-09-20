# STOOGE — User Quick Reference

For people who *use* STOOGE: ISSOs, analysts and assessors working in the UI.
For the service/route/NATS cheat sheet see the Quick Reference artifact; for how
to exercise features on the test stack see `STOOGE-Testing-Quick-Reference.md`.

> A formatted, shareable version is published as an artifact:
> **Working in STOOGE** — https://claude.ai/artifact/Um5JzD8CzNnNeAM8UNdhHK

Applies to **v0.9.0-beta**.

---

## Signing in and what you can do

You log in through Keycloak; STOOGE reads your roles from that login. Roles
stack. Access can *additionally* be restricted per system package, so two people
with identical roles may see different systems.

| Role | What it lets you do |
|---|---|
| **Reader** | View everything you have package access to. No edits. |
| **Editor** | Reader, plus edit checklist findings, upload scans, maintain POA&M, run reconciliations, manage tasks. |
| **Assessor** | Record the assessment side: compliance statements, implementation status, assessment dates, review frequency. |
| **Download** | Export checklists, reports and the POA&M workbook. |
| **Administrator** | All of the above, plus package creation, access grants, checklist unlocking, catalog/overlay import, Scan Watch config, OS-classification mappings. |

---

## Where things live (19 sidebar pages)

**Day-to-day work**

| Page | Use it to | Need |
|---|---|---|
| Dashboard | Systems at a glance — scores, open findings, recent change | Reader |
| System Packages | Open a system, browse checklists, set who may see it | Reader |
| Upload | Bring in a `.ckl`, SCC XCCDF results, or a `.nessus` file by hand | Editor |
| Tasks | Work assigned to you; assign work to others | Editor |
| POA&M | Work the live POA&M record; export in eMASS format | Editor |
| Compliance | Generate the system compliance listing | Reader |

**Control compliance**

| Page | Use it to | Need |
|---|---|---|
| Control Baseline | FIPS 199 categorization, authority overlay, system type, tailoring | Assessor |
| Control Assessment | Compliance statement per control; findings roll up here by CCI | Assessor |
| ConMon Calendar | When each applicable control falls due; materialise tasks | Assessor |

**Monitoring and posture**

| Page | Use it to | Need |
|---|---|---|
| ConMon | SP 800-137 posture: freshness, coverage, currency, aging, overdue controls | Reader |
| Authorization | AO view — ongoing-authorization posture across the portfolio | Reader |
| Trends | Vulnerability counts over time; new / resolved / persisting | Reader |
| Inventory | Asset registry by OS class; fleet findings | Reader |
| PPSM | Approved ports baseline, reconciled against what scans found | Editor |
| Container Security | Run Trivy against a target folder | Editor |

**Setup and records**

| Page | Use it to | Need |
|---|---|---|
| Templates | Browse the STIG checklist template library | Reader |
| Notifications | Choose what gets emailed, incl. the weekly ConMon digest | Reader |
| Scan Watch | Point STOOGE at a share so scan drops import themselves | Administrator |
| Audit | Change history — who changed what, when, from what to what | Reader |

---

## The four workflows

### 1. Standing up a new system

1. **Create the package and grant access** — *System Packages*. Restrict to the
   right teams, or leave unrestricted and everyone sees it.
2. **Categorize it** — *Control Baseline*. C/I/A; STOOGE takes the high-water mark.
3. **Pick the overlay and system type** — *Control Baseline*. This **selects**
   the control set; it does not filter the NIST baseline. Saving with no system
   type is refused (it would select nothing).
4. **Tailor, with a reason** — justification required, history kept. Withdrawn
   controls cannot be added.

### 2. Getting scan and checklist data in

1. **Choose how it arrives** — *Upload* by hand, *Scan Watch* polling a share, or
   *Container Security* for Trivy.
2. **Let the delta run** — every upload is an immutable snapshot; STOOGE computes
   new / resolved / persisting and tracks firstSeen / lastSeen.
3. **Check what it produced** — *Trends* for movement, *Inventory* for new hosts,
   *PPSM* for new ports. POA&M drafts appear on their own from checklist saves.

### 3. Working findings to closure

1. **Fix the checklist** — status, comments, finding details. Bulk edit applies
   one change across many findings and **previews the transitions** first.
2. **Maintain the POA&M** — drafts and status moves are automatic; hand-typed
   fields are never overwritten. Closure becomes "completed — pending
   verification", never deleted.
3. **Attach the evidence** — journal entries take file attachments on any record.

### 4. Proving continuous monitoring

1. **Say how each control is implemented** — *Control Assessment*. Record an
   assessment date **and a review frequency**, or the control never comes due again.
2. **Read the year** — *ConMon Calendar*. Watch the "no cadence" count.
3. **Turn the calendar into work** — materialise a 30-day / 90-day / rest-of-year
   window into tasks. Re-running is safe: it skips what exists and never edits a
   task someone has touched.
4. **Watch the posture** — *ConMon* and *Authorization*.

---

## System type decides the control set

Exactly four types, from the DCSA controls workbook. The overlay **selects**
applicable controls — about half of what it selects sits outside NIST moderate.

| Type | Controls | Notes |
|---|---:|---|
| **WAN/LAN** | 485 | The DCSA baseline; default for networked enclaves |
| **P2P** | 407 | Peer-to-peer; drops 78 |
| **MUSA** | 366 | Multi-user standalone; drops 119 |
| **SUSA** | 348 | Single-user standalone; drops 137 |

Each control carries a minimum SLCM frequency, which builds the calendar. A
WAN/LAN system is ~3,577 occurrences a year — which is why the calendar
materialises a window at a time.

---

## What the statuses actually claim

### Control Assessment — what the scans say

| Status | Means |
|---|---|
| **No open findings** | Nothing mapped is currently failing. **Not** "satisfied" — only an assessor decides that, via implementation status. |
| **Open** | At least one mapped finding is open. |
| **Not Reviewed** | Checks reached the control; nobody adjudicated them. |
| **Not applicable** | Mapped checks were marked not applicable. |
| **No scan coverage** | No automated check reaches this control. Common and expected — these need a written statement. |

### ConMon Calendar — what the year says

| Status | Means |
|---|---|
| **met** | The recorded assessment date falls inside the period this occurrence *covers* (annual covers the year, quarterly its quarter, monthly its month). |
| **missing-evidence** | Period passed with no assessment date inside it. |
| **upcoming** | Not due yet. |

**"met" is a floor, not a tally.** A control stores *one* assessment date, so
only the period containing it can read met. Earlier periods show as missing
evidence even when the work was done — nothing recorded it. Per-occurrence
records would fix this; they do not exist yet.

---

## Gotchas

- **Automation never overwrites you.** POA&M and PPSM auto-create and refresh
  what the scanner owns and leave hand-typed fields alone. Discovered rows are
  never deleted.
- **A locked checklist is read-only.** Saving returns a conflict; an
  Administrator must unlock. Bulk edit across a STIG type silently skips locked
  checklists.
- **Restricted packages just vanish** — no warning, absent from every list and
  dropdown. Ask an Administrator whether you should be on the grant.
- **A control with no cadence never comes due.** Counted separately on the
  calendar; that count is the number worth staring at.
- **Scan evidence is not an assessment.** The scan badge is informational.
- **Just after a redeploy, wait ~30s** before trusting an authorization error —
  Keycloak is still coming up.

---

Not in this beta: document generation (SSP, SAR, RAR, CCRI).
