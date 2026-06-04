# UI/UX 規劃

## 設計目標

- 在 LINE 內使用時畫面自然、快速、現代。
- 手機優先，避免過多說明文字。
- 會員流程需在 3 至 5 步內完成主要任務。
- 讓使用者感覺像在使用 LINE 原生延伸服務，而不是外部網頁。
- 後台維持 SaaS dashboard 風格，資訊密度高但不壓迫。

## 設計系統

| 項目 | 規劃 |
| --- | --- |
| Design System | LINE LIFF Mobile Template + Material 3 spacing |
| 主色 | LINE 綠搭配醫療信任綠 |
| 輔助色 | 薄荷綠、暖白、墨黑、琥珀提示色 |
| 風格 | 圓角、乾淨、卡片式、低噪音、清楚留白 |
| 元件 | Bottom navigation、cards、chips、modal bottom sheet、segmented tabs、toast、status badge |
| 後台 | SaaS Admin Dashboard 風格 |

## LIFF 視覺方向

### 顧客端

- 版面以手機 360px 到 430px 為主要設計基準。
- 首屏要直接出現主要任務，例如活動、兌換券、會員狀態或邀請好友。
- 底部導覽使用 4 個以內主要入口，避免使用過多頁籤。
- 系統訊息使用右上通知鈴與輕量彈出卡片。
- 表單與確認視窗使用 bottom sheet，符合手機拇指操作。
- CTA 按鈕固定使用實心主色，次要操作使用 outline 或文字按鈕。

### Admin 後台

- 桌機優先，左側 sidebar + 上方搜尋列。
- 表格資料要有狀態標籤、快速操作、搜尋、篩選。
- 管理頁面避免裝飾性大圖，以資料掃描效率為主。

## 色彩規範

| Token | 色碼 | 用途 |
| --- | --- | --- |
| Primary | `#06C755` | LINE 登入、主要 CTA、成功狀態 |
| Primary Deep | `#147A5C` | 重要按鈕、標題強調、Admin 主色 |
| Mint Surface | `#EAF8F1` | 選取狀態、icon 底色、提示背景 |
| Warm Canvas | `#FBFAF7` | App 背景 |
| Ink | `#17211D` | 主要文字 |
| Muted | `#68736D` | 次要文字 |
| Border | `#DDE5DF` | 卡片與分隔線 |
| Warning | `#C76A12` | 待審核、提醒、即將到期 |
| Error | `#C94343` | 錯誤、失敗、停用 |

## 字體與排版

| 層級 | 大小 | 粗細 | 用途 |
| --- | --- | --- | --- |
| Page Title | 26px | 800 | 頁面主標題 |
| Section Title | 20px | 700 | 區塊標題 |
| Card Title | 17px | 700 | 卡片標題 |
| Body | 14px | 400 | 一般說明 |
| Caption | 12px | 500 | 日期、來源、輔助資訊 |
| Button | 15px | 700 | CTA 按鈕 |

## 間距與圓角

| 項目 | 規則 |
| --- | --- |
| Page Padding | 20px |
| Card Padding | 16px 到 20px |
| Card Gap | 12px 到 16px |
| Button Height | 48px |
| Icon Button | 42px |
| Card Radius | 18px 到 24px |
| Button Radius | 14px |
| Bottom Sheet Radius | 上方 24px |

## 頁面清單

- 活動消息
- Veeva 問卷
- Thank You
- 最新資訊
- 兌換券
- 會員中心
- 系統訊息
- 邀請好友
- Admin 儀表板
- Admin 會員管理
- Admin 活動管理
- Admin 最新資訊管理
- Admin 兌換券管理
- Admin 推薦管理

## 核心畫面模板

### 活動首頁

- 頂部顯示頁面名稱與通知按鈕。
- 卡片包含活動狀態、活動名稱、簡短描述、獎勵、CTA。
- 活動卡片需支援：進行中、尚未開放、已完成、已截止。

### 最新資訊

- 小型資訊卡，固定高度。
- 顯示標題、日期、來源、分類 icon。
- 點擊後可進入詳細頁或外部連結。

### 兌換券

- 每張卡片只顯示商品名稱、兌換期限、兌換按鈕。
- 即將到期需用醒目但不刺眼的提示。
- 兌換前必須跳出確認視窗。

### 會員中心

- 未登入：顯示 LINE 登入。
- 已登入：顯示會員資料、資格狀態、已得券、已邀請、常用功能。
- 系統訊息從右上角展開，使用圓角浮層。

### 邀請好友

- 顯示推薦狀態：邀請中、已完成、已發券。
- 使用 LINE 分享按鈕作為主要 CTA。
- 清楚顯示「好友完成資格後，雙方各得一張兌換券」。

## 狀態設計

- loading：顯示簡潔 loading indicator。
- empty：清楚說明目前沒有資料。
- error：顯示可重試與客服協助。
- success：兌換、送出、分享成功需明確回饋。

## UI/UX 驗收項目

- [ ] LIFF 內 360px、390px、430px 寬度正常。
- [ ] 底部導覽不超過 4 個主要入口。
- [ ] 主要 CTA 在手機上容易點擊。
- [ ] 文字不溢出、不重疊、不被 fixed bar 遮住。
- [ ] 彈窗、bottom sheet 在小螢幕不超出畫面。
- [ ] loading / empty / error / success 狀態都有畫面。
- [ ] LINE 登入與分享流程符合 LIFF 使用情境。
- [ ] 推薦連結進入後能清楚看到目前任務與獎勵。
- [ ] Admin 表格在 1280px 桌面寬度可完整閱讀。
- [ ] 所有狀態標籤顏色一致，避免同一狀態多種顏色。

## 設計檔案位置

- 可預覽 UI 模板：`03_UI設計圖/liff-ui-template.html`
- 參考風格：`03_UI設計圖/reference/`
- 線框圖：`03_UI設計圖/wireframe/`
- 高保真 mockup：`03_UI設計圖/mockup/`
- 實作截圖：`03_UI設計圖/screenshot/`
