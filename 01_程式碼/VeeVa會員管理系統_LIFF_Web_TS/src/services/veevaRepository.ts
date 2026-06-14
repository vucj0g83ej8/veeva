import {
  collection,
  doc,
  getDoc,
  getDocs,
  increment,
  limit,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  where,
  writeBatch,
} from 'firebase/firestore'
import { firestore } from './firebase'
import type {
  BootstrapData,
  LiffProfile,
  VeevaActivity,
  VeevaActivityRegistration,
  VeevaMember,
  VeevaMemberReward,
  VeevaNews,
  VeevaReferralRecord,
  VeevaReward,
} from '../types/veeva'
import { shareCodeFromId } from '../utils/shareCode'

export async function loadBootstrap(): Promise<BootstrapData> {
  const [activitySnap, newsSnap, rewardSnap] = await Promise.all([
    getDocs(query(collection(firestore, 'activities'), limit(60))),
    getDocs(query(collection(firestore, 'news'), limit(60))),
    getDocs(query(collection(firestore, 'rewards'), limit(80))),
  ])

  return {
    activities: activitySnap.docs.map((item) =>
      activityFromData(item.id, item.data()),
    ),
    news: newsSnap.docs.map((item) => newsFromData(item.id, item.data())),
    rewards: rewardSnap.docs.map((item) => rewardFromData(item.id, item.data())),
  }
}

export async function loadMember(memberId: string) {
  const memberDoc = await getDoc(doc(firestore, 'members', memberId))
  if (!memberDoc.exists()) return undefined
  return memberFromData(memberDoc.id, memberDoc.data())
}

export async function upsertLineMember(input: {
  profile: LiffProfile
  lineIdToken?: string
  referralCode?: string
}) {
  const existing = await loadMember(input.profile.userId)
  const token = input.lineIdToken?.trim()
  const shareCode = existing?.shareCode ?? shareCodeFromId(input.profile.userId)
  const memberRef = doc(firestore, 'members', input.profile.userId)

  const payload: Record<string, unknown> = {
    id: input.profile.userId,
    name: input.profile.displayName || existing?.name || 'LINE 會員',
    hospital: existing?.hospital ?? '',
    department: existing?.department ?? '',
    status: existing?.status ?? 'loggedIn',
    accountStatus: existing?.accountStatus ?? 'active',
    earnedCoupons: existing?.earnedCoupons ?? 0,
    invitedCount: existing?.invitedCount ?? 0,
    shareCode,
    lineUserId: input.profile.userId,
    avatarUrl: input.profile.pictureUrl ?? existing?.avatarUrl ?? null,
    email: input.profile.email ?? existing?.email ?? null,
    lineStatusMessage:
      input.profile.statusMessage ?? existing?.lineStatusMessage ?? null,
    lastLineLoginAt: serverTimestamp(),
    lineLoginProvider: 'line',
    updatedAt: serverTimestamp(),
  }

  if (!existing?.createdAt) {
    payload.createdAt = serverTimestamp()
  }
  if (token) {
    payload.lineIdToken = token
    payload.lineIdTokenUpdatedAt = serverTimestamp()
  }

  await setDoc(memberRef, payload, { merge: true })
  const updatedMember =
    (await loadMember(input.profile.userId)) ??
    ({
      id: input.profile.userId,
      name: input.profile.displayName,
      hospital: '',
      department: '',
      status: 'loggedIn',
      accountStatus: 'active',
      earnedCoupons: 0,
      invitedCount: existing?.invitedCount ?? 0,
      shareCode,
      lineUserId: input.profile.userId,
      avatarUrl: input.profile.pictureUrl,
      email: input.profile.email,
    } satisfies VeevaMember)

  if (input.referralCode) {
    await createReferralIfNeeded(updatedMember, input.referralCode)
  }

  return (await loadMember(input.profile.userId)) ?? updatedMember
}

export async function loadMemberRewards(memberId: string) {
  const rewardsSnap = await getDocs(
    query(
      collection(firestore, 'memberRewards'),
      where('memberId', '==', memberId),
      limit(50),
    ),
  )
  return rewardsSnap.docs.map((item) => memberRewardFromData(item.id, item.data()))
}

export async function loadReferralRecords(memberId: string) {
  const referralSnap = await getDocs(
    query(
      collection(firestore, 'referrals'),
      where('referrerMemberId', '==', memberId),
      limit(50),
    ),
  )
  return referralSnap.docs.map((item) => referralFromData(item.id, item.data()))
}

export async function loadMemberActivityRecords(memberId: string) {
  const [registrationSnap, completionSnap] = await Promise.all([
    getDocs(
      query(
        collection(firestore, 'activityRegistrations'),
        where('memberId', '==', memberId),
        limit(100),
      ),
    ),
    getDocs(
      query(
        collection(firestore, 'activityCompletions'),
        where('memberId', '==', memberId),
        limit(100),
      ),
    ),
  ])

  const records = [
    ...registrationSnap.docs.map((item) =>
      activityRecordFromData(item.id, item.data(), 'registered'),
    ),
    ...completionSnap.docs.map((item) =>
      activityRecordFromData(item.id, item.data(), 'completed'),
    ),
  ]

  return records.reduce<VeevaActivityRegistration[]>((unique, record) => {
    const existingIndex = unique.findIndex(
      (item) => item.activityId === record.activityId,
    )
    if (existingIndex === -1) {
      unique.push(record)
      return unique
    }
    if (record.status === 'completed') {
      unique[existingIndex] = record
    }
    return unique
  }, [])
}

export async function registerActivity(input: {
  activity: VeevaActivity
  member: VeevaMember
}) {
  const registrationId = `${input.activity.id}_${input.member.id}`
  const registrationRef = doc(
    firestore,
    'activityRegistrations',
    registrationId,
  )
  await setDoc(
    registrationRef,
    {
      activityId: input.activity.id,
      activityTitle: input.activity.title,
      activityType: input.activity.type,
      memberId: input.member.id,
      memberName: input.member.name,
      memberAvatarUrl: input.member.avatarUrl ?? null,
      memberLineUserId: input.member.lineUserId ?? input.member.id,
      status: 'registered',
      registeredAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
    { merge: true },
  )
}

async function createReferralIfNeeded(member: VeevaMember, referralCode: string) {
  if (member.referredByMemberId || member.referredByShareCode) {
    return
  }
  if (member.shareCode.toUpperCase() === referralCode.toUpperCase()) {
    return
  }

  const referrerSnap = await getDocs(
    query(
      collection(firestore, 'members'),
      where('shareCode', '==', referralCode.toUpperCase()),
      limit(1),
    ),
  )
  const referrerDoc = referrerSnap.docs[0]
  if (!referrerDoc || referrerDoc.id === member.id) {
    return
  }

  const referrer = memberFromData(referrerDoc.id, referrerDoc.data())
  const referralId = `${referrer.id}_${member.id}`
  const referralRef = doc(firestore, 'referrals', referralId)
  const existingReferral = await getDoc(referralRef)
  if (existingReferral.exists()) {
    return
  }

  const batch = writeBatch(firestore)
  batch.set(
    referralRef,
    {
      referrerMemberId: referrer.id,
      referredMemberId: member.id,
      referrerShareCode: referrer.shareCode,
      referredName: member.name,
      referredAvatarUrl: member.avatarUrl ?? null,
      createdAt: serverTimestamp(),
    },
    { merge: true },
  )
  batch.set(
    doc(firestore, 'members', member.id),
    {
      referredByMemberId: referrer.id,
      referredByShareCode: referrer.shareCode,
      referredAt: serverTimestamp(),
    },
    { merge: true },
  )
  batch.set(
    doc(firestore, 'members', referrer.id),
    {
      invitedCount: increment(1),
      updatedAt: serverTimestamp(),
    },
    { merge: true },
  )
  await batch.commit()
}

function memberFromData(id: string, data: Record<string, unknown>): VeevaMember {
  return {
    id,
    name: stringValue(data.name, 'LINE 會員'),
    hospital: stringValue(data.hospital),
    department: stringValue(data.department),
    status: enumValue(data.status, 'loggedIn'),
    accountStatus: enumValue(data.accountStatus, 'active'),
    earnedCoupons: numberValue(data.earnedCoupons),
    invitedCount: numberValue(data.invitedCount),
    shareCode: stringValue(data.shareCode, shareCodeFromId(id)),
    lineUserId: optionalString(data.lineUserId),
    avatarUrl: optionalString(data.avatarUrl),
    email: optionalString(data.email),
    lineStatusMessage: optionalString(data.lineStatusMessage),
    lineIdToken: optionalString(data.lineIdToken),
    lineIdTokenUpdatedAt: dateValue(data.lineIdTokenUpdatedAt),
    createdAt: dateValue(data.createdAt),
    lastLineLoginAt: dateValue(data.lastLineLoginAt),
    referredByMemberId: optionalString(data.referredByMemberId),
    referredByShareCode: optionalString(data.referredByShareCode),
    referredAt: dateValue(data.referredAt),
    isAdmin: data.isAdmin === true,
    adminRole: optionalString(data.adminRole),
  }
}

function activityFromData(
  id: string,
  data: Record<string, unknown>,
): VeevaActivity {
  return {
    id,
    type: enumValue<VeevaActivity['type']>(data.type, 'survey'),
    label: stringValue(data.label, '活動'),
    title: stringValue(data.title, '未命名活動'),
    description: stringValue(data.description),
    reward: stringValue(data.reward, '會員獎勵'),
    rewardId: optionalString(data.rewardId),
    status: enumValue(data.status, 'published'),
    active: data.active === true,
    periodText: optionalString(data.periodText),
    note: optionalString(data.note),
    imageUrl: optionalString(data.imageUrl),
    surveyUrl: optionalString(data.surveyUrl),
    actionUrl: optionalString(data.actionUrl),
    location: optionalString(data.location),
  }
}

function newsFromData(id: string, data: Record<string, unknown>): VeevaNews {
  return {
    id,
    date: stringValue(data.date),
    source: stringValue(data.source, 'Veeva'),
    title: stringValue(data.title, '未命名文章'),
    summary: stringValue(data.summary),
    status: enumValue(data.status, 'published'),
    category: optionalString(data.category),
    imageUrl: optionalString(data.imageUrl),
    content: optionalString(data.content),
    detailContent: optionalString(data.detailContent),
    keyPoints: stringListValue(data.keyPoints),
    externalUrl: optionalString(data.externalUrl),
    helpfulCount: numberValue(data.helpfulCount, 12),
  }
}

function rewardFromData(id: string, data: Record<string, unknown>): VeevaReward {
  return {
    id,
    name: stringValue(data.name, '兌換券'),
    category: stringValue(data.category, '其他'),
    stock: numberValue(data.stock),
    issued: numberValue(data.issued),
    redeemed: numberValue(data.redeemed),
    status: enumValue(data.status, 'active'),
    expiresAt: dateValue(data.expiresAt),
    imageUrl: optionalString(data.imageUrl),
    description: optionalString(data.description),
  }
}

function memberRewardFromData(
  id: string,
  data: Record<string, unknown>,
): VeevaMemberReward {
  return {
    id,
    memberId: stringValue(data.memberId),
    rewardId: stringValue(data.rewardId),
    rewardName: stringValue(data.rewardName, '兌換券'),
    rewardImageUrl:
      optionalString(data.rewardImageUrl) ?? optionalString(data.imageUrl),
    status: enumValue(data.status, 'issued'),
    issuedAt: dateValue(data.issuedAt),
    redeemedAt: dateValue(data.redeemedAt),
    expiresAt: dateValue(data.expiresAt),
  }
}

function referralFromData(
  id: string,
  data: Record<string, unknown>,
): VeevaReferralRecord {
  return {
    id,
    referrerMemberId: stringValue(data.referrerMemberId),
    referredMemberId: stringValue(data.referredMemberId),
    referrerShareCode: stringValue(data.referrerShareCode),
    referredName: stringValue(data.referredName, 'LINE 會員'),
    referredAvatarUrl: optionalString(data.referredAvatarUrl),
    createdAt: dateValue(data.createdAt),
  }
}

function activityRecordFromData(
  id: string,
  data: Record<string, unknown>,
  fallbackStatus: VeevaActivityRegistration['status'],
): VeevaActivityRegistration {
  return {
    id,
    activityId: stringValue(data.activityId),
    activityTitle: stringValue(data.activityTitle, '未命名活動'),
    memberId: stringValue(data.memberId),
    memberName: stringValue(data.memberName, 'LINE 會員'),
    status: enumValue<VeevaActivityRegistration['status']>(
      data.status,
      fallbackStatus,
    ),
    registeredAt: dateValue(data.registeredAt),
    completedAt: dateValue(data.completedAt),
  }
}

function stringValue(value: unknown, fallback = '') {
  if (typeof value === 'string') return value
  if (typeof value === 'number') return String(value)
  return fallback
}

function optionalString(value: unknown) {
  const text = stringValue(value).trim()
  return text || undefined
}

function numberValue(value: unknown, fallback = 0) {
  if (typeof value === 'number') return value
  if (typeof value === 'string') return Number.parseInt(value, 10) || fallback
  return fallback
}

function stringListValue(value: unknown) {
  if (Array.isArray(value)) {
    return value
      .map((item) => stringValue(item).trim())
      .filter(Boolean)
  }
  if (typeof value === 'string') {
    return value
      .split(/\r?\n/)
      .map((item) => item.trim())
      .filter(Boolean)
  }
  return []
}

function enumValue<T extends string>(value: unknown, fallback: T) {
  return typeof value === 'string' && value ? (value as T) : fallback
}

function dateValue(value: unknown) {
  if (value instanceof Date) return value
  if (value instanceof Timestamp) return value.toDate()
  if (typeof value === 'string') return new Date(value)
  return undefined
}
