// מביא משרות פתוחות של מתחרים מ-Apify ושומר אותן ב-market-jobs.json (המבנה שהמסך "שוק העבודה והמתחרים" קורא).
// הרצה (Node 18 ומעלה):
//   PowerShell:  $env:APIFY_TOKEN = "<הטוקן שלך>"; node tools/fetch-jobs.mjs
// הטוקן נקרא רק ממשתנה סביבה ולא נשמר בקובץ.

import { writeFile } from 'node:fs/promises';

const ACTOR = 'bebity~linkedin-jobs-scraper';       // Actor ב-Apify Store: bebity/linkedin-jobs-scraper
const LOCATION = 'Israel';
const ROWS_PER_QUERY = 10;                          // כמה משרות לבקש לכל תפקיד (משפיע על העלות)

// החברות והתפקידים להצלבה. להחליף בחברות מתחרות אמיתיות.
const COMPETITORS = ['Wix', 'monday.com', 'Check Point', 'Fiverr', 'Payoneer'];
// תפקידים באנגלית, כי LinkedIn מחפש לפי שם המשרה כפי שהוא מופיע במודעות. כל תפקיד נשלח בהרצה נפרדת.
const ROLES = ['Software Developer', 'DevOps Engineer', 'QA Engineer', 'Sales Representative', 'Customer Support', 'Accountant', 'Marketing Manager', 'Operations Coordinator', 'Recruiter'];

const token = process.env.APIFY_TOKEN;
if (!token) { console.error('חסר APIFY_TOKEN במשתני הסביבה.'); process.exit(1); }

const url = `https://api.apify.com/v2/acts/${ACTOR}/run-sync-get-dataset-items`;
const items = [];
for (const role of ROLES) {
  // שמות השדות של ה-Actor עשויים להשתנות. אם משהו נכשל, השגיאה של Apify תגיד איזה שדה לתקן.
  const input = { title: role, location: LOCATION, companyName: COMPETITORS, publishedAt: 'r2592000', rows: ROWS_PER_QUERY };
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify(input),
  });
  if (!res.ok) { console.error('Apify החזיר שגיאה', res.status, await res.text()); process.exit(1); }
  const part = await res.json();
  console.log(`${role}: ${part.length} משרות`);
  items.push(...part);
}

const pick = (o, ...keys) => { for (const k of keys) if (o[k] != null && o[k] !== '') return o[k]; return null; };
const day = v => { const d = new Date(v); return isNaN(d) ? null : d.toISOString().slice(0, 10); };

// במקום לשמור את טקסט המודעה המלא (תוכן של החברות ושל LinkedIn), נשמרת רק רשימת הדרישות שזוהו בו.
// אותה רשימה קיימת גם בדאשבורד (KW). אם מוסיפים דרישה, מוסיפים אותה בשני המקומות.
const KW = [['היברידי', /היברידי|hybrid/i], ['עבודה מהבית', /מהבית|remote/i], ['אנגלית', /אנגלית|english/i], ['תואר ראשון', /תואר ראשון|bachelor|b\.?sc/i], ['ניסיון של 3 שנים ומעלה', /3\+? שנ|3\+? years/i], ['משמרות', /משמרות|shift/i], ['React', /react/i], ['Node.js', /node/i], ['Python', /python/i], ['SQL', /\bsql\b/i], ['AWS', /\baws\b/i], ['Excel', /excel|אקסל/i], ['Salesforce', /salesforce/i], ['CRM', /\bcrm\b/i], ['SAP', /\bsap\b/i]];
const requirements = text => {
  const found = KW.filter(([, re]) => re.test(text)).map(([label]) => label);
  return found.length ? 'דרישות: ' + found.join(', ') + '.' : '';
};

function salary(o) {
  const s = o.salary;
  if (s && typeof s === 'object') {
    const per = String(s.period || s.unit || '').toLowerCase();
    const f = /year|שנ/.test(per) ? 1 / 12 : /hour|שע/.test(per) ? 182 : 1;
    const a = Number(s.min ?? s.from), b = Number(s.max ?? s.to);
    if (a || b) return { salaryMin: Math.round((a || b) * f), salaryMax: Math.round((b || a) * f) };
  }
  return { salaryMin: null, salaryMax: null };
}

const seen = new Set();
const jobs = [];
for (const o of items) {
  const link = pick(o, 'jobUrl', 'link', 'url');
  const id = String(pick(o, 'id', 'jobId') ?? link ?? '');
  if (!id || seen.has(id)) continue;
  seen.add(id);
  jobs.push({
    id,
    title: pick(o, 'title', 'jobTitle') ?? '',
    company: pick(o, 'companyName', 'company') ?? '',
    location: pick(o, 'location', 'jobLocation') ?? '',
    postedAt: day(pick(o, 'postedAt', 'publishedAt', 'postedDate', 'listedAt')),
    url: link ?? '',
    ...salary(o),
    description: requirements(String(pick(o, 'title', 'jobTitle') ?? '') + ' ' + String(pick(o, 'descriptionText', 'description') ?? '')),
  });
}

const out = { meta: { source: 'apify', actor: ACTOR.replace('~', '/'), fetchedAt: new Date().toISOString(), sample: false }, jobs };
await writeFile(new URL('../dashboard/market-jobs.json', import.meta.url), JSON.stringify(out, null, 1), 'utf8');
console.log(`נשמרו ${jobs.length} משרות ב-dashboard/market-jobs.json`);
