# Moodle Grader

Grade Moodle assignment submissions locally, with the PDF next to a grade/notes panel, then push the grades back to Moodle in one click. No server, no install: one HTML file, one setup script, one bookmarklet.

Built for Tel Aviv University's Hebrew Moodle (the UI is in Hebrew, RTL), but the worksheet parser accepts English column headers too.

## Files

| File | What it is |
|---|---|
| `moodle_grader.html` | The grading tool. Works standalone (pick a folder with PDFs + worksheet CSV) or pre-loaded by the setup script. |
| `setup_moodle_grading.command` | macOS setup script: finds the Moodle downloads, matches each PDF to its student by participant ID, opens the grader. |
| `courses.json` | Per-course settings (grading scheme, max grade, section label). Add your own courses here. |
| `moodle_push.html` | Installs the **Moodle Push** bookmarklet that fills grades and notes into Moodle's quick-grading page. |
| `WORKFLOW.md` | The full per-assignment workflow and known Moodle gotchas. |
| `TECHNICAL.md` | Data format, keyboard shortcuts, implementation notes. |

## Quick start

1. In Moodle, on the assignment page, download **all submissions** (ZIP, in per-student folders) and the **grading worksheet** (CSV).
2. Double-click `setup_moodle_grading.command`, enter a course key from `courses.json` and the assignment number.
3. Grade in the browser (Chrome recommended). Progress is saved automatically.
4. Click **📤 ייצוא ל-Moodle**, turn on quick grading in Moodle, click the **Moodle Push** bookmarklet, save.

See `WORKFLOW.md` for details.

## Privacy

Everything runs on your computer. Student files, names and grades never leave it, and `.gitignore` keeps generated grading folders out of the repository. Do not commit `moodle_grading/`.
