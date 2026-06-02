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
echo === Parkir Webhook QRIS ===
echo.
echo Service ini dijalankan menggunakan PHP + XAMPP.
echo.
echo Pastikan:
echo 1. XAMPP sudah terinstall
echo 2. Apache berjalan
echo 3. PHP tersedia di PATH
echo.

set /p PHP_DIR=Path folder PHP [C:\xampp\php]: 
if "!PHP_DIR!"=="" set PHP_DIR=C:\xampp\php

set /p DB_USER=MySQL user [admin]: 
if "!DB_USER!"=="" set DB_USER=admin

set /p DB_PASS=MySQL password [usp1235]: 
if "!DB_PASS!"=="" set DB_PASS=usp1235

REM Update config
cd /d "%~dp0"

REM Wait... I'll create config.php manually
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

REM Copy webhook ke XAMPP
copy /Y src\webhook.php "!PHP_DIR!\..\htdocs\webhook-qris\"
copy /Y src\config.php "!PHP_DIR!\..\htdocs\webhook-qris\"

echo.
echo ✅ Webhook QRIS installed!
echo.
echo URL: http://localhost/webhook-qris/webhook.php
echo.
echo Untuk akses dari public, gunakan Cloudflare Tunnel:
echo   cloudflared tunnel --url http://localhost/webhook-qris/webhook.php
pause
