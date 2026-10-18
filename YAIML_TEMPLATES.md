---
role: document-templates
title: YAIML Document Starters
purpose: Dormant local writing aids for core and specialist memory.
not-here: Project facts, required empty documents, or new permissions.
durability: Durable starters; preserve local policy during refresh.
budget: About 2500 words; read only the relevant starter.
read-with: Local operating guide; affected core document.
update-when: Approved conventions or local template needs change.
agent-guidance: Adapt from evidence, preserve direction, omit unused sections, set role-appropriate budgets.
---
# YAIML Document Starters
Outlines are not project facts. Reuse documents; never instantiate the collection merely because it exists. Projects control names, headings, adaptations, additional roles.
Read selected headers first. Preserve meaning/governed retention; fill supported knowledge, retain consequential unknowns, remove empty headings/instructions, budget new memory. Repair discovery/pointers after creation. Companion names require no missing files.
|Need|Starter|
|---|---|
|State/direction/risks/priorities|SOT|
|Design/boundaries|ARCHITECTURE|
|Commands/procedures|MAINTAINER_GUIDE|
|Concepts/rules|DOMAIN_MODEL|
|Approved obligations/review|LEGAL_OR_COMPLIANCE|
|Human choices/corrections|PREFERENCES|
|Product promise/principles|PRODUCT_DOCTRINE|
|Active/accepted risks|RISK_REVIEW|
|Trust boundaries/constraints|SECURITY_MEMORY|
|Naming/distinctions|TERMS_GLOSSARY|
## SOT
````md
---
yaiml: 0.2
role: sot
title: SOT
purpose: Current engineering state and direction.
belongs-here: Goals, developer asks, current capabilities, risks, test/verification state, priorities, divergence, useful recent lessons.
not-here: durable architecture, command reference, complete history.
durability: volatile; synthesize and prune aggressively.
read-with: Architecture; Maintainer Guide.
update-when: direction, verified reality, risks, priorities, or useful engineering lessons change.
agent-guidance: Verify implementation; preserve human intent; mark uncertainty/conflicts; prune stale detail.
---
# SOT
SoT = State Of The. Use `SOT.md` or the established local filename. Adapt headings, omit empty sections, retain consequential unknowns. Replace changed facts in place; no session summaries or duplicate facts.
## Purpose And Direction
Identity, human asks, approved decisions, corrections, and relevant decision sources/owners; distinguish intent from implementation.
## Current State And Capabilities
Verified checkout capabilities with consequential evidence; separate proposals/deployment, label inference/unknowns. Keep unrelated passages stable; summarize completion as current capability.
## Active Risks And Divergence
Unresolved risks, debt, and conflicts among direction, design, code, tests, or contributors. Remove resolved items; preserve accepted risks and decision sources.
## Verification
Replaceable consequential results/gaps; distinguish defined/executed checks. Preserve prior date, revision, environment, limits; edits do not revalidate.
## Immediate Priorities And Open Questions
Next useful actions and shaping questions; link a larger backlog.
## Useful Lessons
Retain only conditions that change future action, active decisions, and rejected approaches worth preventing. Routine history belongs in Git.
````
## ARCHITECTURE
````md
---
yaiml: 0.2
role: architecture
title: Architecture
purpose: Durable system shape, boundaries, invariants, and intended architecture.
belongs-here: Current/intended architecture, ownership boundaries, data flow, invariants, debt, retired approaches.
not-here: current priorities, command reference, complete file inventory.
durability: durable; update when architecture changes materially.
read-with: SoT; Maintainer Guide.
update-when: boundaries, responsibilities, invariants, target architecture, or architectural debt change.
agent-guidance: Separate current, intended, transitional, uncertain, obsolete architecture; accidental implementation is not design.
---
# Architecture
Adapt headings; omit unused sections. Distinguish intended boundaries from accidental implementation.
## System Model And Components
Major components, responsibilities, data flow; no directory inventory.
## Boundaries And Invariants
Ownership of decisions, data, state, UI, integrations, and domain logic. Preserve lasting rules and decision sources.
## Current And Intended Architecture
Separate verified implementation, declared design, transitions, violations, and unresolved questions.
## Danger Zones
Fragile boundaries, concentrated responsibilities, generated outputs, sensitive modules; link maintainer procedures.
## Decisions And Retired Approaches
Retain useful rationale/rejected designs; prevent their accidental return; prune obsolete detail.
````
## MAINTAINER_GUIDE
````md
---
yaiml: 0.2
role: maintainer
title: Maintainer Guide
purpose: Current procedures, commands, diagnostics, and failure playbooks.
belongs-here: setup, commands, tests, build/run flows, debugging paths, important files, operations, release, recovery.
not-here: Product intent, durable architecture, full history.
durability: current-only; remove dead commands and obsolete paths.
read-with: SoT; Architecture.
update-when: commands, setup, diagnostics, release, or recovery procedures change.
agent-guidance: Verify command claims when practical. Mark environment-dependent or unverified procedures.
---
# Maintainer Guide
Adapt headings; omit unused sections; keep procedures actionable/current.
## Setup And Commands
Shortest checkout-to-work path, tools, assumptions. Separate executed/defined commands and unverified procedures. Retain consequential command, outcome, date, revision, environment; existence is not a pass.
## Focused Checks And Diagnostics
Test/build/lint/diagnostic procedures and interpretation; service/hardware/account/credential requirements without sensitive values. Retain sanitized outcomes, not logs. Name consequential invariants, independent expectation sources, comparison conditions, evidence gaps; matching outputs alone do not establish intent.
## Important And Dangerous Files
Editing boundaries and important files; no complete inventory.
## Failure, Release, And Recovery Procedures
Recurring symptoms, likely owners, evidence, recovery. Relevant release, rollback, backup/restore procedures and verification limits.
## YAIML Maintenance
Local operating-guide/template/YAIMLACP routes from init or equivalent guidance; no downloads/servers. Persistent instructions assess coordination from context and require first-use or changed-scope/cost confirmation. Record current scoped decisions, sources, limits, cancellation, gaps.
Record instruction routes, shared guidance, activation gaps, branch/reviewer responsibilities. Update affected memory without reminders; respect read-only scope. Keep edits passage-scoped; coordinate broad cleanup. Before integration reconcile actual target and combined code/memory despite clean merges; preserve independent work/conflicts and recheck affected evidence.
“Update YAIML”: identify supplied/local reference and revision; request missing references. Preserve memory, discovery layout/extensions, and concurrent edits. Migrate only with explicit authorization and checked compatibility.
“Prune SoT”/“compress YAIML”: synthesize current understanding; preserve decisions, evidence limits, unresolved issues, governed records. Report before/after sizes, justified growth, and necessary overages in the response. Keep private reference locations out of versioned files.
````
## DOMAIN_MODEL
````md
---
yaiml: 0.2
role: domain
title: Domain Model
purpose: Durable domain concepts, vocabulary, rules, unresolved questions.
belongs-here: Domain vocabulary, business/product rules, conceptual entities, ambiguity.
not-here: current implementation status, command procedures, complete history.
durability: durable; remove obsolete terminology and merge duplicate concepts.
read-with: SoT; Architecture.
update-when: domain concepts, terms, or rules change materially.
agent-guidance: Verify implementation; preserve human-approved domain intent; mark ambiguity.
---
# Domain Model
## Core Concepts
## Vocabulary
## Business Or Product Rules
## Declared Intent
## Links To Implementation Evidence
## Known Ambiguity
## Retired Terms
````
## LEGAL_OR_COMPLIANCE
````md
---
yaiml: 0.2
role: legal-or-compliance
title: Legal Or Compliance Memory
purpose: Human-approved legal/licensing/regulatory/compliance constraints; no casual rewrites.
belongs-here: human-approved legal constraints, compliance obligations, approval requirements.
not-here: Legal/compliance advice, implementation truth, casual inference, AI-generated legal conclusions.
durability: governed; destructive pruning requires human approval.
read-with: SoT; Architecture; Maintainer Guide.
update-when: Human supplies approved legal/compliance changes.
agent-guidance: Request human review for conflicts. Preserve human-approved statements. Do not invent IP claims, assign ownership, or select/change licenses without explicit human approval.
---
# Legal Or Compliance Memory
Record approved constraints, repository evidence, reviews, human questions; generate no legal conclusions. Follow approval/retention/privacy/access rules. Memory grants no organizational permission or professional conclusions.
## Authority And Review
Policy/legal/compliance owner; last meaningful review; higher-authority sources; required material-change review path.
## Human-Approved Constraints
## Current Repository Evidence
## IP And Rights Notes
## Approval Requirements
## Known Gaps
## Open Questions For Humans
````
## PREFERENCES
````md
---
yaiml: 0.2
role: preferences
title: Preferences
purpose: Durable human/project preferences guiding agents.
belongs-here: Style, workflow, product taste, collaboration norms, recurring human corrections.
not-here: Transient tasks, full history, implementation evidence except to explain preference conflicts.
durability: Durable, revisable; remove superseded/false preferences.
read-with: SoT; Architecture; Maintainer Guide.
update-when: Human states/corrects/retires preferences affecting future work.
agent-guidance: Preserve consequential human wording; label inference; one-off choices are not permanent rules.
---
# Preferences
## Human Preferences
## Product Preferences
## Engineering Preferences
## Collaboration Preferences
## Inferred Preferences
## Retired Preferences
````
## PRODUCT_DOCTRINE
````md
---
yaiml: 0.2
role: product-doctrine
title: Product Doctrine
purpose: Durable product principles, audience assumptions, experience goals, rejected directions.
belongs-here: Product principles, user promises, language decisions, experience boundaries, positioning, tradeoffs, rejected shapes.
not-here: sprint status, implementation details, command procedures, complete roadmap.
durability: durable; update when human product direction changes.
read-with: SoT; Architecture; Preferences; Terms And Glossary.
update-when: audience, product promise, experience doctrine, or rejected direction changes materially.
agent-guidance: Preserve declared human product intent; label inference; never rewrite doctrine to justify accidental implementation.
---
# Product Doctrine
## Product Promise
## Audience
## Experience Principles
## Product Language
## Tradeoff Rules
## Rejected Directions
## Known Divergence
## Open Product Questions
````
## RISK_REVIEW
````md
---
yaiml: 0.2
role: risk-review
title: Risk Review
purpose: Active/recurring project risks requiring review outside SoT.
belongs-here: security, privacy, reliability, legal, product, operational, release, and agent-workflow risks.
not-here: Professional advice, full audit history, generic worries, resolved risks without lessons.
durability: active-risk focused; preserve durable lessons and remove resolved noise.
read-with: SoT; Architecture; Maintainer Guide; Security Memory; Legal Or Compliance Memory.
update-when: Risk discovery, resolution, escalation, acceptance, or material change.
agent-guidance: Separate verified risks/suspicions; expose uncertainty. Agent notes are not professional advice. Exclude raw secrets, sensitive personal data, speculative legal/IP conclusions. Remove resolved active risks after retaining durable lessons.
---
# Risk Review
Project risk memory and review preparation; not professional legal, security, compliance, privacy, or operational advice.
## Active Risks
## Accepted Risks
## Useful Lessons From Resolved Risks
## Verification Notes
## Mitigations
## Escalation Or Human Review Needed
## Open Risk Questions
````
## SECURITY_MEMORY
````md
---
yaiml: 0.2
role: security
title: Security Memory
purpose: Project security assumptions, trust boundaries, reviewed constraints, evidence, active risks.
belongs-here: Human-reviewed constraints, trust boundaries, threat assumptions, sensitive data categories, active risks, open questions.
not-here: professional security advice, raw secrets, exploit details, complete audit history, command reference.
durability: durable with active-risk pruning.
read-with: SoT; Architecture; Maintainer Guide.
update-when: trust boundaries, authentication, authorization, secrets, or data exposure change.
agent-guidance: Verify security against code/configuration/tests/runtime; expose uncertainty. Agent notes are not professional security advice. Exclude raw secrets and restricted exploit details.
---
# Security Memory
Project memory is not a professional security assessment.
## Trust Boundaries
## Sensitive Data
Record data categories/locations, rules, risks, evidence, owners, questions under retention/privacy/access policy. Exclude raw secrets, credentials, tokens, private keys, passwords, customer personal data. Record permitted knowledge; this memory cannot decide storage safety.
## Authority And Review
Security owner/group; last meaningful review; higher-authority sources; required material-change review path.
## Authentication And Authorization
## Active Risks
## Known Divergence
## Verification Notes
## Open Security Questions
````
## TERMS_GLOSSARY
````md
---
yaiml: 0.2
role: terms-glossary
title: Terms And Glossary
purpose: Preserve project vocabulary, naming, domain terms, distinctions.
belongs-here: canonical terms, forbidden terms, aliases, distinctions, naming rationale, unresolved terminology.
not-here: full domain model, current priorities, command reference.
durability: durable; merge duplicates and retire obsolete terms deliberately.
read-with: SoT; Architecture; Domain Model.
update-when: terminology, naming, or project vocabulary changes materially.
agent-guidance: Preserve human-approved names; label disputed/inferred terms; never normalize away meaningful distinctions.
---
# Terms And Glossary
## Canonical Terms
## Important Distinctions
## Aliases And Legacy Names
## Forbidden Or Retired Terms
## Disputed Terms
## Open Naming Questions
````
