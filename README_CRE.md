# Panduan Integrasi Oracle/Validator - Verity

Dokumen ini menjelaskan cara menghubungkan layanan **Oracle/Validator** ke kontrak cerdas **Verity**. Verity menggunakan `CREAdapter` (sebagai modul Oracle) untuk memungkinkan penyedia data mengelola siklus hidup pasar.

## 0. Arsitektur: Keystone Forwarder

**Production:** CRE DON → Chainlink Keystone Forwarder → `Verity.onReport` (msg.sender = Keystone)

**Hackathon/Lokal:** User/CRE → MockKeystoneForwarder.forward(metadata, report) → `Verity.onReport` (msg.sender = MockKeystoneForwarder)

Fungsi `onlyCre` memeriksa bahwa pemanggil memiliki `CRE_ROLE`. Di BaseScan, kolom "from" pada tx = Keystone Forwarder (bukan user). Untuk hackathon, deploy tanpa `CRE_ADDRESS` di .env agar `MockKeystoneForwarder` di-deploy; user trigger via `forward(metadata, report)`.

## 1. Peran dan Akses (Access Control)

Untuk dapat berinteraksi dengan kontrak Verity, alamat dompet atau kontrak layanan Oracle harus memiliki peran `CRE_ROLE`.

### Cara Memberikan Akses
Peran ini diberikan pada saat deployment (melalui konstruktor) atau oleh admin melalui fungsi standar `AccessControl`.

```solidity
// Alamat yang memiliki ADMIN_ROLE dapat memberikan akses
grantRole(CRE_ROLE, alamat_layanan_oracle);
```

## 2. Alur Integrasi

### A. Membuat Pasar Baru (`createMarketFromCre`)
Layanan Oracle bertanggung jawab untuk memvalidasi dan membuat pasar taruhan di Verity.

**Parameter:**
- `creator`: Alamat pembuat pasar (biasanya alamat pengguna yang mengajukan).
- `deadline`: Waktu penutupan pasar (Unix timestamp).
- `feeBps`: Biaya dalam Basis Points (maksimal 1000 atau 10%).
- `category`: Kategori pasar (0: CryptoPrice, 1: Political, 2: Sports, 3: Other).
- `question`: Pertanyaan pasar.
- `resolutionCriteria`: Kriteria penyelesaian.
- `dataSources`: Sumber data pendukung.

### B. Melaporkan Manipulasi (`reportManipulation`)
Jika CRE mendeteksi adanya aktivitas mencurigakan atau manipulasi pada pasar yang aktif, CRE dapat melaporkan skor manipulasi.

- Jika `score >= 70`, pasar akan secara otomatis masuk ke status **Paused** (Ditangguhkan).

### C. Menyelesaikan Pasar (`resolveMarketFromCre`)
Setelah `deadline` tercapai, Oracle harus mengirimkan hasil akhir pasar.

**Logika Penyelesaian:**
- Jika `confidence >= 90`: Pasar diselesaikan (**Resolved**) dengan hasil yang ditentukan (`Yes` atau `No`).
- Jika `confidence < 90`: Pasar akan masuk ke mode **Escalation**, di mana pengguna dapat melakukan refund.

## 3. Referensi API (CREAdapter)

Layanan CRE dapat memanggil fungsi-fungsi berikut pada kontrak `Verity`:

| Fungsi | Deskripsi | Akses |
| :--- | :--- | :--- |
| `createMarketFromCre(...)` | Membuat pasar baru dan mengembalikan `marketId`. | `onlyCre` |
| `reportManipulation(marketId, score, reason)` | Melaporkan skor manipulasi (0-100). | `onlyCre` |
| `resolveMarketFromCre(marketId, outcome, confidence)` | Menentukan hasil akhir pasar setelah deadline. | `onlyCre` |

### Konstanta Kategori (`MarketCategory`)
- `0` : CryptoPrice
- `1` : Political
- `2` : Sports
- `3` : Other

### Konstanta Hasil (`MarketOutcome`)
- `1` : YES
- `2` : NO

---

## Contoh Interaksi (Javascript/ethers.js)

```javascript
const verity = new ethers.Contract(VERITY_ADDRESS, verityAbi, signer);

// Membuat pasar baru
await verity.createMarketFromCre(
  userAddress,
  Math.floor(Date.now() / 1000) + 86400, // 1 hari dari sekarang
  200, // 2% fee
  2, // Sports
  "Apakah Indonesia akan menang melawan Arab Saudi?",
  "Skor resmi dari FIFA",
  "fifa.com"
);

// Menyelesaikan pasar
await verity.resolveMarketFromCre(marketId, 1, 100); // 1 = YES, 100% confidence
```
