$OUs = Get-ADOrganizationalUnit -Filter * -Properties CanonicalName | Select-Object -ExpandProperty CanonicalName

$OUs_Infos = @()
foreach ($OU in $OUs)
{
   $OU = $OU.Remove(0,$OU.IndexOfAny("/")+1)
   $Lenght = ($OU.ToString()).Length
   $Level = ([regex]::Matches($OU, "/" )).count
    $TempObject = [PSCustomObject]@{
        Name = $OU
        Length = $Lenght
        Level = $Level
        }
   $OUs_Infos += $TempObject    
}

$OUs = $OUs_Infos | Select-Object Name,Length,Level | Sort-Object Name,Length,Level

$EXPORT = @()
foreach ($OU in $OUs)
{
    $HierarchyString = ""

    for ($i = 1; $i -le $OU.Level; $i++)
    { 
        $HierarchyString = $HierarchyString + " "
    }

    if ($OU.Level -gt 0){$HierarchyString = $HierarchyString + "∟" }

    for ($i = 1; $i -le $OU.Level; $i++)
    { 
        $HierarchyString = $HierarchyString + "_"  
    }
    
    $OU = $HierarchyString + (($OU.Name).Split("/")[$OU.level])
    
    $EXPORT += $OU
}

return $Export