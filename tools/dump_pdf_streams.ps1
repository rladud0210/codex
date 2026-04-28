$ErrorActionPreference = "Stop"

$pdfPath = "C:\Users\admin\Desktop\codex\source.pdf"
$outDir = "C:\Users\admin\Desktop\codex\out\streams"

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$bytes = [System.IO.File]::ReadAllBytes($pdfPath)
$text = [System.Text.Encoding]::ASCII.GetString($bytes)

function Expand-FlateStream {
    param(
        [byte[]]$Data
    )

    $input = New-Object System.IO.MemoryStream
    $input.Write($Data, 0, $Data.Length)
    $input.Position = 0

    $output = New-Object System.IO.MemoryStream
    $deflate = New-Object System.IO.Compression.DeflateStream($input, [System.IO.Compression.CompressionMode]::Decompress)

    try {
        $buffer = New-Object byte[] 4096
        while (($read = $deflate.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $output.Write($buffer, 0, $read)
        }
        return $output.ToArray()
    }
    finally {
        $deflate.Dispose()
        $output.Dispose()
        $input.Dispose()
    }
}

$objRegex = [regex]'(?ms)(\d+)\s+0\s+obj(.*?)endobj'
$matches = $objRegex.Matches($text)

foreach ($match in $matches) {
    $objNum = $match.Groups[1].Value
    $objBody = $match.Groups[2].Value

    if ($objBody -notmatch '/Filter/FlateDecode') {
        continue
    }

    $streamIndex = $objBody.IndexOf("stream")
    if ($streamIndex -lt 0) {
        continue
    }

    $bodyStart = $match.Groups[2].Index
    $streamStartInText = $bodyStart + $streamIndex + 6

    while ($streamStartInText -lt $text.Length -and ($bytes[$streamStartInText] -eq 10 -or $bytes[$streamStartInText] -eq 13 -or $bytes[$streamStartInText] -eq 32)) {
        $streamStartInText++
    }

    $lengthMatch = [regex]::Match($objBody, '/Length\s+(\d+)')
    if (-not $lengthMatch.Success) {
        continue
    }

    $length = [int]$lengthMatch.Groups[1].Value
    if ($length -le 0) {
        continue
    }

    $streamBytes = New-Object byte[] $length
    [Array]::Copy($bytes, $streamStartInText, $streamBytes, 0, $length)

    try {
        $inflated = Expand-FlateStream -Data $streamBytes
        $outFile = Join-Path $outDir ("obj_{0}.bin" -f $objNum)
        [System.IO.File]::WriteAllBytes($outFile, $inflated)
        $preview = [System.Text.Encoding]::UTF8.GetString($inflated)
        $previewFile = Join-Path $outDir ("obj_{0}.txt" -f $objNum)
        Set-Content -LiteralPath $previewFile -Value $preview -Encoding UTF8
        "OK $objNum"
    }
    catch {
        "ERR $objNum $($_.Exception.Message)"
    }
}
