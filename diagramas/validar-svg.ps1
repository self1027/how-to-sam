[CmdletBinding()]
param(
    [string]$SvgDirectory
)

$ErrorActionPreference = 'Stop'
$diagramDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $SvgDirectory) {
    $SvgDirectory = Join-Path $diagramDirectory 'svg'
}
$guide = Get-Content -LiteralPath (Join-Path $diagramDirectory 'guia-de-estudo.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$settings = [System.Xml.XmlReaderSettings]::new()
$settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
$settings.XmlResolver = $null
$validatedCount = 0

foreach ($page in $guide.pages) {
    foreach ($diagram in $page.diagrams) {
        $fileName = "$($page.id)-$($diagram.id).svg"
        $filePath = Join-Path $SvgDirectory $fileName
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            throw "SVG ausente: $fileName"
        }

        $reader = [System.Xml.XmlReader]::Create($filePath, $settings)
        try {
            $document = [System.Xml.XmlDocument]::new()
            $document.XmlResolver = $null
            $document.Load($reader)
        } finally {
            $reader.Dispose()
        }

        $root = $document.DocumentElement
        if ($root.LocalName -ne 'svg' -or $root.NamespaceURI -ne 'http://www.w3.org/2000/svg') {
            throw "Raiz SVG ou namespace invalido: $fileName"
        }
        $unsupported = $document.SelectNodes("//*[local-name()='foreignObject' or local-name()='script' or local-name()='iframe' or namespace-uri()='http://www.w3.org/1999/xhtml']")
        if ($unsupported.Count -gt 0) {
            throw "HTML ou script embutido em $fileName; exporte com htmlLabels=false na raiz da configuracao Mermaid."
        }
        if (-not $root.HasAttribute('viewBox')) {
            throw "viewBox ausente: $fileName"
        }

        $background = $root.SelectSingleNode("*[local-name()='rect' and @data-diagram-background='true']")
        if (-not $background) {
            throw "Fundo ausente: $fileName; execute diagramas/preparar-svg.ps1 antes da validacao."
        }

        $validatedCount++
    }
}

Write-Output "$validatedCount SVGs validados: XML valido, fundo presente e sem HTML embutido."
