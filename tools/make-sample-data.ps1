# יוצר קובצי נתוני דוגמה מומצאים לדאשבורד: dashboard/data/sample-employees.csv ו-sample-attendance.csv
# התאריכים נבנים ביחס ל-Today. להרצה מחדש (כשהדוגמה מתיישנת):
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/make-sample-data.ps1
# כל השמות והמספרים מומצאים. מספרי הזהות מתחילים ב-000 ואינם של אנשים אמיתיים.
param(
    [datetime]$Today = (Get-Date).Date,
    [string]$OutDir = (Join-Path $PSScriptRoot '..\dashboard\data')
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
$rnd = New-Object System.Random 4172026
function NextR { return $rnd.NextDouble() }

$first = @('נועה','איתי','מיכל','עומר','שירה','יונתן','תמר','דניאל','ליאור','רוני','אורי','הדס','גיא','מאיה','אריאל','נגה','עידו','ענת','רותם','שקד','יובל','דנה','אלון','מור','ניצן','סתיו','עדי','אביב','טל','לירון','גל','ספיר','אסף','קרן','נדב','שני','בן','מעיין','רון','יעל','אורן','חן','שגיא','מיטל','אסתר','נתן','רינת')
$last = @('כהן','לוי','מזרחי','פרידמן','אברהם','ביטון','דהן','שפירא','אזולאי','גולן','חיים','קפלן','אדרי','רוזן','שמעוני','בן דוד','אשכנזי','נחום','סגל','וייס')
$depts = @(
    @{ n = 'פיתוח'; r = @('מפתח/ת Full Stack','מפתח/ת Backend','מהנדס/ת QA','מהנדס/ת DevOps'); w = 6 },
    @{ n = 'מכירות'; r = @('נציג/ת מכירות','מנהל/ת לקוחות'); w = 6 },
    @{ n = 'שירות לקוחות'; r = @('נציג/ת שירות','ראש/ת צוות תמיכה'); w = 7 },
    @{ n = 'כספים'; r = @('מנהל/ת חשבונות','אנליסט/ית כספים'); w = 2 },
    @{ n = 'שיווק'; r = @('מנהל/ת קמפיינים','מנהל/ת תוכן'); w = 3 },
    @{ n = 'תפעול'; r = @('מתאם/ת תפעול','מנהל/ת לוגיסטיקה'); w = 4 },
    @{ n = 'משאבי אנוש'; r = @('מגייס/ת','מנהל/ת שכר'); w = 2 }
)
$totalW = ($depts | ForEach-Object { $_.w } | Measure-Object -Sum).Sum
$need = [ordered]@{ contract = 3; f101 = 5; training = 24; equipment = 8; access = 10 }
$perMonth = @(6,5,4,5,4,4,4,4,3,3,3,2)

function CheckDigitId([string]$b8) {
    $s = 0
    for ($i = 0; $i -lt 8; $i++) {
        $d = [int][string]$b8[$i] * (($i % 2) + 1)
        if ($d -gt 9) { $d -= 9 }
        $s += $d
    }
    return $b8 + ((10 - $s % 10) % 10)
}
function D([datetime]$d) { return $d.ToString('dd/MM/yyyy', $inv) }

$curStart = New-Object DateTime $Today.Year, $Today.Month, 1
$emp = New-Object System.Text.StringBuilder
$att = New-Object System.Text.StringBuilder
[void]$emp.AppendLine('מספר זהות,שם,מחלקה,תפקיד,תאריך פתיחת משרה,תאריך תחילת עבודה,חוזה,טופס 101,הדרכות,ציוד,הרשאות,תאריך עזיבה')
[void]$att.AppendLine('מספר זהות,תאריך,שעות,סוג יום')
$ids = New-Object 'System.Collections.Generic.HashSet[string]'
$i = 0
$attRows = 0

for ($mb = 0; $mb -lt $perMonth.Count; $mb++) {
    for ($k = 0; $k -lt $perMonth[$mb]; $k++, $i++) {
        $w = (NextR) * $totalW
        $d = $depts[0]
        foreach ($x in $depts) { $w -= $x.w; if ($w -le 0) { $d = $x; break } }
        $dom = 1 + [Math]::Floor((NextR) * 26)
        if ($mb -eq 0) { $dom = [Math]::Min($dom, $Today.Day) }
        $st = $curStart.AddMonths(-$mb).AddDays($dom - 1)
        $wd = [int]$st.DayOfWeek
        if ($wd -ge 5) { if ($mb -gt 0) { $st = $st.AddDays(7 - $wd) } else { $st = $st.AddDays(-($wd - 4)) } }
        $age = [Math]::Max(0, ($Today - $st).TotalDays)
        $status = [ordered]@{}
        foreach ($key in $need.Keys) {
            $n = $need[$key] * (0.7 + (NextR) * 0.9)
            if ($age -ge $n) { $status[$key] = 'הושלם' } elseif ($age -ge $n * 0.35) { $status[$key] = 'בתהליך' } else { $status[$key] = 'טרם התחיל' }
        }
        if ($age -gt 10 -and (NextR) -lt 0.13) {
            $pick = @('f101','equipment','access','training')[[int][Math]::Floor((NextR) * 4)]
            if ((NextR) -lt 0.5) { $status[$pick] = 'בתהליך' } else { $status[$pick] = 'טרם התחיל' }
        }
        $left = $null
        if ($mb -ge 1 -and (NextR) -lt 0.24) {
            $l = $st.AddDays(25 + [Math]::Floor((NextR) * 150))
            if ($l -lt $Today) { $left = $l }
        }
        do { $id = CheckDigitId ('000' + (10000 + [Math]::Floor((NextR) * 89999)).ToString($inv)) } while (-not $ids.Add($id))
        $name = $first[$i % $first.Count] + ' ' + $last[($i * 7 + 3) % $last.Count]
        $role = $d.r[[int][Math]::Floor((NextR) * $d.r.Count)]
        $opened = $st.AddDays(-(25 + [Math]::Floor((NextR) * 55)))
        $leftTxt = ''
        if ($left) { $leftTxt = D $left }
        [void]$emp.AppendLine(($id, $name, $d.n, $role, (D $opened), (D $st), $status['contract'], $status['f101'], $status['training'], $status['equipment'], $status['access'], $leftTxt) -join ',')

        $end = $Today
        if ($left) { $end = $left.AddDays(-1) }
        for ($t = $st; $t -le $end; $t = $t.AddDays(1)) {
            if ([int]$t.DayOfWeek -gt 4) { continue }
            $x = NextR
            if ($x -lt 0.06) { [void]$att.AppendLine("$id,$(D $t),0,חופשה") }
            elseif ($x -lt 0.09) { [void]$att.AppendLine("$id,$(D $t),0,מחלה") }
            else {
                $h = [Math]::Round((7.5 + (NextR) * 2) * 4) / 4
                [void]$att.AppendLine("$id,$(D $t),$($h.ToString('0.##', $inv)),עבודה")
            }
            $attRows++
        }
    }
}

New-Item -ItemType Directory -Force $OutDir | Out-Null
$bom = New-Object System.Text.UTF8Encoding($true)
[IO.File]::WriteAllText((Join-Path $OutDir 'sample-employees.csv'), $emp.ToString(), $bom)
[IO.File]::WriteAllText((Join-Path $OutDir 'sample-attendance.csv'), $att.ToString(), $bom)
"נוצרו $i עובדים ו-$attRows שורות נוכחות ב-$((Resolve-Path $OutDir).Path)"
