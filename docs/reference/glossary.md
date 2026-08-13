# Glossary

**Status:** accepted<br>
**Last verified:** 2026-08-13

- **User** — a person with one account. The same user can learn, author cases,
  or do both.
- **Case** — the authored learning scenario: background, assignment,
  stakeholders, relationships, documents, and publication state.
- **Author** — the single user who owns and edits a case.
- **Cohort** — one offering of a case. It owns the join code and optional due
  date so the same case can be run with multiple groups.
- **Enrollment** — one user's membership in one cohort.
- **Attempt** — one run through the research experience for an enrollment.
  It pins one published configuration; reset ends it and creates another from
  the latest publication.
- **Stakeholder** — an AI-simulated person the learner can interview. Use this
  name in code and author UI; avoid the generated scaffold's `Contact` name.
- **Referral** — an authored path by which one stakeholder may introduce
  another.
- **Case document** — a file or authored document that may become available to
  the learner.
- **Document bundle** — one or more case documents a stakeholder may share
  under the same authored guidance.
- **Conversation** — the persisted message thread with one stakeholder. In the
  learner UI it is called an interview; the same storage supports an author's
  test drive.
- **Message** — a learner/author or stakeholder turn in a conversation.
- **Model run** — one request to an AI provider, including provider identifiers,
  usage, timing, status, and the exact input snapshot needed to diagnose it.
- **Introduction** — the successful, server-validated effect of a stakeholder
  making another stakeholder available in an attempt.
- **Document release** — the successful, server-validated effect of a
  stakeholder sharing a document bundle in an attempt.
- **Test drive** — an author-only experiment with a stakeholder, optionally
  containing left and right conversations using different models. It pins the
  current draft and previews tool effects without changing learner access.
- **Published configuration** — the atomic snapshot from which new learner
  attempts are created. It is distinct from the author's mutable draft.
