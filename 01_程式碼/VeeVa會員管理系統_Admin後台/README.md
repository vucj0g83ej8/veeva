# VeeVa Admin 後台管理平台

這是 VeeVa 會員管理系統的獨立後台 Flutter Web 專案，與 LIFF 會員端分開維護與部署。

## 專案資訊

- Firebase project：`veeva-8d30c`
- Firebase Hosting site：`veeva-admin`
- Firestore database：`(default)` / `asia-east1`
- 正式網址：`https://veeva-admin.web.app`
- Admin LIFF ID：`2010298394-CWB7Tlp4`

## 常用指令

```sh
flutter analyze
flutter test
flutter build web --dart-define=ADMIN_LIFF_ID=YOUR_ADMIN_LIFF_ID
firebase deploy --only hosting
```

## Firebase 資料串接

- `lib/firebase_options.dart`：Firebase Web App 設定。
- `lib/data/veeva_models.dart`：Firestore 資料模型。
- `lib/data/veeva_repository.dart`：Firestore / Storage repository 與 demo fallback。
- `tools/seed_firestore.mjs`：寫入活動、最新資訊、兌換券、會員、審核名單與管理者初始資料。

常用後端指令：

```sh
firebase deploy --only firestore
node tools/seed_firestore.mjs
```

目前使用的 collections：`activities`、`news`、`rewards`、`members`、`reviewSubmissions`、`adminUsers`。

後台權限使用 LINE 會員授權：會員需先透過 LIFF 登入產生 `members/{lineUserId}`，再由後台權限管理頁把該會員授權到 `adminUsers/{lineUserId}`。正式資料以真實 LINE 登入會員為準，不需再 seed `line-demo-*` 測試會員。

後台登入統一使用 LINE LIFF。請在 LINE Developers 建立 Admin 專用 LIFF App，Endpoint URL 設為 `https://veeva-admin.web.app/`，部署時用 `ADMIN_LIFF_ID` 帶入；後台 LINE 登入會固定 redirect 回這個根網址，不會帶測試用 query string。若未設定，後台會停在 LINE 登入設定提示畫面。

LIFF 登入後的 `members` 會記錄 LINE userId、displayName、avatarUrl、email、statusMessage、最近登入時間，以及最新 `lineIdToken` 與 token 更新時間。後台列表只顯示 token 是否已記錄，不直接顯示完整 token。

Cloud Storage 程式架構已保留，但 Firebase 新專案在 2024/10/30 後建立 default Storage bucket 需要 Blaze 方案；免費優先時先使用 `imageUrl` 或 Hosting 靜態圖。
