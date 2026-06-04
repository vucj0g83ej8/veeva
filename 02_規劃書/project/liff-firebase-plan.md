# VeeVa 會員系統 LINE LIFF + Firebase 規劃書

## 1. 規劃目標

本規劃將原本的跨平台 App 概念調整為 **LINE 官方帳號內的 LIFF 會員系統**。使用者不需要下載 App，只要加入 LINE 官方帳號，透過 Rich Menu、活動訊息或推薦連結即可開啟會員系統。

第一版伺服器與資料庫採用：

| 項目 | 規劃 |
| --- | --- |
| 前台部署 | Firebase Hosting |
| 資料庫 | Cloud Firestore |
| 後端邏輯 | Firebase Cloud Functions |
| 使用者身分 | LINE LIFF / LINE Login |
| 推薦分享 | LIFF 分享連結 + referral code |
| 後台 | Admin Web，同樣部署於 Firebase Hosting |

## 2. 系統型態

| 模組 | 說明 |
| --- | --- |
| LINE 官方帳號 | 會員入口、Rich Menu、活動通知、審核通知 |
| LIFF 會員系統 | 活動消息、Veeva 問卷、會員中心、兌換券、最新資訊、推薦分享 |
| Firebase Hosting | 部署 LIFF Web App 與 Admin Web |
| Firestore | 保存會員、活動、推薦關係、問卷狀態、兌換券與最新資訊 |
| Cloud Functions | 處理登入驗證、推薦綁定、發券、防重複操作、後台管理邏輯 |
| Admin 後台 | 會員審核、活動管理、最新資訊管理、兌換券管理、推薦管理 |

## 3. 使用者流程

### 3.1 一般會員流程

1. 使用者加入 LINE 官方帳號。
2. 點擊 Rich Menu 的「活動消息」或收到活動訊息。
3. 開啟 LIFF 會員系統。
4. LIFF 取得 LINE 使用者身分。
5. 使用者查看活動並填寫 Veeva 問卷。
6. 送出後顯示 Thank You 頁。
7. 系統建立待審核狀態。
8. Admin 後台審核通過。
9. 系統發送站內訊息或 LINE 訊息。
10. 使用者回到會員中心查看兌換券。

### 3.2 推薦分享流程

1. 會員 A 進入會員中心。
2. 點擊「邀請好友」。
3. 系統產生推薦連結：

```text
https://liff.line.me/{LIFF_ID}?ref=A8X2K9&campaignId=main2026
```

4. 會員 A 使用 LIFF 分享功能將連結傳給朋友 B。
5. 朋友 B 點擊連結並開啟 LIFF。
6. 系統取得朋友 B 的 LINE userId。
7. Cloud Functions 根據 `ref` 找到會員 A。
8. 系統建立 A 與 B 的推薦關係。
9. 朋友 B 完成問卷與審核後，系統發放禮券給 A 與 B。

## 4. LIFF 頁面規劃

| 頁面 | 功能 |
| --- | --- |
| 活動消息 | 顯示活動卡片、活動狀態、立即開始 |
| Veeva 問卷 | 內嵌或外開 Veeva/OneTrust 表單 |
| 送出成功 | 顯示 Thank You 與「審查結果將會寄至您的信箱」 |
| 最新資訊 | 條列式醫學消息與活動資訊 |
| 兌換券 | 顯示商品名稱、期限、兌換按鈕與確認視窗 |
| 會員中心 | 顯示會員資料、資格狀態、活動紀錄、通知設定 |
| 系統訊息 | 顯示審核通過、活動上架、資料更新等站內消息 |
| 邀請好友 | 產生推薦連結，分享給 LINE 好友或群組 |

## 5. Firestore 資料結構

### 5.1 members

```text
members/{memberId}
- lineUserId
- displayName
- pictureUrl
- email
- hospital
- department
- reviewStatus: pending | approved | rejected
- createdAt
- updatedAt
- lastLoginAt
```

### 5.2 campaigns

```text
campaigns/{campaignId}
- title
- description
- status: draft | active | closed
- startAt
- endAt
- rewardRule
- createdAt
- updatedAt
```

### 5.3 surveySubmissions

```text
surveySubmissions/{submissionId}
- memberId
- campaignId
- veevaUrl
- status: opened | submitted | pendingReview | approved
- submittedAt
- createdAt
```

### 5.4 coupons

```text
coupons/{couponId}
- title
- category
- expiresAt
- status: active | disabled | expired
- stock
- issuedCount
- redeemedCount
- createdAt
- updatedAt
```

### 5.5 couponGrants

```text
couponGrants/{grantId}
- memberId
- couponId
- source: survey | referralInviter | referralInvitee | manual
- referralId
- status: available | redeemed | expired
- grantedAt
- redeemedAt
```

### 5.6 referrals

```text
referrals/{referralId}
- referralCode
- inviterMemberId
- inviteeMemberId
- campaignId
- status: clicked | registered | completed | rewarded | invalid
- createdAt
- completedAt
- rewardedAt
```

### 5.7 news

```text
news/{newsId}
- title
- source
- category
- publishedAt
- status: draft | published
- createdAt
- updatedAt
```

### 5.8 systemMessages

```text
systemMessages/{messageId}
- memberId
- title
- body
- type: review | coupon | campaign | system
- readAt
- createdAt
```

### 5.9 adminUsers

```text
adminUsers/{uid}
- email
- role: owner | admin | operator | viewer
- status: active | disabled
- createdAt
```

## 6. 推薦綁定規則

| 規則 | 說明 |
| --- | --- |
| 不可自己推薦自己 | inviterMemberId 不可等於 inviteeMemberId |
| 同一活動不可重複綁定 | 同一 invitee 在同一 campaign 只能有一筆有效 referral |
| 未完成條件不發券 | 需完成問卷與審核通過後才給券 |
| 發券需防重複 | 使用 Cloud Functions transaction 避免重複發券 |
| referral code 不使用會員流水 ID | 使用隨機碼或短碼，避免被猜測 |

## 7. Admin 後台規劃

| 頁面 | 功能 |
| --- | --- |
| 儀表板 | 問卷完成、待審核、審核通過、兌換券庫存、推薦成效 |
| 會員管理 | 待審核/已審核分頁、會員資料、審核通過 |
| 活動管理 | 活動列表、新增活動、活動期間、狀態管理 |
| 最新資訊管理 | 新增、編輯、發布醫學消息 |
| 兌換券管理 | 券種、庫存、發放數、兌換數、補庫存、啟用停用 |
| 推薦管理 | 查看推薦人、被推薦人、完成狀態、發券狀態 |
| 系統訊息 | 手動或自動發送站內通知 |

## 8. UI / UX 設計方向

此系統會在 LINE 內使用，畫面需符合手機優先、操作簡單、快速完成任務的特性。

建議採用：

| 類型 | 建議 |
| --- | --- |
| Design System | Material 3 |
| 視覺風格 | 現代、圓潤、乾淨、卡片式、低噪音 |
| 主色 | LINE 綠 / 醫療信任綠 |
| 顧客端元件 | Bottom navigation、cards、chips、modal bottom sheet、toast/snackbar |
| 後台元件 | SaaS Admin Dashboard、統計卡、表格、搜尋、篩選、分頁 |

### 8.1 顧客端 UI

| 頁面 | UI 優化 |
| --- | --- |
| 活動消息 | 大卡片 + 狀態標籤 + 明確 CTA |
| 最新資訊 | 小型一致高度卡片，列表更容易掃描 |
| 兌換券 | 商品名稱、期限、兌換按鈕，降低資訊負擔 |
| 會員中心 | 會員資料卡 + 常用功能列表 + 系統訊息入口 |
| 邀請好友 | 顯示推薦成果、分享按鈕、已得獎勵 |

### 8.2 Admin UI

| 頁面 | UI 優化 |
| --- | --- |
| 儀表板 | 統計卡、狀態分布、最新待審核 |
| 會員管理 | 分頁式名單、搜尋、審核操作 |
| 兌換券管理 | 庫存狀態、補庫存、啟用停用 |
| 推薦管理 | 推薦關係、完成狀態、獎勵狀態 |

## 9. 權限與安全

| 項目 | 做法 |
| --- | --- |
| LIFF 使用者 | 使用 LINE ID token 驗證 |
| Firestore 寫入 | 敏感操作由 Cloud Functions 執行 |
| 後台登入 | Firebase Authentication + adminUsers 權限表 |
| Firestore Rules | 會員只能讀取自己的資料；Admin 需驗證 role |
| 發券 | Cloud Functions transaction 防止重複發券 |
| 推薦 | Cloud Functions 檢查自推、重複推薦、活動狀態 |

## 10. 開發階段

| 階段 | 內容 | 交付 |
| --- | --- | --- |
| Phase 1 | LIFF + Firebase 專案初始化 | Hosting、Firestore、Functions、LIFF 設定 |
| Phase 2 | 顧客端 LIFF 頁面 | 活動、問卷、會員中心、兌換券、最新資訊 |
| Phase 3 | 推薦分享 | referral code、分享連結、推薦綁定 |
| Phase 4 | Admin 後台 | 會員、活動、資訊、兌換券、推薦管理 |
| Phase 5 | 整合與測試 | LINE 內測試、Firestore Rules、UAT |
| Phase 6 | 上線交付 | Firebase deploy、文件、操作說明 |

## 11. 需要申請與準備的項目

| 項目 | 用途 |
| --- | --- |
| LINE 官方帳號 | 會員入口、Rich Menu、通知 |
| LINE Developers Provider | 管理 LINE Login / Messaging API Channel |
| LINE Login Channel | 建立 LIFF App 與登入身份 |
| Messaging API Channel | 官方帳號訊息、Rich Menu、Webhook |
| Firebase Project | Hosting、Firestore、Functions、Authentication |
| 正式網域 | LIFF Endpoint、Firebase Hosting custom domain |
| 隱私權政策與服務條款 | LINE Login / LIFF / 會員資料使用 |

## 12. 待確認問題

| 問題 | 影響 |
| --- | --- |
| Veeva 表單是否允許在 LIFF / iframe / WebView 中開啟 | 決定問卷要內嵌或外開 |
| LINE 官方帳號是否需推播訊息 | 影響 Messaging API 與費用 |
| 推薦獎勵發放條件 | 決定何時建立 couponGrants |
| 兌換券是否需要實體 POS 或第三方券商 | 影響 Firestore 資料模型與 API |
| Admin 是否需要多人權限 | 影響 Firebase Auth 與 role 設計 |

## 13. 官方文件參考

- [LINE LIFF Documentation](https://developers.line.biz/en/docs/liff/)
- [LIFF API Reference](https://developers.line.biz/en/reference/liff/)
- [LINE Messaging API](https://developers.line.biz/en/docs/messaging-api/)
- [Firebase Hosting](https://firebase.google.com/docs/hosting)
- [Firebase CLI / Firestore Rules](https://firebase.google.com/docs/cli)

