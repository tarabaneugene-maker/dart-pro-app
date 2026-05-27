$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "ssh"
$psi.Arguments = "-o StrictHostKeyChecking=accept-new bombressor@192.144.13.217 `"sudo docker ps -a --filter name=dart --format '{{.Status}} {{.Names}}' 2>&1; echo ---; sudo docker ps --filter name=dart --format '{{.Status}}' 2>&1; echo ---; curl -s --max-time 3 http://localhost:8080/health 2>&1 || echo no_server`""
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true

$p = [System.Diagnostics.Process]::Start($psi)
Start-Sleep -Milliseconds 1500
$p.StandardInput.WriteLine("!9InchNails")
Start-Sleep -Milliseconds 500
$p.StandardInput.WriteLine("!GfhjkmGfhjkm32")
$p.StandardInput.Close()
$output = $p.StandardOutput.ReadToEnd()
$p.WaitForExit(30000)
Write-Output $output
Write-Output "EXIT: $($p.ExitCode)"
