-- =====================================================
-- KEPUTUSAN CLEANING (berdasarkan hasil di 01_eksplorasi.sql)
-- =====================================================
-- 1. Tidak ada duplikat order_id.
-- 2. Hanya order_status = 'delivered' yang dihitung sebagai penjualan
--    (96.478 dari 99.441 pesanan, sekitar 97%).
-- 3. Periode analisis: 2017-01 s.d. 2018-08 (20 bulan penuh).
--    Data 2016 sangat sedikit dan Nov 2016 kosong.
--    Terkonfirmasi: 2018-09 hanya 16 order dan 2018-10 hanya 4 order,
--    padahal bulan-bulan sebelumnya 6.000+. Data terpotong, bukan penurunan bisnis.
-- 4. Harga maksimum 6.735 tidak dihapus karena masih wajar untuk produk mahal.
-- 5. 610 produk tanpa kategori diberi label 'unknown' saat analisis.

-- Membuat view pesanan bersih (delivered, Jan 2017 - Agu 2018)
CREATE VIEW clean_orders AS
SELECT *
FROM orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01';
  
 -- Verifikasi isi view clean_orders
SELECT COUNT(*) AS jumlah_order_bersih,
       MIN(order_purchase_timestamp) AS awal,
       MAX(order_purchase_timestamp) AS akhir
FROM clean_orders;
-- Hasil: 96.211 pesanan bersih, 2017-01-05 s.d. 2018-08-29