# CRE (Centralized Resolution Entity) System

## Overview
CRE adalah sistem off-chain yang bertugas mengelola dan mengoperasikan prediction market Verity. CRE memiliki 3 fungsi utama di smart contract:

1. **Create Market** - Membuat market baru
2. **Report Manipulation** - Mendeteksi dan melaporkan manipulasi
3. **Resolve Market** - Menentukan hasil akhir market setelah deadline

---

## Struktur Folder

```
cre-system/
├── backend/
│   ├── src/
│   │   ├── api/              # REST API endpoints
│   │   │   ├── markets.ts
│   │   │   ├── manipulation.ts
│   │   │   └── resolution.ts
│   │   ├── services/         # Business logic
│   │   │   ├── contract.service.ts
│   │   │   ├── market.service.ts
│   │   │   ├── manipulation.service.ts
│   │   │   └── resolution.service.ts
│   │   ├── monitoring/       # Real-time monitoring
│   │   │   ├── market-monitor.ts
│   │   │   └── manipulation-detector.ts
│   │   ├── data-aggregation/ # Data sources integration
│   │   │   ├── chainlink.ts
│   │   │   ├── coingecko.ts
│   │   │   └── aggregator.ts
│   │   ├── database/        # Database models & queries
│   │   │   ├── models/
│   │   │   └── queries/
│   │   └── config/
│   │       ├── contract.config.ts
│   │       └── database.config.ts
│   ├── package.json
│   └── tsconfig.json
│
├── frontend/
│   ├── src/
│   │   ├── pages/
│   │   │   ├── Dashboard.tsx
│   │   │   ├── Markets.tsx
│   │   │   ├── Manipulation.tsx
│   │   │   └── Resolution.tsx
│   │   ├── components/
│   │   │   ├── MarketCard.tsx
│   │   │   ├── ManipulationAlert.tsx
│   │   │   └── ResolutionForm.tsx
│   │   └── services/
│   │       └── api.service.ts
│   └── package.json
│
├── database/
│   ├── schema.sql
│   └── migrations/
│
└── docs/
    ├── API.md
    └── CRE_WORKFLOW.md
```

---

## Fungsi CRE di Smart Contract

### 1. `createMarketFromCre`
**Tujuan:** Membuat market baru atas permintaan creator

**Parameter:**
- `creator` - Address yang membuat market
- `deadline` - Batas waktu market (Unix timestamp)
- `feeBps` - Fee dalam basis points (max 1000 = 10%)
- `category` - Kategori market (0=Crypto, 1=Political, 2=Sports, 3=Other)
- `question` - Pertanyaan market
- `resolutionCriteria` - Kriteria resolusi
- `dataSources` - Sumber data yang digunakan

**Workflow:**
1. Creator submit request via frontend
2. CRE review & approve
3. CRE call smart contract
4. Market created, emit event

---

### 2. `reportManipulation`
**Tujuan:** Mendeteksi dan melaporkan manipulasi trading

**Parameter:**
- `marketId` - ID market yang dicurigai
- `score` - Skor manipulasi (0-100, threshold = 70)
- `reason` - Alasan laporan

**Workflow:**
1. Monitoring system detect anomaly
2. CRE staff review
3. Jika score >= 70, market otomatis paused
4. Admin bisa unpause setelah investigasi

**Indikator Manipulasi:**
- Wash trading (trading dengan diri sendiri)
- Volume spike tidak wajar
- Price manipulation
- Bot activity patterns

---

### 3. `resolveMarketFromCre`
**Tujuan:** Menentukan hasil akhir market setelah deadline

**Parameter:**
- `marketId` - ID market
- `outcome` - Hasil (0=Unresolved, 1=Yes, 2=No)
- `confidence` - Tingkat kepercayaan (0-100, threshold = 90)

**Workflow:**
1. Deadline passed
2. CRE aggregate data dari multiple sources
3. Jika confidence >= 90 → Market Resolved
4. Jika confidence < 90 → Market Escalated (refund semua)

**Data Sources:**
- Chainlink Price Feeds
- CoinGecko API
- On-chain data
- External APIs

---

## Tech Stack

- **Backend:** Node.js + TypeScript + Express
- **Database:** PostgreSQL
- **Blockchain:** ethers.js / viem
- **Monitoring:** WebSocket untuk real-time updates
- **Frontend:** React + TypeScript
- **Data Sources:** Chainlink, CoinGecko, custom APIs



