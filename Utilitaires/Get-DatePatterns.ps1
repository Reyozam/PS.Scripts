$patterns = "d","D","g","G","f","F","m","o","r","s", "t","T","u","U","Y","dd","MM","yyyy","yy","hh","mm","ss","yyyyMMdd","yyyyMMddhhmm","yyyyMMddhhmmss"
 
Write-host "It is now $(Get-Date)" -ForegroundColor Green
 
foreach ($pattern in $patterns) {
#display text
"{0}`t{1}" -f $pattern,(Get-Date -Format $pattern)
 
} #foreach
 
Write-Host "Most patterns are case sensitive" -ForegroundColor Green
