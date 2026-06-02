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

Proses instalasi:
1. Cek NSSM (diperlukan untuk service management)
2. Tanya path PHP executable dan port
3. Register PHP built-in server sebagai **NSSM service** (`ParkirWebhookPHP`) — auto-start
4. Setup **Cloudflare Tunnel** otomatis:
   - Login ke Cloudflare (browser akan terbuka)
   - Buat tunnel `parkir-webhook-qris`
   - Register tunnel sebagai **NSSM service** (`ParkirWebhookTunnel`) — auto-start
5. Tampilkan petunjuk config DNS di Cloudflare Dashboard

## Cloudflare Tunnel

`install.bat` akan otomatis:
- Login ke Cloudflare
- Membuat tunnel `parkir-webhook-qris`
- Register sebagai Windows service via NSSM

**Setelah instalasi**, kamu perlu:

1. Buka https://dash.cloudflare.com/
2. Pilih domain (situsindoprima.my.id)
3. DNS → Add record:
   - **Type:** CNAME
   - **Name:** qris-webhook
   - **Target:** `<tunnel-id>.cfargotunnel.com`
   - **Proxy:** Proxied (orange cloud)

4. Kirim URL ke qris.interactive.co.id sebagai endpoint webhook

## Control Services

```cmd
nssm start ParkirWebhookPHP     ← Start PHP server
nssm stop ParkirWebhookPHP      ← Stop PHP server
nssm restart ParkirWebhookPHP   ← Restart PHP server

nssm start ParkirWebhookTunnel  ← Start Cloudflare Tunnel
nssm stop ParkirWebhookTunnel   ← Stop Cloudflare Tunnel
nssm restart ParkirWebhookTunnel
```

## Konfigurasi

Edit `src/config.php` setelah instalasi:
- DB credentials (host, user, pass, database name)
