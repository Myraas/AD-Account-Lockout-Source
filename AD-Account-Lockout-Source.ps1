Clear-Host

function Format-EventInfo {
    param (
        $Event,
        $DCName
    )
    
    $customObject = [PSCustomObject]@{
        'AccountName' = $Event.ReplacementStrings[0]
        'LockoutSource' = $Event.ReplacementStrings[1]
        'DomainController' = $DCName
        'LockoutTimestamp' = $Event.TimeGenerated
    }
    
    return $customObject
}

function Get-AccountLockoutEvents {
    param (
        [string]$DomainController
    )
    
    try {
        $Events = Get-EventLog -LogName Security -InstanceId 4740 -ComputerName $DomainController -ErrorAction Stop | Select-Object -First 6
        
        $formattedEvents = @()
        
        foreach ($Event in $Events) {
            $formattedEventInfo = Format-EventInfo -Event $Event -DCName $DomainController
            $formattedEvents += $formattedEventInfo
        }
        
        return $formattedEvents
    }
    catch {
        Write-Host "Error retrieving events from $DomainController`: $($_.Exception.Message)" -ForegroundColor Yellow
        return @()
    }
}

try {
    $DomainControllers = Get-ADDomainController -Filter * | Select-Object -ExpandProperty Name
    if ($DomainControllers.Count -eq 0) {
        Write-Host "No domain controllers found." -ForegroundColor Red
        exit
    }
}
catch {
    Write-Host "Error retrieving domain controllers: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

Write-Host "Found $($DomainControllers.Count) domain controllers. Checking for account lockouts..." -ForegroundColor Cyan

$allLockoutEvents = @()

foreach ($DC in $DomainControllers) {
    Write-Host "Checking DC: $DC" -ForegroundColor Gray
    
    $pingResult = Test-Connection -ComputerName $DC -Count 2 -Quiet
    
    if ($pingResult) {
        Write-Host "  Connection successful, retrieving lockout events..." -ForegroundColor Gray
        $dcEvents = Get-AccountLockoutEvents -DomainController $DC
        
        if ($dcEvents.Count -gt 0) {
            $allLockoutEvents += $dcEvents
            # Write-Host "  Found $($dcEvents.Count) lockout events." -ForegroundColor Green
        }
        else {
            # Write-Host "  No lockout events found." -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  $DC is unresponsive." -ForegroundColor Gray
    }
}

if ($allLockoutEvents.Count -gt 0) {
    $allLockoutEvents | Sort-Object -Property LockoutTimestamp -Descending | Format-Table -AutoSize
} 
else {
    Write-Host "`nNo account lockout events found on any responsive domain controllers." -ForegroundColor Yellow
}
