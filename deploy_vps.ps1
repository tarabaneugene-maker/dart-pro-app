# PowerShell скрипт для деплоя Dart Pro App на VPS 192.144.13.217
$hostname = "bombressor@192.144.13.217"
$password1 = "!9InchNails"
$password2 = "!GfhjkmGfhjkm32"

Write-Host "Connecting to $hostname and running deploy script with sudo..." -ForegroundColor Green

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "ssh"
$psi.Arguments = "-o StrictHostKeyChecking=accept-new $hostname `"curl -fsSL https://raw.githubusercontent.com/tarabaneugene-maker/dart-pro-app/main/server/setup.sh | sudo bash`""
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$p = [System.Diagnostics.Process]::Start($psi)
Start-Sleep -Milliseconds 2000
$p.StandardInput.WriteLine($password1)
Start-Sleep -Milliseconds 1000
$p.StandardInput.WriteLine($password2)
$p.StandardInput.Close()

$output = $p.StandardOutput.ReadToEnd()
$errorOutput = $p.StandardError.ReadToEnd()
$p.WaitForExit(600000)  # 10 минут таймаут

Write-Host "=== STDOUT ===" -ForegroundColor Cyan
Write-Output $output
if ($errorOutput) {
    Write-Host "=== STDERR ===" -ForegroundColor Yellow
    Write-Output $errorOutput
}
Write-Host "EXIT CODE: $($p.ExitCode)" -ForegroundColor Magenta
