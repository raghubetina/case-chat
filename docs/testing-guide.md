# Case Chat: a note for the first people trying it

**https://cc.booth.school**

Case Chat turns a written case into a set of people a student interviews. The student starts with a
thin situation and two or three names, and earns the rest by asking someone the right question.

Please author a case you already teach.

## Start with the seeded case

Sign in as **alice@example.com**, with the passphrase sent alongside this note, and choose
**Authoring**. One case is already loaded: **Meridian: The Friday Allocation** — seven people, two
of them in the student's starting directory, and two files every student gets. Its join code is
`MERIDIAN-01` if you want to walk it as a student first.

Open it for the shape of a case: who holds what, who introduces whom, and how a referral condition
is written. The screenshots in this note come from it.

Its prose is placeholder text. Meridian was written to exercise the app rather than to teach, and
it has not had the editing a case you assign would get, so treat its wording as a stand-in rather
than a model.

## Create your own account

Author under your own account rather than alice's, so that several people can work at once without
editing each other's cases. Create an account at the link above; a verification email arrives from
`no-reply@notifications.booth.school`. Then choose **Authoring**.

A small case, four or five people and a document or two, took us about an hour. We have not
timed anyone else.

## 1. Set up the case

![Case setup: title, course, join code, background and assignment, with a reachability panel](images/case-setup.jpg)

**Background** is handed to every student for free. So are the **Assignment**, everyone you put in
the starting directory, and any file you tick "Given to every student at the start". Everything
else has to be earned, so keep Background thin: where the student is, what is due, and when.

The **Join code** arrives pre-filled. Keep it or type your own, but do not clear it: a case with an
empty code will publish and still cannot be joined. Post it with the assignment.

**Reachability**, in the right-hand panel, checks that everyone in the case can be reached from the
starting directory through some chain of introductions. The app refuses to publish while anyone is
unreachable.

## 2. Add the people

Add people one at a time. The create form asks only for name, role and system prompt; the
description, the model, the referral rows and the rehearsal panel appear once you save.

![A person's editor: identity, description, system prompt, and the test drive panel](images/person-editor.jpg)

The **system prompt** is where you write the person. Cover:

- Who they are, and how they talk.
- What they know, in numbers where there are numbers. Where this is vague, they invent.
- What they withhold, and what would make them say it anyway.

Dr. Ortiz above is told she will not tell the student what to optimise for, because choosing the
objective is the assignment.

Do not write referral instructions here. Who this person introduces, and when, is set in the **Can
introduce** rows further down the same page. Written in both places, the two can disagree.

### What the app sends the model

Your system prompt is one part of what the model receives. Each time this person answers, the app
composes a prompt from these blocks, in order:

| Block | Where it comes from |
| --- | --- |
| `<case_background>` | The case Background, only if "Knows the case background" is ticked |
| `<who_you_are>` | `You are {name}, {role}.` followed by your system prompt, verbatim |
| `<people_you_can_introduce>` | Generated from your **Can introduce** rows, never from your prose |
| `<documents_you_hold>` | Generated from your share rules |
| `<how_to_answer>` | A fixed house style, identical for everyone in the case |

Your prompt is passed through untouched, formatting included. Markdown in the prompt tends to
produce markdown in the answer.

`<how_to_answer>` already tells everyone to stay in character, to talk rather than write a
memo, to say when they are unsure, to say when something falls outside their role, and not to do
the student's analysis. You do not need to restate any of it.

Untick "Knows the case background" for someone whose value to the student is that they see only
their own end of the case. Left ticked, they are given the case Background.

![Model and reasoning effort, the case-background toggle, and the list of people this person can introduce](images/who-answers-and-referrals.jpg)

**Who answers as this person** is set per person. Both fields open on what will answer if you
change nothing: GPT-5.6 Sol at high reasoning effort. Saving writes the choice down, so a later
change to the deployment default leaves this case on the model you picked.

**Usage**, in the sidebar, shows what each person has cost to answer as, with your rehearsals
counted apart from students' replies.

## 3. Can introduce: who each person sends the student to

Each row names someone else and the condition that opens the introduction. The condition
should describe a question worth asking rather than a keyword:

> *When the student asks what 'the most good' means, or how to compare a dose in one county with
> a dose in another.*

Written that way, the introduction goes to a student who has noticed the objective is undefined.
Written as *"when the student asks about epidemiology"*, it fires as soon as the topic comes up.

Watch the reachability panel as you add rows.

## 4. Case files, and who hands them over

Every document is uploaded under **Case files**, earned ones included.

![Case files: the two documents Meridian gives every student, and the form for adding one](images/case-files.jpg)

Tick "Given to every student at the start" on the files everyone should have. Left unticked, a file
has to be earned: open the person who holds it and add it under **Can share**, with a condition
written the same way as a referral's.

Meridian gives both its files to everyone, so it has no earned document to copy.

## 5. Test drive

Once a person is saved, their editor has a rehearsal panel on the right. Ask a question there
as a student would.

![The test drive panel: a question and an in-character refusal](images/test-drive.jpg)

Nothing you ask here reaches a student, and rehearsing does not enrol you in your own case. Each
rehearsal is still a real model call, counted in that person's token total, and the form
accepts thirty in five minutes before rate limiting you. **Reset** clears the rehearsal transcript.
Reset after every prompt edit, because the earlier turns came from the old prompt.

Ask the hardest question you expect, edit the prompt, reset, ask again. Worth probing:

- The question they are supposed to refuse.
- Something they cannot know, to see whether they say so or invent it.
- A vague question. They should ask what you are trying to decide.
- A question that should fire a referral, to see whether it fires on the condition you wrote or on
  anything adjacent to it.
- A contradiction from somebody else in the case, to see whether they hold their own view or adopt
  whatever the student said last.

## 6. Look at it as a student

Publish the case. Students cannot join an unpublished case, and publishing is refused while anyone
is unreachable. Then use **Preview as student** and join with your own code.

![The student's starting directory: two contacts out of seven](images/student-directory.jpg)

Seven people in this case; the student starts with two.

![An introduction arriving in the thread: a reason, then a contact card](images/earned-introduction.jpg)

Here the student asked who gets left short. Dr. Ortiz volunteered what her prompt tells her to keep
back unless pushed — that she could not sign a plan leaving a county at zero — and then introduced
Marcus Bell.

## What to send back

1. Did authoring it teach you anything about your own case?
2. Where did somebody break character? Send the question and the reply.
3. Would you assign this instead of the handout, alongside it, or not at all?
4. How long did authoring take?
5. What would a student learn here that the written case does not teach?

## Known rough edges

These are already on the list, so please do not spend time reporting them.

- `/privacy` and `/terms` are placeholder text.
- Anthropic models arrive in visible chunks. The OpenAI default arrives more finely.
