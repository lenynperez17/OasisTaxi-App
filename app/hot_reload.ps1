Write-Host "Enviando hot reload al servidor Flutter..." -ForegroundColor Green
$wshell = New-Object -ComObject wscript.shell
$wshell.AppActivate("flutter run")
Start-Sleep -Milliseconds 500
$wshell.SendKeys("r")
Write-Host "Hot reload enviado!" -ForegroundColor Green