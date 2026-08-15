# Case Chat: a note for the first people trying it

**https://case-chat-claude.onrender.com**

Case Chat turns a written case into a set of people a student interviews. The student starts with a
thin situation and two or three names, and earns the rest by asking someone the right question.

Please author a case you already teach, and tell us whether the interview version teaches anything
the handout does not. A case invented to suit the tool would flatter it.

One vocabulary note: this document says *stakeholder*, but the interface says **contact**, and
calls the set of them the **cast**.

## Create an account and open Authoring

Create an account at the link above. A verification email arrives from
`no-reply@notifications.booth.school`. Then choose **Authoring**.

A small case, four or five stakeholders and a document or two, took us about an hour. We have not
timed anyone else.

## 1. Set up the case

![Case setup: title, course, join code, background and assignment, with a reachability panel](images/case-setup.jpg)

**Background** is handed to every student for free. So are the **Assignment**, everyone you put in
the starting directory, and any file you tick "Given to every student at the start". Everything
else has to be earned, so keep Background thin: where the student is, what is due, and when. A
two-page setup pasted here rebuilds the handout.

The **Join code** arrives pre-filled. Keep it or type your own, but do not clear it: a case with an
empty code will publish and still cannot be joined. Post it with the assignment.

**Reachability**, in the right-hand panel, checks that every stakeholder can be reached from the
starting directory through some chain of introductions. It is not advisory. The app refuses to
publish while anyone is unreachable, so an ignored panel becomes a hard stop at step 6.

## 2. Write the cast

Add stakeholders one at a time. The create form asks only for name, role and system prompt; the
description, the model, the referral rows and the rehearsal panel appear once you save.

![The stakeholder editor: identity, description, system prompt, and the test drive panel](images/stakeholder-editor.jpg)

The **system prompt** is where you write the person. Cover:

- Who they are, and how they talk.
- What they know, in numbers where there are numbers. Where this is vague, the stakeholder
  invents.
- What they withhold, and what would make them say it anyway.

Dr. Ortiz above is told she will not tell the student what to optimise for, because choosing the
objective is the assignment.

Do not write referral instructions here. Who this person introduces, and when, is set in the **Can
introduce** rows further down the same page. Written in both places, the two versions drift apart.

### What the app sends the model

Your system prompt is one part of what the model receives. Each time this person answers, the app
composes a prompt from these blocks, in order:

| Block | Where it comes from |
| --- | --- |
| `<case_background>` | The case Background, only if "Knows the case background" is ticked |
| `<who_you_are>` | `You are {name}, {role}.` followed by your system prompt, verbatim |
| `<people_you_can_introduce>` | Generated from your **Can introduce** rows, never from your prose |
| `<documents_you_hold>` | Generated from your share rules |
| `<how_to_answer>` | A fixed house style, identical for every stakeholder |

Your prompt is passed through untouched, formatting included. Markdown in the prompt tends to
produce markdown in the answer, and an interview answer in headed bullet points does not read as a
person talking.

`<how_to_answer>` already tells every stakeholder to stay in character, to talk rather than write a
memo, to say when they are unsure, to say when something falls outside their role, and not to do
the student's analysis. You do not need to restate any of it.

Untick "Knows the case background" for someone whose value to the student is that they see only
their own end of the case. Left ticked, they are given the case Background.

![Model and reasoning effort, the case-background toggle, and the list of people this stakeholder can introduce](images/who-answers-and-referrals.jpg)

**Who answers as this person** is set per stakeholder. The deployment default is GPT-5.6 Sol at
high reasoning effort. Model and reasoning effort are separate fields, and the deployment's high
does not follow a model you choose: pick a model and leave effort on "Model's own default", and the
provider decides the effort rather than inheriting high.

## 3. Can introduce: who each stakeholder sends the student to

Each row names another stakeholder and the condition that opens the introduction. The condition
should describe a question worth asking rather than a keyword:

> *When the student asks what 'the most good' means, or how to compare a dose in one county with
> a dose in another.*

Written that way, meeting the epidemiologist is the reward for noticing that the objective is
undefined. Written as *"when the student asks about epidemiology"*, it is a scavenger hunt.

Watch the reachability panel as you add rows.

## 4. Case files, and who hands them over

Every document is uploaded under **Case files**, earned ones included.

![Can share: a document, and the condition under which the stakeholder hands it over](images/share-rules.jpg)

Tick "Given to every student at the start" on the files everyone should have. Left unticked, a file
has to be earned, so attach it to whichever stakeholder holds it under **Can share**, with a
condition written the same way as a referral's.

## 5. Test drive

Once a stakeholder is saved, their editor has a rehearsal panel on the right. Ask a question there
as a student would.

![The test drive panel: a question and the stakeholder's in-character refusal](images/test-drive.jpg)

Nothing you ask here reaches a student, and rehearsing does not enrol you in your own case. Each
rehearsal is still a real model call, counted in that stakeholder's token total, and the form
accepts thirty in five minutes before rate limiting you. **Reset** clears the rehearsal transcript.
Reset after every prompt edit, because the earlier turns came from the old prompt.

Ask the hardest question you expect, edit the prompt, reset, ask again. Worth probing:

- The question they are supposed to refuse.
- Something they cannot know, to see whether they say so or invent it.
- A vague question. They should ask what you are trying to decide.
- A question that should fire a referral, to see whether it fires on the condition you wrote or on
  anything adjacent to it.
- A contradiction from another stakeholder, to see whether they hold their own view or adopt
  whatever the student said last.

## 6. Look at it as a student

Publish the case. Students cannot join an unpublished case, and publishing is refused while anyone
is unreachable. Then use **Preview as student** and join with your own code.

![The student's starting directory: two contacts out of a cast of seven](images/student-directory.jpg)

Seven people in this cast; the student starts with two.

![An introduction arriving in the thread: the stakeholder says why, then a contact card](images/earned-introduction.jpg)

Here the student asked who signs the recommendation, and Dr. Ortiz sent them to the Governor's
office.

## What to send back

1. Did authoring it teach you anything about your own case?
2. Where did a stakeholder break? Send the question and the reply.
3. Would you assign this instead of the handout, alongside it, or not at all?
4. How long did authoring take?
5. What would a student learn here that the written case does not teach? If the answer is nothing,
   we would rather know now.

## Known rough edges

These are already on the list, so please do not spend time reporting them.

- `/privacy` and `/terms` are placeholder text.
- There is no error tracking. If you hit an error page, screenshot it, or we will not see it.
- Token use per stakeholder is recorded, but no screen shows it, and the GPT-5.6 prices are not in
  the catalogue yet, so rows from the default model carry no cost figure.
- Anthropic models arrive in visible chunks. The OpenAI default arrives more finely.
