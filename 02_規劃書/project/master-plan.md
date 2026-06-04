# VeeVa LINE LIFF 會員系統總規劃

## 專案背景

將既有 VeeVa 會員系統調整為 LINE 官方帳號內使用的 LIFF 會員系統。使用者透過 LINE Rich Menu、活動訊息或好友推薦連結開啟系統，不需下載 App。

## 專案目標

- 使用 LINE LIFF 建立會員入口。
- 使用 Firebase Hosting 部署顧客端與 Admin 後台。
- 使用 Firestore 保存會員、活動、問卷狀態、推薦關係與兌換券資料。
- 建立推薦分享流程，讓推薦人與被推薦人可綁定並依條件發券。
- 以現代化手機優先 UI 改善使用體驗。

## 使用者角色

| 角色 | 說明 |
| --- | --- |
| 會員 | 透過 LINE 開啟 LIFF，參與活動、填問卷、查看兌換券 |
| 被推薦朋友 | 透過推薦連結進入，完成會員與問卷流程 |
| 營運人員 | 使用 Admin 後台管理會員審核、活動、資訊、兌換券 |
| 系統管理員 | 管理 Firebase、LINE 設定、權限與資料安全 |

## 核心流程

1. 使用者加入 LINE 官方帳號。
2. 點擊 Rich Menu 或活動訊息開啟 LIFF。
3. LIFF 取得 LINE 使用者身分並建立會員。
4. 使用者填寫 Veeva 問卷。
5. Admin 後台審核會員。
6. 審核通過後發送系統訊息與兌換券。
7. 會員可分享推薦連結給朋友。
8. 朋友完成指定條件後，雙方取得禮券。

## 技術架構

| 層級 | 技術 |
| --- | --- |
| 顧客端 | Flutter Web / LIFF Web App |
| 後台 | Flutter Web Admin |
| Hosting | Firebase Hosting |
| Database | Cloud Firestore |
| Backend | Firebase Cloud Functions |
| Auth | LINE LIFF / LINE Login，Admin 使用 Firebase Authentication |

## 相關文件

- [LINE LIFF + Firebase 詳細規劃](./liff-firebase-plan.md)
- [需求規格](./requirement-spec.md)
- [技術規劃](./technical-plan.md)
- [UI/UX 規劃](./ui-ux-plan.md)
- [資料與 API 規劃](./data-api-plan.md)
- [工時估算](./development-hours.md)
- [驗收查驗清單](./validation-checklist.md)
- [發佈檢查清單](./release-checklist.md)

