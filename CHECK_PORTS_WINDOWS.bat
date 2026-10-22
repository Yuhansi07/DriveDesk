@echo off
setlocal
 echo Checking DriveDesk ports 3000 (API) and 8080 (Flutter)...
 powershell -NoProfile -ExecutionPolicy Bypass -Command "$ports=3000,8080; Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object {$ports -contains $_.LocalPort} | ForEach-Object { $p=Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue; [PSCustomObject]@{Port=$_.LocalPort; PID=$_.OwningProcess; Program=$p.ProcessName; Path=$p.Path} } | Format-Table -AutoSize"
 echo.
 echo To stop your old DriveDesk process, open its terminal and press Ctrl+C.
 echo Do not terminate an unknown process just to free a port.
 pause
