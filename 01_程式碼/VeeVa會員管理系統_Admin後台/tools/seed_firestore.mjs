import { execFileSync } from 'node:child_process';

const projectId = 'veeva-8d30c';
const database = '(default)';
const baseDocumentPath = `projects/${projectId}/databases/${database}/documents`;

function getAccessToken() {
  const output = execFileSync('firebase', ['login:list', '--json'], {
    encoding: 'utf8',
  });
  const parsed = JSON.parse(output);
  const token = parsed.result?.[0]?.tokens?.access_token;
  if (!token) {
    throw new Error('Firebase CLI access token not found.');
  }
  return token;
}

function fieldValue(value) {
  if (value === null || value === undefined) {
    return { nullValue: null };
  }
  if (value instanceof Date) {
    return { timestampValue: value.toISOString() };
  }
  if (typeof value === 'boolean') {
    return { booleanValue: value };
  }
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(fieldValue) } };
  }
  return { stringValue: String(value) };
}

function fields(data) {
  return Object.fromEntries(
    Object.entries(data)
      .filter(([, value]) => value !== undefined)
      .map(([key, value]) => [key, fieldValue(value)]),
  );
}

function write(collection, id, data) {
  return {
    update: {
      name: `${baseDocumentPath}/${collection}/${id}`,
      fields: fields(data),
    },
  };
}

const activities = [
  {
    id: 'survey-coffee',
    label: '限時活動',
    title: '填問卷，拿咖啡券',
    description: '完成問卷並通過資格確認後，即可獲得咖啡兌換券。分享給朋友，朋友完成後你再得 1 張。',
    reward: '咖啡兌換券',
    status: 'published',
    active: true,
    periodText: '2026/05/01 - 2026/06/30',
    note: '完成問卷後發放兌換券',
  },
  {
    id: 'seminar-reminder',
    label: '即將開始',
    title: '研討會報名提醒',
    description: '醫學會活動名額開放後，會員可直接收到報名提醒與活動資訊。',
    reward: '活動提醒',
    status: 'scheduled',
    active: false,
    periodText: '2026/06/15 - 2026/07/15',
    note: '醫學會活動報名通知',
  },
  {
    id: 'hospital-mission',
    label: '籌備中',
    title: '院所限定任務',
    description: '依照院所與科別推出限定任務，完成後可獲得專屬會員獎勵。',
    reward: '專屬獎勵',
    status: 'draft',
    active: false,
    periodText: '未設定',
    note: '指定院所會員任務',
  },
];

const news = [
  {
    id: 'who-product-alert',
    date: '2026/05/07',
    source: 'WHO',
    title: 'WHO 發布醫療產品警示',
    summary: '提醒留意部分 Iohexol / Iodixanol 顯影劑產品的品質風險，臨床使用前應確認供應來源與批號資訊。',
    status: 'published',
    category: '公共衛生',
  },
  {
    id: 'who-gcp-course',
    date: '2026/05/05',
    source: 'WHO',
    title: 'WHO 推出臨床試驗良好實務線上課程',
    summary: '新課程聚焦臨床試驗品質、倫理與執行標準，可作為研究團隊訓練素材。',
    status: 'published',
    category: '臨床研究',
  },
  {
    id: 'fda-realtime-trials',
    date: '2026/04/30',
    source: 'HHS / FDA',
    title: 'FDA 推動即時臨床試驗追蹤試點',
    summary: 'FDA 宣布推進 real-time clinical trials 相關措施，目標是提升臨床試驗資訊透明度與執行效率。',
    status: 'published',
    category: '法規',
  },
  {
    id: 'fda-hearing-gene-therapy',
    date: '2026/04/23',
    source: 'HHS / FDA',
    title: 'FDA 核准遺傳性聽損基因治療',
    summary: 'FDA 核准 Otarmeni，為遺傳性聽損治療帶來新的基因治療選項。',
    status: 'published',
    category: '治療進展',
  },
  {
    id: 'nih-monthly-topics',
    date: '2026/05',
    source: 'NIH News in Health',
    title: 'NIH 更新燒傷修復、阿茲海默症預測與腎結石研究主題',
    summary: 'NIH 月刊整理多項研究進展，包含燒傷癒合、阿茲海默症風險預測與腎結石中的細菌研究。',
    status: 'published',
    category: '研究',
  },
  {
    id: 'cdc-respiratory-low',
    date: '2026/04/17',
    source: 'CDC',
    title: '美國急性呼吸道疾病就醫活動維持低水準',
    summary: 'CDC 呼吸道疾病資料顯示，急性呼吸道疾病導致就醫的整體活動量處於 very low 水準。',
    status: 'published',
    category: '公共衛生',
  },
];

const rewards = [
  {
    id: 'COFFEE-8X2L',
    name: '中杯美式咖啡 1 杯',
    category: '飲品',
    stock: 120,
    issued: 58,
    redeemed: 36,
    expiresAt: new Date('2026-08-31T15:59:59.000Z'),
    status: 'active',
  },
  {
    id: 'TEA-42QK',
    name: '無糖綠茶 1 瓶',
    category: '飲品',
    stock: 80,
    issued: 42,
    redeemed: 21,
    expiresAt: new Date('2026-09-15T15:59:59.000Z'),
    status: 'active',
  },
  {
    id: 'BOOK-7P9A',
    name: '醫學書展 100 元折抵券',
    category: '折抵',
    stock: 60,
    issued: 24,
    redeemed: 9,
    expiresAt: new Date('2026-10-05T15:59:59.000Z'),
    status: 'active',
  },
  {
    id: 'MASK-M3D8',
    name: '醫療口罩 1 盒',
    category: '實體贈品',
    stock: 90,
    issued: 32,
    redeemed: 18,
    expiresAt: new Date('2026-07-20T15:59:59.000Z'),
    status: 'active',
  },
  {
    id: 'BENTO-Q6R2',
    name: '健康便當折價券',
    category: '餐飲',
    stock: 55,
    issued: 20,
    redeemed: 7,
    expiresAt: new Date('2026-09-30T15:59:59.000Z'),
    status: 'active',
  },
  {
    id: 'POINT-L5N1',
    name: '會員點數 300 點',
    category: '點數',
    stock: 300,
    issued: 120,
    redeemed: 62,
    expiresAt: new Date('2026-12-31T15:59:59.000Z'),
    status: 'active',
  },
];

const reviews = [
  {
    id: 'demo-review-1',
    memberId: 'line-demo-chang',
    name: '張雅雯',
    hospital: '北醫附醫',
    department: '胸腔內科',
    status: 'pending',
    completedAt: new Date('2026-05-08T01:12:00.000Z'),
  },
  {
    id: 'demo-review-2',
    memberId: 'line-demo-wu',
    name: '吳志誠',
    hospital: '高醫',
    department: '腎臟科',
    status: 'pending',
    completedAt: new Date('2026-05-08T02:04:00.000Z'),
  },
  {
    id: 'demo-review-3',
    memberId: 'line-demo-li',
    name: '李佩珊',
    hospital: '亞東醫院',
    department: '小兒科',
    status: 'pending',
    completedAt: new Date('2026-05-08T03:27:00.000Z'),
  },
  {
    id: 'demo-review-4',
    memberId: 'line-demo-wang',
    name: '王小明',
    hospital: '台大醫院',
    department: '心臟內科',
    status: 'approved',
    completedAt: new Date('2026-05-07T07:42:00.000Z'),
  },
  {
    id: 'demo-review-5',
    memberId: 'line-demo-chen',
    name: '陳怡君',
    hospital: '榮總',
    department: '家醫科',
    status: 'approved',
    completedAt: new Date('2026-05-07T09:21:00.000Z'),
  },
];

const members = [
  {
    id: 'line-demo-wang',
    lineUserId: 'line-demo-wang',
    name: '王小明',
    hospital: '台大醫院',
    department: '心臟內科',
    status: 'verified',
    earnedCoupons: 3,
    invitedCount: 5,
    shareCode: 'A8D2K',
    email: 'wang@example.com',
    isAdmin: true,
    adminRole: 'owner',
  },
  {
    id: 'line-demo-chen',
    lineUserId: 'line-demo-chen',
    name: '陳怡君',
    hospital: '榮總',
    department: '家醫科',
    status: 'verified',
    earnedCoupons: 2,
    invitedCount: 1,
    shareCode: 'C7K91',
    email: 'chen@example.com',
    isAdmin: false,
  },
  {
    id: 'line-demo-chang',
    lineUserId: 'line-demo-chang',
    name: '張雅雯',
    hospital: '北醫附醫',
    department: '胸腔內科',
    status: 'pendingReview',
    earnedCoupons: 0,
    invitedCount: 0,
    shareCode: 'Z9A12',
    email: 'chang@example.com',
    isAdmin: false,
  },
  {
    id: 'line-demo-wu',
    lineUserId: 'line-demo-wu',
    name: '吳志誠',
    hospital: '高醫',
    department: '腎臟科',
    status: 'pendingReview',
    earnedCoupons: 0,
    invitedCount: 0,
    shareCode: 'W4Q08',
    email: 'wu@example.com',
    isAdmin: false,
  },
  {
    id: 'line-demo-li',
    lineUserId: 'line-demo-li',
    name: '李佩珊',
    hospital: '亞東醫院',
    department: '小兒科',
    status: 'pendingReview',
    earnedCoupons: 0,
    invitedCount: 0,
    shareCode: 'L7P33',
    email: 'li@example.com',
    isAdmin: false,
  },
];

const adminUsers = [
  {
    id: 'line-demo-wang',
    memberId: 'line-demo-wang',
    lineUserId: 'line-demo-wang',
    name: '王小明',
    email: 'wang@example.com',
    role: 'owner',
    status: 'active',
    permissions: ['members', 'activities', 'news', 'rewards', 'settings'],
    grantedAt: new Date('2026-06-01T02:00:00.000Z'),
  },
];

const writes = [
  ...activities.map((item) => write('activities', item.id, item)),
  ...news.map((item) => write('news', item.id, item)),
  ...rewards.map((item) => write('rewards', item.id, item)),
  ...reviews.map((item) => write('reviewSubmissions', item.id, item)),
  ...members.map((item) => write('members', item.id, item)),
  ...adminUsers.map((item) => write('adminUsers', item.id, item)),
];

const token = getAccessToken();
const response = await fetch(
  `https://firestore.googleapis.com/v1/${baseDocumentPath}:commit`,
  {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ writes }),
  },
);

const body = await response.json();
if (!response.ok) {
  throw new Error(JSON.stringify(body, null, 2));
}

console.log(
  JSON.stringify(
    {
      status: 'success',
      writes: writes.length,
      updateTime: body.writeResults?.at(-1)?.updateTime,
    },
    null,
    2,
  ),
);
