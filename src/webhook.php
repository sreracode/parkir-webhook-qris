<?php
// webhook.php
header('Content-Type: application/json');

// Memuat konfigurasi
$config = require 'config.php';
$db = $config['db'];

// Ambil raw JSON body
$raw = file_get_contents('php://input');
$data = json_decode($raw, true);

// Pengecekan payload (kompatibel dengan PHP versi lama)
if ($data === null || !isset($data['invoice'])) {
    http_response_code(400);
    echo json_encode(array('status' => 'error', 'message' => 'invalid payload'));
    exit;
}

// Koneksi ke MySQL menggunakan data dari config
try {
    $dsn = "mysql:host=" . $db['host'] . ";port=" . $db['port'] . ";dbname=" . $db['name'] . ";charset=utf8";
    $pdo = new PDO($dsn, $db['user'], $db['pass']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(array('status' => 'error', 'message' => 'Database connection failed'));
    exit;
}

// Helper: ambil nilai array dengan fallback
function val($arr, $key) {
    return isset($arr[$key]) ? $arr[$key] : '';
}

// Simpan data webhook ke tabel
$stmt = $pdo->prepare("
    INSERT INTO tbqriswebhook 
        (invoice, rrn, note, qris_status, qris_paid_date, payment_method, customer_name)
    VALUES 
        (:invoice, :rrn, :note, :qris_status, :qris_paid_date, :method, :name)
    ON DUPLICATE KEY UPDATE
        qris_status = VALUES(qris_status),
        qris_paid_date = VALUES(qris_paid_date)
");

$stmt->execute(array(
    ':invoice'        => val($data, 'invoice'),
    ':rrn'            => val($data, 'rrn'),
    ':note'           => val($data, 'note'),
    ':qris_status'    => val($data, 'qris_status'),
    ':qris_paid_date' => val($data, 'qris_paid_date'),
    ':method'         => val($data, 'qris_payment_methodby'),
    ':name'           => val($data, 'qris_payment_customername'),
));

// Balas 200 OK agar provider tidak mengirim ulang request
http_response_code(200);
echo json_encode(array('status' => 'ok'));
?>