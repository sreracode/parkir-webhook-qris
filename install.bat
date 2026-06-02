@echo off
setlocal enabledelayedexpansion

TITLE Parkir Webhook QRIS Installer

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Jalankan sebagai Administrator!
    pause
    exit /b 1
)

echo.
echo === Parkir Webhook QRIS Installer ===
echo   Instalasi: PHP server + Cloudflare Tunnel
echo.

REM ─── Cek NSSM ────────────────────────────────────────────────
if not exist "C:\nssm\win64\nssm.exe" (
    echo [!] NSSM tidak ditemukan. Download dari https://nssm.cc/download
    echo     Extract ke C:\nssm\
    pause
    exit /b 1
)
set NSSM=C:\nssm\win64\nssm.exe

REM ─── Config ──────────────────────────────────────────────────
set /p PHP_EXE=Path PHP executable [C:\xampp\php\php.exe]: 
if "!PHP_EXE!"=="" set PHP_EXE=C:\xampp\php\php.exe

set /p WEBHOOK_PORT=Port untuk webhook [8090]: 
if "!WEBHOOK_PORT!"=="" set WEBHOOK_PORT=8090

set /p DB_USER=MySQL user [admin]: 
if "!DB_USER!"=="" set DB_USER=admin

set /p DB_PASS=MySQL password [usp1235]: 
if "!DB_PASS!"=="" set DB_PASS=usp1235

REM ─── Buat config.php ────────────────────────────────────────
cd /d "%~dp0"
if not exist "src" mkdir src

(
echo ^<?php
echo return [
echo     'db' => [
echo         'host' => 'localhost',
echo         'port' => 3306,
echo         'name' => 'dbparkir',
echo         'user' => '!DB_USER!',
echo         'pass' => '!DB_PASS!',
echo     ]
echo ];
) > src\config.php

REM ─── 1. Install PHP Server sebagai NSSM Service ────────────
echo.
echo [1/4] Menginstall PHP webhook server...

%NSSM% stop ParkirWebhookPHP 2>nul
%NSSM% remove ParkirWebhookPHP confirm 2>nul

%NSSM% install ParkirWebhookPHP "!PHP_EXE!" "-S 0.0.0.0:!WEBHOOK_PORT! -t \"%~dp0src\""
%NSSM% set ParkirWebhookPHP AppDirectory "%~dp0src"
%NSSM% set ParkirWebhookPHP DisplayName "Parkir Webhook PHP Server"
%NSSM% set ParkirWebhookPHP Description "QRIS payment webhook receiver (PHP built-in server)"
%NSSM% set ParkirWebhookPHP Start SERVICE_AUTO_START
%NSSM% set ParkirWebhookPHP AppStdout "%~dp0logs\php_stdout.log"
%NSSM% set ParkirWebhookPHP AppStderr "%~dp0logs\php_error.log"
%NSSM% set ParkirWebhookPHP AppExit Default Exit

REM Buat folder logs
if not exist "logs" mkdir logs

REM ─── 2. Setup Cloudflare Tunnel ────────────────────────────
echo [2/4] Setup Cloudflare Tunnel...

REM Cek cloudflared
where cloudflared >nul 2>&1
if %errorlevel% neq 0 (
    if exist "%~dp0cloudflared.exe" (
        set CF_BIN=%~dp0cloudflared.exe
    ) else (
        echo [!] cloudflared tidak ditemukan.
        echo     Download dari: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
        echo     Taruh cloudflared.exe di folder ini, atau pastikan ada di PATH.
        set /p CF_BIN=Path ke cloudflared.exe: 
        if "!CF_BIN!"=="" (
            echo [!] Cloudflare Tunnel dilewati. Install manual nanti.
            goto :skip_tunnel
        )
    )
) else (
    for /f "delims=" %%a in ('where cloudflared') do set CF_BIN=%%a
)

REM Login dulu
echo.
echo Login ke Cloudflare diperlukan untuk setup tunnel.
echo Setelah perintah berikut, browser akan terbuka. Login dengan akun Sreracode@gmail.com.
echo.
echo Tekan ENTER untuk login...
pause >nul
"!CF_BIN!" tunnel login

REM Buat tunnel
set TUNNEL_NAME=parkir-webhook-qris
echo.
echo Membuat tunnel: !TUNNEL_NAME!...
"!CF_BIN!" tunnel create !TUNNEL_NAME! >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Tunnel mungkin sudah ada, lanjutkan...
)

REM Dapatkan Tunnel ID
for /f "tokens=*" %%a in ('"!CF_BIN!" tunnel list ^| findstr /i "!TUNNEL_NAME!"') do (
    set TUNNEL_LINE=%%a
)
echo Tunnel info: !TUNNEL_LINE!

REM Install tunnel sebagai NSSM service
echo.
echo [3/4] Install Cloudflare Tunnel sebagai service Windows...

%NSSM% stop ParkirWebhookTunnel 2>nul
%NSSM% remove ParkirWebhookTunnel confirm 2>nul

%NSSM% install ParkirWebhookTunnel "!CF_BIN!" "tunnel run !TUNNEL_NAME!"
%NSSM% set ParkirWebhookTunnel DisplayName "Parkir Webhook Cloudflare Tunnel"
%NSSM% set ParkirWebhookTunnel Description "Cloudflare Tunnel untuk QRIS webhook"
%NSSM% set ParkirWebhookTunnel Start SERVICE_AUTO_START
%NSSM% set ParkirWebhookTunnel AppStdout "%~dp0logs\tunnel_stdout.log"
%NSSM% set ParkirWebhookTunnel AppStderr "%~dp0logs\tunnel_error.log"
%NSSM% set ParkirWebhookTunnel AppExit Default Exit

REM Buat file konfigurasi tunnel untuk referensi
for /f "tokens=2 delims= " %%a in ('"!CF_BIN!" tunnel list ^| findstr /i "!TUNNEL_NAME!"') do (
    set TUNNEL_ID=%%a
)

(
echo # Cloudflare Tunnel Configuration
echo TUNNEL_NAME=!TUNNEL_NAME!
echo TUNNEL_ID=!TUNNEL_ID!
echo LOCAL_PORT=!WEBHOOK_PORT!
echo LOCAL_URL=http://localhost:!WEBHOOK_PORT!/webhook.php
) > config\tunnel-info.txt

echo.
echo Tunnel ID: !TUNNEL_ID!
echo.
echo ⚠️  Penting! Konfigurasi DNS di Cloudflare Dashboard:
echo    1. Buka https://dash.cloudflare.com/
echo    2. Pilih domain (situsindoprima.my.id)
echo    3. DNS ^> Add record:
echo       Type: CNAME
echo       Name: qris-webhook
echo       Target: !TUNNEL_ID!.cfargotunnel.com
echo       Proxy: Proxied (orange cloud)
echo.
echo    Nanti webhook akan bisa diakses di:
echo    https://qris-webhook.situsindoprima.my.id/webhook.php
echo.
echo    Kirim URL ini ke qris.interactive.co.id sebagai endpoint webhook.
echo.

:skip_tunnel

REM ─── 4. Start Services ─────────────────────────────────────
echo [4/4] Memulai service...

%NSSM% start ParkirWebhookPHP
echo   ✅ PHP Webhook started on port !WEBHOOK_PORT!

if exist "!CF_BIN!" (
    %NSSM% start ParkirWebhookTunnel
    echo   ✅ Cloudflare Tunnel started
)

echo.
echo ╔══════════════════════════════════════════════╗
echo ║      INSTALASI WEBHOOK QRIS SELESAI         ║
echo ╠══════════════════════════════════════════════╣
echo ║                                              ║
echo ║  Local URL : http://localhost:!WEBHOOK_PORT! ║
echo ║              /webhook.php                    ║
echo ║                                              ║
echo ║  Public URL: https://qris-webhook.           ║
echo ║              situsindoprima.my.id/           ║
echo ║              webhook.php                     ║
echo ║                                              ║
echo ║  Service: nssm start/stop/restart            ║
echo ║    ParkirWebhookPHP                          ║
echo ║    ParkirWebhookTunnel                       ║
echo ║                                              ║
echo ╚══════════════════════════════════════════════╝
pause
