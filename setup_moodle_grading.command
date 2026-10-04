#!/bin/bash
# ============================================================
# Moodle grading setup — GENERIC, config-driven, ID-matched.
# Works for ANY course listed in courses.json.
#
# Before running, download from the Moodle assignment page:
#   1) פעולות ▸ הורדת כל ההגשות לפי סטודנט   (submissions ZIP)
#   2) פעולות ▸ הורדת גיליון-הציונים האלקטרוני (worksheet CSV)
# Both land in ~/Downloads. Then double-click this file.
#
# Key difference from the old per-tirgul scripts: PDFs are matched to
# students by the Moodle PARTICIPANT ID embedded in each submission
# folder name ("{Name}_{id}_assignsubmission_file"), never by name.
# Student file names are unreliable ("11.pdf", the exercise sheet, etc.),
# so ID matching is the only robust method.
# ============================================================
cd "$(dirname "$0")"
ROOT="$(pwd)"
GRADER_SRC="$ROOT/moodle_grader.html"
CONFIG="$ROOT/courses.json"

[ -f "$CONFIG" ] || { echo "❌ courses.json not found next to this script."; read -n 1 -s -r -p "Press any key..."; exit 1; }
[ -f "$GRADER_SRC" ] || { echo "❌ moodle_grader.html not found."; read -n 1 -s -r -p "Press any key..."; exit 1; }

echo ""
echo "=== Moodle grading setup ==="
echo ""
echo "Courses in courses.json:"
python3 -c "import json;d=json.load(open('$CONFIG'));[print('  -',k,'('+v.get('label','')+', '+v.get('scheme','')+')') for k,v in d['courses'].items()]"
echo ""
read -r -p "Course key (e.g. physics_a): " COURSE
read -r -p "Tirgul / assignment number (e.g. 11): " N
[ -z "$COURSE" ] && { echo "No course given."; read -n 1 -s -r -p "Press any key..."; exit 1; }
[ -z "$N" ] && { echo "No number given."; read -n 1 -s -r -p "Press any key..."; exit 1; }

TARGET="$ROOT/moodle_grading/${COURSE}_tirgul${N}"
mkdir -p "$TARGET"

# Pick the newest REAL Moodle downloads from ~/Downloads (last 3 hours). Files are
# checked by content, not just extension: these two get deleted after setup, so an
# unrelated zip/csv that happens to be newer must never be picked.
PICK=$(python3 - "$HOME/Downloads" <<'PYPICK'
import os, sys, time, zipfile
d = sys.argv[1]; now = time.time(); z = c = ''
files = sorted((os.path.join(d, f) for f in os.listdir(d)), key=os.path.getmtime, reverse=True)
for f in files:
    if now - os.path.getmtime(f) > 3 * 3600 or not os.path.isfile(f): continue
    low = f.lower()
    try:
        if not z and low.endswith('.zip') and any('_assignsubmission_' in n for n in zipfile.ZipFile(f).namelist()): z = f
        elif not c and low.endswith('.csv'):
            head = open(f, encoding='utf-8-sig', errors='ignore').readline().lower()
            if ('מזהה' in head or 'identifier' in head) and ('שם מלא' in head or 'full name' in head): c = f
    except Exception: pass
print(z); print(c)
PYPICK
)
BUNDLE=$(printf '%s\n' "$PICK" | sed -n 1p)
WORKSHEET=$(printf '%s\n' "$PICK" | sed -n 2p)

[ -z "$BUNDLE" ] && { echo "❌ No Moodle submissions .zip from the last 3 hours in ~/Downloads. Run 'הורדת כל ההגשות לפי סטודנט' first."; read -n 1 -s -r -p "Press any key..."; exit 1; }
echo ""
echo "Bundle:    $BUNDLE"
[ -n "$WORKSHEET" ] && echo "Worksheet: $WORKSHEET"
echo ""

python3 - "$TARGET" "$BUNDLE" "$WORKSHEET" "$N" "$COURSE" "$CONFIG" <<'PYEOF'
import csv, json, os, re, sys, zipfile

FOLDER, BUNDLE, WORKSHEET, N, COURSE, CONFIG = sys.argv[1:7]
courses = json.load(open(CONFIG, encoding='utf-8'))['courses']
if COURSE not in courses:
    sys.exit(f"❌ Course '{COURSE}' is not in courses.json (known: {', '.join(courses)}). Nothing was changed.")
cfg = courses[COURSE]
scheme  = cfg.get('scheme', 'pass_fail')
maxG    = cfg.get('maxGrade', 100)
section = cfg.get('section', '')
ASSIGNMENT_NAME = f"תרגיל {N}"

# 1) Map participant-id -> pdf(s) from the zip's per-student folder names.
folder_re = re.compile(r'_(\d+)_assignsubmission_[a-z]+(?:/|$)')
id_to_infos, id_to_other = {}, {}
with zipfile.ZipFile(BUNDLE) as z:
    for info in z.infolist():
        if info.is_dir(): continue
        m = folder_re.search(info.filename)
        if not m: continue
        if info.filename.lower().endswith('.pdf'):
            id_to_infos.setdefault(m.group(1), []).append(info)
        elif '_assignsubmission_file' in info.filename:
            id_to_other.setdefault(m.group(1), []).append(os.path.basename(info.filename))
print(f"Participant IDs with a PDF in zip: {len(id_to_infos)}")

# 2) Extract each student's PDF as {id}.pdf (id-based, collision-free).
id_to_pdf = {}
with zipfile.ZipFile(BUNDLE) as z:
    for pid, infos in id_to_infos.items():
        for i, info in enumerate(infos):
            name = f"{pid}.pdf" if i == 0 else f"{pid}__{i+1}.pdf"
            with z.open(info) as src, open(os.path.join(FOLDER, name), 'wb') as out:
                out.write(src.read())
            id_to_pdf.setdefault(pid, []).append(name)

# 3) Load worksheet CSV.
csv_path = os.path.join(FOLDER, 'worksheet.csv')
if WORKSHEET and os.path.isfile(WORKSHEET):
    import shutil; shutil.copy(WORKSHEET, csv_path)
header, rows = [], []
if os.path.exists(csv_path):
    with open(csv_path, encoding='utf-8-sig', newline='') as f:
        r = csv.reader(f); header = next(r, [])
        rows = [x for x in r if any(c.strip() for c in x)]

lc = [h.strip().lower() for h in header]
def fc(keys):
    for k in keys:
        for i, h in enumerate(lc):
            if k.lower() in h: return i
    return -1
cols = {'identifier': fc(['identifier','מזהה']), 'name': fc(['full name','שם מלא','name','שם']),
        'grade': fc(['grade','ציונים','ציון']), 'feedback': fc(['feedback','הערות','comment']),
        'submitDate': fc(['last modified (submission)','submitted','הגשה']),
        'onlineText': fc(['online text','טקסט מקוון','תוכן מקוון']), 'status': fc(['status','מצב'])}
csv_all_rows = [dict(zip(header, row + ['']*(len(header)-len(row)))) for row in rows]

id_re = re.compile(r'(\d+)')
students, matched = [], 0
for row in csv_all_rows:
    name = row[header[cols['name']]] if cols['name'] >= 0 else ''
    ident = row[header[cols['identifier']]] if cols['identifier'] >= 0 else ''
    mm = id_re.search(ident or ''); pid = mm.group(1) if mm else None
    pdfs = id_to_pdf.get(pid, []) if pid else []
    pdf = pdfs[0] if pdfs else None
    if pdf: matched += 1
    # A student with an approved extension has NOT missed the deadline — never auto-fail them.
    # Moodle puts "ניתנה הארכת זמן עד: ..." in the status column of the worksheet CSV.
    status_txt = row[header[cols['status']]] if cols['status'] >= 0 else ''
    has_ext = 'הארכ' in status_txt or 'extension' in status_txt.lower()
    sub_date = (row[header[cols['submitDate']]] if cols['submitDate'] >= 0 else '').strip()
    # Submitted, but nothing we can show as a PDF (image/docx/online text) — must not be auto-failed.
    submitted = sub_date not in ('', '-') or bool(pid and id_to_other.get(pid))
    students.append({'name': name, 'id': pid or '', 'pdfFile': './'+pdf if pdf else None,
                     'pdfFiles': ['./'+x for x in pdfs], 'submitted': submitted,
                     'otherFiles': id_to_other.get(pid, []) if pid else [],
                     'submitDate': row[header[cols['submitDate']]] if cols['submitDate'] >= 0 else '',
                     'onlineText': row[header[cols['onlineText']]] if cols['onlineText'] >= 0 else '',
                     'hasExtension': has_ext,
                     'extensionNote': status_txt.strip() if has_ext else '',
                     'gradeFromCsv': row[header[cols['grade']]] if cols['grade'] >= 0 else '',
                     'feedbackFromCsv': row[header[cols['feedback']]] if cols['feedback'] >= 0 else ''})

data = {'course': COURSE, 'assignmentName': ASSIGNMENT_NAME, 'maxGrade': maxG,
        'gradingScheme': scheme, 'sectionLabel': section,
        'csvHeader': header, 'cols': cols, 'csvAllRows': csv_all_rows,
        'students': students, 'auxFiles': {}}
with open(os.path.join(FOLDER, 'data.js'), 'w', encoding='utf-8') as f:
    f.write('window.__EMBEDDED_DATA = ' + json.dumps(data, ensure_ascii=False) + ';')

subm = sum(1 for s in students if s['submitDate'] and s['submitDate'] != '-')
ext = [s['name'] for s in students if s['hasExtension']]
print(f"data.js: {len(students)} students | {matched} matched to PDFs (by ID) | {subm} submitted")
if ext:
    print(f"⏳ {len(ext)} with a time extension — left ungraded, NOT auto-failed: " + ", ".join(ext))
known = {s['id'] for s in students}
stray = sorted(set(id_to_pdf) - known)
if stray:
    print(f"⚠️  {len(stray)} submission(s) in the zip belong to nobody in the worksheet (IDs {', '.join(stray)}) — re-download the worksheet.")
nonpdf = [s['name'] for s in students if not s['pdfFile'] and s['submitted']]
if nonpdf:
    print(f"📎 {len(nonpdf)} submitted something that is not a PDF — left ungraded, check in Moodle: " + ", ".join(nonpdf))
multi = [s['name'] for s in students if len(s['pdfFiles']) > 1]
if multi:
    print(f"📚 {len(multi)} submitted more than one PDF (switch files in the grader): " + ", ".join(multi))
if matched == 0 and id_to_pdf:
    print("⚠️  0 matched but PDFs exist — is the worksheet CSV from the SAME assignment?")
try: os.remove(BUNDLE)
except OSError: pass
if WORKSHEET:
    try: os.remove(WORKSHEET)
    except OSError: pass
PYEOF

STATUS=$?
[ "$STATUS" -ne 0 ] && { echo ""; echo "Setup failed."; read -n 1 -s -r -p "Press any key..."; exit 1; }

cp "$GRADER_SRC" "$TARGET/grader.html"
echo "Opening grader..."
open "$TARGET/grader.html"
sleep 2
