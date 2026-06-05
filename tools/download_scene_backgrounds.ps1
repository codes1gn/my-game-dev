$scenes = @(
    @{ file = "bg_temple.jpg"; prompt = "Ancient Chinese mountain temple shrouded in thick fog, dark eerie atmosphere, moss covered stone steps, weathered wooden pillars, dim lantern light, detective crime scene investigation, photorealistic, cinematic lighting, 4K" },
    @{ file = "bg_smart_apartment.jpg"; prompt = "Modern Chinese luxury apartment with amber warm lighting, smart home devices, LED strips, glass windows at night, dark crime scene atmosphere, photorealistic, cinematic noir, 4K" },
    @{ file = "bg_mansion.jpg"; prompt = "Luxurious Chinese villa interior, dark mahogany furniture, grand staircase, dim chandelier, mirrors creating unsettling reflections, dark mystery atmosphere, photorealistic, crime scene, 4K" },
    @{ file = "bg_old_apartment.jpg"; prompt = "Dark cramped old Chinese apartment room, sealed windows with tape, dim single bulb lighting, claustrophobic atmosphere, crime scene investigation, photorealistic, noir style, 4K" },
    @{ file = "bg_clinic.jpg"; prompt = "Traditional Chinese medicine clinic interior, old wooden medicine cabinets, dried herbs hanging from ceiling, dim lighting, dusty sinister eerie atmosphere, crime scene investigation, photorealistic, 4K" },
    @{ file = "bg_house_domestic.jpg"; prompt = "Modest Chinese family house interior, broken furniture, signs of domestic violence, scattered toys, dim fluorescent light, oppressive atmosphere, crime scene, photorealistic, dark cinematic, 4K" },
    @{ file = "bg_fishing_port.jpg"; prompt = "Chinese fishing port at night, rusty abandoned boats, wet wooden docks, flickering street lamp, fog from sea, dark mysterious atmosphere, crime scene investigation, photorealistic, cinematic noir, 4K" },
    @{ file = "bg_bar.jpg"; prompt = "Dark Chinese cocktail bar interior, neon signs reflecting on glass, drinks on counter, dim purple red lighting, empty stools, mysterious noir atmosphere, crime scene, photorealistic, 4K" },
    @{ file = "bg_piano_house.jpg"; prompt = "Old Chinese residential building stairwell, worn concrete stairs, grand piano visible through half open door on third floor, dim natural light, melancholic atmosphere, crime scene, photorealistic, 4K" }
)

$outDir = Join-Path $PSScriptRoot "..\assets\scenes"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$success = 0
$failed = 0

foreach ($s in $scenes) {
    $outPath = Join-Path $outDir $s.file
    if (Test-Path $outPath) {
        $existing = Get-Item $outPath
        if ($existing.Length -gt 10000) {
            Write-Host "[SKIP] $($s.file) already exists ($($existing.Length) bytes)" -ForegroundColor Yellow
            $success++
            continue
        }
        Remove-Item $outPath -Force
    }

    $encoded = [System.Uri]::EscapeDataString($s.prompt)
    $url = "https://image.pollinations.ai/prompt/${encoded}?width=1920&height=1080&nologo=true"

    Write-Host "[DOWN] $($s.file) ..." -ForegroundColor Cyan
    curl.exe -L --max-time 180 --silent --output $outPath $url 2>$null

    if (Test-Path $outPath) {
        $fi = Get-Item $outPath
        $bytes = [System.IO.File]::ReadAllBytes($fi.FullName)
        if ($bytes.Length -gt 5000 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8) {
            Write-Host "[OK]   $($s.file) - $($fi.Length) bytes" -ForegroundColor Green
            $success++
        } else {
            Write-Host "[FAIL] $($s.file) - not a valid JPEG ($($fi.Length) bytes)" -ForegroundColor Red
            Remove-Item $outPath -Force
            $failed++
        }
    } else {
        Write-Host "[FAIL] $($s.file) - download failed" -ForegroundColor Red
        $failed++
    }

    Write-Host "       Waiting 30s before next download..."
    Start-Sleep -Seconds 30
}

Write-Host ""
Write-Host "Done: $success succeeded, $failed failed" -ForegroundColor White
