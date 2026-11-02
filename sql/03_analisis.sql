-- KPI utama: total revenue, jumlah pesanan, dan AOV (rata-rata nilai pesanan)
SELECT
  ROUND(SUM(oi.price), 2)                              AS total_revenue,
  COUNT(DISTINCT co.order_id)                          AS jumlah_pesanan,
  ROUND(SUM(oi.price) / COUNT(DISTINCT co.order_id), 2) AS aov
FROM clean_orders co
JOIN order_items oi ON co.order_id = oi.order_id;
-- Hasil: revenue 13.181.027,13 | 96.211 pesanan | AOV 137,0
-- Catatan: tanpa DISTINCT, AOV menjadi ±119 (rata-rata per barang, bukan per pesanan)
-- Mata uang: Real Brasil (BRL), karena data asli Olist dari Brasil

-- Tren revenue dan jumlah pesanan per bulan
SELECT
  strftime('%Y-%m', co.order_purchase_timestamp)  AS bulan,
  ROUND(SUM(oi.price), 2)                         AS revenue,
  COUNT(DISTINCT co.order_id)                     AS jumlah_pesanan,
  ROUND(SUM(oi.price) / COUNT(DISTINCT co.order_id), 2) AS aov
FROM clean_orders co
JOIN order_items oi ON co.order_id = oi.order_id
GROUP BY bulan
ORDER BY bulan
-- Hasil: revenue tertinggi 2017-11 (987.765), naik ~52% dari 2017-10, turun ~26% di 2017-12
-- Penyebab: lonjakan jumlah pesanan (4.478 -> 7.289), bukan AOV (144,76 -> 135,51)
-- Dugaan: efek event diskon akhir tahun (perlu dibuktikan dengan data harian)
-- Catatan: sepanjang 2018 revenue relatif mendatar di kisaran 830-980 ribu per bulan

-- Pertumbuhan revenue bulan ke bulan (MoM) memakai window function LAG
WITH bulanan AS (
  SELECT
    strftime('%Y-%m', co.order_purchase_timestamp) AS bulan,
    ROUND(SUM(oi.price), 2)                        AS revenue
  FROM clean_orders co
  JOIN order_items oi ON co.order_id = oi.order_id
  GROUP BY bulan
)
SELECT
  bulan,
  revenue,
  LAG(revenue) OVER (ORDER BY bulan) AS revenue_bulan_lalu,
  ROUND((revenue - LAG(revenue) OVER (ORDER BY bulan)) * 100.0
        / LAG(revenue) OVER (ORDER BY bulan), 1) AS growth_pct
FROM bulanan
ORDER BY bulan;

-- Hasil: 2017-11 = +52,4%, 2017-12 = -26,5%
-- Pertumbuhan tertinggi 2017-02 (+109,5%), efek basis kecil, bukan insight utama
-- Sepanjang 2018 pertumbuhan MoM mendekati nol dan sering negatif (-12,4% s.d. +2,1%)

-- Top 10 kategori produk berdasarkan revenue (beserta kontribusinya)
SELECT
  COALESCE(ct.product_category_name_english, 'unknown') AS kategori,
  ROUND(SUM(oi.price), 2)                               AS revenue,
  COUNT(DISTINCT co.order_id)                           AS jumlah_pesanan,
  ROUND(SUM(oi.price) * 100.0 /
        (SELECT SUM(oi2.price)
         FROM clean_orders co2
         JOIN order_items oi2 ON co2.order_id = oi2.order_id), 1) AS pct_revenue
FROM clean_orders co
JOIN order_items oi              ON co.order_id = oi.order_id
LEFT JOIN products p             ON oi.product_id = p.product_id
LEFT JOIN category_translation ct ON p.product_category_name = ct.product_category_name
GROUP BY kategori
ORDER BY revenue DESC
LIMIT 10;
-- Hasil: peringkat 1 health_beauty (1.229.557,5 | 9,3%), 2 watches_gifts (8,8%), 3 bed_bath_table (7,8%)
-- Top 3 kategori = ~25,9% revenue, revenue relatif tersebar merata
-- Label 'unknown' tidak masuk 10 besar
-- Catatan: bed_bath_table punya pesanan terbanyak (9.267) tetapi revenue peringkat 3,
--          watches_gifts pesanan hanya 5.491 tetapi revenue peringkat 2 (harga per barang lebih tinggi)

-- Revenue, ongkir, dan rasio ongkir terhadap harga per state pelanggan
SELECT
  c.customer_state                                  AS state,
  COUNT(DISTINCT co.order_id)                       AS jumlah_pesanan,
  ROUND(SUM(oi.price), 2)                           AS revenue,
  ROUND(SUM(oi.freight_value), 2)                   AS total_ongkir,
  ROUND(SUM(oi.freight_value) * 100.0 / SUM(oi.price), 1) AS rasio_ongkir_pct
FROM clean_orders co
JOIN order_items oi ON co.order_id = oi.order_id
JOIN customers c    ON co.customer_id = c.customer_id
GROUP BY state
ORDER BY revenue DESC;	
-- Hasil: SP revenue terbesar (5.055.587 | 40.406 pesanan | ~38% total revenue)
-- Rasio ongkir terendah SP (13,9%); tertinggi RR (27,8%, hanya 40 pesanan) dan MA (26,2%, 713 pesanan)
-- Pola: state revenue besar (SP, RJ, MG, RS, PR) rasio ongkir 13,9-18,2%; state kecil di Utara/Timur Laut 20-28%
-- Insight: ongkir mahal di wilayah jauh kemungkinan menghambat penjualan (perlu uji lebih lanjut)

-- Metrik RFM per pelanggan unik (recency, frequency, monetary)
SELECT
  c.customer_unique_id,
  CAST(julianday('2018-08-31') - julianday(MAX(co.order_purchase_timestamp)) AS INT) AS recency_hari,
  COUNT(DISTINCT co.order_id)  AS frequency,
  ROUND(SUM(oi.price), 2)      AS monetary
FROM clean_orders co
JOIN order_items oi ON co.order_id = oi.order_id
JOIN customers c    ON co.customer_id = c.customer_id
GROUP BY c.customer_unique_id
ORDER BY monetary DESC
LIMIT 20;
-- Hasil: dari 20 pelanggan dengan monetary terbesar, 18 hanya belanja 1 kali (frequency maks 4)
-- Pelanggan terbesar: monetary 13.440, frequency 1, jadi nilai besar berasal dari satu pembelian mahal

-- Distribusi frekuensi belanja: berapa pelanggan yang belanja 1x, 2x, 3x, dst.
WITH rfm AS (
  SELECT
    c.customer_unique_id,
    COUNT(DISTINCT co.order_id) AS frequency
  FROM clean_orders co
  JOIN customers c ON co.customer_id = c.customer_id
  GROUP BY c.customer_unique_id
)
SELECT
  frequency,
  COUNT(*) AS jumlah_pelanggan,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM rfm), 2) AS pct_pelanggan
FROM rfm
GROUP BY frequency
ORDER BY frequency;
-- Hasil: 93.104 pelanggan unik; 90.315 (97,0%) hanya belanja 1x; 2.789 (~3,0%) belanja 2x atau lebih
-- Frequency maksimum 15 (1 pelanggan)
-- Insight: retensi sangat rendah, pertumbuhan bergantung pada pelanggan baru
-- Implikasi: skor Frequency 1-5 tidak cocok, segmentasi memakai aturan sederhana

-- Segmentasi pelanggan berdasarkan aturan RFM sederhana
WITH rfm AS (
  SELECT
    c.customer_unique_id,
    CAST(julianday('2018-08-31') - julianday(MAX(co.order_purchase_timestamp)) AS INT) AS recency_hari,
    COUNT(DISTINCT co.order_id) AS frequency,
    SUM(oi.price)               AS monetary
  FROM clean_orders co
  JOIN order_items oi ON co.order_id = oi.order_id
  JOIN customers c    ON co.customer_id = c.customer_id
  GROUP BY c.customer_unique_id
),
segmen AS (
  SELECT *,
    CASE
      WHEN frequency >= 2 THEN 'Pelanggan Berulang'
      WHEN monetary >= 300 THEN 'Bernilai Tinggi (1x)'
      WHEN recency_hari <= 90 THEN 'Baru'
      ELSE 'Tidak Aktif'
    END AS segmen
  FROM rfm
)
SELECT
  segmen,
  COUNT(*)                                  AS jumlah_pelanggan,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM segmen), 1) AS pct_pelanggan,
  ROUND(SUM(monetary), 2)                   AS revenue,
  ROUND(SUM(monetary) * 100.0 / (SELECT SUM(monetary) FROM segmen), 1) AS pct_revenue
FROM segmen
GROUP BY segmen
ORDER BY revenue DESC;
-- Hasil segmentasi (aturan: berulang >=2 pesanan; bernilai tinggi >=300; baru <=90 hari; sisanya tidak aktif)
-- Tidak Aktif: 66.634 (71,6%) | revenue 47,7%
-- Bernilai Tinggi (1x): 7.328 (7,9%) | revenue 35,2% (rata-rata ~632 per pelanggan)
-- Baru: 16.353 (17,6%) | revenue 11,7%
-- Pelanggan Berulang: 2.789 (3,0%) | revenue 5,5% (rata-rata ~260 per pelanggan)
-- Insight: 7,9% pelanggan menyumbang 35,2% revenue, perlu program khusus untuk mempertahankan mereka
-- Verifikasi: total pelanggan 93.104 dan total revenue 13.181.027,13 cocok dengan KPI