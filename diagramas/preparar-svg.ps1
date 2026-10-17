[CmdletBinding()]
param(
    [string]$SvgDirectory,
    [ValidateRange(8, 128)]
    [double]$Padding = 32
)

$ErrorActionPreference = 'Stop'
$diagramDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $SvgDirectory) {
    $SvgDirectory = Join-Path $diagramDirectory 'svg'
}
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$svgNamespace = 'http://www.w3.org/2000/svg'
$preparedCount = 0

function Format-SvgNumber([double]$Value) {
    return $Value.ToString('0.######', [System.Globalization.CultureInfo]::InvariantCulture)
}

foreach ($svgFile in Get-ChildItem -LiteralPath $SvgDirectory -Filter '*.svg' -File) {
    $document = [System.Xml.XmlDocument]::new()
    $document.XmlResolver = $null
    $document.PreserveWhitespace = $true
    $document.Load($svgFile.FullName)
    $root = $document.DocumentElement

    $originalViewBox = $root.GetAttribute('data-diagram-viewbox')
    if (-not $originalViewBox) {
        $originalViewBox = $root.GetAttribute('viewBox')
        $root.SetAttribute('data-diagram-viewbox', $originalViewBox)
    }
    $bounds = @($originalViewBox.Trim() -split '[,\s]+' | ForEach-Object {
        [double]::Parse($_, $culture)
    })
    if ($bounds.Count -ne 4) {
        throw "viewBox invalido: $($svgFile.Name)"
    }

    $x = $bounds[0] - $Padding
    $y = $bounds[1] - $Padding
    $width = $bounds[2] + 2 * $Padding
    $height = $bounds[3] + 2 * $Padding
    $viewBox = @($x, $y, $width, $height) | ForEach-Object { Format-SvgNumber $_ }
    $root.SetAttribute('viewBox', ($viewBox -join ' '))
    $root.SetAttribute('width', (Format-SvgNumber $width))
    $root.SetAttribute('height', (Format-SvgNumber $height))
    $root.SetAttribute('preserveAspectRatio', 'xMidYMid meet')

    $background = $root.SelectSingleNode("*[local-name()='rect' and @data-diagram-background='true']")
    if (-not $background) {
        $background = $document.CreateElement('rect', $svgNamespace)
        $background.SetAttribute('data-diagram-background', 'true')
        $null = $root.PrependChild($background)
    }
    $background.SetAttribute('x', (Format-SvgNumber ($x + 0.5)))
    $background.SetAttribute('y', (Format-SvgNumber ($y + 0.5)))
    $background.SetAttribute('width', (Format-SvgNumber ($width - 1)))
    $background.SetAttribute('height', (Format-SvgNumber ($height - 1)))
    $background.SetAttribute('rx', '16')
    $background.SetAttribute('fill', '#f6f8fc')
    $background.SetAttribute('stroke', '#d8e2ee')
    $background.SetAttribute('stroke-width', '1')

    $settings = [System.Xml.XmlWriterSettings]::new()
    $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
    $settings.OmitXmlDeclaration = $true
    $settings.Indent = $false
    $writer = [System.Xml.XmlWriter]::Create($svgFile.FullName, $settings)
    try {
        $document.Save($writer)
    } finally {
        $writer.Dispose()
    }
    $preparedCount++
}

Write-Output "$preparedCount SVGs preparados com fundo claro, borda e margem interna."
