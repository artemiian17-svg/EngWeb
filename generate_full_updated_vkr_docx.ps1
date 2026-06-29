$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function U {
    param([string]$Value)
    return [System.Text.RegularExpressions.Regex]::Replace(
        $Value,
        '\\u([0-9a-fA-F]{4})',
        {
            param($Match)
            [char][int]::Parse($Match.Groups[1].Value, [System.Globalization.NumberStyles]::HexNumber)
        }
    )
}

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
    if ($Style -ne "") { $styleXml = "<w:pStyle w:val=`"$Style`"/>" }
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

$outputPath = Join-Path $PSScriptRoot "2371_KT3_Andreev_AS_full_updated_v4.docx"
if (Test-Path $outputPath) { Remove-Item $outputPath -Force }

$lines = @(
    @{ t = U '\u0420\u0410\u0417\u0420\u0410\u0411\u041e\u0422\u041a\u0410 \u0412\u0415\u0411-\u0421\u0410\u0419\u0422\u0410 \u041f\u0420\u0410\u041a\u0422\u0418\u041a\u0418 \u0418\u041d\u041e\u0421\u0422\u0420\u0410\u041d\u041d\u042b\u0425 \u042f\u0417\u042b\u041a\u041e\u0412'; s = 'Title' }
    @{ t = '' }
    @{ t = U '\u0410\u0432\u0442\u043e\u0440: \u0410\u043d\u0434\u0440\u0435\u0435\u0432 \u0410.\u0421.' }
    @{ t = U '\u041d\u0430\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u0438\u0435: 09.03.02 \u0418\u043d\u0444\u043e\u0440\u043c\u0430\u0446\u0438\u043e\u043d\u043d\u044b\u0435 \u0441\u0438\u0441\u0442\u0435\u043c\u044b \u0438 \u0442\u0435\u0445\u043d\u043e\u043b\u043e\u0433\u0438\u0438' }
    @{ t = U '\u041f\u0440\u043e\u0444\u0438\u043b\u044c: \u0418\u043d\u0444\u043e\u0440\u043c\u0430\u0446\u0438\u043e\u043d\u043d\u044b\u0435 \u0441\u0438\u0441\u0442\u0435\u043c\u044b \u0438 \u0442\u0435\u0445\u043d\u043e\u043b\u043e\u0433\u0438\u0438 \u0432 \u0431\u0438\u0437\u043d\u0435\u0441\u0435' }
    @{ t = '' }
    @{ t = U '\u0420\u0415\u0424\u0415\u0420\u0410\u0422'; s = 'Heading1' }
    @{ t = U '\u0420\u0430\u0437\u0440\u0430\u0431\u043e\u0442\u043a\u0430, \u0432\u0435\u0431-\u0441\u0430\u0439\u0442, \u0438\u043d\u043e\u0441\u0442\u0440\u0430\u043d\u043d\u044b\u0435 \u044f\u0437\u044b\u043a\u0438, \u0438\u043d\u0442\u0435\u0440\u0444\u0435\u0439\u0441, \u0443\u0440\u043e\u043a\u0438, \u0431\u043b\u043e\u0433, \u0437\u0430\u044f\u0432\u043a\u0430, NoSQL, IndexedDB, \u0441\u0435\u0440\u0432\u0438\u0441.' }
    @{ t = U '\u041e\u0431\u044a\u0435\u043a\u0442\u043e\u043c \u0440\u0430\u0437\u0440\u0430\u0431\u043e\u0442\u043a\u0438 \u044f\u0432\u043b\u044f\u0435\u0442\u0441\u044f \u0432\u0435\u0431-\u0441\u0430\u0439\u0442 \u043f\u0440\u0430\u043a\u0442\u0438\u043a\u0438 \u0438\u043d\u043e\u0441\u0442\u0440\u0430\u043d\u043d\u044b\u0445 \u044f\u0437\u044b\u043a\u043e\u0432, \u043f\u0440\u0435\u0434\u043d\u0430\u0437\u043d\u0430\u0447\u0435\u043d\u043d\u044b\u0439 \u0434\u043b\u044f \u043f\u0440\u0435\u0434\u0441\u0442\u0430\u0432\u043b\u0435\u043d\u0438\u044f \u0443\u0441\u043b\u0443\u0433 \u043f\u043b\u0430\u0442\u0444\u043e\u0440\u043c\u044b \u0438 \u043e\u0440\u0433\u0430\u043d\u0438\u0437\u0430\u0446\u0438\u0438 \u0432\u0437\u0430\u0438\u043c\u043e\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u044f \u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u0442\u0435\u043b\u0435\u0439 \u0441 \u0443\u0447\u0435\u0431\u043d\u044b\u043c \u043a\u043e\u043d\u0442\u0435\u043d\u0442\u043e\u043c.' }
    @{ t = U '\u0412\u0435\u0431-\u0441\u0430\u0439\u0442 \u0440\u0430\u0437\u0440\u0430\u0431\u043e\u0442\u0430\u043d \u0441 \u0438\u0441\u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u043d\u0438\u0435\u043c HTML5, CSS3 \u0438 JavaScript. \u0425\u0440\u0430\u043d\u0435\u043d\u0438\u0435 \u0434\u0430\u043d\u043d\u044b\u0445 \u0432 \u0442\u0435\u043a\u0443\u0449\u0435\u0439 \u0432\u0435\u0440\u0441\u0438\u0438 \u043f\u0440\u043e\u0435\u043a\u0442\u0430 \u0440\u0435\u0430\u043b\u0438\u0437\u043e\u0432\u0430\u043d\u043e \u0441 \u043f\u043e\u043c\u043e\u0449\u044c\u044e \u043a\u043b\u0438\u0435\u043d\u0442\u0441\u043a\u043e\u0433\u043e NoSQL-\u0445\u0440\u0430\u043d\u0438\u043b\u0438\u0449\u0430 IndexedDB. \u0414\u043b\u044f \u0443\u043d\u0438\u0444\u0438\u043a\u0430\u0446\u0438\u0438 \u0434\u043e\u0441\u0442\u0443\u043f\u0430 \u043a \u0434\u0430\u043d\u043d\u044b\u043c \u0438\u0441\u043f\u043e\u043b\u044c\u0437\u0443\u0435\u0442\u0441\u044f \u0441\u0435\u0440\u0432\u0438\u0441\u043d\u044b\u0439 \u0441\u043b\u043e\u0439 data-service.js.' }
    @{ t = '' }
    @{ t = 'ABSTRACT'; s = 'Heading1' }
    @{ t = 'The subject of this development project is a website for foreign language practice. It is intended to serve as an informational and educational resource.' }
    @{ t = 'The website is developed using HTML5, CSS3, and JavaScript. Data storage is implemented with the client-side NoSQL mechanism IndexedDB. A separate service layer, data-service.js, is used to organize access to posts, requests, lessons, and authorization state.' }
    @{ t = '' }
    @{ t = U '\u041e\u041f\u0420\u0415\u0414\u0415\u041b\u0415\u041d\u0418\u042f, \u041e\u0411\u041e\u0417\u041d\u0410\u0427\u0415\u041d\u0418\u042f \u0418 \u0421\u041e\u041a\u0420\u0410\u0429\u0415\u041d\u0418\u042f'; s = 'Heading1' }
    @{ t = U 'API \u2014 \u043f\u0440\u043e\u0433\u0440\u0430\u043c\u043c\u043d\u044b\u0439 \u0438\u043d\u0442\u0435\u0440\u0444\u0435\u0439\u0441 \u043f\u0440\u0438\u043b\u043e\u0436\u0435\u043d\u0438\u044f.' }
    @{ t = U 'IndexedDB \u2014 \u0432\u0441\u0442\u0440\u043e\u0435\u043d\u043d\u043e\u0435 \u0432 \u0431\u0440\u0430\u0443\u0437\u0435\u0440 \u043a\u043b\u0438\u0435\u043d\u0442\u0441\u043a\u043e\u0435 NoSQL-\u0445\u0440\u0430\u043d\u0438\u043b\u0438\u0449\u0435.' }
    @{ t = U '\u0412\u0412\u0415\u0414\u0415\u041d\u0418\u0415'; s = 'Heading1' }
    @{ t = U '\u0412 \u0443\u0441\u043b\u043e\u0432\u0438\u044f\u0445 \u0430\u043a\u0442\u0438\u0432\u043d\u043e\u0433\u043e \u0440\u0430\u0437\u0432\u0438\u0442\u0438\u044f \u0446\u0438\u0444\u0440\u043e\u0432\u044b\u0445 \u0442\u0435\u0445\u043d\u043e\u043b\u043e\u0433\u0438\u0439 \u043e\u0441\u043e\u0431\u0443\u044e \u0437\u043d\u0430\u0447\u0438\u043c\u043e\u0441\u0442\u044c \u043f\u0440\u0438\u043e\u0431\u0440\u0435\u0442\u0430\u0435\u0442 \u0441\u043e\u0437\u0434\u0430\u043d\u0438\u0435 \u043e\u0431\u0440\u0430\u0437\u043e\u0432\u0430\u0442\u0435\u043b\u044c\u043d\u044b\u0445 \u0432\u0435\u0431-\u0440\u0435\u0441\u0443\u0440\u0441\u043e\u0432. \u041e\u0434\u043d\u0438\u043c \u0438\u0437 \u0432\u043e\u0441\u0442\u0440\u0435\u0431\u043e\u0432\u0430\u043d\u043d\u044b\u0445 \u043d\u0430\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u0438\u0439 \u044f\u0432\u043b\u044f\u0435\u0442\u0441\u044f \u043e\u0440\u0433\u0430\u043d\u0438\u0437\u0430\u0446\u0438\u044f \u043f\u0440\u0430\u043a\u0442\u0438\u043a\u0438 \u0438\u043d\u043e\u0441\u0442\u0440\u0430\u043d\u043d\u044b\u0445 \u044f\u0437\u044b\u043a\u043e\u0432 \u0432 \u043e\u043d\u043b\u0430\u0439\u043d-\u0444\u043e\u0440\u043c\u0430\u0442\u0435.' }
    @{ t = U '1 \u0410\u041d\u0410\u041b\u0418\u0417 \u0417\u0410\u0414\u0410\u0427\u0418 \u0421\u041e\u0417\u0414\u0410\u041d\u0418\u042f \u0412\u0415\u0411-\u0421\u0410\u0419\u0422\u0410 \u041f\u0420\u0410\u041a\u0422\u0418\u041a\u0418 \u0418\u041d\u041e\u0421\u0422\u0420\u0410\u041d\u041d\u042b\u0425 \u042f\u0417\u042b\u041a\u041e\u0412'; s = 'Heading1' }
    @{ t = U '1.1 \u041e\u0431\u0437\u043e\u0440 \u0438 \u0430\u043d\u0430\u043b\u0438\u0437 \u043e\u0441\u043d\u043e\u0432\u043d\u044b\u0445 \u0440\u0430\u0437\u0434\u0435\u043b\u043e\u0432 \u0432\u0435\u0431-\u0441\u0430\u0439\u0442\u0430'; s = 'Heading2' }
    @{ t = U '\u041e\u0441\u043d\u043e\u0432\u043d\u044b\u043c\u0438 \u0440\u0430\u0437\u0434\u0435\u043b\u0430\u043c\u0438 \u0441\u0430\u0439\u0442\u0430 \u044f\u0432\u043b\u044f\u044e\u0442\u0441\u044f \u0433\u043b\u0430\u0432\u043d\u0430\u044f \u0441\u0442\u0440\u0430\u043d\u0438\u0446\u0430, \u0443\u0441\u043b\u0443\u0433\u0438, \u0443\u0440\u043e\u043a\u0438, \u0431\u043b\u043e\u0433, \u043a\u043e\u043d\u0442\u0430\u043a\u0442\u044b \u0438 \u0441\u043b\u0443\u0436\u0435\u0431\u043d\u044b\u0435 \u0441\u0442\u0440\u0430\u043d\u0438\u0446\u044b \u0443\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u0438\u044f \u043a\u043e\u043d\u0442\u0435\u043d\u0442\u043e\u043c.' }
    @{ t = U '2 \u0424\u041e\u0420\u041c\u0418\u0420\u041e\u0412\u0410\u041d\u0418\u0415 \u0422\u0420\u0415\u0411\u041e\u0412\u0410\u041d\u0418\u0419 \u041a \u0412\u0415\u0411-\u0421\u0410\u0419\u0422\u0423'; s = 'Heading1' }
    @{ t = U '2.1 \u0422\u0440\u0435\u0431\u043e\u0432\u0430\u043d\u0438\u044f \u043a \u0438\u043d\u0442\u0435\u0440\u0444\u0435\u0439\u0441\u0443'; s = 'Heading2' }
    @{ t = U '\u0418\u043d\u0442\u0435\u0440\u0444\u0435\u0439\u0441 \u0434\u043e\u043b\u0436\u0435\u043d \u0431\u044b\u0442\u044c \u0430\u0434\u0430\u043f\u0442\u0438\u0432\u043d\u044b\u043c, \u0435\u0434\u0438\u043d\u044b\u043c \u043f\u043e \u0441\u0442\u0438\u043b\u044e \u0438 \u0443\u0434\u043e\u0431\u043d\u044b\u043c \u0434\u043b\u044f \u0438\u0441\u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u043d\u0438\u044f \u043d\u0430 \u0440\u0430\u0437\u043d\u044b\u0445 \u0443\u0441\u0442\u0440\u043e\u0439\u0441\u0442\u0432\u0430\u0445.' }
    @{ t = U '2.2 \u0422\u0440\u0435\u0431\u043e\u0432\u0430\u043d\u0438\u044f \u043a \u0445\u0440\u0430\u043d\u0435\u043d\u0438\u044e \u0434\u0430\u043d\u043d\u044b\u0445'; s = 'Heading2' }
    @{ t = U '\u0414\u0430\u043d\u043d\u044b\u0435 \u043e \u043f\u0443\u0431\u043b\u0438\u043a\u0430\u0446\u0438\u044f\u0445, \u0437\u0430\u044f\u0432\u043a\u0430\u0445, \u0443\u0440\u043e\u043a\u0430\u0445 \u0438 \u0441\u043e\u0441\u0442\u043e\u044f\u043d\u0438\u0438 \u0430\u0432\u0442\u043e\u0440\u0438\u0437\u0430\u0446\u0438\u0438 \u0434\u043e\u043b\u0436\u043d\u044b \u0441\u043e\u0445\u0440\u0430\u043d\u044f\u0442\u044c\u0441\u044f \u0432 \u043a\u043b\u0438\u0435\u043d\u0442\u0441\u043a\u043e\u043c NoSQL-\u0445\u0440\u0430\u043d\u0438\u043b\u0438\u0449\u0435 IndexedDB.' }
    @{ t = U '3 \u041e\u0411\u0417\u041e\u0420 \u0421\u041e\u0412\u0420\u0415\u041c\u0415\u041d\u041d\u042b\u0425 \u0421\u041f\u041e\u0421\u041e\u0411\u041e\u0412 \u0421\u041e\u0417\u0414\u0410\u041d\u0418\u042f \u0412\u0415\u0411-\u0421\u0410\u0419\u0422\u041e\u0412'; s = 'Heading1' }
    @{ t = U '3.1 \u0410\u043d\u0430\u043b\u0438\u0437 \u0438 \u0432\u044b\u0431\u043e\u0440 \u0442\u0435\u0445\u043d\u043e\u043b\u043e\u0433\u0438\u0439'; s = 'Heading2' }
    @{ t = U '\u0414\u043b\u044f \u0440\u0435\u0430\u043b\u0438\u0437\u0430\u0446\u0438\u0438 \u043f\u0440\u043e\u0435\u043a\u0442\u0430 \u0432\u044b\u0431\u0440\u0430\u043d \u0441\u0442\u0435\u043a HTML5, CSS3 \u0438 JavaScript \u0441 \u043a\u043b\u0438\u0435\u043d\u0442\u0441\u043a\u0438\u043c NoSQL-\u0445\u0440\u0430\u043d\u0438\u043b\u0438\u0449\u0435\u043c IndexedDB \u0438 \u0441\u0435\u0440\u0432\u0438\u0441\u043d\u044b\u043c \u0441\u043b\u043e\u0435\u043c data-service.js.' }
    @{ t = U '4 \u0420\u0410\u0417\u0420\u0410\u0411\u041e\u0422\u041a\u0410 \u0412\u0415\u0411-\u0421\u0410\u0419\u0422\u0410'; s = 'Heading1' }
    @{ t = U '4.1 \u041e\u0431\u0437\u043e\u0440 \u0441\u0442\u0440\u0443\u043a\u0442\u0443\u0440\u044b \u043f\u0440\u043e\u0435\u043a\u0442\u0430'; s = 'Heading2' }
    @{ t = U '\u0412 \u043a\u043e\u0440\u043d\u0435\u0432\u043e\u0439 \u0434\u0438\u0440\u0435\u043a\u0442\u043e\u0440\u0438\u0438 \u0440\u0430\u0441\u043f\u043e\u043b\u043e\u0436\u0435\u043d\u044b \u0441\u0442\u0440\u0430\u043d\u0438\u0446\u044b index.html, services.html, lessons.html, blog.html, post.html, contacts.html, login.html, create-post.html \u0438 requests.html, \u0430 \u0442\u0430\u043a\u0436\u0435 \u0444\u0430\u0439\u043b\u044b main.js, data-service.js \u0438 scripts \u0441\u0442\u0440\u0430\u043d\u0438\u0446.' }
    @{ t = U '4.2 \u0425\u0440\u0430\u043d\u0435\u043d\u0438\u0435 \u0434\u0430\u043d\u043d\u044b\u0445'; s = 'Heading2' }
    @{ t = U '\u0414\u043b\u044f \u0445\u0440\u0430\u043d\u0435\u043d\u0438\u044f \u0434\u0430\u043d\u043d\u044b\u0445 \u0438\u0441\u043f\u043e\u043b\u044c\u0437\u0443\u0435\u0442\u0441\u044f IndexedDB. \u0412 \u0431\u0430\u0437\u0435 lingoflux-nosql \u0441\u043e\u0437\u0434\u0430\u0435\u0442\u0441\u044f \u0445\u0440\u0430\u043d\u0438\u043b\u0438\u0449\u0435 appState, \u0432 \u043a\u043e\u0442\u043e\u0440\u043e\u043c \u0441\u043e\u0445\u0440\u0430\u043d\u044f\u044e\u0442\u0441\u044f \u043f\u0443\u0431\u043b\u0438\u043a\u0430\u0446\u0438\u0438, \u0437\u0430\u044f\u0432\u043a\u0438, \u0443\u0440\u043e\u043a\u0438 \u0438 \u0441\u043e\u0441\u0442\u043e\u044f\u043d\u0438\u0435 \u0430\u0432\u0442\u043e\u0440\u0438\u0437\u0430\u0446\u0438\u0438.' }
    @{ t = U '4.3 \u041a\u043b\u0438\u0435\u043d\u0442-\u0441\u0435\u0440\u0432\u0438\u0441\u043d\u043e\u0435 \u0432\u0437\u0430\u0438\u043c\u043e\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0435'; s = 'Heading2' }
    @{ t = U '\u0412\u0437\u0430\u0438\u043c\u043e\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0435 \u0441 \u0434\u0430\u043d\u043d\u044b\u043c\u0438 \u043e\u0440\u0433\u0430\u043d\u0438\u0437\u043e\u0432\u0430\u043d\u043e \u0447\u0435\u0440\u0435\u0437 data-service.js. \u0421\u0435\u0440\u0432\u0438\u0441 \u043f\u0440\u0435\u0434\u043e\u0441\u0442\u0430\u0432\u043b\u044f\u0435\u0442 \u043c\u0435\u0442\u043e\u0434\u044b list, getById, create, remove \u0438 status \u0434\u043b\u044f \u0440\u0430\u0431\u043e\u0442\u044b \u0441 \u043f\u043e\u0441\u0442\u0430\u043c\u0438, \u0437\u0430\u044f\u0432\u043a\u0430\u043c\u0438, \u0443\u0440\u043e\u043a\u0430\u043c\u0438 \u0438 \u0430\u0432\u0442\u043e\u0440\u0438\u0437\u0430\u0446\u0438\u0435\u0439.' }
    @{ t = U '4.4 \u0420\u0430\u0437\u0433\u0440\u0430\u043d\u0438\u0447\u0435\u043d\u0438\u0435 \u0434\u043e\u0441\u0442\u0443\u043f\u0430'; s = 'Heading2' }
    @{ t = U '\u041e\u0431\u044b\u0447\u043d\u044b\u0439 \u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u0442\u0435\u043b\u044c \u043c\u043e\u0436\u0435\u0442 \u043f\u0440\u043e\u0441\u043c\u0430\u0442\u0440\u0438\u0432\u0430\u0442\u044c \u0443\u0440\u043e\u043a\u0438, \u043d\u043e \u043d\u0435 \u043c\u043e\u0436\u0435\u0442 \u0441\u043e\u0437\u0434\u0430\u0432\u0430\u0442\u044c \u0438 \u0443\u0434\u0430\u043b\u044f\u0442\u044c \u0438\u0445. \u042d\u0442\u0438 \u0434\u0435\u0439\u0441\u0442\u0432\u0438\u044f \u0434\u043e\u0441\u0442\u0443\u043f\u043d\u044b \u0442\u043e\u043b\u044c\u043a\u043e \u0430\u0432\u0442\u043e\u0440\u0438\u0437\u043e\u0432\u0430\u043d\u043d\u043e\u043c\u0443 \u0441\u043e\u0442\u0440\u0443\u0434\u043d\u0438\u043a\u0443.' }
    @{ t = U '5 \u042d\u041a\u041e\u041d\u041e\u041c\u0418\u0427\u0415\u0421\u041a\u041e\u0415 \u041e\u0411\u041e\u0421\u041d\u041e\u0412\u0410\u041d\u0418\u0415'; s = 'Heading1' }
    @{ t = U '\u0420\u0430\u0437\u0440\u0430\u0431\u043e\u0442\u043a\u0430 \u0446\u0438\u0444\u0440\u043e\u0432\u044b\u0445 \u043e\u0431\u0440\u0430\u0437\u043e\u0432\u0430\u0442\u0435\u043b\u044c\u043d\u044b\u0445 \u0440\u0435\u0441\u0443\u0440\u0441\u043e\u0432 \u0442\u0440\u0435\u0431\u0443\u0435\u0442 \u0442\u0440\u0443\u0434\u043e\u0432\u044b\u0445 \u0438 \u0442\u0435\u0445\u043d\u0438\u0447\u0435\u0441\u043a\u0438\u0445 \u0437\u0430\u0442\u0440\u0430\u0442. \u0417\u0430\u0442\u0440\u0430\u0442\u044b \u043e\u043f\u0440\u0430\u0432\u0434\u0430\u043d\u044b \u043f\u0440\u0430\u043a\u0442\u0438\u0447\u0435\u0441\u043a\u043e\u0439 \u0446\u0435\u043d\u043d\u043e\u0441\u0442\u044c\u044e \u043f\u0440\u043e\u0435\u043a\u0442\u0430 \u0438 \u0432\u043e\u0437\u043c\u043e\u0436\u043d\u043e\u0441\u0442\u044c\u044e \u0435\u0433\u043e \u0434\u0430\u043b\u044c\u043d\u0435\u0439\u0448\u0435\u0433\u043e \u0440\u0430\u0437\u0432\u0438\u0442\u0438\u044f.' }
    @{ t = U '\u0417\u0410\u041a\u041b\u042e\u0427\u0415\u041d\u0418\u0415'; s = 'Heading1' }
    @{ t = U '\u0412 \u0440\u0435\u0437\u0443\u043b\u044c\u0442\u0430\u0442\u0435 \u0440\u0430\u0431\u043e\u0442\u044b \u0431\u044b\u043b \u0441\u043e\u0437\u0434\u0430\u043d \u0432\u0435\u0431-\u0441\u0430\u0439\u0442 \u043f\u0440\u0430\u043a\u0442\u0438\u043a\u0438 \u0438\u043d\u043e\u0441\u0442\u0440\u0430\u043d\u043d\u044b\u0445 \u044f\u0437\u044b\u043a\u043e\u0432. \u0421\u0430\u0439\u0442 \u0438\u043c\u0435\u0435\u0442 \u0441\u043e\u0432\u0440\u0435\u043c\u0435\u043d\u043d\u044b\u0439 \u0432\u0438\u0434, \u0430\u0434\u0430\u043f\u0442\u0438\u0432\u043d\u0443\u044e \u0441\u0442\u0440\u0443\u043a\u0442\u0443\u0440\u0443 \u0438 \u043d\u0430\u0431\u043e\u0440 \u0438\u043d\u0442\u0435\u0440\u0430\u043a\u0442\u0438\u0432\u043d\u044b\u0445 \u0444\u0443\u043d\u043a\u0446\u0438\u0439.' }
    @{ t = U '\u0422\u0435\u043a\u0443\u0449\u0430\u044f \u0432\u0435\u0440\u0441\u0438\u044f \u043f\u0440\u043e\u0435\u043a\u0442\u0430 \u0440\u0435\u0430\u043b\u0438\u0437\u043e\u0432\u0430\u043d\u0430 \u043d\u0430 HTML5, CSS3 \u0438 JavaScript. \u0414\u043b\u044f \u0445\u0440\u0430\u043d\u0435\u043d\u0438\u044f \u0434\u0430\u043d\u043d\u044b\u0445 \u0438\u0441\u043f\u043e\u043b\u044c\u0437\u0443\u0435\u0442\u0441\u044f IndexedDB, \u0430 \u0432\u0437\u0430\u0438\u043c\u043e\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0435 \u0441 \u043d\u0438\u043c \u043e\u0440\u0433\u0430\u043d\u0438\u0437\u043e\u0432\u0430\u043d\u043e \u0447\u0435\u0440\u0435\u0437 data-service.js.' }
    @{ t = U '\u0421\u041f\u0418\u0421\u041e\u041a \u0418\u0421\u041f\u041e\u041b\u042c\u0417\u041e\u0412\u0410\u041d\u041d\u042b\u0425 \u0418\u0421\u0422\u041e\u0427\u041d\u0418\u041a\u041e\u0412'; s = 'Heading1' }
    @{ t = '1. MDN Web Docs. HTML, CSS, JavaScript, IndexedDB API.' }
    @{ t = U '2. \u041c\u0430\u043a\u043a\u043e\u043d\u043d\u0435\u043b\u043b \u0421. \u0421\u043e\u0432\u0435\u0440\u0448\u0435\u043d\u043d\u044b\u0439 \u043a\u043e\u0434. \u041c\u0430\u0441\u0442\u0435\u0440-\u043a\u043b\u0430\u0441\u0441.' }
    @{ t = U '\u041f\u0420\u0418\u041b\u041e\u0416\u0415\u041d\u0418\u0415 \u0410. \u041b\u0418\u0421\u0422\u0418\u041d\u0413 \u041f\u0420\u041e\u0413\u0420\u0410\u041c\u041c\u042b'; s = 'Heading1' }
    @{ t = U '\u0412 \u043f\u0440\u0438\u043b\u043e\u0436\u0435\u043d\u0438\u0438 \u043f\u0440\u0438\u0432\u043e\u0434\u044f\u0442\u0441\u044f \u043e\u0441\u043d\u043e\u0432\u043d\u044b\u0435 \u0444\u0430\u0439\u043b\u044b \u043f\u0440\u043e\u0435\u043a\u0442\u0430, \u0440\u0435\u0430\u043b\u0438\u0437\u0443\u044e\u0449\u0438\u0435 \u0438\u043d\u0442\u0435\u0440\u0444\u0435\u0439\u0441, \u0441\u0435\u0440\u0432\u0438\u0441\u043d\u044b\u0439 \u0441\u043b\u043e\u0439 \u0438 \u0445\u0440\u0430\u043d\u0435\u043d\u0438\u0435 \u0434\u0430\u043d\u043d\u044b\u0445.' }
    @{ t = U '\u041f\u0420\u0418\u041b\u041e\u0416\u0415\u041d\u0418\u0415 \u0411. \u041e\u0422\u041e\u0411\u0420\u0410\u0416\u0415\u041d\u0418\u0415 \u0412\u0415\u0411-\u0421\u0410\u0419\u0422\u0410 \u041d\u0410 \u041c\u041e\u0411\u0418\u041b\u042c\u041d\u042b\u0425 \u0423\u0421\u0422\u0420\u041e\u0419\u0421\u0422\u0412\u0410\u0425'; s = 'Heading1' }
    @{ t = U '\u0412 \u043f\u0440\u0438\u043b\u043e\u0436\u0435\u043d\u0438\u0438 \u0434\u043e\u043b\u0436\u043d\u044b \u0431\u044b\u0442\u044c \u0440\u0430\u0437\u043c\u0435\u0449\u0435\u043d\u044b \u0441\u043a\u0440\u0438\u043d\u0448\u043e\u0442\u044b \u0433\u043b\u0430\u0432\u043d\u043e\u0439 \u0441\u0442\u0440\u0430\u043d\u0438\u0446\u044b, \u0443\u0441\u043b\u0443\u0433, \u0443\u0440\u043e\u043a\u043e\u0432, \u0431\u043b\u043e\u0433\u0430 \u0438 \u043a\u043e\u043d\u0442\u0430\u043a\u0442\u043e\u0432.' }
)

$paragraphs = New-Object System.Collections.Generic.List[string]
foreach ($item in $lines) {
    if ($item.t -eq '') {
        $paragraphs.Add('<w:p/>')
    } else {
        $style = if ($item.ContainsKey('s')) { $item.s } else { '' }
        $paragraphs.Add((New-ParagraphXml -Text $item.t -Style $style))
    }
}

$stylesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/><w:qFormat/>
    <w:pPr><w:spacing w:line="360" w:lineRule="auto" w:after="120"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/><w:sz w:val="28"/><w:szCs w:val="28"/><w:lang w:val="ru-RU"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:qFormat/>
    <w:pPr><w:jc w:val="center"/><w:spacing w:before="240" w:after="240"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:qFormat/>
    <w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="30"/><w:szCs w:val="30"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:qFormat/>
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
  <dc:title>$(X ($lines[0].t))</dc:title>
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
