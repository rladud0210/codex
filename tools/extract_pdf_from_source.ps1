$ErrorActionPreference = "Stop"

$pdfPath = "C:\Users\admin\Desktop\codex\source.pdf"
$outPath = "C:\Users\admin\Desktop\codex\out\word_pdf_extract.txt"

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0

try {
    $doc = $word.Documents.Open($pdfPath, $false, $true)
    $text = $doc.Content.Text
    Set-Content -LiteralPath $outPath -Value $text -Encoding UTF8
    "OPENED"
    "Pages=$($doc.ComputeStatistics(2))"
    "Chars=$($text.Length)"
    if ($text.Length -gt 3000) {
        $text.Substring(0, 3000)
    } else {
        $text
    }
    $doc.Close(0)
}
finally {
    $word.Quit()
}
