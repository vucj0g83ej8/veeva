# 資料與 API 規劃

## Firestore Collections

| Collection | 用途 |
| --- | --- |
| members | 會員與 LINE 身分資料 |
| campaigns | 活動資料 |
| surveySubmissions | 問卷送出與審核狀態 |
| coupons | 兌換券主資料與庫存 |
| couponGrants | 會員獲得的券 |
| referrals | 推薦關係 |
| news | 最新資訊 |
| systemMessages | 站內系統訊息 |
| adminUsers | 後台管理員與權限 |

## Cloud Functions

| Function | 用途 |
| --- | --- |
| verifyLineProfile | 驗證 LINE ID token 並取得會員 |
| createReferral | 建立推薦關係 |
| completeSurvey | 建立問卷完成狀態 |
| approveMember | 審核會員並觸發發券 |
| grantCoupon | 發放兌換券並防止重複 |
| redeemCoupon | 兌換券狀態更新 |
| createSystemMessage | 建立系統訊息 |

## 權限規則

- 使用者只能讀取自己的 `members`、`couponGrants`、`systemMessages`。
- 使用者不可直接修改 `couponGrants`、`referrals`、`reviewStatus`。
- Admin 操作需透過 Firebase Auth 與 `adminUsers` role 驗證。
- 發券、審核、推薦綁定需使用 transaction 或 idempotency key。

