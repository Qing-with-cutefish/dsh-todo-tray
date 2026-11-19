# Tree Rings · dsh-todo-tray

> **Tree Rings**: a mandatory record shipped with every project, documenting why it grew this way, why each version changed, and which approaches were tried and abandoned — so whoever comes later can walk back to the last node that still holds.

This record follows the Tree Rings standard v1.0. The full Chinese record for this project is in `docs/年轮.md`; this page is the English definition of the format, meant to be reused.

## What a tree-ring file is

A tree-ring file is the project's memory of decisions, not a changelog. Cut it open and the cross-section tells you why the thing grew this way, which year had a drought (what broke), and which branch was tried and then pruned (what was abandoned). It exists because users do not review every change: the "why" must live in the file, not in a chat log. What is scarce in open source is recorded failure, not code.

## The five required sections

1. **What it is, who it is for** — one paragraph. No marketing words. Say whose problem it solves, and where it does not apply.
2. **Why it grew this way** — every entry must point to a real failure or a real user quote. "We used async IO for performance" is not acceptable; "the tray icon repainted every 200 ms and kept CPU at 12%, after switching to event-driven it dropped to 0.3%" is.
3. **Change record** — one ring per version, newest on top, old rings are never rewritten. Fixed fields per ring: version / date / who / background / what changed / why / blast radius / rollback / evidence (task id, path, hash).
4. **Dead ends** — approaches tried but not taken, with a negative constraint ("do not suggest this again"). This is the most valuable section: it saves whoever comes next from repeating the same failure.
5. **Pointers** — evidence, backups, acceptance reports, design docs, upstream task ids. Paths and links only, never copied content.

## Three maintenance rules

1. **Every version bump adds a ring, in the same change.** Old rings are append-only history: never edit them.
2. **If agreed behavior or acceptance criteria change, write it back to the mainline task as well.** This file is not the only source of truth; the upstream task will otherwise verify against the old criteria.
3. **A release or delivery is not complete unless this file is current.** Documentation-only changes are tagged `+doc` and do not bump the version number.

## Starting a new project

```
docs/年轮.md
├─ 1 What it is, who it is for
├─ 2 Why it grew this way      ← write this first, keep adding while building
├─ 3 Change record             ← v0.1 is the first ring
├─ 4 Dead ends                 ← open it when the first approach is rejected
└─ 5 Pointers
```

Language: write it in the team's working language. The file is named "tree rings" (年轮), not CHANGELOG — a CHANGELOG is only section 3.
