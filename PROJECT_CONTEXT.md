# PROJECT_CONTEXT — parkir-webhook-qris

## Fungsi Utama
Menerima webhook/callback pembayaran QRIS dari provider (qris.interactive.co.id) dan menyimpan ke database `tbqriswebhook`. Service paling kritis — jika mati, pembayaran QRIS tidak terkonfirmasi.

## Teknologi
- **Bahasa:** PHP
- **Server:** PHP built-in server
- **Database:** PDO MySQL
- **Format:** JSON POST

## Entry Point
- **File:** `src/webhook.php`
- **File alternatif:** `src/webhook2.php` (kemungkinan versi 2)
- **Config:** `src/config.php`

## File/Folder Penting
| Path | Fungsi |
|---|---|
| `src/webhook.php` | Endpoint utama — terima POST, INSERT ke DB |
| `src/webhook2.php` | Alternatif endpoint |
| `src/config.php` | Konfigurasi database |
| `.env` | Environment variables (GitHub token, Cloudflare) |
| `install.bat` / `install.ps1` | Install script |
| `logs/php_error.log` | Error log |
| `logs/php_stdout.log` | Output log |
| `logs/tunnel_error.log` | Cloudflare tunnel error |
| `logs/tunnel_stdout.log` | Cloudflare tunnel output |

## API
- **Method:** POST
- **Content-Type:** application/json
- **Payload dari provider QRIS:**
```json
{
  "invoice": "...",
  "rrn": "...",
  "note": "...",
  "qris_status": "success",
  "qris_paid_date": "...",
  "qris_payment_methodby": "...",
  "qris_payment_customername": "..."
}
```

## Database
- **Host:** localhost, **DB:** dbparkir, **User:** admin
- **Operasi:** INSERT INTO `tbqriswebhook` ... ON DUPLICATE KEY UPDATE
- **Unique key:** `invoice`

## Flow
```
qris.interactive.co.id
    │ (HTTP POST callback)
    ▼
webhook.php
    │ INSERT/UPDATE
    ▼
tbqriswebhook
    │ (polling SELECT)
    ▼
SMARTPARK CheckQrisPaid()
```

## Relasi
- **qris.interactive.co.id:** Provider QRIS — sumber callback
- **SMARTPARK:** Membaca `tbqriswebhook` via `CheckQrisPaid()`
- **Cloudflare Tunnel:** Mungkin menggunakan tunnel untuk expose endpoint ke internet

## Koreksi Hasil Scan Source 2026-06-10

- Installer `install.ps1` default memakai port `8090` dan PHP built-in server `-S 0.0.0.0:<port> -t src`.
- `webhook.php` adalah endpoint sederhana: POST JSON, wajib `invoice`, insert/update `tbqriswebhook`, response `{"status":"ok"}`.
- `webhook.php` hanya update `qris_status` dan `qris_paid_date` saat duplicate invoice.
- `webhook2.php` adalah alternatif dengan monitor UI Basic Auth, whitelist IP, dan `X-API-Key`; `config.php` yang ditemukan belum berisi API key khusus sehingga deployment aktif perlu dikonfirmasi.
- SMARTPARK hanya menganggap pembayaran selesai jika `qris_status='success'`.

## Risiko Jika Mati/Diubah
- 🔴 **KRITIS** — pembayaran QRIS TIDAK terkonfirmasi
- Customer sudah bayar, sistem tidak tahu
- Transaksi akan pending selamanya
- Format payload berubah → INSERT gagal

## Catatan Debugging
- Cek PHP server: `Get-Process php*`
- Cek log: `logs/php_error.log`
- Test manual POST:
```
curl -X POST http://localhost:<port>/webhook.php \
  -H "Content-Type: application/json" \
  -d '{"invoice":"test123","qris_status":"success"}'
```
- Cek database: `SELECT * FROM tbqriswebhook ORDER BY created_at DESC LIMIT 5`
- Config di `src/config.php` — pastikan DB credentials benar
- Cloudflare tunnel: cek `logs/tunnel_*.log`
