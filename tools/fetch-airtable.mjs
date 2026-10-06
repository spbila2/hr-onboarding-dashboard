// מרענן את dashboard/data/hires.json מטבלת "עובדים חדשים" ב-Airtable.
// נשמרים רק תחום, תפקיד ותאריך תחילת עבודה. שמות ומספרי זהות לא נקראים ולא נשמרים.
// הרצה (Node 18 ומעלה):
//   PowerShell:  $env:AIRTABLE_TOKEN = (Read-Host "token").Trim(); node tools/fetch-airtable.mjs
// ה-token הוא Personal Access Token מ-airtable.com/create/tokens, עם ההרשאה data.records:read
// ועם גישה ל-base "קליטת עובדים" בלבד.

import { writeFile } from 'node:fs/promises';

const BASE_ID = 'apphvloFwyopeXu51';
const TABLE_ID = 'tblOd7xx8DQcj1LD2';
const FIELDS = { dept: 'מחלקה', role: 'תפקיד', start: 'תאריך תחילת עבודה' };

const token = process.env.AIRTABLE_TOKEN;
if (!token) { console.error('חסר AIRTABLE_TOKEN במשתני הסביבה.'); process.exit(1); }

// Airtable מחזיר תאריך כ-YYYY-MM-DD. אם השדה טקסט בפורמט dd/mm/yyyy, ממירים.
function isoDate(v) {
  const s = String(v ?? '').trim();
  let m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s);
  if (m) return `${m[1]}-${m[2]}-${m[3]}`;
  m = /^(\d{1,2})[./](\d{1,2})[./](\d{4})/.exec(s);
  if (m) return `${m[3]}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}`;
  return null;
}

const hires = [];
let offset;
do {
  const qs = new URLSearchParams({ pageSize: '100' });
  for (const f of Object.values(FIELDS)) qs.append('fields[]', f);
  if (offset) qs.set('offset', offset);
  const res = await fetch(`https://api.airtable.com/v0/${BASE_ID}/${TABLE_ID}?${qs}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) { console.error('Airtable החזיר שגיאה', res.status, await res.text()); process.exit(1); }
  const page = await res.json();
  for (const r of page.records) {
    const f = r.fields ?? {};
    const start = isoDate(f[FIELDS.start]);
    const dept = String(f[FIELDS.dept] ?? '').trim();
    if (!start || !dept) continue;
    hires.push({ dept, role: String(f[FIELDS.role] ?? '').trim(), start });
  }
  offset = page.offset;
} while (offset);

const out = { meta: { source: 'airtable', updatedAt: new Date().toISOString().slice(0, 10) }, hires };
await writeFile(new URL('../dashboard/data/hires.json', import.meta.url), JSON.stringify(out, null, 1), 'utf8');
console.log(`נשמרו ${hires.length} קליטות ב-dashboard/data/hires.json`);
