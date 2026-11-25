# Runs `rojo serve` and restarts it if it crashes (Rojo 7.7.1 can crash when a file
# disappears mid-change, e.g. during fast edits). After a restart, press Connect again
# in Studio's Rojo plugin. Stop with Ctrl+C.
#
# Windows blocks unsigned scripts by default, so run it like this:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\serve.ps1
# (sync.cmd does the same job for double-clicking.)
#
# If Rojo exits 5 times within 30 seconds it is not a one-off crash (e.g. port 34872 already
# in use, or a broken default.project.json), so the script stops instead of looping forever.
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$recent = @()
while ($true) {
	& "$root\.tools\rojo.exe" serve default.project.json
	$code = $LASTEXITCODE
	$now = Get-Date
	$recent = @($recent | Where-Object { ($now - $_).TotalSeconds -lt 30 }) + $now
	Write-Host ""
	if ($recent.Count -ge 5) {
		Write-Host "Rojo exited 5 times in 30 seconds (last exit code $code). Not restarting." -ForegroundColor Red
		Write-Host "Check that nothing else uses port 34872 and that default.project.json is valid." -ForegroundColor Red
		exit 1
	}
	Write-Host "Rojo stopped (exit code $code). Restarting in 2 seconds... (Ctrl+C to quit)" -ForegroundColor Yellow
	Write-Host "In Studio, press Connect in the Rojo plugin again after it restarts." -ForegroundColor Yellow
	Start-Sleep -Seconds 2
}
