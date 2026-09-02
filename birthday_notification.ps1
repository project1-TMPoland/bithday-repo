param(
    [string]$CsvPath = ".\employee_birthdays.csv",

    # Local testing ke liye parameter de sakte ho.
    # Pipeline mein ise secret variable se pass karna better hai.
    [string]$SlackWebhookUrl = $env:SLACK_WEBHOOK_URL
)

$ErrorActionPreference = "Stop"

Write-Host "======================================"
Write-Host "Employee Birthday Checker"
Write-Host "======================================"

# Check CSV exists
if (-not (Test-Path -LiteralPath $CsvPath)) {
    Write-Error "CSV file not found: $CsvPath"
    exit 1
}

# Check Slack webhook
if ([string]::IsNullOrWhiteSpace($SlackWebhookUrl)) {
    Write-Error "Slack webhook URL is not configured."
    exit 1
}

# Current date
$Today = Get-Date

Write-Host "Today: $($Today.ToString('yyyy-MM-dd'))"
Write-Host "CSV:   $CsvPath"

# Read CSV
$Employees = Import-Csv -LiteralPath $CsvPath

$BirthdayEmployees = @(
    $Employees | Where-Object {

        try {
            $Birthday = [datetime]::ParseExact(
                $_.Birthday.Trim(),
                "yyyy-MM-dd",
                [System.Globalization.CultureInfo]::InvariantCulture
            )

            # Compare only month and day
            ($Birthday.Month -eq $Today.Month) -and
            ($Birthday.Day -eq $Today.Day)
        }
        catch {
            Write-Warning "Invalid birthday date for employee '$($_.'Employee Name')': $($_.Birthday)"
            $false
        }
    }
)

# No birthday today
if ($BirthdayEmployees.Count -eq 0) {

    Write-Host "No employee birthday today."
    Write-Host "No Slack notification will be sent."

    exit 0
}

Write-Host ""
Write-Host "Birthday(s) found:"
Write-Host "--------------------------------------"

$Names = @()

foreach ($Employee in $BirthdayEmployees) {

    $Name = $Employee.'Employee Name'

    Write-Host "Birthday: $Name"

    $Names += $Name
}

# Create Slack message
if ($Names.Count -eq 1) {

    $Message = "🎂 Happy Birthday to *$($Names[0])*! 🎉`nWishing you a fantastic birthday and a wonderful year ahead! 🥳"

}
else {

    $NameList = ($Names | ForEach-Object {
        "• *$_*"
    }) -join "`n"

    $Message = "🎂 *Today's Birthdays!* 🎉`n`n$NameList`n`nWishing everyone a fantastic birthday! 🥳"
}

# Slack payload
$Payload = @{
    text = $Message
} | ConvertTo-Json -Depth 5

Write-Host ""
Write-Host "Sending birthday notification to Slack..."

try {

    Invoke-RestMethod `
        -Uri $SlackWebhookUrl `
        -Method Post `
        -ContentType "application/json" `
        -Body $Payload

    Write-Host "Slack notification sent successfully. ✅"

}
catch {

    Write-Error "Failed to send Slack notification."
    Write-Error $_.Exception.Message

    exit 1
}


