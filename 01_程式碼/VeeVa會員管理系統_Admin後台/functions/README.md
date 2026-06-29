# VeeVa Firebase Functions

## LINE 兌換券通知

`sendRewardIssuedLineMessage` 會在 `memberNotifications` 新增 `type = rewardIssued` 的通知時觸發，並透過 LINE Messaging API 發送 Flex Message 卡片給會員。

需要在 `functions/.env` 設定環境變數後重新部署 Functions：

```bash
LINE_CHANNEL_ACCESS_TOKEN="LINE Messaging API Channel access token"
```

可選環境變數：

```bash
LINE_LIFF_ID=2010298394-7PwRtpTY
```

部署：

```bash
npx firebase-tools@latest deploy --only functions
```

卡片按鈕會導向：

```text
https://liff.line.me/{LINE_LIFF_ID}?liff.state=/coupons?reward={memberRewardId}
```
