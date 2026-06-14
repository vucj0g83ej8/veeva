# VeeVa LIFF 客戶端重做技術比較報告：React vs Vue

日期：2026-06-13  
比較對象：

1. React + Vite + TypeScript
2. Vue 3 + Vite + TypeScript

評估範圍：VeeVa 客戶端 LIFF App 重做，不包含後台重做。  
結論摘要：兩者都會比目前 Flutter Web LIFF 更適合手機 LINE 內建瀏覽器。若重視長期維護、人力取得、第三方生態與未來擴充，建議 React。若重視開發速度、模板直覺、單一檔案元件的清楚度，Vue 3 也非常適合。

## 1. 專案背景

目前 Flutter Web 版本在 LIFF / LINE 內建瀏覽器使用時，已觀察到：

- 頁面滑動不夠順
- 手機操作時有殘影感
- 畫面切換與重新載入感明顯
- Flutter Web 輸出以 canvas 與較重的 runtime 為主，對簡單會員系統來說偏重

新版重做目標不是追求複雜動畫，而是讓 LIFF 在手機裡像一般網頁一樣順：

- 輕量載入
- DOM 原生滑動
- 少動畫、少陰影、少重繪
- Firebase / Firestore 資料沿用
- LINE LIFF SDK 穩定串接
- 後台不重做，只換客戶端

## 2. 共同優勢

React + Vite + TypeScript 與 Vue 3 + Vite + TypeScript 都有以下共同優勢：

- 都是一般 HTML / CSS / JavaScript 輸出，比 Flutter Web 更接近手機瀏覽器原生行為
- 都能使用 Vite 取得快速開發環境與輕量 build
- 都支援 TypeScript
- 都能直接使用 LINE LIFF JavaScript SDK
- 都能串接 Firebase Web SDK
- 都能部署到 Firebase Hosting
- 都能做路由、頁面分包、lazy loading
- 都適合製作 LIFF 這種手機 Web App

因此，真正的差異不是「能不能做」，而是：

- 哪一個更適合長期維護？
- 哪一個開發速度更快？
- 哪一個未來找人接手更容易？
- 哪一個在複雜資料流與狀態管理上更穩？
- 哪一個對這個案子的成本比較合理？

## 3. 核心比較表

| 面向 | React + Vite + TypeScript | Vue 3 + Vite + TypeScript |
| --- | --- | --- |
| LIFF 手機順暢度 | 高 | 高 |
| 首次載入潛力 | 高，可透過 code splitting 控制 | 高，通常也很輕 |
| 開發速度 | 中高 | 高 |
| 學習曲線 | 中 | 低到中 |
| TypeScript 整合 | 成熟，TSX 生態完整 | 成熟，但 template type check 需 vue-tsc |
| UI 組件生態 | 非常大 | 大，但通常比 React 小 |
| Firebase 整合 | 非常成熟 | 成熟 |
| LINE LIFF SDK 整合 | 直接使用，框架無關 | 直接使用，框架無關 |
| 長期人力取得 | 最容易 | 容易，但市場較 React 小 |
| 架構自由度 | 高，但需要規範 | 中高，Vue 官方風格較一致 |
| 大型專案擴充 | 很強 | 很強，但大型團隊慣例較少於 React |
| 表單與互動 | 很強，選擇多 | 很直覺，寫起來快 |
| 狀態管理 | 選擇多，需決策 | Pinia 官方推薦清楚 |
| 程式碼一致性 | 需制定規範 | 較容易保持一致 |
| 未來轉交維護 | 優 | 佳 |
| 適合本案程度 | 推薦 | 很適合 |

## 4. React 方案詳細分析

### 4.1 優點

#### 優點一：市場最大，未來接手容易

React 是目前最主流的前端框架之一，未來如果要找工程師、外包、維護人員，通常 React 人力最多。

對 VeeVa 專案的好處：

- 未來要交給其他工程師維護比較容易
- 外部套件、範例、問題解法多
- 若後續要擴充更完整會員系統，React 生態支援度高

#### 優點二：TypeScript + TSX 生態非常成熟

React 使用 TSX，可以讓 UI 與 TypeScript 型別直接整合。

適合本案的地方：

- Firestore 資料模型可以有清楚型別
- LINE profile、member、activity、reward、news 都能定義 type
- 元件 props 型別清楚
- 較容易避免欄位名稱寫錯

#### 優點三：第三方套件選擇最多

React 相關套件非常多，例如：

- 路由：React Router
- 資料抓取：TanStack Query
- 表單：React Hook Form
- 狀態管理：Zustand、Redux Toolkit、Jotai
- UI：MUI、Radix UI、shadcn/ui、Headless UI
- 測試：Testing Library、Vitest、Playwright

對本案的幫助：

- 會員中心、活動列表、兌換券、文章詳情都能用成熟模式開發
- 若未來要做更複雜的活動任務，也有較多工具可選

#### 優點四：適合複雜互動與狀態管理

VeeVa 後續可能會有：

- LINE 登入狀態
- 會員停用檢查
- 活動完成狀態
- 兌換券發放狀態
- 邀請關聯狀態
- 快取與重新整理

React 在這類狀態設計上彈性高，配合 TanStack Query 或 Zustand 可以做得很穩。

#### 優點五：長期擴充彈性高

如果之後不只做 LIFF，還想做：

- 獨立會員網站
- Web App
- PWA
- 活動頁 landing page
- 後台部分頁面重做

React 的長期擴充彈性會比較高。

### 4.2 缺點

#### 缺點一：寫法較自由，需要先定規範

React 很自由，這是優點也是缺點。若沒有先定架構，容易出現：

- hooks 寫法不一致
- 資料抓取散落在各頁
- 狀態管理分散
- 元件拆分風格不同

解法：

- 一開始就建立 `features/` 架構
- API / Firestore 操作集中到 `services/`
- 資料抓取統一用 hooks
- 重要型別集中在 `types/`

#### 缺點二：樣板程式可能比 Vue 多

React 某些表單、條件顯示、雙向輸入綁定，寫起來會比 Vue 多一點程式碼。

例如：

- input value + onChange
- modal 狀態管理
- 表單驗證

若本案畫面多為表單與列表，React 需要更好的元件封裝。

#### 缺點三：初期架構決策較多

React 需要決定：

- 路由用什麼
- 狀態管理用什麼
- 表單用什麼
- UI 套件用什麼
- CSS 用什麼

如果決策不清楚，專案初期會多花一些時間。

### 4.3 React 適合本案的情境

React 適合：

- 你希望之後容易找人接手
- 你希望專案能長期擴充
- 你希望未來可能重做更多前端頁面
- 你希望使用最多現成套件
- 你希望資料流與狀態管理有更強彈性

## 5. Vue 3 方案詳細分析

### 5.1 優點

#### 優點一：開發速度快，畫面直覺

Vue 的 Single-File Component 寫法把 template、script、style 放在同一個 `.vue` 檔案，對中小型 LIFF 頁面很直覺。

對本案的好處：

- 活動卡片、兌換券卡片、會員中心等 UI 很快可以做出來
- template 比 TSX 更接近 HTML
- 條件顯示、列表渲染寫法清楚

#### 優點二：雙向綁定與表單處理直覺

Vue 的 `v-model` 對表單很方便。VeeVa 客戶端雖然不是後台，但仍有：

- 問卷完成確認
- 活動報名
- 會員資料顯示與可能的補充欄位
- 搜尋或篩選

Vue 會寫得比較少、比較直覺。

#### 優點三：官方風格比較一致

Vue 官方推薦的搭配通常比較明確：

- Vue Router
- Pinia
- Vue SFC
- vue-tsc

對專案的好處：

- 架構選擇少一點
- 程式碼風格比較容易統一
- 新專案啟動速度快

#### 優點四：元件可讀性好

Vue 的 template 對 UI 結構很清楚。對客戶端頁面來說：

- 活動頁
- 最新資訊頁
- 兌換券頁
- 會員中心

這些都是大量 UI 組合，Vue 會很容易閱讀。

#### 優點五：效能足夠且體驗佳

Vue 3 對這種手機 SPA 很適合。只要不要放太重動畫或不必要 watch，效能通常很好。

### 5.2 缺點

#### 缺點一：人才市場比 React 小

Vue 工程師也不少，但整體市場通常比 React 少。未來如果要找人接手，React 的選擇會更廣。

對本案的影響：

- 短期不一定有差
- 長期維護、交接、擴充時，React 稍微更有優勢

#### 缺點二：大型生態選擇較少

Vue 的套件生態成熟，但在某些領域選擇不如 React 多，例如：

- 複雜 headless UI
- 複雜資料表
- 特殊互動元件
- 大型狀態或資料同步方案

本案目前不算大型，影響有限；但如果未來功能變多，React 彈性較大。

#### 缺點三：TypeScript 在 template 裡需要額外工具配合

Vue 3 TypeScript 已經成熟，但 template 的型別檢查需要 `vue-tsc`。整體體驗很好，但和 React TSX 相比，會多一層工具。

可能遇到：

- template 型別錯誤需要熟悉 Vue tooling
- generic component 寫法比 React 不直覺
- 複雜 props / emits 型別需遵守 Vue 寫法

#### 缺點四：若團隊不熟 Vue，接手需要時間

Vue 很好學，但如果維護者主要熟 React，Vue 的：

- Composition API
- ref / reactive
- computed / watch
- SFC
- Pinia

仍需要適應。

### 5.3 Vue 適合本案的情境

Vue 適合：

- 你希望最快做出穩定手機版 LIFF
- 你希望 UI 檔案看起來接近 HTML
- 你希望表單與簡單互動寫得少一點
- 你希望專案架構不要有太多技術選擇
- 主要維護者熟 Vue 或不排斥 Vue

## 6. 針對 VeeVa LIFF 的重點比較

### 6.1 手機順暢度

結論：React 和 Vue 差距不大，都會明顯優於 Flutter Web。

影響順暢度的真正關鍵：

- 是否避免重動畫
- 是否減少固定元素重疊
- 是否避免大面積 box-shadow / blur
- 是否控制圖片大小
- 是否避免一次渲染大量列表
- 是否避免不必要 Firestore 即時監聽
- 是否拆分頁面 bundle

如果寫法正確，React 與 Vue 都能順。

### 6.2 開發速度

Vue 通常比較快，尤其是：

- 卡片列表
- 表單
- 條件顯示
- modal
- 簡單頁面

React 初期要花更多時間定義 hooks、狀態、資料抓取方式，但長期可維護性很好。

### 6.3 維護與交接

React 較優。

原因：

- 人才多
- 大型專案案例多
- 企業前端使用普遍
- 套件與範例多

若未來希望找其他工程師接手，React 比較保險。

### 6.4 Firebase 串接

兩者幾乎相同。

Firebase Web SDK 是框架無關的：

- React 可用 custom hooks 封裝
- Vue 可用 composables 封裝

範例：

- React：`useMember()`, `useActivities()`
- Vue：`useMember()`, `useActivities()`

差異很小。

### 6.5 LINE LIFF 串接

兩者幾乎相同。

LINE LIFF SDK 也是框架無關的：

- 初始化 LIFF
- 檢查登入
- 取得 profile
- 取得 id token
- shareTargetPicker

這些都可以直接寫在 service 層。

建議兩個方案都要做：

```text
services/liff.ts
```

不要把 LIFF 邏輯散落在每個頁面。

### 6.6 UI 設計與 RWD

Vue 會比較直覺，React 彈性更高。

若畫面以：

- 活動卡
- 兌換券卡
- 最新資訊卡
- 會員中心
- 邀請紀錄彈窗

為主，Vue 寫起來會很舒服。

若未來要做更複雜 UI 狀態，例如：

- 任務進度
- 多活動流程
- 動態表單
- 多條件活動資格
- 複雜發券狀態

React 的狀態管理選擇會更多。

## 7. 風險比較

| 風險 | React | Vue |
| --- | --- | --- |
| 專案架構失控 | 中，需先定規範 | 低到中 |
| 初期開發太慢 | 中 | 低 |
| 未來不好找人 | 低 | 中 |
| 套件選錯 | 中 | 低到中 |
| TypeScript 複雜度 | 中 | 中 |
| LINE LIFF 相容性 | 低 | 低 |
| Firebase 整合風險 | 低 | 低 |
| 手機效能風險 | 低 | 低 |

## 8. 工時比較

以同樣功能範圍估算：

| 功能 | React 預估 | Vue 預估 |
| --- | --- | --- |
| 專案初始化與架構 | 4 到 6 小時 | 3 到 5 小時 |
| LIFF 登入與會員建立 | 6 到 10 小時 | 6 到 10 小時 |
| 會員中心 | 6 到 10 小時 | 5 到 8 小時 |
| 邀請分享與邀請紀錄 | 8 到 14 小時 | 8 到 13 小時 |
| 活動列表與活動詳情 | 8 到 12 小時 | 7 到 11 小時 |
| 兌換券頁 | 6 到 10 小時 | 5 到 9 小時 |
| 最新資訊頁 | 5 到 8 小時 | 4 到 7 小時 |
| 效能調整與手機測試 | 8 到 14 小時 | 8 到 14 小時 |

總估算：

- React：51 到 84 小時
- Vue：46 到 77 小時

Vue 在初期 UI 開發可能會快一些；React 在長期維護與後續擴充上比較有優勢。

## 9. 推薦結論

### 我的建議：React + Vite + TypeScript

原因：

1. 這個專案不是一次性活動頁，而是會員系統，後續會長期擴充。
2. 未來可能加入更多任務、發券、推薦、最新資訊與會員權限邏輯。
3. React 生態與人力取得最有優勢。
4. TypeScript + TSX 對資料模型與元件 props 很穩。
5. LINE LIFF、Firebase、Firestore 都能很好封裝在 React hooks 與 service layer 裡。

### Vue 3 什麼情況下更適合？

如果你的優先順序是：

1. 希望最快做出新 LIFF MVP
2. 希望畫面程式碼更接近 HTML
3. 功能短期內不會變太複雜
4. 維護者偏好 Vue

那 Vue 3 + Vite + TypeScript 會是很好的選擇。

## 10. 最終建議決策

建議採用：

```text
React + Vite + TypeScript
```

建議搭配：

```text
React Router
TanStack Query 或簡化版 custom hooks
Zustand 或 React Context
Firebase Web SDK
LINE LIFF SDK
Tailwind CSS 或 CSS Modules
Vitest
Playwright
```

開發策略：

1. 不一次重做所有功能
2. 先做登入、會員中心、邀請、活動、兌換券 MVP
3. 先發布新 hosting 測試
4. 手機 LINE 實測順暢度
5. 通過後再切正式 LIFF Endpoint

## 11. 參考官方文件

- React 官方 Learn 文件：https://react.dev/learn
- React TypeScript 官方文件：https://react.dev/learn/typescript
- Vue 官方介紹：https://vuejs.org/guide/introduction.html
- Vite 官方 Why Vite：https://vite.dev/guide/why.html

