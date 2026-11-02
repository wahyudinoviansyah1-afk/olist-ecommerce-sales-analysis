-- Preview tabel orders
SELECT * FROM orders LIMIT 5;

-- Preview tabel order_items
SELECT * FROM order_items LIMIT 5;

-- Preview tabel customers
SELECT * FROM customers LIMIT 5;

-- 	Preview tabel products
SELECT * FROM products LIMIT 5;

-- =====================================================
-- CATATAN PEMAHAMAN STRUKTUR DATA
-- =====================================================
-- 1. Satu baris di tabel orders = 1 transaksi/pesanan.
-- 2. Satu baris di tabel order_items = 1 barang dalam sebuah pesanan.
--    Jumlahnya (112.650) lebih banyak dari orders (99.441)
--    karena satu pesanan bisa berisi lebih dari satu barang.
-- 3. Relasi antar tabel:
--    - orders <-> order_items lewat kolom order_id
--    - orders <-> customers   lewat kolom customer_id
--    - customers: customer_id berbeda tiap pesanan,
--      customer_unique_id = identitas pelanggan sebenarnya.

-- Perbandingan jumlah costumer_id dan customer_unique_id
SELECT
  COUNT(DISTINCT customer_id)        AS jumlah_customer_id,
  COUNT(DISTINCT customer_unique_id) AS jumlah_customer_unique_id
FROM customers;
-- Hasil: 99441 customer_id vs 96096 customer_unique_id

-- Validasi tipe data kolom price dan freight_value
SELECT typeof(price) AS tipe_price, typeof(freight_value) AS tipe_ongkir, COUNT(*) AS jumlah
FROM order_items
GROUP BY 1, 2;
-- Hasil: price dan freight_value bertipe real (112.650 baris), aman untuk SUM/AVG

-- Cek duplikasi order_id
SELECT order_id, COUNT(*) AS jumlah
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Distribusi status pesanan
SELECT order_status, COUNT(*) AS jumlah
FROM orders
GROUP BY order_status
ORDER BY jumlah DESC;

-- Rentang Tanggal Data
SELECT MIN(order_purchase_timestamp) AS tanggal_awal,
       MAX(order_purchase_timestamp) AS tanggal_akhir
FROM orders;

-- Jumlah pesanan per bulan
SELECT strftime('%Y-%m', order_purchase_timestamp) AS bulan,
       COUNT(*) AS jumlah_order
FROM orders
GROUP BY bulan
ORDER BY bulan;

-- Sebaran harga (min, max, average)
SELECT MIN(price), MAX(price), ROUND(AVG(price), 2) FROM order_items;

-- Jumlah produksi per kategori
SELECT COUNT(*) AS produk_tanpa_kategori
FROM products
WHERE product_category_name IS NULL OR product_category_name = '';