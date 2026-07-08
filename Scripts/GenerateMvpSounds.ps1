param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$sampleRate = 44100
$baseDir = Join-Path $Root "Sources/SquishMac/Resources/Sounds"

function Write-Wav {
    param(
        [string]$Path,
        [double[]]$Samples
    )

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null

    $stream = [System.IO.File]::Create($Path)
    $writer = New-Object System.IO.BinaryWriter($stream)

    try {
        $byteRate = $sampleRate * 2
        $dataSize = $Samples.Count * 2

        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
        $writer.Write([int](36 + $dataSize))
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
        $writer.Write([int]16)
        $writer.Write([int16]1)
        $writer.Write([int16]1)
        $writer.Write([int]$sampleRate)
        $writer.Write([int]$byteRate)
        $writer.Write([int16]2)
        $writer.Write([int16]16)
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
        $writer.Write([int]$dataSize)

        foreach ($sample in $Samples) {
            $clamped = [Math]::Max(-1.0, [Math]::Min(1.0, $sample))
            $writer.Write([int16]($clamped * 32767))
        }
    }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

function New-Sound {
    param(
        [string]$Kind,
        [int]$Variant
    )

    $duration = switch ($Kind) {
        "bubble" { 0.18 + $Variant * 0.025 }
        "slime" { 0.42 + $Variant * 0.035 }
        "squishy" { 0.32 + $Variant * 0.030 }
        "pop" { 0.14 + $Variant * 0.018 }
        default { 0.25 }
    }

    $count = [int]($sampleRate * $duration)
    $samples = New-Object double[] $count
    $random = New-Object System.Random (1000 + ($Kind.GetHashCode() -band 0xffff) + $Variant)

    for ($i = 0; $i -lt $count; $i++) {
        $t = $i / $sampleRate
        $u = $i / [Math]::Max(1, $count - 1)
        $noise = ($random.NextDouble() * 2.0) - 1.0
        $value = 0.0

        switch ($Kind) {
            "bubble" {
                $env = [Math]::Exp(-20.0 * $u)
                $freq = 620 + 180 * $Variant - 260 * $u
                $value = [Math]::Sin(2 * [Math]::PI * $freq * $t) * $env
                $value += $noise * 0.18 * [Math]::Exp(-45.0 * $u)
            }
            "slime" {
                $env = [Math]::Sin([Math]::PI * $u) * [Math]::Exp(-1.2 * $u)
                $freq = 90 + 45 * [Math]::Sin(2 * [Math]::PI * (2.0 + $Variant) * $t)
                $value = [Math]::Sin(2 * [Math]::PI * $freq * $t) * 0.55 * $env
                $value += $noise * 0.22 * $env
            }
            "squishy" {
                $env = [Math]::Sin([Math]::PI * $u)
                $freq = 180 + 90 * $u + 25 * $Variant
                $value = [Math]::Sin(2 * [Math]::PI * $freq * $t) * 0.45 * $env
                $value += [Math]::Sin(2 * [Math]::PI * ($freq * 0.5) * $t) * 0.25 * $env
                $value += $noise * 0.12 * $env
            }
            "pop" {
                $env = [Math]::Exp(-36.0 * $u)
                $freq = 1050 + 220 * $Variant
                $value = [Math]::Sin(2 * [Math]::PI * $freq * $t) * $env
                $value += $noise * 0.35 * [Math]::Exp(-80.0 * $u)
            }
        }

        $samples[$i] = $value * 0.75
    }

    return $samples
}

foreach ($kind in @("bubble", "slime", "squishy", "pop")) {
    for ($variant = 1; $variant -le 3; $variant++) {
        $path = Join-Path $baseDir "$kind/$kind-$variant.wav"
        Write-Wav -Path $path -Samples (New-Sound -Kind $kind -Variant $variant)
    }
}

Write-Host "Generated MVP sounds in $baseDir"
