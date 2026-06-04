# 需求規格

## 功能需求

| 模組 | 需求 |
| --- | --- |
| LINE LIFF 入口 | 使用者可從 LINE 官方帳號開啟會員系統 |
| 會員身分 | 使用 LINE userId 綁定會員資料 |
| 活動消息 | 顯示活動卡片與 CTA |
| Veeva 問卷 | 於 LIFF 內嵌或外開問卷表單 |
| 送出成功 | 顯示 Thank You 與審查結果提示 |
| 最新資訊 | 顯示醫學消息與活動資訊 |
| 兌換券 | 顯示券名稱、期限、兌換按鈕與確認視窗 |
| 會員中心 | 顯示會員資料、資格狀態、功能列表 |
| 系統訊息 | 顯示審核、活動、券相關通知 |
| 推薦分享 | 會員可分享 referral link，朋友登入後建立關係 |
| Admin 後台 | 管理會員、活動、資訊、兌換券、推薦關係 |

## 非功能需求

- 手機優先設計，需適合 LINE 內瀏覽器。
- Firebase Hosting 需支援 HTTPS。
- Firestore 敏感資料寫入需透過 Cloud Functions。
- 推薦與發券需防止重複觸發。

## 不包含項目

- 第三方 POS 深度串接。
- LINE Push Message 大量正式推播費用。
- App Store / Google Play 原生 App 上架。
- 高流量壓測與資安滲透測試。

## 待確認問題

- Veeva 表單是否允許在 LIFF / iframe / WebView 中開啟。
- 推薦獎勵發放條件與券種。
- LINE 官方帳號是否要使用推播訊息。
- Admin 是否需要多人權限與分級角色。

