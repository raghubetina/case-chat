# Architecture decision records

Architecture decision records explain choices that a future maintainer might
reasonably question. Product and domain documents state the current result;
these files preserve why it was chosen and when to revisit it.

| ADR | Decision | Status | Implementation |
| --- | --- | --- | --- |
| [0001](0001-use-repository-documentation-and-adrs.md) | Repository documentation plus lean ADRs | Accepted | Verified |
| [0002](0002-use-rodauth-rails.md) | Use `rodauth-rails` for accounts | Accepted | Accounts, policies, and first author controller verified; remaining integration planned |
| [0003](0003-use-first-party-ai-sdks.md) | Integrate providers through first-party SDKs | Accepted | Planned |
| [0004](0004-publish-an-atomic-configuration.md) | Publish an atomic configuration snapshot | Accepted | Lifecycle plus case and stakeholder editing verified; remaining child concurrency planned |
| [0005](0005-compose-stakeholder-prompts-in-the-app.md) | Compose stakeholder prompts in the app | Accepted | Author input verified; composition and AI integration planned |
| [0006](0006-use-rails-native-infrastructure.md) | Keep the prototype Rails-native | Accepted | Verified |

New ADRs should include: status, implementation status, date, context, decision,
consequences, confirmation, revisit trigger, and sources. When superseding an
ADR, update this index and link both records.
