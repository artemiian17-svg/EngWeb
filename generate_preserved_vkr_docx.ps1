$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function X {
    param([string]$Value)
    if ($null -eq $Value) { return "" }

    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $Value.ToCharArray()) {
        $code = [int][char]$char
        if ($char -eq '&') { [void]$builder.Append('&amp;') }
        elseif ($char -eq '<') { [void]$builder.Append('&lt;') }
        elseif ($char -eq '>') { [void]$builder.Append('&gt;') }
        elseif ($code -gt 127) { [void]$builder.Append(('&#x{0:X4};' -f $code)) }
        else { [void]$builder.Append($char) }
    }
    return $builder.ToString()
}

function New-ParagraphXml {
    param([string]$Text, [string]$Style = "")

    $styleXml = ""
    if ($Style -ne "") {
        $styleXml = "<w:pStyle w:val=`"$Style`"/>"
    }

    $escaped = X $Text
    return @"
<w:p>
  <w:pPr>$styleXml</w:pPr>
  <w:r><w:t xml:space="preserve">$escaped</w:t></w:r>
</w:p>
"@
}

function Add-ZipEntryText {
    param([System.IO.Compression.ZipArchive]$Archive, [string]$Path, [string]$Content)
    $entry = $Archive.CreateEntry($Path)
    $writer = New-Object System.IO.StreamWriter($entry.Open(), [System.Text.UTF8Encoding]::new($false))
    try { $writer.Write($Content) } finally { $writer.Dispose() }
}

$sourcePath = Join-Path $PSScriptRoot "vkr_preserved_source.txt"
$outputPath = Join-Path $PSScriptRoot "2371_KT3_Andreev_AS_preserved_updated.docx"

if (-not (Test-Path $sourcePath)) {
    throw "Source file not found: $sourcePath"
}

if (Test-Path $outputPath) {
    Remove-Item $outputPath -Force
}

$lines = Get-Content $sourcePath -Encoding UTF8
$paragraphs = New-Object System.Collections.Generic.List[string]
$documentTitle = "Updated document"
$firstNonEmptyHandled = $false

foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        $paragraphs.Add("<w:p/>")
        continue
    }

    $trimmed = $line.Trim()

    if (-not $firstNonEmptyHandled) {
        $documentTitle = $trimmed
        $paragraphs.Add((New-ParagraphXml -Text $trimmed -Style "Title"))
        $firstNonEmptyHandled = $true
        continue
    }

    $isAllUpper = ($trimmed -eq $trimmed.ToUpper()) -and ($trimmed.Length -lt 180)
    $hasLetters = $trimmed -match '\p{L}'

    if ($isAllUpper -and $hasLetters) {
        $paragraphs.Add((New-ParagraphXml -Text $trimmed -Style "Heading1"))
        continue
    }

    if ($trimmed -cmatch '^[0-9]+\s+') {
        $paragraphs.Add((New-ParagraphXml -Text $trimmed -Style "Heading1"))
        continue
    }

    if ($trimmed -cmatch '^[0-9]+\.[0-9]+\s+') {
        $paragraphs.Add((New-ParagraphXml -Text $trimmed -Style "Heading2"))
        continue
    }

    $paragraphs.Add((New-ParagraphXml -Text $trimmed))
}

$stylesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:line="360" w:lineRule="auto" w:after="120"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/><w:sz w:val="28"/><w:szCs w:val="28"/><w:lang w:val="ru-RU"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:jc w:val="center"/><w:spacing w:before="240" w:after="240"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="30"/><w:szCs w:val="30"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:before="160" w:after="80"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr>
  </w:style>
</w:styles>
"@

$documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
 xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
 xmlns:v="urn:schemas-microsoft-com:vml"
 xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:w10="urn:schemas-microsoft-com:office:word"
 xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
 xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"
 xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk"
 xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml"
 xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"
 mc:Ignorable="w14 wp14">
  <w:body>
    $($paragraphs -join "`n")
    <w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>
  </w:body>
</w:document>
"@

$contentTypesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
"@

$rootRelsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
"@

$documentRelsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
"@

$coreXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:dcterms="http://purl.org/dc/terms/"
 xmlns:dcmitype="http://purl.org/dc/dcmitype/"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>$(X $documentTitle)</dc:title>
  <dc:creator>Codex</dc:creator>
  <cp:lastModifiedBy>Codex</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">2026-05-08T00:00:00Z</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">2026-05-08T00:00:00Z</dcterms:modified>
</cp:coreProperties>
"@

$appXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
 xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Microsoft Office Word</Application>
</Properties>
"@

$fileStream = [System.IO.File]::Open($outputPath, [System.IO.FileMode]::Create)
try {
    $archive = New-Object System.IO.Compression.ZipArchive($fileStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        Add-ZipEntryText -Archive $archive -Path "[Content_Types].xml" -Content $contentTypesXml
        Add-ZipEntryText -Archive $archive -Path "_rels/.rels" -Content $rootRelsXml
        Add-ZipEntryText -Archive $archive -Path "docProps/core.xml" -Content $coreXml
        Add-ZipEntryText -Archive $archive -Path "docProps/app.xml" -Content $appXml
        Add-ZipEntryText -Archive $archive -Path "word/document.xml" -Content $documentXml
        Add-ZipEntryText -Archive $archive -Path "word/styles.xml" -Content $stylesXml
        Add-ZipEntryText -Archive $archive -Path "word/_rels/document.xml.rels" -Content $documentRelsXml
    }
    finally { $archive.Dispose() }
}
finally { $fileStream.Dispose() }

Write-Output $outputPath
