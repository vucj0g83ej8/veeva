import type { VeevaActivity, VeevaActivityType } from '../types/veeva'

interface ActivityFlow {
  type: VeevaActivityType
  label: string
  actionLabel: string
  description: string
  nextStep: string
}

const activityFlows: Record<VeevaActivityType, ActivityFlow> = {
  survey: {
    type: 'survey',
    label: '問卷活動',
    actionLabel: '填寫問卷',
    description: '適合問卷、意見調查、資格審核或活動回饋。',
    nextStep: '點擊後會前往問卷頁面，完成後依活動規則審核或發放獎勵。',
  },
  registration: {
    type: 'registration',
    label: '活動報名',
    actionLabel: '我要報名',
    description: '適合研討會、講座、課程、線上或實體活動報名。',
    nextStep: '點擊後會建立會員報名紀錄，後續可由後台查看報名名單。',
  },
  referral: {
    type: 'referral',
    label: '邀請好友',
    actionLabel: '邀請好友',
    description: '適合推薦會員、分享邀請連結、好友加入獎勵活動。',
    nextStep: '點擊後會開啟 LINE 分享卡片，朋友登入後會和邀請者建立關聯。',
  },
  task: {
    type: 'task',
    label: '任務活動',
    actionLabel: '開始任務',
    description: '適合閱讀文章、完成會員資料、觀看內容或指定動作。',
    nextStep: '點擊後會進入指定任務流程，完成後可依活動設定發放獎勵。',
  },
  checkin: {
    type: 'checkin',
    label: '簽到活動',
    actionLabel: '活動簽到',
    description: '適合現場報到、QR Code 簽到或限定地點活動。',
    nextStep: '點擊後會進入簽到流程，現場活動可搭配 QR Code 驗證。',
  },
  external: {
    type: 'external',
    label: '外部連結',
    actionLabel: '前往活動',
    description: '適合導向官方頁、外部活動頁、表單或合作頁面。',
    nextStep: '點擊後會開啟指定活動連結。',
  },
}

export function activityFlowFor(activity: VeevaActivity) {
  return activityFlows[activity.type] ?? activityFlows.external
}

export function activityTypeOptions() {
  return Object.values(activityFlows)
}
