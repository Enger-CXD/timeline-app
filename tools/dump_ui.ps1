param([string]$serial = 'emulator-5554')
$adb = 'D:\Android\Sdk\platform-tools\adb.exe'

$xml = ''
for ($i = 0; $i -lt 5; $i++) {
    & $adb -s $serial shell rm -f /sdcard/uidump.xml | Out-Null
    $res = (& $adb -s $serial shell uiautomator dump /sdcard/uidump.xml) -join ''
    Start-Sleep -Milliseconds 700
    if ($res -match 'dumped to') {
        $xml = (& $adb -s $serial shell cat /sdcard/uidump.xml) -join ''
        if ($xml -match '<hierarchy') { break }
    }
    Start-Sleep -Seconds 1
}

if ($xml -notmatch '<hierarchy') {
    Write-Output 'DUMP_FAILED'
    exit 1
}

foreach ($m in [regex]::Matches($xml, '<node [^>]*>')) {
    $tag = $m.Value
    $text = ''
    $desc = ''
    $hint = ''
    $bounds = ''
    if ($tag -match 'text="([^"]*)"') { $text = $Matches[1] }
    if ($tag -match 'content-desc="([^"]*)"') { $desc = $Matches[1] }
    if ($tag -match 'hint="([^"]*)"') { $hint = $Matches[1] }
    if ($tag -match 'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"') { $bounds = "$($Matches[1]),$($Matches[2])-$($Matches[3]),$($Matches[4])" }
    $label = ($text + ' ' + $desc + ' ' + $hint).Trim()
    $label = $label -replace "`n", ' / '
    if ($label -ne '' -and $bounds -ne '') {
        Write-Output "$bounds | $label"
    }
}
