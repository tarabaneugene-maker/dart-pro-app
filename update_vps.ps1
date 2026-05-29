# PowerShell скрипт для быстрого обновления Dart Pro App на VPS
$hostname = "bombressor@192.144.13.217"
$password1 = "!9InchNails"
$password2 = "!GfhjkmGfhjkm32"

Write-Host "Обновление $hostname..." -ForegroundColor Green

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "ssh"
$psi.Arguments = "-o StrictHostKeyChecking=accept-new $hostname `"sudo bash -c 'cd /opt/dart-pro-app && git pull 2>&1 && echo ---GIT DONE--- && docker stop dart-pro-server 2>&1 && docker rm dart-pro-server 2>&1 && echo ---STOP DONE--- && docker build -t dart-pro-server -f Dockerfile . 2>&1 && echo ---BUILD DONE--- && docker run -d --name dart-pro-server --restart unless-stopped -p 0.0.0.0:9090:9090 -v /opt/dart-pro-data:/app/data -e PORT=9090 dart-pro-server 2>&1 && echo ---RUN DONE---'`""
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$p = [System.Diagnostics.Process]::Start($psi)

# Асинхронное чтение вывода — предотвращает deadlock
$outputBuilder = New-Object System.Text.StringBuilder
$errorBuilder = New-Object System.Text.StringBuilder
$outputEvent = Register-ObjectEvent -InputObject $p -EventName OutputDataReceived -Action {
    $outputBuilder.AppendLine($EventArgs.Data) | Out-Null
}
$errorEvent = Register-ObjectEvent -InputObject $p -EventName ErrorDataReceived -Action {
    $errorBuilder.AppendLine($EventArgs.Data) | Out-Null
}
$p.BeginOutputReadLine()
$p.BeginErrorReadLine()

Start-Sleep -Milliseconds 2000
$p.StandardInput.WriteLine($password1)
Start-Sleep -Milliseconds 1000
$p.StandardInput.WriteLine($password2)
$p.StandardInput.Close()

$p.WaitForExit(600000)  # 10 минут таймаут

# Отписываемся от событий
Unregister-Event -SourceIdentifier $outputEvent.Name -ErrorAction SilentlyContinue
Unregister-Event -SourceIdentifier $errorEvent.Name -ErrorAction SilentlyContinue

Write-Host "=== STDOUT ===" -ForegroundColor Cyan
Write-Output $outputBuilder.ToString()
if ($errorBuilder.ToString().Trim()) {
    Write-Host "=== STDERR ===" -ForegroundColor Yellow
    Write-Output $errorBuilder.ToString()
}
Write-Host "EXIT CODE: $($p.ExitCode)" -ForegroundColor Magenta
