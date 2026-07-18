# Premortem transcript: owdata implementation plan

Date: 2026-07-18
Subject: the owdata index metapackage plan, issues #1 to #12 in openwashdata/owdata
Method: Gary Klein premortem. Frame: it is July 2027, twelve months out, and the plan has failed. Eight independent investigators worked backward to explain why, followed by an adversarial counter-check and a synthesis.

## Gathered context

What: owdata, an index and documentation metapackage for the ~70 openwashdata R data packages. Harvested catalog tibbles (owd_packages, owd_datasets, owd_variables) shipped as package data, owd_search() and owd_install(), a pkgdown catalog site including a ~2,500-row cross-org variable dictionary, r-universe registration for all packages, a weekly automated harvest committing to main, a version-tier inclusion policy tied to pkgreview (dev / candidate / catalogued, with a transitional legacy rule for ~29 DOI-holding sub-1.0.0 packages), and a migration campaign to bring existing packages into the policy.

Who it affects: the openwashdata core team (one plan author working part-time, one colleague whose involvement is an open discussion), the outside contributors who own the ~70 data package repos, and WASH-sector data users who today find data through openwashdata.org and its Google Sheet backed catalog of 56 published packages.

Success at twelve months: the catalog is live with about 32 packages at launch, the site is the org's living catalog, one-line installs work via r-universe, the weekly harvest runs at near-zero maintenance, the Google Sheet is retired, maintainers follow the tier policy, and the migration campaign completes with zero legacy rows.

Relevant external facts: pkgreview, the review tooling the tiers depend on, is itself mid-overhaul with implementation starting September 2026; each review is heavyweight (four issues per package, human check-ins and sign-offs). The org pipeline question (fairenough versus pkgreview bundling) is still an open discussion (pkgreview issue #20). The owdata repo currently contains only a README; the plan lives entirely in the issues.

## Raw premortem: failure reasons found

- R1. The migration campaign stalls: ~45 heavyweight reviews on one part-time maintainer, using tooling under rebuild; the grandfather rule never gets deleted and the tier policy never becomes meaningful.
- R2. The "bump to 0.1.0 is the review request" signal has no listener and no enforcement; requests go unseen, packages get promoted to 1.0.0 without review, and Version plus DOI stops meaning reviewed.
- R3. Silent harvest rot: schema-only gates let content-level garbage publish weekly; the problems tibble, harvest-failure issues, and an expiring org PAT go unwatched.
- R4. The r-universe cutover breaks distribution: washr drops out of the superseded registry or serves a broken default-branch state; dev-tier build failures make the universe look abandoned; org-owner permissions and the PAT are unowned coordination points.
- R5. Two-catalog divergence: the website switchover is an unowned follow-up that never happens; the Google Sheet stays the real catalog and owdata's contradicting numbers kill trust and adoption.
- R6. Solo-capacity overcommit: the coding phases ship, the coordination phases stall; working code, dead project.
- R7. Wrong distribution model: a volatile living index shipped as installed package data is frozen at each user's install date; same version, different data; stale search results.
- R8 (found by the adversarial counter-check). No mandate: the plan encodes governance over other people's repos with no consent, announcement, or objection-handling step anywhere in the 12 issues.

## Deep dives

The eight investigator reports follow, verbatim apart from formatting.


## R1 Migration campaign stalls

STORY: The arithmetic was visible from day one and nobody ran it. Phase 5 required ~45 reviews (29 legacy + 16 queued at 0.1.0), each pkgreview cycle being four issues, four PRs into dev, one dev-to-main PR, with human check-ins before commits and human sign-off at every gate. Even at an optimistic one review per part-time week, that is a full year of throughput, the entire success horizon consumed by Phase 5 alone. Worse, pkgreview's own v1.1.0-to-v1.3.0 overhaul only started implementation in September 2026, so the first months of the campaign ran on tooling the maintainer knew was about to change, creating a rational incentive to wait. The first tip: October 2026, when the maintainer paused the queue "until v1.3.0 lands", a pause that became the default state, because the harvest (#9) was humming, the site (#7) was live, and the catalog looked done. The second tip: the grandfather rule made stalling invisible. Legacy = TRUE packages counted as catalogued, so the launch metric ("~32 packages") was satisfied without a single review completing. The dated transitional rule had no enforcement mechanism; its date slid twice. The scripted PR campaign to bump 29 packages to 1.0.0 was blocked behind reviews that never finished; by July 2027, roughly 5 reviews were done, 29 legacy rows remained, and 0.1.0 meant nothing because bumping to it queued you behind a two-year backlog.

ASSUMPTION: That a review process designed for occasional, one-at-a-time quality gating could be run 45 times as a batch campaign by one part-time person without changing the process itself.

WARNINGS:
- Reviews completed per month: fewer than 4 in any month after campaign start means more than 12 months to clear the queue.
- The legacy = TRUE row count in owd_packages not decreasing across two consecutive weekly harvests after the campaign officially began.

## R2 The 0.1.0 review-request signal has no listener

STORY: The convention shipped in #2 and was documented in the #7 versioning-policy article and the #11 washr vignette update: "bump to 0.1.0 IS the pkgreview request." What never shipped was anything that heard the request. No GitHub Action watched DESCRIPTION diffs, no webhook pinged the maintainer, no issue got auto-opened. The first tip came in October 2026, right after the migration campaign (#10) started: three contributors outside the core team followed the vignette exactly, filled dictionaries, bumped to 0.1.0, and waited. The maintainer, part-time and buried in the weekly-harvest work (#9), only discovered the bumps by accident six weeks later while eyeballing harvest diffs. Two of the three contributors had already stopped responding. Word spread in the org that review requests go into a void. Second tip, February 2027: a contributor who had waited three months read the policy article, noticed nothing technically prevented a 1.0.0 bump, versioned their package 1.0.0, ran the standard washr Zenodo release, and got a DOI. The harvester (#4) did exactly what #2 specified, Version >= 1.0.0 plus DOI in CITATION.cff equals catalogued, because the four-closed-review-issues check had been deferred as "optional later hardening". The package appeared with a catalogued badge on the pkgdown site (#7) and became a default in owd_install() (#6). Two more packages followed the same path by May. Meanwhile the 29 legacy = TRUE packages already displayed catalogued badges without review, so unreviewed-but-catalogued looked normal, not anomalous. By July 2027 the tier column mixed reviewed, grandfathered, and self-promoted packages indistinguishably, and the org quietly went back to trusting the Google Sheet.

ASSUMPTION: That a version number could function as a request and a gate simultaneously, in an org where no one is paid to watch versions and nothing but norms prevents writing "1.0.0".

WARNINGS:
- Any package at 0.1.0 or above for more than 14 days with zero pkgreview issues opened against it (mechanically checkable from harvest data).
- Any catalogued-tier package whose repo lacks the four closed review issues and postdates the grandfather cutoff; the count should be exactly zero, and the first nonzero harvest is the alarm.

## R3 Silent harvest rot

STORY: The rot began in September 2026, when washr shipped a template update that wrote dictionary.csv with a new variable_type column ordering and semicolon delimiters for multi-value descriptions. Not one of the fixture pathologies from #3 covered it; fixtures froze the KNOWN pathologies of July 2026 while the templates kept evolving. The hardened parser did exactly what it was designed to do: it did not abort, it quietly shunted three new packages into the problems tibble and half-parsed two others into garbage descriptions and NA DOIs. The #4 threshold did its job too: 5 of 72 packages is 7 percent, under the 10 percent tripwire; no shipped table was empty. CI green. The Monday 03:00 UTC run committed as github-actions[bot] straight to main, pkgdown rebuilt, and the catalog published rows with blank DOIs and tier badges computed from missing metadata. Schema tests were the gate, and schema tests assert names, types, non-emptiness, never values. NA is a valid character column entry. The problems tibble was "printed at the end" of a log nobody reads. Meanwhile in November the org PAT expired; registry sync failed, the if: failure() step dutifully opened a harvest-failure issue, into a repo the part-time maintainer was not watching between grant deadlines. The issue got weekly bot updates and zero human views. Each week the drift compounded: fairenough churned again in January, failure crept to 9 percent, still under threshold. In April 2027 a downstream researcher emailed asking why a package's DOI resolved to nothing and the tier badge contradicted the package README. The catalog had been visibly wrong for roughly six months. "Near-zero maintenance" had meant near-zero observation.

ASSUMPTION: That absence of pipeline errors implies correctness of published content; silent degradation was designed in as a feature (tryCatch, problems tibble, 10 percent tolerance) with no human ever required to look.

WARNINGS:
- Problems-tibble row count or NA-rate in DOI/tier/description columns trending up week-over-week across harvest runs (trivially diffable in the git history of the committed tables).
- A harvest-failure issue open more than 14 days with only bot comments and no assignee activity.

## R4 r-universe cutover breakage

STORY: The cutover shipped in the wrong order. The maintainer, not an org owner, created openwashdata.r-universe.dev and packages.json himself, then waited eleven days for an owner to install the r-universe GitHub App and mint the org PAT. During that window the custom registry was already live, and it superseded the auto-generated CRAN registry immediately. The first packages.json, generated from the harvest of data packages, listed the ~70 data packages, but the "washr MUST be listed explicitly" note lived in the plan, not in the harvester code. washr vanished from the universe for two weeks; it was the one package external users actually install. When it was re-added, the entry tracked its default branch mid-refactor, so install.packages("washr") served a dev snapshot with a broken template function. Nobody noticed because the success criterion only tested washmalawi. Meanwhile the "free CI feedback, not blockers" framing collided with reality: ~30 dev-tier packages went red on the universe dashboard simultaneously. The landing page, the exact URL owd_install() and the new pkgdown site advertised, showed a wall of failed builds. Two external users filed issues asking if the org was abandoned. The killing blow came in month five: the org PAT (fine-grained, 90-day expiry, owned by the one owner who set it up) expired silently. The Phase 4 sync step failed, but nobody watched a weekly cron in a repo with one part-time maintainer. data-raw/packages.json and the registry repo drifted for four months; new packages harvested into owdata's catalog returned 404 from install.packages() while the site listed them as installable.

ASSUMPTION: That registry correctness was a one-time setup task rather than a continuously monitored dependency, and that the maintainer controlled all the org-level levers it required.

WARNINGS:
- Diff between the harvester's data-raw/packages.json and the registry repo's packages.json non-empty for more than 1 week, or the sync workflow's last run shows failure.
- washr's universe build commit SHA does not match its latest release tag; universe dashboard failure count exceeds ~25 percent.

## R5 Two-catalog divergence, no adoption

STORY: owdata shipped on schedule in autumn 2026. The pkgdown site went live with owd_packages, owd_datasets, and the 2,500-row variable dictionary, technically everything issues #5 and #7 promised. The tip point came immediately: issue #11, the openwashdata.org switchover, was explicitly scoped as "nothing here blocks the metapackage", lived in a website repo outside the issue list, and had no owner or date. So it entered nobody's queue. The metapackage was "done"; the funding milestone was met; attention moved on. openwashdata.org kept rendering the Google Sheet's 56 published packages via washr::update_gsheet_metadata(). The second tip was the tier policy collision. The one early visitor path, a researcher clicking from openwashdata.org's data page, landed on a catalog claiming 32 catalogued packages, 29 of them flagged legacy = TRUE, with the rest labelled unreviewed candidate. The org's own front door said 56 published. Nobody had reconciled the vocabularies. A user who found their dataset marked "candidate, unreviewed" on owdata but "published" on the official site trusted neither. Maintainers of new packages faced a practical choice: update the sheet (which the actual website renders) or the owdata pipeline (which nothing renders). They updated the sheet. By spring 2027 the sheet and owdata had drifted by five packages. The variable search, the killer feature, never found its audience because there was no announcement plan, no prominent link, and search engines kept ranking the established openwashdata.org page. By July 2027, owdata analytics showed dozens of monthly visitors, mostly the team itself.

ASSUMPTION: That building a better catalog would, on its own, make it the catalog; that distribution and switchover would somehow happen without an owner, a date, or a plan.

WARNINGS:
- 30 days post-launch: issue #11 still unassigned in the website repo, and openwashdata.org's data page contains zero links to the owdata site.
- washr::update_gsheet_metadata() calls or sheet edits continue after owdata launch; each one is a maintainer voting for the old catalog.

## R6 Solo-capacity overcommit

STORY: Phases 1 and 2 shipped fast; by late 2026 the scaffold, hardened parsers, harvest orchestrator, and pkgdown catalog were done, because AI-assisted solo coding is exactly what the maintainer is good at and exactly what fills the gaps between other commitments. The tipping point came in September 2026, when pkgreview's v1.1.0 implementation window opened on schedule. pkgreview had its own premortem-derived issue list and a three-milestone roadmap; it consumed the coordination bandwidth owdata's phases 3 to 5 needed. The r-universe registration stalled first: making the repo public and registering ~70 packages required org-level decisions, and the discussion issue with the colleague ("I would like to review this with you and identify our next pipeline") was never converted into a meeting, so the tier policy sat encoding a fairenough-vs-pkgreview answer nobody had ratified. Registering 70 packages under an unratified policy felt presumptuous, so it waited. The migration campaign never really started. Bringing ~45 packages through review meant PRs across 29 external repos, but every review also ran through pkgreview, the very tool being rebuilt, so migration was deferred "until v1.2.0 lands". The weekly harvest ran against a half-registered universe, producing a catalog with legacy rows nobody trusted. The website switchover, owned by nobody, defaulted to the old site. By July 2027: polished package, live-but-ignored site, zero operational adoption. Working code, dead project.

ASSUMPTION: That the maintainer's demonstrated throughput on solo coding phases would transfer to coordination-heavy phases running concurrently with two other roadmapped projects.

WARNINGS:
- Phase 2 complete but the r-universe registration issue (phase 3) has zero commits or comments 30 days after phase 2 closes.
- The colleague's pipeline discussion issue passes 60 days with no scheduled review and the tier policy unchanged and unratified.

## R7 Wrong distribution model for a living index

STORY: The tipping point was baked in at issue #5: usethis::use_data() welded a weekly-changing catalog to the R package installation lifecycle. The weekly harvest (#9) committed to main every Monday, the pkgdown site rebuilt, and the team saw freshness everywhere they looked, because they looked at the site. Users looked at owd_packages() from a library installed in September 2026. By January 2027 the org had added six packages and re-tiered a dozen after reviews; owd_search() returned none of that. The startup message honestly said "(harvested 2026-07-06)", but a date six months old at attach time prompted no one to reinstall. r-universe users only got current data at first install, then froze like everyone else, since nothing bumped DESCRIPTION's Version on harvest commits, so update.packages() saw nothing to update. That same non-bump made the failure undebuggable: two users on version 0.2.0 filed contradictory issues about owd_datasets row counts, both correct for their install week. Maintainers could not reproduce either. The "CRAN-plausible later" goal made it worse: an eventual CRAN submission would freeze one snapshot for months, with data-only re-releases impossible, so the most discoverable install channel would be the stalest. By spring 2027, install links in frozen catalogs pointed at renamed repos and moved artifacts; a workshop instructor publicly told attendees to "just use the website, the package is out of date", and the success criterion, trusting owd_search() to answer "what data does the org have", was dead.

ASSUMPTION: That users would reinstall the package roughly as often as the data changed; that installation frequency could track harvest frequency.

WARNINGS:
- Median gap between users' stamped harvest date (reportable via the startup message or an owd_age() check) and the current Monday harvest exceeding ~4 weeks.
- First GitHub issue reporting a package or tier that exists on the site but not in owd_packages(), or two same-version installs disagreeing on row counts.
## R8 No mandate: governance without consent (adversarial counter-check)

The counter-check's verdict: every listed failure treats non-adoption as a capacity or mechanics problem. None names the legitimacy problem. owdata unilaterally redefines what other people's version numbers and DOIs mean, retroactively, in a public ETH-branded index, and the 12 issues contain no announcement, consultation, or objection-handling step. Even with infinite maintainer time and perfect enforcement, the governed parties can simply refuse.

STORY: Issue #2 ships the tier policy as code before anyone outside the plan author has agreed to it, including the second maintainer, whose fairenough-versus-pkgreview decision the policy hard-codes while that discussion is explicitly still open. The first harvest publishes a table that publicly reclassifies finished work: 29 DOI-holding packages get legacy = TRUE, a visible asterisk on cited, Zenodo-archived output whose external authors (students, partner orgs) were never told; 16 packages at 0.1.0 are implicitly labeled unreviewed candidates. The org's funder-facing story of 56 published packages becomes a stratified hierarchy nobody signed off on. Then issue #10 makes it invasive: scripted 1.0.0-bump PRs into contributors' repos. A version bump is an author act with real side effects: new Zenodo version DOIs, changed citations, an implicit claim of stability. Absent maintainers never merge; present ones ask who authorized this; the second maintainer objects that the tier semantics preempt the pipeline decision. The politically safe retreat is to declare tiers informational, which guts issues #2, #6 (owd_install tier semantics), #7 (the versioning-policy article), and #10. The code all works. The policy it exists to express is dead on contact: not stalled, vetoed.

ASSUMPTION: That publishing a classification scheme for other people's work is a technical act rather than a governance act requiring their consent.

WARNINGS:
- Issue #2 merges while the fairenough/pkgreview thread with the second maintainer is still unresolved: code outrunning agreement.
- The first contact any external contributor has with the tier system is a bot PR or a legacy = TRUE flag on the public site, followed by "why was my package changed or labeled" comments and unmerged bump PRs.

## Synthesis

### The most likely failure

R1, the migration campaign stall, driven by R6, solo capacity. The arithmetic is unforgiving: ~45 reviews of four issues and five PRs each, run by one part-time person who is simultaneously rebuilding the review tooling those reviews depend on. At an optimistic one review per week the campaign alone consumes the entire twelve-month horizon. The grandfather rule makes the stall invisible because legacy = TRUE rows satisfy the launch metric without a single review completing.

### The most dangerous failure

R8, the missing mandate. Capacity problems can be fixed with time; a vetoed policy cannot. If the tier scheme publicly relabels colleagues' and contributors' published, DOI-holding work without their consent, the likely outcome is not slow adoption but active objection, and the safe retreat (tiers become informational) guts the point of issues #2, #6, #7, and #10 while burning the relationships the migration campaign needs. R2 is its mechanical twin: even absent objections, an unenforced version-plus-DOI proxy quietly stops meaning reviewed.

### Likelihood x impact

High probability, high damage (act first): R1 migration stall, R5 two-catalog divergence, R6 solo overcommit, R8 no mandate.

Medium probability, high damage (insure): R2 gamed tier signal, R3 silent harvest rot.

High probability, medium damage (design fix now, cheap): R7 stale package data.

Medium probability, medium damage (checklist items): R4 r-universe cutover breakage.

### The hidden assumption

Across all eight analyses: the plan assumes mechanical signals can substitute for human agreement and human attention. Version plus DOI substitutes for review consent (#2), green schema tests substitute for content correctness (#9), an unowned follow-up substitutes for adoption (#11), and publishing a policy substitutes for ratifying it. The single load-bearing sentence is "Version + DOI is a trustworthy mechanical proxy": every phase leans on it, and it is only true if the social process it proxies exists, has capacity, and has been agreed to by the people it governs.

### The revised plan

1. Ratify before you build (R8, R6). Convert pkgreview issue #20 into a scheduled decision meeting with the second maintainer. Get a written sign-off on the tier policy recorded in the owdata repo before issue #2 merges. Draft a short announcement to contributors, and rename the public-facing flag from "legacy" to something neutral such as "published before the 2026 review standard".
2. Give the review request a listener (R2). Move the four-closed-review-issues check from optional later hardening into the day-one harvester (one API call per candidate or catalogued package), and add a harvest step that auto-opens a review-request issue when a package first reaches 0.1.0. The tier badge for a package that fails the check renders as flagged, not catalogued.
3. Rescope the migration before launch (R1). Decide now between a lightweight retro-review for the 29 legacy packages (they already have DOIs and citations) or making legacy a permanent, honestly labeled tier. Set a throughput target in reviews per month and size the campaign to it. Do not promise zero legacy rows in twelve months.
4. Make the switchover a launch criterion, not a follow-up (R5). The owdata site does not launch publicly until the openwashdata.org data page reads the harvested artifact, or at minimum links to it prominently, with a named owner and date for the swap and an agreed freeze date for the Google Sheet.
5. Gate the harvest on content, not just schema (R3). Fail or alert on week-over-week increases in problems-tibble rows, NA DOIs among catalogued packages, or unexplained tier changes. Route harvest failures to a channel a human actually reads (email), and put the PAT expiry on a calendar or replace it with a GitHub App installation token.
6. Protect washr in the cutover (R4). The packages.json generator hard-codes washr and owdata with a unit test asserting their presence. Rehearse the registry cutover with an org owner available, verify install.packages("washr") from the universe as an acceptance criterion, and consider starting the registry with candidate and catalogued packages only instead of 70 repos with 30 red builds.
7. Fix the staleness model in issue #6, not after launch (R7). Either add an owd_refresh() that fetches the live catalog.json at runtime with installed data as fallback, or bump DESCRIPTION Version on every harvest commit so update.packages() works and bug reports are reproducible. Print a warning on attach when the installed harvest is more than eight weeks old. Drop the near-term CRAN ambition; it is incompatible with weekly data.

### Kill criteria

1. If the tier policy has no written sign-off from the second maintainer by the time Phase 1 code is complete, do not run the first public harvest. Pause rather than publish an unratified classification of other people's work.
2. If fewer than 4 reviews per month complete in the first two months of the migration campaign, stop the campaign and switch to the lightweight retro-review or permanent-legacy design instead of grinding.
3. If 60 days after the owdata site launches the openwashdata.org data page still renders the Google Sheet with no link to owdata, halt Phases 3 and 4 until the switchover lands. Two diverging catalogs is worse than one stale one.

### Pre-launch checklist

1. Tier policy ratified in writing by the second maintainer; contributor announcement drafted; legacy flag renamed to neutral wording.
2. Harvester verifies the four closed review issues for every non-legacy catalogued package, with a test.
3. packages.json generator includes washr and owdata by construction, with a test; cutover rehearsed with an org owner; washr install from the universe verified.
4. Weekly harvest alerts on content-level regressions and reaches a human channel; PAT expiry handled.
5. Website switchover PR exists in the website repo with an owner and a date; Google Sheet freeze date agreed.
6. Staleness mechanism (refresh function or per-harvest version bump plus attach warning) implemented and tested.
