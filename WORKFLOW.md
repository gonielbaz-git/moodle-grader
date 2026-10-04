# Moodle Grading — Workflow

A local, PDF-friendly way to grade Moodle assignments and push grades back — without fighting the Moodle web UI.

## The pieces

| File | What it is |
|---|---|
| `moodle_grader.html` | The grading tool (master copy). Scroll each student's PDF, tap pass/fail or a grade, add a note. |
| `setup_moodle_grading.command` | One generic setup script for **any** course. Double-click, pick course + tirgul number. |
| `courses.json` | Per-course config (scheme, section). Add a block to support a new course. |
| `moodle_push.html` | Installs the **📤 Moodle Push** bookmarklet that fills grades + notes back into Moodle in one click. |
| `moodle_grading/<course>_tirgul<N>/` | A generated folder per assignment: PDFs, `worksheet.csv`, `data.js`, and a `grader.html`. |

## Full workflow (per assignment)

**1. Download from Moodle** (assignment page ▸ פעולות):
- הורדת כל ההגשות לפי סטודנט → submissions **ZIP**
- הורדת גיליון-הציונים האלקטרוני → worksheet **CSV**

Both land in `~/Downloads`.

**2. Set up** — double-click `setup_moodle_grading.command`, type the course key (e.g. `physics_a`) and the number (e.g. `11`). It:
- extracts each PDF **matched to the student by Moodle participant ID** (never by filename — student filenames like `11.pdf` are unreliable),
- builds the grader with everything embedded, and opens it.

**3. Grade** in the browser tool. Notes stay local; the PDF is right there.

**4. Push back to Moodle:**
- In the grader, click **📤 ייצוא ל-Moodle** (copies grades + notes to clipboard).
- In Moodle, on the assignment's submissions page, tick **מתן ציון מהיר** (quick grading).
- Click the **📤 Moodle Push** bookmarklet → it fills every grade **and** note → click **💾 שמור עמוד**.
- More than 50 students? Next page, click the bookmarklet again (data is remembered, no need to re-copy).

## One-time: install the bookmarklet

Open `moodle_push.html` and drag the **📤 Moodle Push** button up to your browser's bookmarks bar. Done.

## Why not just upload the CSV?

**Don't. The CSV import does not work on TAU Moodle — for any scheme.** Re-tested 17 Jul 2026 on
math_tools tirgul 11 (a plain 0–100 points assignment): the confirm screen listed all 55 changes
correctly ("הגדרת ציון עבור X ל-100.00"), אישור was clicked, and **nothing was written** — the
assignment still read `דורש מתן ציון 21`. Tried twice. It fails silently, with a preview that looks
perfect, which is what makes it dangerous.

It's not just pass/fail scales, as previously assumed — points grades are dropped too. Always use
quick grading + the **📤 Moodle Push** bookmarklet. That reads the real scale values off the page
(any scale, any language) and always writes grade + note together so notes never get wiped.

## Adding a new course

Add a block to `courses.json`:

```json
"chem_a": { "label": "כימיה א'", "scheme": "pass_fail", "maxGrade": 100, "section": "" }
```

`scheme` is `pass_fail` (עובר/לא עובר), `binary_0_100` (0 or 100) or `numeric` (0..maxGrade). `setup_moodle_grading.command` will then offer it.

## Gotchas (learned the hard way)

- **Students with an extension are never auto-failed.** Moodle writes
  `ניתנה הארכת זמן עד: ...` into the worksheet's `מצב` column. The setup script flags those
  (`hasExtension`), the grader shows them as **⏳ הארכה**, leaves them blank, and both exports skip
  them. Without this they'd get a visible 0 while they still have weeks to submit.
- **The scheme is baked in at grading time.** `courses.json` → `data.js` → localStorage. If the
  course scheme is wrong you'll grade with the wrong buttons and the export is unusable. Changing
  `courses.json` does **not** fix an already-open grader — click **איפוס מלא** first.
  (math_tools is `binary_0_100`, not `pass_fail`. This was wrong in `courses.json` until 17 Jul 2026.)
- **The roster moves.** A student joined between the worksheet download and the upload on tirgul 11.
  Anyone not in the CSV is simply skipped — re-download the worksheet if it's been sitting a while.
- **Match by participant ID, not name.** Students name files anything.
- **Non-PDF and multi-file submissions.** Someone who submitted an image/docx is left ungraded (not auto-failed) with a note to check Moodle; someone with several PDFs gets numbered file buttons in the grader.
- **Two students with the same name.** Saved progress is tracked by participant ID, so they never share a grade. The bookmarklet can only see names on the Moodle page, so it leaves both rows empty and tells you to fill them by hand.
- **Invalid grades are rejected.** A typo (`8o`), a grade above the maximum, or anything other than 0/100 in a binary course turns the box red, is not counted as graded and is not exported.
- **Unknown course key.** The setup script stops instead of guessing a grading scheme.
- **Each course + assignment keeps its own saved progress**, so two graders open at once don't overwrite each other.
- **Pass/fail values must be `עובר` / `לא עובר`** (with the vav) to match the Moodle scale.
- **Quick-grade Save submits every note field** — set grades and notes together, or blank fields overwrite existing notes. The bookmarklet handles this.
- **Stale browser state:** if the grader shows wrong statuses after re-linking PDFs, click **איפוס מלא**.
