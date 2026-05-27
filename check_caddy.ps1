# PowerShell скрипт для проверки Caddy и портов на VPS
$hostname = "bombressor@192.144.13.217"
$password1 = "!9InchNails"
$password2 = "!GfhjkmGfhjkm32"

Write-Host "Проверка Caddy и портов на $hostname..." -ForegroundColor Green

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "ssh"
$psi.Arguments = "-o StrictHostKeyChecking=accept-new $hostname `"sudo bash -c 'echo ---PORTS--- && ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null && echo ---CADDY--- && systemctl status caddy 2>&1 | head -20 && echo ---CADDYFILE--- && cat /etc/caddy/Caddyfile 2>&1'`""
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
$p.WaitForExit(30000)

Write-Host "=== STDOUT ===" -ForegroundColor Cyan
Write-Output $output
if ($errorOutput) {
    Write-Host "=== STDERR ===" -ForegroundColor Yellow
    Write-Output $errorOutput
}
Write-Host "EXIT CODE: $($p.ExitCode)" -ForegroundColor Magenta
