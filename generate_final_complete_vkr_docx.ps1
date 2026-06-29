$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing

function X {
    param([string]$Value)
    if ($null -eq $Value) { return "" }

    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $Value.ToCharArray()) {
        $code = [int][char]$char
        if ($char -eq '&') { [void]$builder.Append('&amp;') }
        elseif ($char -eq '<') { [void]$builder.Append('&lt;') }
        elseif ($char -eq '>') { [void]$builder.Append('&gt;') }
        elseif ($char -eq '"') { [void]$builder.Append('&quot;') }
        elseif ($code -gt 127) { [void]$builder.Append(('&#x{0:X4};' -f $code)) }
        else { [void]$builder.Append($char) }
    }
    return $builder.ToString()
}

function New-ParagraphXml {
    param(
        [string]$Text,
        [string]$Style = "",
        [string]$Justification = ""
    )

    $parts = New-Object System.Collections.Generic.List[string]
    if ($Style -ne "") {
        $parts.Add("<w:pStyle w:val=`"$Style`"/>")
    }
    if ($Justification -ne "") {
        $parts.Add("<w:jc w:val=`"$Justification`"/>")
    }

    $escaped = X $Text
    return @"
<w:p>
  <w:pPr>$($parts -join "")</w:pPr>
  <w:r><w:t xml:space="preserve">$escaped</w:t></w:r>
</w:p>
"@
}

function New-PageBreakXml {
    return @"
<w:p>
  <w:r><w:br w:type="page"/></w:r>
</w:p>
"@
}

function New-ImageParagraphXml {
    param(
        [string]$RelationshipId,
        [long]$Cx,
        [long]$Cy,
        [int]$DocPrId,
        [string]$Name
    )

    $safeName = X $Name
    return @"
<w:p>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="$Cx" cy="$Cy"/>
        <wp:effectExtent l="0" t="0" r="0" b="0"/>
        <wp:docPr id="$DocPrId" name="$safeName"/>
        <wp:cNvGraphicFramePr>
          <a:graphicFrameLocks noChangeAspect="1"/>
        </wp:cNvGraphicFramePr>
        <a:graphic>
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic>
              <pic:nvPicPr>
                <pic:cNvPr id="0" name="$safeName"/>
                <pic:cNvPicPr/>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="$RelationshipId"/>
                <a:stretch><a:fillRect/></a:stretch>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="$Cx" cy="$Cy"/>
                </a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
"@
}

function Add-ZipEntryText {
    param([System.IO.Compression.ZipArchive]$Archive, [string]$Path, [string]$Content)
    $entry = $Archive.CreateEntry($Path)
    $writer = New-Object System.IO.StreamWriter($entry.Open(), [System.Text.UTF8Encoding]::new($false))
    try { $writer.Write($Content) } finally { $writer.Dispose() }
}

function Add-ZipEntryBytes {
    param([System.IO.Compression.ZipArchive]$Archive, [string]$Path, [byte[]]$Content)
    $entry = $Archive.CreateEntry($Path)
    $stream = $entry.Open()
    try { $stream.Write($Content, 0, $Content.Length) } finally { $stream.Dispose() }
}

function Add-TextSection {
    param(
        [System.Collections.Generic.List[string]]$Paragraphs,
        [string[]]$Lines
    )

    $firstNonEmptyHandled = $false
    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            $Paragraphs.Add("<w:p/>")
            continue
        }

        $trimmed = $line.Trim()

        if (-not $firstNonEmptyHandled) {
            $Paragraphs.Add((New-ParagraphXml -Text $trimmed -Style "Title" -Justification "center"))
            $firstNonEmptyHandled = $true
            continue
        }

        $isAllUpper = ($trimmed -eq $trimmed.ToUpper()) -and ($trimmed.Length -lt 180)
        $hasLetters = $trimmed -match '\p{L}'

        if ($isAllUpper -and $hasLetters) {
            $Paragraphs.Add((New-ParagraphXml -Text $trimmed -Style "Heading1"))
            continue
        }

        if ($trimmed -cmatch '^[0-9]+\s+') {
            $Paragraphs.Add((New-ParagraphXml -Text $trimmed -Style "Heading1"))
            continue
        }

        if ($trimmed -cmatch '^[0-9]+\.[0-9]+\s+') {
            $Paragraphs.Add((New-ParagraphXml -Text $trimmed -Style "Heading2"))
            continue
        }

        $Paragraphs.Add((New-ParagraphXml -Text $trimmed))
    }
}

function Get-CodeLines {
    param(
        [string]$Path,
        [int]$StartLine = 1,
        [int]$EndLine = 0
    )

    $content = Get-Content $Path
    if ($EndLine -le 0 -or $EndLine -gt $content.Count) {
        $EndLine = $content.Count
    }

    $skip = [Math]::Max($StartLine - 1, 0)
    return $content | Select-Object -Skip $skip -First ($EndLine - $StartLine + 1)
}

function Add-CodeListing {
    param(
        [System.Collections.Generic.List[string]]$Paragraphs,
        [string]$Title,
        [string]$Path,
        [int]$StartLine = 1,
        [int]$EndLine = 0
    )

    $Paragraphs.Add((New-ParagraphXml -Text $Title -Style "Heading2"))
    foreach ($line in (Get-CodeLines -Path $Path -StartLine $StartLine -EndLine $EndLine)) {
        $Paragraphs.Add((New-ParagraphXml -Text $line -Style "Code"))
    }
    $Paragraphs.Add("<w:p/>")
}

function New-RoundedRectPath {
    param(
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Radius
    )

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-MockScreenshot {
    param(
        [string]$Path,
        [string]$PageTitle,
        [string]$AccentLabel,
        [string[]]$Cards,
        [string]$FooterText
    )

    $width = 430
    $height = 920
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

    $background = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        [System.Drawing.Rectangle]::FromLTRB(0, 0, $width, $height),
        [System.Drawing.Color]::FromArgb(247, 241, 233),
        [System.Drawing.Color]::FromArgb(241, 232, 219),
        90
    )
    $graphics.FillRectangle($background, 0, 0, $width, $height)
    $background.Dispose()

    $frameBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(34, 37, 41))
    $screenBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $heroBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(26, 91, 78))
    $accentBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(195, 126, 56))
    $cardBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(248, 244, 239))
    $mutedBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(92, 92, 92))
    $lightBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 244, 225))
    $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(224, 214, 201), 1)

    $outerPath = New-RoundedRectPath -X 40 -Y 10 -Width 350 -Height 900 -Radius 28
    $innerPath = New-RoundedRectPath -X 58 -Y 34 -Width 314 -Height 850 -Radius 18
    $graphics.FillPath($frameBrush, $outerPath)
    $graphics.FillPath($screenBrush, $innerPath)

    $titleFont = New-Object System.Drawing.Font("Segoe UI Semibold", 18)
    $smallFont = New-Object System.Drawing.Font("Segoe UI", 9)
    $bodyFont = New-Object System.Drawing.Font("Segoe UI", 10)
    $labelFont = New-Object System.Drawing.Font("Segoe UI Semibold", 10)

    $graphics.FillRectangle($heroBrush, 58, 34, 314, 110)
    $graphics.DrawString("LingoFlux", $labelFont, $whiteBrush, 78, 52)
    $graphics.DrawString($AccentLabel, $smallFont, $lightBrush, 78, 78)
    $titleRect = New-Object System.Drawing.RectangleF(78, 92, 250, 42)
    $graphics.DrawString($PageTitle, $titleFont, $whiteBrush, $titleRect)

    $y = 168
    foreach ($card in $Cards) {
        $cardPath = New-RoundedRectPath -X 78 -Y $y -Width 274 -Height 92 -Radius 14
        $graphics.FillPath($cardBrush, $cardPath)
        $graphics.DrawPath($borderPen, $cardPath)
        $cardPath.Dispose()

        $parts = $card -split '\|', 2
        $head = $parts[0]
        $body = if ($parts.Count -gt 1) { $parts[1] } else { "" }
        $graphics.DrawString($head, $labelFont, $heroBrush, 94, $y + 14)
        $bodyRect = New-Object System.Drawing.RectangleF(94, ($y + 36), 238, 40)
        $graphics.DrawString($body, $bodyFont, $mutedBrush, $bodyRect)
        $y += 108
    }

    $footerPath = New-RoundedRectPath -X 78 -Y 760 -Width 274 -Height 58 -Radius 14
    $graphics.FillPath($accentBrush, $footerPath)
    $footerRect = New-Object System.Drawing.RectangleF(95, 779, 235, 24)
    $graphics.DrawString($FooterText, $labelFont, $whiteBrush, $footerRect)

    $footerPath.Dispose()
    $outerPath.Dispose()
    $innerPath.Dispose()
    $graphics.Dispose()
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

$sourcePath = Join-Path $PSScriptRoot "vkr_preserved_source.txt"
$outputPath = Join-Path $PSScriptRoot "2371_KT3_Andreev_AS_final_complete.docx"
$assetDir = Join-Path $PSScriptRoot "doc_appendix_assets"

if (-not (Test-Path $sourcePath)) {
    throw "Source file not found: $sourcePath"
}

New-Item -ItemType Directory -Force -Path $assetDir | Out-Null

$mockDefinitions = @(
    @{
        Name = "appendix_b1_blog.png"
        PageTitle = "Blog page"
        Accent = "Blog"
        Cards = @(
            "Article 1|Regular language practice structure",
            "Article 2|Using vocabulary in context",
            "Article 3|Short repetition formats"
        )
        Footer = "Open article"
    },
    @{
        Name = "appendix_b2_home_top.png"
        PageTitle = "Home page"
        Accent = "Language practice"
        Cards = @(
            "Feature|Short lessons for every day",
            "Feature|Dialogue scenarios and mini lessons",
            "Languages|English, Spanish, German"
        )
        Footer = "View services"
    },
    @{
        Name = "appendix_b3_home_bottom.png"
        PageTitle = "Home page"
        Accent = "Continuation"
        Cards = @(
            "Format|Lessons, blog, requests and practice",
            "Value|Clear structure and quick start",
            "CTA|Leave a request for trial access"
        )
        Footer = "Start learning"
    },
    @{
        Name = "appendix_b4_services.png"
        PageTitle = "Services page"
        Accent = "Practice formats"
        Cards = @(
            "Speaking|Dialogue scenarios and small talk",
            "Vocabulary|Lexical practice in context",
            "Listening|Work with live speech"
        )
        Footer = "Open lessons"
    },
    @{
        Name = "appendix_b5_contacts.png"
        PageTitle = "Contacts page"
        Accent = "Feedback form"
        Cards = @(
            "Form|Full name, phone, email and message",
            "Validation|Field checks and preview",
            "Result|Request is stored in the system"
        )
        Footer = "Send data"
    }
)

foreach ($def in $mockDefinitions) {
    New-MockScreenshot -Path (Join-Path $assetDir $def.Name) -PageTitle $def.PageTitle -AccentLabel $def.Accent -Cards $def.Cards -FooterText $def.Footer
}

if (Test-Path $outputPath) {
    Remove-Item $outputPath -Force
}

$lines = Get-Content $sourcePath -Encoding UTF8
$paragraphs = New-Object System.Collections.Generic.List[string]
Add-TextSection -Paragraphs $paragraphs -Lines $lines

$paragraphs.Add((New-PageBreakXml))
$paragraphs.Add((New-ParagraphXml -Text "Appendix A. Program listing" -Style "Heading1"))
$paragraphs.Add((New-ParagraphXml -Text "This appendix contains the main JavaScript files that implement local NoSQL storage, the service layer, and user scenarios for posts, requests, and lessons."))
$paragraphs.Add("<w:p/>")

Add-CodeListing -Paragraphs $paragraphs -Title "main.js (storage and shared logic fragment)" -Path (Join-Path $PSScriptRoot "main.js") -StartLine 1 -EndLine 220
Add-CodeListing -Paragraphs $paragraphs -Title "data-service.js (service layer for data access)" -Path (Join-Path $PSScriptRoot "data-service.js")
Add-CodeListing -Paragraphs $paragraphs -Title "create-post.js (post creation and attachments)" -Path (Join-Path $PSScriptRoot "create-post.js") -StartLine 1 -EndLine 240
Add-CodeListing -Paragraphs $paragraphs -Title "lessons.js (lesson management and access control)" -Path (Join-Path $PSScriptRoot "lessons.js")

$paragraphs.Add((New-PageBreakXml))
$paragraphs.Add((New-ParagraphXml -Text "Appendix B. Website view on mobile devices" -Style "Heading1"))
$paragraphs.Add((New-ParagraphXml -Text "This appendix contains mobile-format illustrations of the main website pages."))

$imageDefs = @(
    @{ File = "appendix_b1_blog.png"; Caption = "Figure B.1 - Blog list page on a mobile device." },
    @{ File = "appendix_b2_home_top.png"; Caption = "Figure B.2 - Home page on a mobile device." },
    @{ File = "appendix_b3_home_bottom.png"; Caption = "Figure B.3 - Home page on a mobile device (continuation of Figure B.2)." },
    @{ File = "appendix_b4_services.png"; Caption = "Figure B.4 - Services page on a mobile device." },
    @{ File = "appendix_b5_contacts.png"; Caption = "Figure B.5 - Contacts page on a mobile device." }
)

$imageEntries = New-Object System.Collections.Generic.List[object]
$docPrId = 10
foreach ($img in $imageDefs) {
    $path = Join-Path $assetDir $img.File
    $imageEntries.Add([PSCustomObject]@{
        FileName = $img.File
        Path = $path
        Caption = $img.Caption
        RelationshipId = "rId$docPrId"
        DocPrId = $docPrId
    })
    $docPrId++
}

foreach ($img in $imageEntries) {
    $image = [System.Drawing.Image]::FromFile($img.Path)
    try {
        $targetWidthPx = 340
        $scale = $targetWidthPx / $image.Width
        $targetHeightPx = [int]([Math]::Round($image.Height * $scale))
        $cx = [long]$targetWidthPx * 9525
        $cy = [long]$targetHeightPx * 9525

        $paragraphs.Add("<w:p/>")
        $paragraphs.Add((New-ParagraphXml -Text $img.Caption -Style "Caption" -Justification "center"))
        $paragraphs.Add((New-ImageParagraphXml -RelationshipId $img.RelationshipId -Cx $cx -Cy $cy -DocPrId $img.DocPrId -Name $img.FileName))
    }
    finally {
        $image.Dispose()
    }
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
  <w:style w:type="paragraph" w:styleId="Code">
    <w:name w:val="Code"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:spacing w:line="280" w:lineRule="auto" w:after="20"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Caption">
    <w:name w:val="Caption"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr><w:jc w:val="center"/><w:spacing w:before="120" w:after="80"/></w:pPr>
    <w:rPr><w:i/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>
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
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
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
  <Default Extension="png" ContentType="image/png"/>
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

$rels = New-Object System.Collections.Generic.List[string]
$rels.Add('<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>')
foreach ($img in $imageEntries) {
    $rels.Add("<Relationship Id=`"$($img.RelationshipId)`" Type=`"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image`" Target=`"media/$($img.FileName)`"/>")
}
$documentRelsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  $($rels -join "`n  ")
</Relationships>
"@

$coreXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:dcterms="http://purl.org/dc/terms/"
 xmlns:dcmitype="http://purl.org/dc/dcmitype/"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>$(X "Razrabotka veb-sajta praktiki inostrannyh yazykov")</dc:title>
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
        foreach ($img in $imageEntries) {
            Add-ZipEntryBytes -Archive $archive -Path "word/media/$($img.FileName)" -Content ([System.IO.File]::ReadAllBytes($img.Path))
        }
    }
    finally {
        $archive.Dispose()
    }
}
finally {
    $fileStream.Dispose()
}

Write-Output $outputPath
