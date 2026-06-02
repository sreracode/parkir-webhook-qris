# Parkir Webhook QRIS

Menerima notifikasi pembayaran QRIS dari qris.interactive.co.id dan menyimpan ke tabel `tbqriswebhook`.

## Alur

1. Customer bayar via QRIS
2. Payment gateway POST webhook ke endpoint ini
3. Data disimpan ke MySQL `tbqriswebhook`
4. VB6 polling cek tabel untuk konfirmasi status

## API

- `POST /webhook.php` — Terima webhook dari payment gateway

  Payload: `{ invoice, rrn, note, qris_status, qris_paid_date, qris_payment_methodby, qris_payment_customername }`

## Instalasi

Jalankan `install.bat` sebagai Administrator.

## Cloudflare Tunnel

Untuk akses public:
```
cloudflared tunnel --url http://localhost:80/webhook-qris/
```
