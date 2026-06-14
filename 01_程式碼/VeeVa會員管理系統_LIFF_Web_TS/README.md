# VeeVa LIFF Web TS

React + Vite + TypeScript 版本的 VeeVa 客戶端 LIFF App。

## 技術

- React
- Vite
- TypeScript
- Firebase Web SDK
- LINE LIFF SDK
- React Router

## 目前完成

- LIFF 初始化
- LINE 登入與登出
- 本地登入 token 時效保存
- Firestore `members` upsert
- Firestore `activities` / `news` / `rewards` 讀取
- 會員已取得兌換券 `memberRewards` 讀取
- 推薦碼 `/r/:code` 與 `?ref=` 解析
- 推薦關聯 `referrals` 建立
- 分享邀請 Flex Message
- 活動、最新資訊、兌換券、會員中心四個底部頁面

## 開發

```bash
npm install
npm run dev
```

## 測試

```bash
npm run lint
npm run test
npm run build
```

## 環境設定

複製 `.env.example` 為 `.env.local` 後可覆寫設定。

```bash
cp .env.example .env.local
```

主要變數：

```text
VITE_LIFF_ID=2010298394-7PwRtpTY
VITE_PUBLIC_LIFF_URL=https://vevva.web.app
```

## Firebase Hosting

此專案預計使用新的 hosting site：

```text
vevva
```

部署前需要先確認 Firebase CLI 已登入，並已建立 hosting site。

```bash
npm run build
firebase deploy --only hosting
```

## 注意

正式切換前，先用新的 LIFF App 或測試 Endpoint 驗證手機 LINE 內建瀏覽器順暢度。確認穩定後，再切換正式 LIFF Endpoint。
