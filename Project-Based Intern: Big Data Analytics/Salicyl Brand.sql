-- DATA CLEANING
-- Hapus kolom kosong/tidak diperlukan
ALTER TABLE Penjualan DROP COLUMN Column13;
ALTER TABLE Penjualan DROP COLUMN Column14;
ALTER TABLE Penjualan DROP COLUMN Column15;

-- DATA TRANSFORMATION
-- Menambahkan kolom id_transaksi
ALTER TABLE Penjualan ADD COLUMN id_transaksi TEXT;
UPDATE Penjualan
SET id_transaksi = id_invoice || '-' || id_barang
WHERE id_transaksi IS NULL AND id_invoice IS NOT NULL AND id_barang IS NOT NULL;

ALTER TABLE Penjualan DROP COLUMN id_transaksi;

-- Mengubah Format Tanggal
UPDATE Penjualan
SET tanggal = strftime('%Y-%m-%d',
  substr(tanggal, length(tanggal) - 3, 4) || '-' ||
  printf('%02d', CAST(substr(tanggal, 1, instr(tanggal, '/') - 1
  ) AS INTEGER)) || '-' ||
  printf('%02d', CAST(substr(
    tanggal,
    instr(tanggal, '/') + 1,
    instr(substr(tanggal, instr(tanggal, '/') + 1), '/') - 1
  ) AS INTEGER))
)
WHERE instr(tanggal, '/') > 0;

-- INTEGRASI DATA
-- JOIN Tabel Penjualan, Barang, dan Pelanggan
SELECT 
  p.id_transaksi, 
  p.tanggal,
  c.nama AS nama_customer,
  b.nama_barang,
  b.kemasan,
  p.lini AS kategori_produk,
  p.jumlah_barang AS qty,
  p.harga AS harga_satuan,
  (p.jumlah_barang * p.harga) AS total,
  p.brand_id,
  p.id_distributor,
  c.cabang_sales,
  c."group" AS jenis_customer
FROM Penjualan AS p
LEFT JOIN Barang AS b 
	ON p.id_barang = b.kode_barang
LEFT JOIN Pelanggan AS c 
	ON p.id_customer = c.id_customer;


-- ANALISIS
-- 1. Penjualan per produk
SELECT 
  b.nama_barang, 
  c."group" AS jenis_customer,
  p.lini AS kategori_produk,
  p.harga AS harga_satuan,
  SUM(p.jumlah_barang) AS total_qty,
  ROUND(SUM(p.jumlah_barang * p.harga)) AS total_harga,
  COUNT(DISTINCT id_transaksi) AS jumlah_transaksi
FROM Penjualan AS p
LEFT JOIN Barang AS b 
	ON p.id_barang = b.kode_barang
LEFT JOIN Pelanggan AS c 
	ON p.id_customer = c.id_customer
GROUP BY b.nama_barang, kategori_produk, jenis_customer
ORDER BY total_harga DESC;
  
-- 2. Pertumbuhan Penjualan Bulanan Cabang

-- Membuat CTE (subquery sementara) --
WITH PenjualanBulananCabang AS (
SELECT 
 	SUBSTR(p.tanggal, 1, 7) AS bulan,
 	c.cabang_sales AS cabang,
 	SUM(p.jumlah_barang) AS total_qty, 
 	ROUND(SUM(p.jumlah_barang * p.harga)) AS total_harga,
 	COUNT(DISTINCT id_transaksi) AS jumlah_transaksi
FROM Penjualan AS p
LEFT JOIN Pelanggan AS c 
	ON p.id_customer = c.id_customer
GROUP BY bulan, cabang )

-- menghitung pesentase pertumbuhan cabang --
SELECT 
	curr.bulan,
	curr.cabang,
	curr.total_qty,
	curr.total_harga,
	curr.jumlah_transaksi,
	ROUND((curr.total_harga - prev.total_harga) * 100/
	NULLIF(prev.total_harga, 0 ), 2) AS pertumbuhan
FROM PenjualanBulananCabang AS curr
LEFT JOIN PenjualanBulananCabang AS prev
	ON curr.cabang = prev.cabang
	AND strftime('%Y-%m', date(curr.bulan || '-01', '-1 month')) = prev.bulan
ORDER BY  curr.cabang, curr.bulan;



	