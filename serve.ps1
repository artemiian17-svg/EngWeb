$ErrorActionPreference = "Stop"

$port = 8000
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
$listener.Start()

$root = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }
$script:dataPath = Join-Path $root "backend-data.json"
$script:sessions = @{}
$script:authCookieName = "lingoflux_session"
$script:adminUsers = @(
    @{ login = "admin"; password = "admin2026" },
    @{ login = "lingoflux"; password = "lingoflux2026" }
)
$script:messages = @{
    invalidJson = "Invalid JSON payload."
    unauthorized = "Authorization required."
    storageInitialized = "Storage is already initialized."
    invalidCredentials = "Invalid login or password."
    postNotFound = "Post not found."
    apiRouteNotFound = "API route not found."
    internalServerError = "Internal server error."
    forbidden = "Access denied."
    notFound = "Resource not found."
    started = "Server started: http://localhost:$port"
    phone = "Open from phone: http://192.168.0.101:$port"
}

function Get-ContentType {
    param([string]$Path)
    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".html" { return "text/html; charset=utf-8" }
        ".css" { return "text/css; charset=utf-8" }
        ".js" { return "application/javascript; charset=utf-8" }
        ".json" { return "application/json; charset=utf-8" }
        ".png" { return "image/png" }
        ".jpg" { return "image/jpeg" }
        ".jpeg" { return "image/jpeg" }
        ".svg" { return "image/svg+xml" }
        ".ico" { return "image/x-icon" }
        ".txt" { return "text/plain; charset=utf-8" }
        default { return "application/octet-stream" }
    }
}

function Get-DefaultBackendData {
    return @{
        posts = @()
        requests = @()
        lessons = @()
    }
}

function ConvertTo-PlainHashtable {
    param($InputObject)

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $map = @{}
        foreach ($key in $InputObject.Keys) {
            $map[$key] = ConvertTo-PlainHashtable -InputObject $InputObject[$key]
        }
        return $map
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $list = @()
        foreach ($item in $InputObject) {
            $list += ,(ConvertTo-PlainHashtable -InputObject $item)
        }
        return $list
    }

    if ($InputObject -is [pscustomobject] -or $InputObject.GetType().Name -eq "PSCustomObject") {
        $map = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $map[$property.Name] = ConvertTo-PlainHashtable -InputObject $property.Value
        }
        return $map
    }

    return $InputObject
}

function Save-BackendData {
    param([hashtable]$Data)
    $json = $Data | ConvertTo-Json -Depth 100
    [IO.File]::WriteAllText($script:dataPath, $json, [Text.UTF8Encoding]::new($false))
}

function Get-BackendData {
    if (-not (Test-Path $script:dataPath)) {
        $initial = Get-DefaultBackendData
        Save-BackendData -Data $initial
        return $initial
    }
    try {
        $raw = Get-Content -Path $script:dataPath -Raw -Encoding UTF8
        $data = ConvertTo-PlainHashtable -InputObject ($raw | ConvertFrom-Json)
    } catch {
        $data = Get-DefaultBackendData
        Save-BackendData -Data $data
    }
    if (-not $data.posts) { $data.posts = @() }
    if (-not $data.requests) { $data.requests = @() }
    if (-not $data.lessons) { $data.lessons = @() }
    return $data
}

function Find-HeaderEnd {
    param([byte[]]$Bytes)
    for ($index = 0; $index -le $Bytes.Length - 4; $index++) {
        if (
            $Bytes[$index] -eq 13 -and
            $Bytes[$index + 1] -eq 10 -and
            $Bytes[$index + 2] -eq 13 -and
            $Bytes[$index + 3] -eq 10
        ) {
            return $index
        }
    }
    return -1
}

function Get-RequestCookies {
    param([hashtable]$Headers)
    $cookies = @{}
    $raw = $Headers["cookie"]
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $cookies
    }
    foreach ($pair in ($raw -split ";")) {
        $parts = $pair.Split("=", 2)
        if ($parts.Length -eq 2) {
            $cookies[$parts[0].Trim()] = $parts[1].Trim()
        }
    }
    return $cookies
}

function Read-HttpRequest {
    param([System.Net.Sockets.TcpClient]$Client)

    $stream = $Client.GetStream()
    $buffer = New-Object byte[] 4096
    $received = New-Object 'System.Collections.Generic.List[byte]'
    $headerEnd = -1

    while ($headerEnd -lt 0) {
        $read = $stream.Read($buffer, 0, $buffer.Length)
        if ($read -le 0) {
            return $null
        }
        $chunk = [byte[]]$buffer[0..($read - 1)]
        $received.AddRange($chunk)
        $headerEnd = Find-HeaderEnd -Bytes $received.ToArray()
    }

    $allBytes = $received.ToArray()
    $headerBytes = if ($headerEnd -gt 0) { [byte[]]$allBytes[0..($headerEnd - 1)] } else { [byte[]]@() }
    $headerText = if ($headerBytes -and $headerBytes.Length -gt 0) { [Text.Encoding]::ASCII.GetString($headerBytes) } else { "" }
    $lines = $headerText -split "`r`n"
    $requestLine = $lines[0]
    $headers = @{}

    foreach ($line in $lines[1..($lines.Length - 1)]) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        $parts = $line.Split(":", 2)
        if ($parts.Length -eq 2) {
            $headers[$parts[0].Trim().ToLowerInvariant()] = $parts[1].Trim()
        }
    }

    $contentLength = 0
    if ($headers.ContainsKey("content-length")) {
        [void][int]::TryParse($headers["content-length"], [ref]$contentLength)
    }

    $bodyOffset = $headerEnd + 4
    $bodyList = New-Object 'System.Collections.Generic.List[byte]'
    if ($allBytes.Length -gt $bodyOffset) {
        $initialBody = [byte[]]$allBytes[$bodyOffset..($allBytes.Length - 1)]
        $bodyList.AddRange($initialBody)
    }

    while ($bodyList.Count -lt $contentLength) {
        $read = $stream.Read($buffer, 0, [Math]::Min($buffer.Length, $contentLength - $bodyList.Count))
        if ($read -le 0) {
            break
        }
        $chunk = [byte[]]$buffer[0..($read - 1)]
        $bodyList.AddRange($chunk)
    }

    $bodyBytes = [byte[]]@()
    if ($contentLength -gt 0) {
        $bodyArray = [byte[]]$bodyList.ToArray()
        if ($bodyArray.Length -ge $contentLength) {
            $bodyBytes = [byte[]]$bodyArray[0..($contentLength - 1)]
        } else {
            $bodyBytes = $bodyArray
        }
    }

    $requestParts = $requestLine.Split(" ")
    return @{
        Stream = $stream
        Method = if ($requestParts.Length -ge 1) { $requestParts[0].ToUpperInvariant() } else { "GET" }
        RawPath = if ($requestParts.Length -ge 2) { $requestParts[1] } else { "/" }
        Headers = $headers
        Cookies = Get-RequestCookies -Headers $headers
        BodyBytes = $bodyBytes
        BodyText = if ($bodyBytes -and $bodyBytes.Length -gt 0) { [Text.Encoding]::UTF8.GetString($bodyBytes) } else { "" }
    }
}

function Send-Response {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,
        [int]$StatusCode,
        [string]$StatusText,
        [byte[]]$Body,
        [string]$ContentType,
        [hashtable]$Headers = @{}
    )

    $headerLines = New-Object System.Collections.Generic.List[string]
    $headerLines.Add("HTTP/1.1 $StatusCode $StatusText")
    $headerLines.Add("Content-Type: $ContentType")
    $headerLines.Add("Content-Length: $($Body.Length)")
    $headerLines.Add("Connection: close")

    foreach ($key in $Headers.Keys) {
        $value = $Headers[$key]
        if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
            foreach ($item in $value) {
                $headerLines.Add("${key}: $item")
            }
        } else {
            $headerLines.Add("${key}: $value")
        }
    }

    $header = ($headerLines + "", "") -join "`r`n"
    $headerBytes = [Text.Encoding]::ASCII.GetBytes($header)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($Body.Length -gt 0) {
        $Stream.Write($Body, 0, $Body.Length)
    }
}

function Send-Json {
    param(
        [System.Net.Sockets.NetworkStream]$Stream,
        [int]$StatusCode,
        [string]$StatusText,
        $Payload,
        [hashtable]$Headers = @{}
    )

    $json = $Payload | ConvertTo-Json -Depth 100
    $body = [Text.Encoding]::UTF8.GetBytes($json)
    Send-Response -Stream $Stream -StatusCode $StatusCode -StatusText $StatusText -Body $body -ContentType "application/json; charset=utf-8" -Headers $Headers
}

function Read-JsonBody {
    param($Request)
    if ([string]::IsNullOrWhiteSpace($Request.BodyText)) {
        return @{}
    }
    try {
        return ConvertTo-PlainHashtable -InputObject ($Request.BodyText | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Get-SessionId {
    param($Request)
    return $Request.Cookies[$script:authCookieName]
}

function Test-Authorized {
    param($Request)
    $sessionId = Get-SessionId -Request $Request
    return -not [string]::IsNullOrWhiteSpace($sessionId) -and $script:sessions.ContainsKey($sessionId)
}

function Assert-Authorized {
    param($Request)
    if (-not (Test-Authorized -Request $Request)) {
        throw [System.UnauthorizedAccessException]::new($script:messages.unauthorized)
    }
}

function New-ApiError {
    param([string]$Message, [int]$StatusCode)
    $error = [System.Exception]::new($Message)
    $error.Data["StatusCode"] = $StatusCode
    return $error
}

function Get-RouteId {
    param([string]$Path, [string]$Prefix)
    return ($Path.Substring($Prefix.Length)).Trim("/")
}

function Get-BodyValue {
    param(
        [hashtable]$Payload,
        [string]$Key,
        $DefaultValue = ""
    )
    if ($Payload.ContainsKey($Key) -and $null -ne $Payload[$Key]) {
        return $Payload[$Key]
    }
    return $DefaultValue
}

function Handle-ApiRequest {
    param($Request)

    $stream = $Request.Stream
    $path = [Uri]::UnescapeDataString(($Request.RawPath -split "\?")[0])
    $method = $Request.Method

    try {
        switch -Regex ("$method $path") {
            "^GET /api/health$" {
                Send-Json -Stream $stream -StatusCode 200 -StatusText "OK" -Payload @{ ok = $true; backend = "powershell" }
                return
            }
            "^GET /api/bootstrap-status$" {
                $data = Get-BackendData
                $postsCount = @($data.posts).Count
                $requestsCount = @($data.requests).Count
                $lessonsCount = @($data.lessons).Count
                Send-Json -Stream $stream -StatusCode 200 -StatusText "OK" -Payload @{
                    postsCount = $postsCount
                    requestsCount = $requestsCount
                    lessonsCount = $lessonsCount
                    totalCount = $postsCount + $requestsCount + $lessonsCount
                    canBootstrap = ($postsCount -eq 0 -and $requestsCount -eq 0 -and $lessonsCount -eq 0)
                }
                return
            }
            "^POST /api/bootstrap$" {
                $payload = Read-JsonBody -Request $Request
                if ($null -eq $payload) {
                    throw (New-ApiError -Message $script:messages.invalidJson -StatusCode 400)
                }
                $current = Get-BackendData
                if (@($current.posts).Count -gt 0 -or @($current.requests).Count -gt 0 -or @($current.lessons).Count -gt 0) {
                    Send-Json -Stream $stream -StatusCode 409 -StatusText "Conflict" -Payload @{ error = $script:messages.storageInitialized }
                    return
                }
                $current.posts = if ($payload.posts) { @($payload.posts) } else { @() }
                $current.requests = if ($payload.requests) { @($payload.requests) } else { @() }
                $current.lessons = if ($payload.lessons) { @($payload.lessons) } else { @() }
                Save-BackendData -Data $current
                Send-Json -Stream $stream -StatusCode 200 -StatusText "OK" -Payload @{ success = $true }
                return
            }
            "^GET /api/auth/status$" {
                Send-Json -Stream $stream -StatusCode 200 -StatusText "OK" -Payload @{ authorized = (Test-Authorized -Request $Request) }
                return
            }
            "^POST /api/auth/login$" {
                $payload = Read-JsonBody -Request $Request
                if ($null -eq $payload) {
                    throw (New-ApiError -Message $script:messages.invalidJson -StatusCode 400)
                }
                $login = [string](Get-BodyValue -Payload $payload -Key "login")
                $password = [string](Get-BodyValue -Payload $payload -Key "password")
                $match = $script:adminUsers | Where-Object { $_.login -eq $login -and $_.password -eq $password } | Select-Object -First 1
                if (-not $match) {
                    Send-Json -Stream $stream -StatusCode 401 -StatusText "Unauthorized" -Payload @{ success = $false; error = $script:messages.invalidCredentials }
                    return
                }
                $sessionId = [guid]::NewGuid().ToString("N")
                $script:sessions[$sessionId] = @{ login = $login; createdAt = [DateTime]::UtcNow }
                Send-Json -Stream $stream -StatusCode 200 -StatusText "OK" -Payload @{ success = $true; authorized = $true } -Headers @{
                    "Set-Cookie" = "$($script:authCookieName)=$sessionId; Path=/; HttpOnly; SameSite=Lax"
                }
                return
            }
            "^POST /api/auth/logout$" {
                $sessionId = Get-SessionId -Request $Request
                if ($sessionId) { $script:sessions.Remove($sessionId) | Out-Null }
                Send-Json -Stream $stream -StatusCode 200 -StatusText "OK" -Payload @{ success = $true; authorized = $false } -Headers @{
                    "Set-Cookie" = "$($script:authCookieName)=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT; HttpOnly; SameSite=Lax"
                }
                return
            }
            "^GET /api/posts$" {
                Send-Json -Stream $stream -StatusCode 200 -StatusText "OK" -Payload @(Get-BackendData).posts
                return
            }
            "^GET /api/posts/.+$" {
                $postId = Get-RouteId -Path $path -Prefix "/api/posts/"
                $data = Get-BackendData
                $post = @($data.posts) | Where-Object { $_.id -eq $postId } | Select-Object -First 1
                if (-not $post) {
                    Send-Json -Stream $stream -StatusCode 404 -StatusText "Not Found" -Payload @{ error = $script:messages.postNotFound }
                    return
                }
                Send-Json -Stream $stream -StatusCode 200 -StatusText "OK" -Payload $post
                return
            }
            "^POST /api/posts$" {
                Assert-Authorized -Request $Request
                $payload = Read-JsonBody -Request $Request
                if ($null -eq $payload) {
                    throw (New-ApiError -Message $script:messages.invalidJson -StatusCode 400)
                }
                $item = @{
                    id = [string](Get-BodyValue -Payload $payload -Key "id")
                    title = [string](Get-BodyValue -Payload $payload -Key "title")
                    summary = [string](Get-BodyValue -Payload $payload -Key "summary")
                    body = [string](Get-BodyValue -Payload $payload -Key "body")
                    date = [string](Get-BodyValue -Payload $payload -Key "date" -DefaultValue ([DateTime]::UtcNow.ToString("o")))
                    image = [string](Get-BodyValue -Payload $payload -Key "image")
                    attachment = Get-BodyValue -Payload $payload -Key "attachment" -DefaultValue $null
                }
                $data = Get-BackendData
                $data.posts = @($item) + @($data.posts)
                Save-BackendData -Data $data
                Send-Json -Stream $stream -StatusCode 201 -StatusText "Created" -Payload $item
                return
            }
            "^DELETE /api/posts/.+$" {
                Assert-Authorized -Request $Request
                $postId = Get-RouteId -Path $path -Prefix "/api/posts/"
                $data = Get-BackendData
                $before = @($data.posts).Count
                $data.posts = @($data.posts | Where-Object { $_.id -ne $postId })
                Save-BackendData -Data $data
                Send-Json -Stream $stream -StatusCode 200 -StatusText "OK" -Payload @{ success = ($before -ne @($data.posts).Count) }
                return
            }
            "^GET /api/lessons$" {
                Send-Json -Stream $stream -StatusCode 200 -StatusText "OK" -Payload @(Get-BackendData).lessons
                return
            }
            "^POST /api/lessons$" {
                Assert-Authorized -Request $Request
                $payload = Read-JsonBody -Request $Request
                if ($null -eq $payload) {
                    throw (New-ApiError -Message $script:messages.invalidJson -StatusCode 400)
                }
                $item = @{
                    id = [string](Get-BodyValue -Payload $payload -Key "id")
                    language = [string](Get-BodyValue -Payload $payload -Key "language")
                    level = [string](Get-BodyValue -Payload $payload -Key "level")
                    title = [string](Get-BodyValue -Payload $payload -Key "title")
                    duration = [string](Get-BodyValue -Payload $payload -Key "duration")
                    goal = [string](Get-BodyValue -Payload $payload -Key "goal")
                    tasks = if ($payload.tasks) { @($payload.tasks) } else { @() }
                }
                $data = Get-BackendData
                $data.lessons = @($item) + @($data.lessons)
                Save-BackendData -Data $data
                Send-Json -Stream $stream -StatusCode 201 -StatusText "Created" -Payload $item
                return
            }
            "^DELETE /api/lessons/.+$" {
                Assert-Authorized -Request $Request
                $lessonId = Get-RouteId -Path $path -Prefix "/api/lessons/"
                $data = Get-BackendData
                $before = @($data.lessons).Count
                $data.lessons = @($data.lessons | Where-Object { $_.id -ne $lessonId })
                Save-BackendData -Data $data
                Send-Json -Stream $stream -StatusCode 200 -StatusText "OK" -Payload @{ success = ($before -ne @($data.lessons).Count) }
                return
            }
            "^GET /api/requests$" {
                Assert-Authorized -Request $Request
                Send-Json -Stream $stream -StatusCode 200 -StatusText "OK" -Payload @(Get-BackendData).requests
                return
            }
            "^POST /api/requests$" {
                $payload = Read-JsonBody -Request $Request
                if ($null -eq $payload) {
                    throw (New-ApiError -Message $script:messages.invalidJson -StatusCode 400)
                }
                $item = @{
                    id = [string](Get-BodyValue -Payload $payload -Key "id")
                    fullname = [string](Get-BodyValue -Payload $payload -Key "fullname")
                    phone = [string](Get-BodyValue -Payload $payload -Key "phone")
                    email = [string](Get-BodyValue -Payload $payload -Key "email")
                    message = [string](Get-BodyValue -Payload $payload -Key "message")
                    date = [string](Get-BodyValue -Payload $payload -Key "date" -DefaultValue ([DateTime]::UtcNow.ToString("o")))
                }
                $data = Get-BackendData
                $data.requests = @($item) + @($data.requests)
                Save-BackendData -Data $data
                Send-Json -Stream $stream -StatusCode 201 -StatusText "Created" -Payload $item
                return
            }
            "^DELETE /api/requests/.+$" {
                Assert-Authorized -Request $Request
                $requestId = Get-RouteId -Path $path -Prefix "/api/requests/"
                $data = Get-BackendData
                $before = @($data.requests).Count
                $data.requests = @($data.requests | Where-Object { $_.id -ne $requestId })
                Save-BackendData -Data $data
                Send-Json -Stream $stream -StatusCode 200 -StatusText "OK" -Payload @{ success = ($before -ne @($data.requests).Count) }
                return
            }
            default {
                Send-Json -Stream $stream -StatusCode 404 -StatusText "Not Found" -Payload @{ error = $script:messages.apiRouteNotFound }
                return
            }
        }
    } catch [System.UnauthorizedAccessException] {
        Send-Json -Stream $stream -StatusCode 401 -StatusText "Unauthorized" -Payload @{ error = $_.Exception.Message }
    } catch {
        $statusCode = if ($_.Exception.Data.Contains("StatusCode")) { [int]$_.Exception.Data["StatusCode"] } else { 500 }
        $statusText = switch ($statusCode) {
            400 { "Bad Request" }
            401 { "Unauthorized" }
            403 { "Forbidden" }
            404 { "Not Found" }
            409 { "Conflict" }
            default { "Internal Server Error" }
        }
        $message = if ([string]::IsNullOrWhiteSpace($_.Exception.Message)) { $script:messages.internalServerError } else { $_.Exception.Message }
        Send-Json -Stream $stream -StatusCode $statusCode -StatusText $statusText -Payload @{ error = $message }
    }
}

Write-Host $script:messages.started
Write-Host $script:messages.phone
Write-Host "Backend data file: $script:dataPath"
Write-Host "Press Ctrl+C to stop"

while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $request = Read-HttpRequest -Client $client
        if ($null -eq $request) {
            continue
        }
        $stream = $request.Stream
        $rawPath = $request.RawPath
        $cleanPath = [Uri]::UnescapeDataString(($rawPath -split "\?")[0])
        if ($cleanPath.StartsWith("/api/", [StringComparison]::OrdinalIgnoreCase)) {
            Handle-ApiRequest -Request $request
            continue
        }
        if ($cleanPath -eq "/") {
            $cleanPath = "/index.html"
        }
        $relativePath = $cleanPath.TrimStart("/").Replace("/", "\")
        $fullPath = [IO.Path]::GetFullPath((Join-Path $root $relativePath))
        if (-not $fullPath.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
            $body = [Text.Encoding]::UTF8.GetBytes($script:messages.forbidden)
            Send-Response -Stream $stream -StatusCode 403 -StatusText "Forbidden" -Body $body -ContentType "text/plain; charset=utf-8"
            continue
        }
        if ((Test-Path $fullPath) -and (Get-Item $fullPath).PSIsContainer) {
            $fullPath = Join-Path $fullPath "index.html"
        }
        if (-not (Test-Path $fullPath)) {
            $body = [Text.Encoding]::UTF8.GetBytes($script:messages.notFound)
            Send-Response -Stream $stream -StatusCode 404 -StatusText "Not Found" -Body $body -ContentType "text/plain; charset=utf-8"
            continue
        }
        $bytes = [IO.File]::ReadAllBytes($fullPath)
        $contentType = Get-ContentType -Path $fullPath
        Send-Response -Stream $stream -StatusCode 200 -StatusText "OK" -Body $bytes -ContentType $contentType
    } finally {
        $client.Close()
    }
}
