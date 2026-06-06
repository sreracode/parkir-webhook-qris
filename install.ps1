<#
.SYNOPSIS
    Parkir Webhook QRIS - Service Installer v2
.DESCRIPTION
    PHP built-in server. Tunnel via shared.ps1 (smart ingress merge).
#>

param([switch]$Install,[switch]$Update,[switch]$Uninstall,[switch]$Status,[switch]$Silent,[int]$Port=8090,[string]$DbHost="localhost",[int]$DbPort=3306,[string]$DbUser="admin",[string]$DbPass="",[string]$DbName="dbparkir",[string]$Domain="webhookmenara.situsindoprima.my.id")

$ErrorActionPreference = "Continue"
$script:PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ServiceDir = $script:PSScriptRoot
. (Join-Path $ServiceDir "..\parkir-installer\shared.ps1")

$PhpExe     = Join-Path $script:ToolsDir "php\php.exe"
$PhpSvc     = "ParkirWebhookPHP"
$ServiceEnv = Join-Path $ServiceDir ".env"

function Find-Php {
    if (Test-Path $PhpExe) { wOK "PHP portable: ${PhpExe}"; return $PhpExe }
    try { $p=(Get-Command php.exe -ErrorAction Stop).Source; wOK "PHP: ${p}"; return $p } catch {}
    if (Test-Path "C:\xampp\php\php.exe") { wOK "PHP XAMPP"; return "C:\xampp\php\php.exe" }
    wErr "PHP tidak ditemukan!"; return $null
}

function Do-Status {
    Write-Host "  Webhook QRIS:" -ForegroundColor Cyan
    foreach ($n in @($PhpSvc,$script:TunnelSvcName)) { try { $s=Get-Service $n -ErrorAction Stop; Write-Host "    ${n}: $($s.Status)" -ForegroundColor $(if($s.Status-eq"Running"){"Green"}else{"Red"}) } catch { Write-Host "    ${n}: BELUM TERINSTALL" -ForegroundColor DarkGray } }
    if (Test-Path $script:SharedEnv) { wOK "Shared .env: $script:SharedEnv" }
    if (Test-Path $ServiceEnv) { wOK "Service .env: $ServiceEnv" }
}
function Do-Uninstall { wStep "Uninstall Webhook QRIS..."; foreach($n in @($PhpSvc)){try{$s=Get-Service $n -ErrorAction SilentlyContinue;if($s){if($s.Status-eq"Running"){Stop-Service $n -Force};& $script:NssmExe remove $n confirm 2>&1|Out-Null;wOK "${n} removed"}}catch{}}; wInfo "Tunnel NOT removed (shared)" }
function Do-Update { wStep "Update Webhook QRIS..."; if(Test-Path (Join-Path $ServiceDir ".git")){Push-Location $ServiceDir;git pull 2>&1|Out-Null;Pop-Location;wOK "Git pull OK"}; try{Restart-Service $PhpSvc -Force;wOK "PHP restarted"}catch{}; try{Restart-Service $script:TunnelSvcName -Force;wOK "Tunnel restarted"}catch{} }

function Do-Install {
    wStep "Install Webhook QRIS..."

    if (-not $Silent) {
        Write-Host ""; Write-Host "Konfigurasi Webhook QRIS:" -ForegroundColor Yellow
        $p=Read-Host "  Port [${Port}]"; if($p){$Port=[int]$p}
        $h=Read-Host "  MySQL Host [${DbHost}]"; if($h){$DbHost=$h}
        $u=Read-Host "  MySQL User [${DbUser}]"; if($u){$DbUser=$u}
        $s=Read-Host "  MySQL Password [******]" -AsSecureString
        $plain=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
        $DbPass = if($plain) { $plain } else { "usp1235" }
        $n=Read-Host "  Database [${DbName}]"; if($n){$DbName=$n}
        $d=Read-Host "  Domain [${Domain}]"; if($d){$Domain=$d}
    } else { if(-not $DbPass){$DbPass="usp1235"} }

    $srcDir = Join-Path $ServiceDir "src"
    if (-not (Test-Path $srcDir)) { New-Item -ItemType Directory -Path $srcDir -Force | Out-Null }
    $cfg = Join-Path $srcDir "config.php"
    $content = @"
<?php
return [
    'db' => [
        'host' => '${DbHost}',
        'port' => ${DbPort},
        'name' => '${DbName}',
        'user' => '${DbUser}',
        'pass' => '${DbPass}',
    ]
];
"@
    [System.IO.File]::WriteAllText($cfg, $content, (New-Object System.Text.UTF8Encoding($false)))
    wOK "config.php dibuat"

    $phpExe = Find-Php; if (-not $phpExe) { exit 1 }

    $logDir = Join-Path $ServiceDir "logs"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

    wStep "Register PHP webhook server..."
    $phpArgs   = "-S 0.0.0.0:${Port} -t `"${srcDir}`""
    $phpOutLog = Join-Path $logDir "php_stdout.log"
    $phpErrLog = Join-Path $logDir "php_error.log"
    Register-Service $PhpSvc $phpExe $phpArgs "Parkir Webhook PHP Server" "QRIS webhook receiver (PHP)" $phpOutLog $phpErrLog $srcDir
    wOK "PHP service registered"

    if (Start-ServiceSafe $PhpSvc) { wOK "PHP RUNNING - http://localhost:${Port}/webhook.php" } else { wWarn "Cek log: ${phpErrLog}" }

    $svcEnvData = Load-EnvFile $ServiceEnv
    $svcEnvData['CF_DNS_NAME'] = $Domain
    Save-EnvFile -Path $ServiceEnv -Data $svcEnvData -KeyOrder @('CF_DNS_NAME')

    wStep "Setting up Cloudflare Tunnel ingress..."
    $tunnelOk = Ensure-TunnelIngress -DnsName $Domain -LocalPort $Port

    Write-Host ""; Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Local:  http://localhost:${Port}/webhook.php" -ForegroundColor Green
    Write-Host "  Public: https://${Domain}/webhook.php" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Cyan
}

if($Uninstall){Do-Uninstall}elseif($Update){Do-Update}elseif($Status){Do-Status}else{Do-Install}
