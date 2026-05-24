$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "ssh"
$psi.Arguments = "-i C:\Users\Пользователь\.ssh\dart -o StrictHostKeyChecking=accept-new bombressor@192.144.13.217 `"echo SSH_OK`""
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
$p.WaitForExit(10000)
Write-Output $output
Write-Output "EXIT: $($p.ExitCode)"
