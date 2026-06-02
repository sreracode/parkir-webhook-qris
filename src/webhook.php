<?php
// webhook.php
header('Content-Type: application/json');

$config = include __DIR__ . '/config.php';
$db = $config['db'];

$raw = file_get_contents('php://input');
$data = json_decode($raw, true);

if (!$data || empty($data['invoice'])) {
    http_response_code(400);
    echo json_encode(array('status' => 'error', 'message' => 'invalid payload'));
    exit;
}

$dsn = sprintf(
    'mysql:host=%s;port=%d;dbname=%s;charset=utf8',
    $db['host'],
    $db['port'],
    $db['name']
);

$pdo = new PDO($dsn, $db['user'], $db['pass']);

function val($arr, $key, $default = '') {
    return isset($arr[$key]) ? $arr[$key] : $default;
}

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

http_response_code(200);
echo json_encode(array('status' => 'ok'));
