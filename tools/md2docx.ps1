param([string]$In, [string]$Out)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$BLUE = '1F4E8C'; $ORANGE = 'EB6834'; $HEADFILL = 'DCE9F8'; $LINE = 'C9D3E0'
$W = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'

function Esc([string]$s) { return ($s -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;') }

function RunXml([string]$text, [bool]$bold, [bool]$code, [int]$sz, [string]$color) {
    if ($text -eq '') { return '' }
    $rpr = ''
    if ($code) { $rpr += '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>' }
    if ($bold) { $rpr += '<w:b/><w:bCs/>' }
    if ($color) { $rpr += '<w:color w:val="' + $color + '"/>' }
    if ($sz -gt 0) { $rpr += '<w:sz w:val="' + $sz + '"/><w:szCs w:val="' + $sz + '"/>' }
    return '<w:r><w:rPr>' + $rpr + '</w:rPr><w:t xml:space="preserve">' + (Esc $text) + '</w:t></w:r>'
}

$rxInline = [regex]'\*\*(.+?)\*\*|`([^`]+)`'
function Inline([string]$t, [int]$sz, [bool]$forceBold, [string]$color) {
    $sb = New-Object System.Text.StringBuilder
    $pos = 0
    foreach ($m in $rxInline.Matches($t)) {
        if ($m.Index -gt $pos) { [void]$sb.Append((RunXml $t.Substring($pos, $m.Index - $pos) $forceBold $false $sz $color)) }
        if ($m.Groups[1].Success) { [void]$sb.Append((RunXml $m.Groups[1].Value $true $false $sz $color)) }
        else { [void]$sb.Append((RunXml $m.Groups[2].Value $forceBold $true $sz $color)) }
        $pos = $m.Index + $m.Length
    }
    if ($pos -lt $t.Length) { [void]$sb.Append((RunXml $t.Substring($pos) $forceBold $false $sz $color)) }
    return $sb.ToString()
}

function Para([string]$inner, [string]$style, [string]$numPr, [string]$bdr, [string]$spacing) {
    $ppr = ''
    if ($style) { $ppr += '<w:pStyle w:val="' + $style + '"/>' }
    $ppr += $numPr + $bdr + '<w:bidi/>' + $spacing
    return '<w:p><w:pPr>' + $ppr + '</w:pPr>' + $inner + '</w:p>'
}

function Table($rows) {
    $ncol = ($rows | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum
    $total = 10100
    $weights = @()
    for ($c = 0; $c -lt $ncol; $c++) {
        $sum = 0
        foreach ($r in $rows) {
            $cell = ''
            if ($c -lt $r.Count) { $cell = ($r[$c] -replace '\*\*|`', '') }
            $sum += [Math]::Min(80, $cell.Length)
        }
        $avg = $sum / $rows.Count
        $weights += [Math]::Max(9, [Math]::Min(45, $avg))
    }
    $wsum = ($weights | Measure-Object -Sum).Sum
    $widths = @()
    foreach ($w in $weights) { $widths += [int][Math]::Max(900, [Math]::Floor($total * $w / $wsum)) }
    $tw = ($widths | Measure-Object -Sum).Sum
    $sb = New-Object System.Text.StringBuilder
    $bd = '<w:top w:val="single" w:sz="4" w:space="0" w:color="' + $LINE + '"/><w:left w:val="single" w:sz="4" w:space="0" w:color="' + $LINE + '"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="' + $LINE + '"/><w:right w:val="single" w:sz="4" w:space="0" w:color="' + $LINE + '"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="' + $LINE + '"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="' + $LINE + '"/>'
    [void]$sb.Append('<w:tbl><w:tblPr><w:bidiVisual/><w:tblW w:w="' + $tw + '" w:type="dxa"/><w:tblBorders>' + $bd + '</w:tblBorders><w:tblLayout w:type="fixed"/><w:tblCellMar><w:top w:w="60" w:type="dxa"/><w:left w:w="100" w:type="dxa"/><w:bottom w:w="60" w:type="dxa"/><w:right w:w="100" w:type="dxa"/></w:tblCellMar></w:tblPr><w:tblGrid>')
    foreach ($w in $widths) { [void]$sb.Append('<w:gridCol w:w="' + $w + '"/>') }
    [void]$sb.Append('</w:tblGrid>')
    for ($ri = 0; $ri -lt $rows.Count; $ri++) {
        $r = $rows[$ri]
        $hdr = ($ri -eq 0)
        $trpr = '<w:cantSplit/>'
        if ($hdr) { $trpr += '<w:tblHeader/>' }
        [void]$sb.Append('<w:tr><w:trPr>' + $trpr + '</w:trPr>')
        for ($c = 0; $c -lt $ncol; $c++) {
            $txt = ''
            if ($c -lt $r.Count) { $txt = $r[$c].Trim() }
            $tcpr = '<w:tcW w:w="' + $widths[$c] + '" w:type="dxa"/>'
            if ($hdr) { $tcpr += '<w:shd w:val="clear" w:color="auto" w:fill="' + $HEADFILL + '"/>' }
            $color = ''
            if ($hdr) { $color = $BLUE }
            $inner = Inline $txt 20 $hdr $color
            [void]$sb.Append('<w:tc><w:tcPr>' + $tcpr + '</w:tcPr>' + (Para $inner '' '' '' '<w:spacing w:before="20" w:after="20" w:line="264" w:lineRule="auto"/>') + '</w:tc>')
        }
        [void]$sb.Append('</w:tr>')
    }
    [void]$sb.Append('</w:tbl>')
    return $sb.ToString()
}

$lines = [IO.File]::ReadAllLines($In, [Text.Encoding]::UTF8)
$body = New-Object System.Text.StringBuilder
$nums = New-Object System.Collections.ArrayList   # numIds of decimal lists
$nextNum = 2
$inNum = $false
$i = 0
while ($i -lt $lines.Count) {
    $line = $lines[$i]
    if ($line.Trim() -eq '') { $inNum = $false; $i++; continue }

    if ($line.TrimStart().StartsWith('|')) {
        $rows = @()
        while ($i -lt $lines.Count -and $lines[$i].TrimStart().StartsWith('|')) {
            $cells = $lines[$i].Trim().Trim('|').Split('|')
            $isSep = $true
            foreach ($c in $cells) { if ($c.Trim() -notmatch '^:?-+:?$') { $isSep = $false } }
            if (-not $isSep) { $rows += , ($cells | ForEach-Object { $_.Trim() }) }
            $i++
        }
        [void]$body.Append((Table $rows))
        [void]$body.Append('<w:p><w:pPr><w:bidi/><w:spacing w:after="60"/></w:pPr></w:p>')
        $inNum = $false
        continue
    }

    if ($line -match '^# (.*)$') { [void]$body.Append((Para (Inline $Matches[1] 0 $false '') 'Title' '' '' '')); $i++; continue }
    if ($line -match '^## (.*)$') { [void]$body.Append((Para (Inline $Matches[1] 0 $false '') 'Heading1' '' '' '')); $i++; continue }
    if ($line -match '^### (.*)$') { [void]$body.Append((Para (Inline $Matches[1] 0 $false '') 'Heading2' '' '' '')); $i++; continue }
    if ($line.Trim() -eq '---') {
        $b = '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="' + $LINE + '"/></w:pBdr>'
        [void]$body.Append((Para '' '' '' $b '<w:spacing w:before="60" w:after="120"/>'))
        $i++; continue
    }
    if ($line -match '^(\s*)- (.*)$') {
        $lvl = [Math]::Min(1, [int][Math]::Floor($Matches[1].Length / 2))
        $np = '<w:numPr><w:ilvl w:val="' + $lvl + '"/><w:numId w:val="1"/></w:numPr>'
        [void]$body.Append((Para (Inline $Matches[2] 0 $false '') '' $np '' '<w:spacing w:after="60"/>'))
        $inNum = $false; $i++; continue
    }
    if ($line -match '^(\d+)\. (.*)$') {
        if (-not $inNum) { [void]$nums.Add($nextNum); $nextNum++; $inNum = $true }
        $np = '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="' + $nums[$nums.Count - 1] + '"/></w:numPr>'
        [void]$body.Append((Para (Inline $Matches[2] 0 $false '') '' $np '' '<w:spacing w:after="60"/>'))
        $i++; continue
    }
    [void]$body.Append((Para (Inline $line.Trim() 0 $false '') '' '' '' ''))
    $inNum = $false
    $i++
}

$sect = '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1000" w:right="900" w:bottom="1000" w:left="900" w:header="500" w:footer="500" w:gutter="0"/><w:bidi/></w:sectPr>'
$document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document ' + $W + '><w:body>' + $body.ToString() + $sect + '</w:body></w:document>'

$styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:styles ' + $W + '>' +
 '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:eastAsia="Arial" w:cs="Arial"/><w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="en-US" w:eastAsia="en-US" w:bidi="he-IL"/></w:rPr></w:rPrDefault>' +
 '<w:pPrDefault><w:pPr><w:bidi/><w:spacing w:after="120" w:line="300" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>' +
 '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>' +
 '<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:before="0" w:after="200"/></w:pPr><w:rPr><w:b/><w:bCs/><w:color w:val="' + $BLUE + '"/><w:sz w:val="52"/><w:szCs w:val="52"/></w:rPr></w:style>' +
 '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:pBdr><w:bottom w:val="single" w:sz="12" w:space="3" w:color="' + $ORANGE + '"/></w:pBdr><w:spacing w:before="420" w:after="160"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:bCs/><w:color w:val="' + $BLUE + '"/><w:sz w:val="34"/><w:szCs w:val="34"/></w:rPr></w:style>' +
 '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="280" w:after="100"/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:bCs/><w:color w:val="' + $BLUE + '"/><w:sz w:val="27"/><w:szCs w:val="27"/></w:rPr></w:style>' +
 '</w:styles>'

$numXml = New-Object System.Text.StringBuilder
[void]$numXml.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:numbering ' + $W + '>')
[void]$numXml.Append('<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="hybridMultilevel"/>' +
 '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="&#8226;"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/><w:color w:val="' + $ORANGE + '"/></w:rPr></w:lvl>' +
 '<w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="&#8211;"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="1260" w:hanging="360"/></w:pPr><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/></w:rPr></w:lvl></w:abstractNum>')
[void]$numXml.Append('<w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="hybridMultilevel"/>' +
 '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum>')
[void]$numXml.Append('<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>')
foreach ($n in $nums) {
    [void]$numXml.Append('<w:num w:numId="' + $n + '"><w:abstractNumId w:val="1"/><w:lvlOverride w:ilvl="0"><w:startOverride w:val="1"/></w:lvlOverride></w:num>')
}
[void]$numXml.Append('</w:numbering>')

$settings = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:settings ' + $W + '><w:themeFontLang w:val="en-US" w:bidi="he-IL"/></w:settings>'
$ct = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/><Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/></Types>'
$rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'
$docrels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/></Relationships>'

if (Test-Path $Out) { Remove-Item $Out -Force }
$fs = [IO.File]::Open($Out, [IO.FileMode]::Create)
$zip = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create)
$enc = New-Object System.Text.UTF8Encoding($false)
function AddEntry([string]$name, [string]$content) {
    $e = $zip.CreateEntry($name)
    $s = $e.Open()
    $b = $enc.GetBytes($content)
    $s.Write($b, 0, $b.Length)
    $s.Close()
}
AddEntry '[Content_Types].xml' $ct
AddEntry '_rels/.rels' $rels
AddEntry 'word/document.xml' $document
AddEntry 'word/_rels/document.xml.rels' $docrels
AddEntry 'word/styles.xml' $styles
AddEntry 'word/numbering.xml' $numXml.ToString()
AddEntry 'word/settings.xml' $settings
$zip.Dispose()
$fs.Dispose()
'OK ' + (Get-Item $Out).Length + ' bytes'
