# 技術規劃

## 架構

```text
LINE Official Account
  -> LIFF Web App on Firebase Hosting
  -> Cloud Functions
  -> Cloud Firestore

Admin Web on Firebase Hosting
  -> Firebase Authentication
  -> Cloud Functions / Firestore
```

## 前端規劃

- 顧客端：Flutter Web 改造成 LIFF Web App。
- 後台：Flutter Web Admin。
- LIFF SDK：取得 profile、context、分享功能。
- UI：Material 3 + LINE 綠色系 + 現代卡片式 layout。

## 後端規劃

- Cloud Functions 驗證 LINE ID token。
- Cloud Functions 處理會員建立、推薦綁定、審核、發券。
- Firestore Rules 限制使用者只能讀取自己的資料。
- Admin 操作需檢查 `adminUsers` role。

## 第三方服務

- LINE Login / LIFF
- LINE Messaging API
- Firebase Hosting
- Firestore
- Cloud Functions
- Firebase Authentication
- Veeva / OneTrust 問卷

## 風險

- Veeva 表單可能限制 iframe 或 LIFF 內嵌。
- Firestore Rules 設計不完整會造成資料安全風險。
- LINE 官方帳號推播可能產生額外費用。

