# Parkir Webhook QRIS

**Penerima notifikasi pembayaran QRIS** dari payment gateway. Menerima webhook → simpan ke MySQL → dipolling VB6.

## Alur

1. Customer bayar via QRIS
2. Payment gateway POST webhook ke endpoint ini
3. Data disimpan ke `tbqriswebhook`
4. VB6 polling tabel untuk konfirmasi status

## API

| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| `POST` | `/webhook.php` | Terima webhook dari payment gateway |

Payload:
```json
{
  "invoice": "INV001",
  "rrn": "123456",
  "note": "",
  "qris_status": "paid",
  "qris_paid_date": "2026-06-05 14:30:00",
  "qris_payment_methodby": "gopay",
  "qris_payment_customername": "Budi"
}
```

## Konfigurasi (`src/config.php`)

```php
return [
    'db' => [
        'host' => 'localhost',
        'port' => 3306,
        'name' => 'dbparkir',
        'user' => 'admin',
        'pass' => 'usp1235',
    ]
];
```

## Cloudflare Tunnel

Service ini memakai **shared Cloudflare Tunnel** (satu tunnel untuk semua service). Tunnel ingress dikelola via `shared.ps1` — setiap service cukup tambah ingress rule tanpa bikin tunnel baru.

## Instalasi

Jalankan `install.ps1` sebagai Administrator.

Installer akan:
1. Generate `config.php`
2. Register PHP built-in server sebagai NSSM service
3. Tambah ingress rule ke Cloudflare Tunnel (via API Token)
4. Update DNS CNAME otomatis

## Shared .env

Credentials Cloudflare & GitHub disimpan di `SERVICE/.env` (sekali isi, semua service pakai):
```
GITHUB_TOKEN=ghp_xxx
CF_API_TOKEN=xxx
CF_ACCOUNT_ID=xxx
CF_ZONE_ID=xxx
CF_TUNNEL_NAME=parkir-tunnel
```

## Teknologi

- **PHP** — Built-in server
- **MySQL** — `tbqriswebhook`
- **Cloudflare Tunnel** — Public access
- **NSSM** — Windows service wrapper

---

Dikembangkan untuk **SMARTPARK** — Situsindo Prima.
