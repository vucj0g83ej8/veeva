# VeeVa 會員管理系統 LIFF App

這是以 Flutter Web 製作的 LINE LIFF 會員系統原型。顧客端 App 已接上
LIFF SDK 基礎架構與 LINE Login 流程。

## LINE LIFF 設定

1. 到 LINE Developers Console 建立或開啟此專案的 LINE Login channel。
2. 新增 LIFF app，並將 Endpoint URL 設為正式部署後的 Web URL。
3. 開啟 App 需要的 scopes：
   - `profile`：讀取 `liff.getProfile()` 的 LINE 顯示名稱與頭像
   - `openid`：取得 `liff.getIDToken()`，供後端或 Firebase 驗證
   - `email`：只有會員流程需要 LINE email 時才開啟
4. 複製 LIFF ID，啟動或建置時透過 `LIFF_ID` 帶入。

## 本機開發

```bash
flutter pub get
flutter run -d chrome --dart-define=LIFF_ID=YOUR_LIFF_ID
```

若希望外部瀏覽器開啟時自動啟動 LINE Login，可額外加入：

```bash
--dart-define=LIFF_AUTO_LOGIN=true
```

## 正式建置

```bash
flutter build web --dart-define=LIFF_ID=2010298394-7PwRtpTY
```

將 `build/web` 部署到 LIFF Endpoint URL 設定的同一個網址。

## 目前測試部署

- Firebase Hosting URL：`https://veeva-8d30c.web.app`
- Firebase project：`veeva-8d30c`
- Firestore database：`(default)` / `asia-east1`
- LINE Developers Provider：`vevva`
- LINE Login channel ID：`2010298394`
- LIFF ID：`2010298394-7PwRtpTY`
- LIFF URL：`https://liff.line.me/2010298394-7PwRtpTY`
- LINE Official Account：`@896pwyxc` / `veeva 測試`
- 測試 rich menu ID：`richmenu-332486f0cedb701fcb794dc9568b59a2`

目前 LINE@ 預設圖文選單已透過 Messaging API 設為測試入口，點擊後會開啟 LIFF URL。
測試圖產生腳本與輸出圖檔在：

- `tools/create_rich_menu_test_image.mjs`
- `tools/veeva-rich-menu-test.png`

## 目前登入流程

- `web/index.html` 載入 LINE 官方 LIFF SDK。
- `lib/services/liff_service_web.dart` 負責初始化 LIFF、啟動 LINE Login，並讀取 LINE profile 與 ID token。
- `lib/services/liff_service_stub.dart` 讓 widget tests 與非 Web build 不需要瀏覽器 SDK 也能執行。
- `lib/main.dart` 將 LINE 顯示名稱、頭像、email、statusMessage 與 ID token 同步到 Firestore `members/{lineUserId}`，再接續問卷或會員中心流程。

## Firebase 資料串接

- `lib/firebase_options.dart`：Firebase Web App 設定。
- `lib/data/veeva_models.dart`：Firestore 資料模型。
- `lib/data/veeva_repository.dart`：Firestore / Storage repository 與 demo fallback。
- `firestore.rules`：目前開發測試用 rules，正式上線前需改成 Firebase Auth 管理員權限。

目前使用的 collections：

- `activities`
- `news`
- `rewards`
- `members`
- `reviewSubmissions`

Cloud Storage 程式架構已保留，但 Firebase 新專案在 2024/10/30 後建立 default Storage bucket 需要 Blaze 方案；免費優先時先使用 `imageUrl` 或 Hosting 靜態圖。
