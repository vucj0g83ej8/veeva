# 驗收查驗清單

## 1. 功能查驗

- [ ] LINE 官方帳號可開啟 LIFF 會員系統。
- [ ] LIFF 可取得 LINE 使用者身分。
- [ ] 使用者可查看活動消息。
- [ ] 使用者可進入 Veeva 問卷。
- [ ] 問卷送出後可顯示 Thank You。
- [ ] 會員中心資料顯示正確。
- [ ] 兌換券列表與兌換確認正常。
- [ ] 系統訊息可開啟與閱讀。
- [ ] 推薦連結可分享並建立關係。

## 2. UI 查驗

- [ ] LINE 內瀏覽器顯示正常。
- [ ] 360px 手機寬度正常。
- [ ] 文字沒有溢出。
- [ ] 卡片、彈窗、按鈕沒有重疊。
- [ ] loading / empty / error / success 狀態完整。

## 3. 資料查驗

- [ ] members 寫入正確。
- [ ] referrals 不會重複建立。
- [ ] couponGrants 不會重複發放。
- [ ] systemMessages 只顯示自己的訊息。
- [ ] Admin 審核狀態更新正確。

## 4. 第三方串接查驗

- [ ] LIFF 初始化正常。
- [ ] LINE profile 取得正常。
- [ ] Firebase Hosting 正常。
- [ ] Firestore 讀寫正常。
- [ ] Cloud Functions 執行正常。
- [ ] Veeva 問卷可正常開啟。

## 5. 後台查驗

- [ ] Admin 可登入。
- [ ] 會員列表可查詢。
- [ ] 待審核/已審核分頁正常。
- [ ] 活動管理正常。
- [ ] 最新資訊管理正常。
- [ ] 兌換券管理正常。
- [ ] 推薦管理可查看狀態。

## 6. 部署查驗

- [ ] Firebase Hosting 已部署。
- [ ] Firestore Rules 已部署。
- [ ] Cloud Functions 已部署。
- [ ] LIFF Endpoint URL 設定正確。
- [ ] 正式網域與 HTTPS 正常。

## 7. 文件查驗

- [ ] 操作說明完成。
- [ ] Firestore 資料結構完成。
- [ ] Cloud Functions 清單完成。
- [ ] UI 圖與規劃書整理完成。

