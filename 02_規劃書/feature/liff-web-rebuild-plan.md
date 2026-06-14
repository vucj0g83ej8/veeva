# VeeVa LIFF 客戶端重做規劃書

日期：2026-06-13  
狀態：提案規劃中，尚未開始製作  
範圍：只規劃新的客戶端 LIFF App，不修改現有 Flutter 專案

## 1. 重做目標

目前 Flutter Web 版本在 LIFF / LINE 內建瀏覽器中操作時容易感覺頓、滑動有殘影、畫面重新整理感明顯。新的 LIFF 客戶端目標是改用更接近原生網頁的技術，降低載入成本與互動延遲。

主要目標：

- 提升手機 LINE 內建瀏覽器滑動與切頁順暢度
- 減少首次載入體積與空白等待時間
- 保留既有 Firebase / Firestore / Storage 架構
- 保留 LINE LIFF 登入、會員資料、邀請分享、活動、兌換券、最新資訊等功能
- 讓新客戶端可以和現有後台共用資料，不需要重做後台
- 可先開新 hosting 測試，確認穩定後再切換正式 LIFF Endpoint URL

## 2. 建議技術方案

建議使用：

- 語言：TypeScript
- 前端框架：React
- 建置工具：Vite
- UI：Tailwind CSS 或 CSS Modules
- LINE：LINE LIFF JavaScript SDK
- 資料庫：Firebase Firestore
- 圖片與素材：Firebase Storage
- 部署：Firebase Hosting

推薦原因：

- React + Vite 載入比 Flutter Web 輕很多
- 產出是一般 HTML / CSS / JavaScript，LINE 內建瀏覽器支援度高
- UI 是 DOM 元素，不是整頁 canvas，手機滑動通常更自然
- 可針對每個頁面做 lazy loading，降低首次載入量
- TypeScript 對資料模型、Firestore 欄位與 LINE profile 比較安全
- 現有 Firebase 專案可以沿用，免費額度也比較容易控制

備選方案：

| 方案 | 優點 | 缺點 | 建議 |
| --- | --- | --- | --- |
| React + Vite + TypeScript | 成熟、快、好維護、Firebase 文件多 | 需要重寫 Flutter UI | 推薦 |
| Vue 3 + Vite + TypeScript | 寫法簡潔、效能好 | 團隊與套件選擇需確認 | 可選 |
| SvelteKit | 體積小、互動快 | 維護人才較少 | 小型專案可考慮 |
| 原生 HTML + TypeScript | 最輕量 | 功能多時維護成本高 | 不建議完整會員系統使用 |
| Next.js | 架構完整 | 若只做 LIFF SPA 會偏重 | 不優先 |

## 3. 新專案建議名稱

建議開新資料夾：

```text
01_程式碼/
└── VeeVa會員管理系統_LIFF_Web_TS/
```

建議 Firebase Hosting site：

```text
veeva-liff-web
```

測試網址範例：

```text
https://veeva-liff-web.web.app
```

正式上線方式：

1. 先保留現有 Flutter LIFF 不動
2. 新版 React LIFF 發布到新的 hosting
3. 使用測試 LIFF App 或測試 endpoint 驗證
4. 測試通過後，再到 LINE Developers Console 將正式 LIFF Endpoint URL 改到新版網址

## 4. 功能範圍

新版 LIFF 客戶端需要重做以下功能：

### 4.1 LINE 登入與會員建立

- LIFF 初始化
- 檢查是否已登入 LINE
- 未登入時導向 LINE Login
- 登入後取得 LINE profile
- 記錄 LINE userId、displayName、pictureUrl
- 記錄 id token 或可用的登入驗證資訊
- 更新第一次登入時間與最後登入時間
- 檢查帳號是否被後台停用
- 停用帳號禁止進入會員功能

### 4.2 首頁與底部導覽

- 活動
- 最新資訊
- 兌換券
- 會員

手機版必須以 LIFF 使用情境為主：

- 頁面不做過重動畫
- 避免固定背景與複雜陰影
- 避免造成 LINE WebView 滑動殘影的效果
- 底部導覽固定但保持輕量

### 4.3 會員中心

- 顯示會員名稱與 LINE 頭像
- 顯示會員狀態
- 顯示專屬邀請連結
- 分享邀請卡片
- 邀請紀錄彈窗
- 已邀請好友清單
- 顯示好友登入成功時間

### 4.4 邀請好友與推薦關聯

- 支援短連結格式，例如 `/r/A8D2K`
- 進入頁面時讀取 ref code
- 使用者登入成功後建立推薦關聯
- 避免自己邀請自己
- 避免重複建立同一筆推薦關係
- 分享卡片使用加入會員送咖啡圖片
- 使用 `liff.shareTargetPicker` 分享給 LINE 好友

### 4.5 活動頁

- 讀取 Firestore 活動清單
- 只顯示後台設定為可見的活動
- 支援問卷活動
- 支援活動報名類活動
- 活動完成後建立任務完成紀錄
- 若活動有對應兌換券，完成後發放到會員帳戶

### 4.6 OneTrust 問卷嵌入

目前 OneTrust 不是我們可控系統，也沒有 API。新版仍可保留現有策略：

- 用 iframe 或外部開啟方式呈現 OneTrust 問卷
- 監聽可信任來源的 postMessage
- 監聽 OneTrust 可能觸發的完成事件
- 若無法可靠取得事件，保留人工確認或後台審核流程

注意：

- 不能保證讀取 iframe 內部 HTML
- 不能繞過 reCAPTCHA
- 不能用前端直接替使用者自動填寫第三方問卷
- 若未來要完全標準化，仍建議使用 OneTrust API 或 Webhook

### 4.7 兌換券頁

- 顯示會員已取得的兌換券
- 不再顯示全部後台新增的兌換券
- 兌換券需由活動完成、任務完成或後台發放產生
- 顯示有效期限
- 顯示兌換狀態
- 支援兌換流程預留

### 4.8 最新資訊頁

- 讀取後台發布的文章
- 只顯示已發布文章
- 支援文章摘要
- 支援文章詳情頁
- 支援封面圖片
- 支援外部連結

## 5. 資料架構沿用策略

原則：Firestore collection 盡量沿用，不重新設計整個資料庫。

建議沿用：

- `members`
- `adminUsers`
- `activities`
- `rewards`
- `memberRewards`
- `referrals`
- `news`
- `surveyCompletions` 或既有問卷完成紀錄 collection

需要確認與整理：

- 目前 LIFF 端寫入會員資料的欄位
- 後台會員管理讀取的欄位
- 活動完成後兌換券發放的資料格式
- 邀請紀錄目前儲存位置
- LINE id token 是否完整保存，以及保存週期

## 6. 專案架構草案

```text
VeeVa會員管理系統_LIFF_Web_TS/
├── src/
│   ├── app/
│   │   ├── App.tsx
│   │   └── router.tsx
│   ├── pages/
│   │   ├── ActivitiesPage.tsx
│   │   ├── NewsPage.tsx
│   │   ├── CouponsPage.tsx
│   │   └── MemberPage.tsx
│   ├── features/
│   │   ├── auth/
│   │   ├── member/
│   │   ├── referrals/
│   │   ├── activities/
│   │   ├── coupons/
│   │   └── news/
│   ├── services/
│   │   ├── firebase.ts
│   │   ├── firestore.ts
│   │   ├── liff.ts
│   │   └── storage.ts
│   ├── types/
│   │   └── veeva.ts
│   └── styles/
│       └── globals.css
├── public/
├── firebase.json
├── package.json
├── vite.config.ts
└── README.md
```

## 7. 開發階段

### 第一階段：基礎架構與登入

目標：

- 建立 React + Vite + TypeScript 專案
- 串接 Firebase
- 串接 LIFF SDK
- 完成 LINE 登入
- 完成會員自動建立與更新登入時間
- 完成停用帳號限制

交付：

- 可在手機 LINE 中登入
- Firestore 可看到會員資料
- 後台會員管理能看到新會員

### 第二階段：會員中心與邀請

目標：

- 會員中心
- 專屬邀請連結
- 推薦關聯
- 邀請紀錄彈窗
- 分享卡片

交付：

- A 分享連結給 B
- B 登入後與 A 建立推薦關係
- A 的邀請紀錄看得到 B

### 第三階段：活動與兌換券

目標：

- 活動列表
- 問卷活動
- 活動報名
- 任務完成紀錄
- 完成活動後發放兌換券
- 會員只看得到自己取得的兌換券

交付：

- 後台新增活動後，客戶端可看到
- 使用者完成任務後取得兌換券

### 第四階段：最新資訊

目標：

- 最新資訊列表
- 文章詳情
- 封面圖片
- 外部連結

交付：

- 後台新增文章後，客戶端可查看

### 第五階段：效能與上線

目標：

- 手機滑動測試
- LINE 內建瀏覽器測試
- iOS Safari / Android Chrome 測試
- Firebase Hosting 測試
- LIFF Endpoint 切換前驗收

交付：

- 新版 hosting 測試網址
- 上線檢查表
- 正式切換建議

## 8. 效能規範

新版 LIFF 客戶端需符合：

- 首頁首次載入盡量控制在 1.5MB 以下
- 主要頁面切換不重新載入整個 App
- 圖片使用壓縮版或 Firebase Storage resize 後素材
- 列表頁避免一次渲染大量資料
- 避免複雜動畫、漸層背景、大面積陰影、filter blur
- 底部導覽與 Header 使用 CSS sticky/fixed，但避免多層 fixed 疊加
- Firestore 讀取使用分頁或 limit
- 常用資料可用 localStorage / sessionStorage 做短期快取

## 9. 權限與安全

前端只做體驗控制，真正權限仍需依賴 Firestore Rules 與資料設計。

需要注意：

- LINE userId 不能讓使用者自行覆蓋
- 會員資料更新需限制可寫欄位
- 兌換券發放最好透過 Cloud Functions 或後台可信流程
- 如果前端直接寫入任務完成紀錄，需要防重複與防偽造
- 停用帳號必須在每次進入 App 或 token 過期時重新檢查
- id token 不建議永久保存，需設定有效時間

## 10. 是否需要 Cloud Functions

可以先不使用 Cloud Functions，以降低成本。

但以下功能若要更安全，建議第二階段再加：

- 活動完成後發放兌換券
- 防止使用者自行偽造完成任務
- 防止重複領券
- 推薦獎勵發放
- 兌換券核銷

初期免費優先做法：

- Firestore transaction
- Firestore Rules
- 前端防重複
- 後台審核

正式營運後建議：

- Cloud Functions 負責獎勵發放與核銷

## 11. 工時預估

| 階段 | 內容 | 預估工時 |
| --- | --- | --- |
| 基礎架構與登入 | React 專案、Firebase、LIFF 登入、會員建立 | 8 到 12 小時 |
| 會員中心與邀請 | 分享連結、推薦關聯、邀請紀錄、分享卡片 | 10 到 16 小時 |
| 活動與兌換券 | 活動列表、任務完成、兌換券發放與顯示 | 14 到 22 小時 |
| 最新資訊 | 列表、文章詳情、封面圖片、外部連結 | 6 到 10 小時 |
| 效能與測試 | 手機 LINE 測試、修正滑動、部署驗收 | 8 到 14 小時 |
| 上線切換 | hosting、LIFF Endpoint、回滾準備 | 3 到 5 小時 |

總預估：49 到 79 小時

若只做 MVP：

- LINE 登入
- 會員中心
- 邀請分享
- 活動列表
- 會員兌換券

預估：28 到 42 小時

## 12. 測試清單

### 登入測試

- LINE App 內開啟 LIFF
- 外部瀏覽器開啟後導回 LINE Login
- 第一次登入建立會員
- 再次登入更新最後登入時間
- 停用帳號不能進入會員功能

### 邀請測試

- A 產生邀請連結
- B 從 A 的連結登入
- Firestore 建立 A-B 推薦關係
- A 的邀請紀錄顯示 B
- B 不會重複被同一邀請建立多次

### 活動測試

- 後台新增問卷活動
- 客戶端顯示活動
- 完成活動後建立紀錄
- 發放兌換券
- 已封存活動不顯示在客戶端

### 兌換券測試

- 會員只看到自己取得的兌換券
- 未取得的後台兌換券不顯示
- 過期券狀態正確
- 已兌換券狀態正確

### 最新資訊測試

- 只顯示已發布文章
- 草稿與封存文章不顯示
- 文章詳情可正常閱讀
- 外部連結可正常開啟

### 效能測試

- iPhone LINE 內建瀏覽器滑動
- Android LINE 內建瀏覽器滑動
- 首頁首次載入時間
- 切換底部 tab 是否順暢
- 返回上一頁是否保留狀態

## 13. 風險與注意事項

- LINE LIFF 在 iOS 與 Android 行為可能不同，需要實機測試
- OneTrust 問卷完成判斷仍受第三方頁面限制
- 若不使用 Cloud Functions，活動完成與發券安全性較弱
- 舊 Flutter 版本與新 React 版本共用 Firestore 時，資料欄位要先統一
- 正式切換 LIFF Endpoint 前，需要保留回滾方案

## 14. 建議決策

建議採用：

```text
TypeScript + React + Vite + Firebase Hosting
```

建議先做 MVP，不一次重做所有細節：

1. LINE 登入與會員建立
2. 會員中心
3. 邀請分享與邀請紀錄
4. 活動列表
5. 會員已取得兌換券

等 MVP 在手機 LINE 內建瀏覽器確認順暢後，再補：

- 最新資訊詳情
- OneTrust 問卷事件優化
- 活動完成自動發券
- Cloud Functions 安全發券

## 15. 下一步

若確認要製作，建議下一步：

1. 新增 `01_程式碼/VeeVa會員管理系統_LIFF_Web_TS/`
2. 建立 React + Vite + TypeScript 專案
3. 建立 Firebase 與 LIFF 設定
4. 先完成登入與會員建立
5. 發布到新的 Firebase Hosting 測試網址
6. 用手機 LINE 實測順暢度

