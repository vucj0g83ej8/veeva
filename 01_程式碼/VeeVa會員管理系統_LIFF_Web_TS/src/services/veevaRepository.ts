import {
  collection,
  doc,
  getDoc,
  getDocs,
  increment,
  limit,
  onSnapshot,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  where,
  writeBatch,
} from "firebase/firestore";
import { firestore } from "./firebase";
import type {
  BootstrapData,
  LiffProfile,
  VeevaActivity,
  VeevaActivityRegistration,
  VeevaEmployeeActivityLink,
  VeevaMember,
  VeevaMemberNotification,
  VeevaMemberReward,
  VeevaNews,
  VeevaReferralRecord,
  VeevaReward,
  VeevaSurveyEngagement,
} from "../types/veeva";
import { shareCodeFromId } from "../utils/shareCode";

const employeeQrSessionKey = "veeva_employee_qr_session_id";
const pendingEmployeeQrAttributionKey = "veeva_pending_employee_qr_attribution";

type RewardIssueSource =
  | "manualAdmin"
  | "activityCompletion"
  | "referralActivityCompletion";

interface RewardQueueResult {
  queued: boolean;
  reason?: "alreadyQueued" | "missingReward";
}

export async function loadBootstrap(): Promise<BootstrapData> {
  const [activitySnap, newsSnap, rewardSnap, clientSettingsSnap] =
    await Promise.all([
      getDocs(query(collection(firestore, "activities"), limit(60))),
      getDocs(query(collection(firestore, "news"), limit(60))),
      getDocs(query(collection(firestore, "rewards"), limit(80))),
      getDoc(doc(firestore, "systemSettings", "clientApp")),
    ]);

  return {
    activities: activitySnap.docs.map((item) =>
      activityFromData(item.id, item.data()),
    ),
    news: newsSnap.docs.map((item) => newsFromData(item.id, item.data())),
    rewards: rewardSnap.docs.map((item) =>
      rewardFromData(item.id, item.data()),
    ),
    clientSettings: clientSettingsFromData(clientSettingsSnap.data() ?? {}),
  };
}

export function subscribeActivities(
  onActivities: (activities: VeevaActivity[]) => void,
  onError?: (error: Error) => void,
) {
  return onSnapshot(
    query(collection(firestore, "activities"), limit(80)),
    (snapshot) => {
      onActivities(
        snapshot.docs.map((item) => activityFromData(item.id, item.data())),
      );
    },
    (error) => onError?.(error),
  );
}

export async function loadMember(memberId: string) {
  const memberDoc = await getDoc(doc(firestore, "members", memberId));
  if (!memberDoc.exists()) return undefined;
  return memberFromData(memberDoc.id, memberDoc.data());
}

export async function upsertLineMember(input: {
  profile: LiffProfile;
  lineIdToken?: string;
  referralCode?: string;
}) {
  const existing = await loadMember(input.profile.userId);
  const token = input.lineIdToken?.trim();
  const shareCode =
    existing?.shareCode ?? shareCodeFromId(input.profile.userId);
  const memberRef = doc(firestore, "members", input.profile.userId);

  const payload: Record<string, unknown> = {
    id: input.profile.userId,
    name: input.profile.displayName || existing?.name || "LINE 會員",
    hospital: existing?.hospital ?? "",
    department: existing?.department ?? "",
    status: existing?.status ?? "loggedIn",
    accountStatus: existing?.accountStatus ?? "active",
    earnedCoupons: existing?.earnedCoupons ?? 0,
    invitedCount: existing?.invitedCount ?? 0,
    shareCode,
    lineUserId: input.profile.userId,
    avatarUrl: input.profile.pictureUrl ?? existing?.avatarUrl ?? null,
    email: input.profile.email ?? existing?.email ?? null,
    lineStatusMessage:
      input.profile.statusMessage ?? existing?.lineStatusMessage ?? null,
    lastLineLoginAt: serverTimestamp(),
    lineLoginProvider: "line",
    updatedAt: serverTimestamp(),
  };

  if (!existing?.createdAt) {
    payload.createdAt = serverTimestamp();
  }
  if (token) {
    payload.lineIdToken = token;
    payload.lineIdTokenUpdatedAt = serverTimestamp();
  }

  await setDoc(memberRef, payload, { merge: true });
  const updatedMember =
    (await loadMember(input.profile.userId)) ??
    ({
      id: input.profile.userId,
      name: input.profile.displayName,
      hospital: "",
      department: "",
      status: "loggedIn",
      accountStatus: "active",
      earnedCoupons: 0,
      invitedCount: existing?.invitedCount ?? 0,
      shareCode,
      lineUserId: input.profile.userId,
      avatarUrl: input.profile.pictureUrl,
      email: input.profile.email,
    } satisfies VeevaMember);

  if (input.referralCode) {
    await createReferralIfNeeded(updatedMember, input.referralCode);
  }

  await bindPendingEmployeeQrAttribution(updatedMember, "registered").catch(
    () => undefined,
  );

  return (await loadMember(input.profile.userId)) ?? updatedMember;
}

export async function updateMemberProfile(input: {
  memberId: string;
  name: string;
  email: string;
}) {
  const name = input.name.trim();
  const email = input.email.trim();
  if (!name) {
    throw new Error("請輸入姓名");
  }

  await setDoc(
    doc(firestore, "members", input.memberId),
    {
      name,
      email: email || null,
      updatedAt: serverTimestamp(),
    },
    { merge: true },
  );

  const updatedMember = await loadMember(input.memberId);
  if (!updatedMember) {
    throw new Error("會員資料更新失敗");
  }
  return updatedMember;
}

export async function updateMemberPhoneVerification(input: {
  memberId: string;
  phoneNumber: string;
  firebasePhoneUid: string;
}) {
  await setDoc(
    doc(firestore, "members", input.memberId),
    {
      phoneNumber: input.phoneNumber,
      phoneVerified: true,
      phoneVerifiedAt: serverTimestamp(),
      firebasePhoneUid: input.firebasePhoneUid,
      updatedAt: serverTimestamp(),
    },
    { merge: true },
  );

  const updatedMember = await loadMember(input.memberId);
  if (!updatedMember) {
    throw new Error("手機驗證資料更新失敗");
  }
  await bindPendingEmployeeQrAttribution(
    updatedMember,
    "phoneVerified",
  ).catch(() => undefined);
  return updatedMember;
}

export async function loadEmployeeActivityLink(code: string) {
  const normalizedCode = normalizeEmployeeQrCode(code);
  if (!normalizedCode) return undefined;
  const linkDoc = await getDoc(
    doc(firestore, "employeeActivityLinks", normalizedCode),
  );
  if (!linkDoc.exists()) return undefined;
  return employeeActivityLinkFromData(linkDoc.id, linkDoc.data());
}

export async function recordEmployeeQrVisit(code: string) {
  const link = await loadEmployeeActivityLink(code);
  if (!link || link.status !== "active") {
    throw new Error("此員工 QR Code 尚未啟用");
  }
  const visitSessionId = employeeQrVisitSessionId(link.code);
  const visitRef = doc(firestore, "employeeQrVisits", visitSessionId);
  const linkRef = doc(firestore, "employeeActivityLinks", link.code);

  await runTransaction(firestore, async (transaction) => {
    const visitSnap = await transaction.get(visitRef);
    if (!visitSnap.exists()) {
      transaction.set(visitRef, {
        linkId: link.code,
        code: link.code,
        employeeMemberId: link.employeeMemberId,
        employeeName: link.employeeName,
        activityId: link.activityId,
        activityTitle: link.activityTitle,
        sessionId: employeeQrSessionId(),
        firstVisitedAt: serverTimestamp(),
        createdAt: serverTimestamp(),
      });
      transaction.set(
        linkRef,
        {
          visitCount: increment(1),
          lastVisitedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    } else {
      transaction.set(
        visitRef,
        {
          lastVisitedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
      transaction.set(
        linkRef,
        {
          lastVisitedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    }
  });

  storePendingEmployeeQrAttribution({
    code: link.code,
    activityId: link.activityId,
    employeeMemberId: link.employeeMemberId,
    visitSessionId,
    storedAt: new Date().toISOString(),
  });
  return link;
}

export async function bindPendingEmployeeQrAttribution(
  member: VeevaMember,
  stage: "registered" | "phoneVerified" = "registered",
) {
  const pending = readPendingEmployeeQrAttribution();
  if (!pending) return;
  const link = await loadEmployeeActivityLink(pending.code);
  if (!link || link.status !== "active") {
    clearPendingEmployeeQrAttribution();
    return;
  }

  const attributionId = firestoreDocumentId([
    member.id,
    link.activityId,
    "employeeQr",
  ]);
  const attributionRef = doc(
    firestore,
    "memberEmployeeAttributions",
    attributionId,
  );
  const visitRef = doc(firestore, "employeeQrVisits", pending.visitSessionId);
  const memberRef = doc(firestore, "members", member.id);
  const linkRef = doc(firestore, "employeeActivityLinks", link.code);

  await runTransaction(firestore, async (transaction) => {
    const attributionSnap = await transaction.get(attributionRef);
    const attributionData = attributionSnap.data();
    const alreadyRegistered = attributionData?.registeredAt;
    const alreadyPhoneVerified = attributionData?.phoneVerifiedAt;

    if (!attributionSnap.exists()) {
      transaction.set(attributionRef, {
        memberId: member.id,
        memberName: member.name,
        memberLineUserId: member.lineUserId ?? member.id,
        memberAvatarUrl: member.avatarUrl ?? null,
        employeeLinkId: link.code,
        employeeMemberId: link.employeeMemberId,
        employeeName: link.employeeName,
        activityId: link.activityId,
        activityTitle: link.activityTitle,
        source: "employeeQr",
        visitSessionId: pending.visitSessionId,
        registeredAt: serverTimestamp(),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      transaction.set(
        linkRef,
        {
          registeredCount: increment(1),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    } else if (!alreadyRegistered) {
      transaction.set(
        attributionRef,
        {
          registeredAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
      transaction.set(
        linkRef,
        {
          registeredCount: increment(1),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    }

    if (stage === "phoneVerified" && !alreadyPhoneVerified) {
      transaction.set(
        attributionRef,
        {
          phoneVerifiedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
      transaction.set(
        linkRef,
        {
          phoneVerifiedCount: increment(1),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    }

    transaction.set(
      visitRef,
      {
        memberId: member.id,
        memberName: member.name,
        memberLineUserId: member.lineUserId ?? member.id,
        phoneVerified: stage === "phoneVerified" || member.phoneVerified === true,
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
    transaction.set(
      memberRef,
      {
        employeeQrAttribution: {
          employeeLinkId: link.code,
          employeeMemberId: link.employeeMemberId,
          activityId: link.activityId,
          source: "employeeQr",
        },
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
  });

  if (stage === "phoneVerified") {
    clearPendingEmployeeQrAttribution();
  }
}

export async function hasMemberMarkedNewsHelpful(input: {
  newsId: string;
  memberId: string;
}) {
  const voteId = firestoreDocumentId([input.newsId, input.memberId]);
  const voteSnap = await getDoc(doc(firestore, "newsHelpfulVotes", voteId));
  return voteSnap.exists();
}

export async function markNewsHelpful(input: {
  news: VeevaNews;
  member: VeevaMember;
}) {
  const voteId = firestoreDocumentId([input.news.id, input.member.id]);
  const voteRef = doc(firestore, "newsHelpfulVotes", voteId);
  const newsRef = doc(firestore, "news", input.news.id);
  let helpfulCount = input.news.helpfulCount ?? 0;
  let liked = false;

  await runTransaction(firestore, async (transaction) => {
    const [voteSnap, newsSnap] = await Promise.all([
      transaction.get(voteRef),
      transaction.get(newsRef),
    ]);
    const currentCount = numberValue(
      newsSnap.data()?.helpfulCount,
      input.news.helpfulCount ?? 0,
    );

    if (voteSnap.exists()) {
      helpfulCount = currentCount;
      liked = true;
      return;
    }

    transaction.set(voteRef, {
      newsId: input.news.id,
      newsTitle: input.news.title,
      memberId: input.member.id,
      memberName: input.member.name,
      memberAvatarUrl: input.member.avatarUrl ?? null,
      memberLineUserId: input.member.lineUserId ?? input.member.id,
      createdAt: serverTimestamp(),
    });
    transaction.set(
      newsRef,
      {
        helpfulCount: increment(1),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );

    helpfulCount = currentCount + 1;
    liked = true;
  });

  return { helpfulCount, liked };
}

export async function loadMemberRewards(memberId: string) {
  const rewardsSnap = await getDocs(
    query(
      collection(firestore, "memberRewards"),
      where("memberId", "==", memberId),
      limit(50),
    ),
  );
  return rewardsSnap.docs
    .map((item) => memberRewardFromData(item.id, item.data()))
    .filter((item) => item.status !== "rejected");
}

export async function loadMemberNotifications(memberId: string) {
  const notificationSnap = await getDocs(
    query(
      collection(firestore, "memberNotifications"),
      where("memberId", "==", memberId),
      limit(60),
    ),
  );
  return notificationSnap.docs
    .map((item) => memberNotificationFromData(item.id, item.data()))
    .sort((a, b) => {
      const aTime = a.createdAt?.getTime() ?? 0;
      const bTime = b.createdAt?.getTime() ?? 0;
      return bTime - aTime;
    });
}

export async function markMemberNotificationsRead(input: {
  memberId: string;
  notificationIds: string[];
}) {
  const uniqueIds = [...new Set(input.notificationIds)].filter(Boolean);
  if (uniqueIds.length === 0) return;
  const batch = writeBatch(firestore);
  for (const notificationId of uniqueIds) {
    batch.set(
      doc(firestore, "memberNotifications", notificationId),
      {
        memberId: input.memberId,
        readAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
  }
  await batch.commit();
}

export async function redeemMemberReward(input: {
  memberRewardId: string;
  memberId: string;
}) {
  const memberRewardRef = doc(firestore, "memberRewards", input.memberRewardId);
  await runTransaction(firestore, async (transaction) => {
    const rewardSnapshot = await transaction.get(memberRewardRef);
    const rewardData = rewardSnapshot.data();
    if (!rewardSnapshot.exists() || !rewardData) {
      throw new Error("找不到兌換券");
    }
    if (rewardData.memberId !== input.memberId) {
      throw new Error("兌換券不屬於目前會員");
    }
    if (rewardData.status === "redeemed") {
      return;
    }
    if (rewardData.status !== "issued") {
      throw new Error("此兌換券目前無法使用");
    }

    transaction.set(
      memberRewardRef,
      {
        status: "redeemed",
        redeemedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );

    const rewardId = optionalString(rewardData.rewardId);
    if (rewardId) {
      transaction.set(
        doc(firestore, "rewards", rewardId),
        {
          redeemed: increment(1),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    }
  });

  const updatedSnapshot = await getDoc(memberRewardRef);
  const updatedData = updatedSnapshot.data();
  if (!updatedSnapshot.exists() || !updatedData) {
    throw new Error("兌換券狀態更新失敗");
  }
  return memberRewardFromData(updatedSnapshot.id, updatedData);
}

export async function loadReferralRecords(memberId: string) {
  const referralCollection = collection(firestore, "referrals");
  const [currentSnap, legacySnap] = await Promise.all([
    getDocs(
      query(
        referralCollection,
        where("referrerMemberId", "==", memberId),
        limit(50),
      ),
    ),
    getDocs(
      query(
        referralCollection,
        where("inviterMemberId", "==", memberId),
        limit(50),
      ),
    ),
  ]);
  const byId = new Map<string, VeevaReferralRecord>();
  for (const item of [...currentSnap.docs, ...legacySnap.docs]) {
    byId.set(item.id, referralFromData(item.id, item.data()));
  }
  return [...byId.values()].sort((a, b) => {
    const aTime = a.createdAt?.getTime() ?? 0;
    const bTime = b.createdAt?.getTime() ?? 0;
    return bTime - aTime;
  });
}

export async function loadMemberActivityRecords(memberId: string) {
  const [registrationSnap, completionSnap] = await Promise.all([
    getDocs(
      query(
        collection(firestore, "activityRegistrations"),
        where("memberId", "==", memberId),
        limit(100),
      ),
    ),
    getDocs(
      query(
        collection(firestore, "activityCompletions"),
        where("memberId", "==", memberId),
        limit(100),
      ),
    ),
  ]);

  const records = [
    ...registrationSnap.docs.map((item) =>
      activityRecordFromData(item.id, item.data(), "registered"),
    ),
    ...completionSnap.docs.map((item) =>
      activityRecordFromData(item.id, item.data(), "completed"),
    ),
  ];

  return records.reduce<VeevaActivityRegistration[]>((unique, record) => {
    const existingIndex = unique.findIndex(
      (item) => item.activityId === record.activityId,
    );
    if (existingIndex === -1) {
      unique.push(record);
      return unique;
    }
    if (
      activityRecordPriority(record) >= activityRecordPriority(unique[existingIndex])
    ) {
      unique[existingIndex] = record;
    }
    return unique;
  }, []);
}

export async function registerActivity(input: {
  activity: VeevaActivity;
  member: VeevaMember;
}) {
  const registrationId = `${input.activity.id}_${input.member.id}`;
  const registrationRef = doc(
    firestore,
    "activityRegistrations",
    registrationId,
  );
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
      status: "registered",
      registeredAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
    { merge: true },
  );

  await queueMemberRewardForActivityCompletion(input.activity, input.member);
  await queueReferrerRewardForActivityCompletion(input.activity, input.member);
}

export async function completeActivity(input: {
  activity: VeevaActivity;
  member: VeevaMember;
  completionMethod?: "behaviorScore" | "system";
  surveyEngagement?: VeevaSurveyEngagement;
}) {
  const completionId = firestoreDocumentId([
    input.member.id,
    input.activity.id,
  ]);
  const completionRef = doc(firestore, "activityCompletions", completionId);
  const notificationRef = doc(
    firestore,
    "memberNotifications",
    firestoreDocumentId([
      input.member.id,
      input.activity.id,
      "activity-completed",
    ]),
  );

  await runTransaction(firestore, async (transaction) => {
    const completionSnapshot = await transaction.get(completionRef);
    const completionData = completionSnapshot.data();
    const payload: Record<string, unknown> = {
      activityId: input.activity.id,
      activityTitle: input.activity.title,
      activityType: input.activity.type,
      memberId: input.member.id,
      memberName: input.member.name,
      memberAvatarUrl: input.member.avatarUrl ?? null,
      memberLineUserId: input.member.lineUserId ?? input.member.id,
      status: "pendingReview",
      surveyUrl: input.activity.surveyUrl ?? null,
      completionMethod: input.completionMethod ?? "system",
      updatedAt: serverTimestamp(),
    };

    if (input.surveyEngagement) {
      payload.surveyEngagement = input.surveyEngagement;
      payload.surveyEngagementScore = input.surveyEngagement.score;
      payload.completedByBehavior = input.surveyEngagement.completedByBehavior;
    }

    if (!completionSnapshot.exists() || !completionData?.completedAt) {
      payload.createdAt = serverTimestamp();
      payload.completedAt = serverTimestamp();
    }

    transaction.set(completionRef, payload, { merge: true });
    transaction.set(
      notificationRef,
      {
        memberId: input.member.id,
        memberName: input.member.name,
        memberLineUserId: input.member.lineUserId ?? input.member.id,
        type: "activityCompleted",
        title: "已收到活動完成紀錄",
        body: `你已完成「${input.activity.title}」的填寫，工作人員確認後會發放兌換券。`,
        activityId: input.activity.id,
        activityTitle: input.activity.title,
        actionPath: `/activities/${input.activity.id}`,
        readAt: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
  });

  const memberReward = await queueMemberRewardForActivityCompletion(
    input.activity,
    input.member,
  );
  const referrerReward = await queueReferrerRewardForActivityCompletion(
    input.activity,
    input.member,
  );

  return {
    completionId,
    memberRewardIssued: false,
    memberRewardReason: memberReward.reason,
    memberRewardQueued: memberReward.queued,
    referrerRewardIssued: false,
    referrerRewardReason: referrerReward.reason,
    referrerRewardQueued: referrerReward.queued,
  };
}

async function queueMemberRewardForActivityCompletion(
  activity: VeevaActivity,
  member: VeevaMember,
) {
  const rewardId = participantRewardIdFor(activity);
  if (!rewardId) {
    return {
      queued: false,
      reason: "missingReward",
    } satisfies RewardQueueResult;
  }

  return queuePendingMemberRewardIfNeeded({
    activity,
    member,
    rewardId,
    source: "activityCompletion",
  });
}

async function queueReferrerRewardForActivityCompletion(
  activity: VeevaActivity,
  completedBy: VeevaMember,
) {
  const rewardId = referrerRewardIdFor(activity);
  if (!rewardId) {
    return {
      queued: false,
      reason: "missingReward",
    } satisfies RewardQueueResult;
  }
  const inviteeRef = doc(firestore, "members", completedBy.id);
  const inviteeSnapshot = await getDoc(inviteeRef);
  const inviteeData = inviteeSnapshot.data();
  const invitee =
    inviteeSnapshot.exists() && inviteeData
      ? memberFromData(inviteeSnapshot.id, inviteeData)
      : completedBy;
  const referrerId = invitee.referredByMemberId?.trim();

  if (!referrerId) {
    return {
      queued: false,
      reason: "missingReward",
    } satisfies RewardQueueResult;
  }
  if (
    invitee.referralRewardGrantedAt ||
    invitee.referralRewardGrantedActivityId
  ) {
    return {
      queued: false,
      reason: "alreadyQueued",
    } satisfies RewardQueueResult;
  }

  const existingReferralRewardSnap = await getDocs(
    query(
      collection(firestore, "memberRewards"),
      where("sourceMemberId", "==", invitee.id),
      limit(20),
    ),
  );
  if (
    existingReferralRewardSnap.docs.some(
      (item) => item.data().source === "referralActivityCompletion",
    )
  ) {
    return {
      queued: false,
      reason: "alreadyQueued",
    } satisfies RewardQueueResult;
  }

  const referrer = await loadMember(referrerId);
  if (!referrer) {
    return {
      queued: false,
      reason: "missingReward",
    } satisfies RewardQueueResult;
  }

  return queuePendingMemberRewardIfNeeded({
    activity,
    member: referrer,
    rewardId,
    source: "referralActivityCompletion",
    sourceMember: invitee,
  });
}

async function queuePendingMemberRewardIfNeeded(input: {
  activity: VeevaActivity;
  member: VeevaMember;
  rewardId: string;
  source: RewardIssueSource;
  sourceMember?: VeevaMember;
}): Promise<RewardQueueResult> {
  const rewardId = input.rewardId.trim();
  if (!rewardId) {
    return { queued: false, reason: "missingReward" };
  }

  const rewardRef = doc(firestore, "rewards", rewardId);
  const grantRef = doc(
    firestore,
    "memberRewards",
    rewardGrantDocumentId({
      memberId: input.member.id,
      rewardId,
      activityId: input.activity.id,
      source: input.source,
      sourceMemberId: input.sourceMember?.id,
    }),
  );

  return runTransaction(firestore, async (transaction) => {
    const existingGrant = await transaction.get(grantRef);
    if (existingGrant.exists()) {
      const existingStatus = existingGrant.data()?.status;
      if (existingStatus !== "rejected") {
        return {
          queued: false,
          reason: "alreadyQueued",
        } satisfies RewardQueueResult;
      }
    }

    const rewardSnapshot = await transaction.get(rewardRef);
    const rewardData = rewardSnapshot.data();
    if (!rewardSnapshot.exists() || !rewardData) {
      return {
        queued: false,
        reason: "missingReward",
      } satisfies RewardQueueResult;
    }

    const reward = rewardFromData(rewardSnapshot.id, rewardData);
    transaction.set(grantRef, {
      memberId: input.member.id,
      memberName: input.member.name,
      memberLineUserId: input.member.lineUserId ?? input.member.id,
      rewardId: reward.id,
      rewardName: reward.name,
      rewardCategory: reward.category,
      rewardImageUrl: reward.imageUrl ?? null,
      redemptionUrl: null,
      voucherId: null,
      status: "pending",
      source: input.source,
      activityId: input.activity.id,
      activityTitle: input.activity.title,
      sourceMemberId: input.sourceMember?.id ?? null,
      sourceMemberName: input.sourceMember?.name ?? null,
      queuedAt: serverTimestamp(),
      expiresAt: reward.expiresAt ? Timestamp.fromDate(reward.expiresAt) : null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    return { queued: true } satisfies RewardQueueResult;
  });
}

async function createReferralIfNeeded(
  member: VeevaMember,
  referralCode: string,
) {
  if (member.referredByMemberId || member.referredByShareCode) {
    return;
  }
  if (member.shareCode.toUpperCase() === referralCode.toUpperCase()) {
    return;
  }

  const referrerSnap = await getDocs(
    query(
      collection(firestore, "members"),
      where("shareCode", "==", referralCode.toUpperCase()),
      limit(1),
    ),
  );
  const referrerDoc = referrerSnap.docs[0];
  if (!referrerDoc || referrerDoc.id === member.id) {
    return;
  }

  const referrer = memberFromData(referrerDoc.id, referrerDoc.data());
  const referralId = `${referrer.id}_${member.id}`;
  const referralRef = doc(firestore, "referrals", referralId);
  const memberRef = doc(firestore, "members", member.id);
  const referrerRef = doc(firestore, "members", referrer.id);

  await runTransaction(firestore, async (transaction) => {
    const [liveMemberSnapshot, existingReferral] = await Promise.all([
      transaction.get(memberRef),
      transaction.get(referralRef),
    ]);
    const liveMember = liveMemberSnapshot.data();
    if (
      existingReferral.exists() ||
      liveMember?.referredByMemberId ||
      liveMember?.referredByShareCode
    ) {
      return;
    }

    transaction.set(
      referralRef,
      {
        referrerMemberId: referrer.id,
        referredMemberId: member.id,
        referrerShareCode: referrer.shareCode,
        referredName: member.name,
        referredAvatarUrl: member.avatarUrl ?? null,
        inviterMemberId: referrer.id,
        inviteeMemberId: member.id,
        inviterShareCode: referrer.shareCode,
        inviteeLineUserId: member.lineUserId ?? member.id,
        inviteeName: member.name,
        inviteeAvatarUrl: member.avatarUrl ?? null,
        status: "linked",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
    transaction.set(
      memberRef,
      {
        referredByMemberId: referrer.id,
        referredByShareCode: referrer.shareCode,
        referredAt: serverTimestamp(),
      },
      { merge: true },
    );
    transaction.set(
      referrerRef,
      {
        invitedCount: increment(1),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
  });
}

function memberFromData(
  id: string,
  data: Record<string, unknown>,
): VeevaMember {
  return {
    id,
    name: stringValue(data.name, "LINE 會員"),
    hospital: stringValue(data.hospital),
    department: stringValue(data.department),
    status: enumValue(data.status, "loggedIn"),
    accountStatus: enumValue(data.accountStatus, "active"),
    earnedCoupons: numberValue(data.earnedCoupons),
    invitedCount: numberValue(data.invitedCount),
    shareCode: stringValue(data.shareCode, shareCodeFromId(id)),
    lineUserId: optionalString(data.lineUserId),
    avatarUrl: optionalString(data.avatarUrl),
    email: optionalString(data.email),
    phoneNumber: optionalString(data.phoneNumber),
    phoneVerified: data.phoneVerified === true,
    phoneVerifiedAt: dateValue(data.phoneVerifiedAt),
    firebasePhoneUid: optionalString(data.firebasePhoneUid),
    lineStatusMessage: optionalString(data.lineStatusMessage),
    lineIdToken: optionalString(data.lineIdToken),
    lineIdTokenUpdatedAt: dateValue(data.lineIdTokenUpdatedAt),
    createdAt: dateValue(data.createdAt),
    lastLineLoginAt: dateValue(data.lastLineLoginAt),
    referredByMemberId: optionalString(data.referredByMemberId),
    referredByShareCode: optionalString(data.referredByShareCode),
    referredAt: dateValue(data.referredAt),
    referralRewardGrantedActivityId: optionalString(
      data.referralRewardGrantedActivityId,
    ),
    referralRewardGrantedRewardId: optionalString(
      data.referralRewardGrantedRewardId,
    ),
    referralRewardGrantedReferrerId: optionalString(
      data.referralRewardGrantedReferrerId,
    ),
    referralRewardGrantedAt: dateValue(data.referralRewardGrantedAt),
    isAdmin: data.isAdmin === true,
    adminRole: optionalString(data.adminRole),
    isEmployee: data.isEmployee === true,
    employeeStatus: optionalString(data.employeeStatus),
    employeeCode: optionalString(data.employeeCode),
    employeeCreatedAt: dateValue(data.employeeCreatedAt),
  };
}

function employeeActivityLinkFromData(
  id: string,
  data: Record<string, unknown>,
): VeevaEmployeeActivityLink {
  return {
    id,
    code: stringValue(data.code, id),
    employeeMemberId: stringValue(data.employeeMemberId),
    employeeName: stringValue(data.employeeName, "員工"),
    employeeAvatarUrl: optionalString(data.employeeAvatarUrl),
    activityId: stringValue(data.activityId),
    activityTitle: stringValue(data.activityTitle, "活動"),
    url: stringValue(data.url),
    status: stringValue(data.status, "active"),
    visitCount: numberValue(data.visitCount),
    registeredCount: numberValue(data.registeredCount),
    phoneVerifiedCount: numberValue(data.phoneVerifiedCount),
    lastVisitedAt: dateValue(data.lastVisitedAt),
    createdAt: dateValue(data.createdAt),
    updatedAt: dateValue(data.updatedAt),
  };
}

function activityFromData(
  id: string,
  data: Record<string, unknown>,
): VeevaActivity {
  return {
    id,
    type: enumValue<VeevaActivity["type"]>(data.type, "survey"),
    label: stringValue(data.label, "活動"),
    title: stringValue(data.title, "未命名活動"),
    description: stringValue(data.description),
    reward: stringValue(data.reward, "會員獎勵"),
    rewardId: optionalString(data.rewardId),
    completionRewardId: optionalString(data.completionRewardId),
    participantRewardId: optionalString(data.participantRewardId),
    referrerRewardId: optionalString(data.referrerRewardId),
    status: enumValue(data.status, "published"),
    active: data.active === true,
    periodText: optionalString(data.periodText),
    note: optionalString(data.note),
    imageUrl: optionalString(data.imageUrl),
    shareImageUrl: optionalString(data.shareImageUrl),
    surveyUrl: optionalString(data.surveyUrl),
    actionUrl: optionalString(data.actionUrl),
    location: optionalString(data.location),
    activityTime: optionalString(data.activityTime),
    organizer: optionalString(data.organizer),
    noticeItems: stringListValue(data.noticeItems),
  };
}

function newsFromData(id: string, data: Record<string, unknown>): VeevaNews {
  return {
    id,
    date: stringValue(data.date),
    source: stringValue(data.source, "Veeva"),
    title: stringValue(data.title, "未命名文章"),
    summary: stringValue(data.summary),
    status: enumValue(data.status, "published"),
    category: optionalString(data.category),
    imageUrl: optionalString(data.imageUrl),
    content: optionalString(data.content),
    detailContent: optionalString(data.detailContent),
    keyPoints: stringListValue(data.keyPoints),
    externalUrl: optionalString(data.externalUrl),
    helpfulCount: numberValue(data.helpfulCount, 0),
  };
}

function rewardFromData(
  id: string,
  data: Record<string, unknown>,
): VeevaReward {
  return {
    id,
    name: stringValue(data.name, "兌換券"),
    category: stringValue(data.category, "其他"),
    stock: numberValue(data.stock),
    issued: numberValue(data.issued),
    redeemed: numberValue(data.redeemed),
    voucherTotal: numberValue(data.voucherTotal),
    voucherAvailable: numberValue(data.voucherAvailable),
    status: enumValue(data.status, "active"),
    expiresAt: dateValue(data.expiresAt),
    imageUrl: optionalString(data.imageUrl),
    description: optionalString(data.description),
  };
}

function clientSettingsFromData(data: Record<string, unknown>) {
  return {
    newsEnabled: data.newsEnabled !== false,
  };
}

function memberRewardFromData(
  id: string,
  data: Record<string, unknown>,
): VeevaMemberReward {
  return {
    id,
    memberId: stringValue(data.memberId),
    rewardId: stringValue(data.rewardId),
    rewardName: stringValue(data.rewardName, "兌換券"),
    rewardImageUrl:
      optionalString(data.rewardImageUrl) ?? optionalString(data.imageUrl),
    redemptionUrl: optionalString(data.redemptionUrl),
    voucherId: optionalString(data.voucherId),
    status: enumValue(data.status, "issued"),
    source: enumValue<NonNullable<VeevaMemberReward["source"]>>(
      data.source,
      "manualAdmin",
    ),
    activityId: optionalString(data.activityId),
    activityTitle: optionalString(data.activityTitle),
    sourceMemberId: optionalString(data.sourceMemberId),
    sourceMemberName: optionalString(data.sourceMemberName),
    issuedAt: dateValue(data.issuedAt),
    redeemedAt: dateValue(data.redeemedAt),
    expiresAt: dateValue(data.expiresAt),
  };
}

function memberNotificationFromData(
  id: string,
  data: Record<string, unknown>,
): VeevaMemberNotification {
  return {
    id,
    memberId: stringValue(data.memberId),
    title: stringValue(data.title, "系統訊息"),
    body: stringValue(data.body),
    type: enumValue<VeevaMemberNotification["type"]>(data.type, "system"),
    activityId: optionalString(data.activityId),
    activityTitle: optionalString(data.activityTitle),
    rewardId: optionalString(data.rewardId),
    rewardName: optionalString(data.rewardName),
    memberRewardId: optionalString(data.memberRewardId),
    actionPath: optionalString(data.actionPath),
    createdAt: dateValue(data.createdAt),
    readAt: dateValue(data.readAt),
  };
}

function referralFromData(
  id: string,
  data: Record<string, unknown>,
): VeevaReferralRecord {
  return {
    id,
    referrerMemberId: stringValue(
      data.referrerMemberId,
      stringValue(data.inviterMemberId),
    ),
    referredMemberId: stringValue(
      data.referredMemberId,
      stringValue(data.inviteeMemberId),
    ),
    referrerShareCode: stringValue(
      data.referrerShareCode,
      stringValue(data.inviterShareCode),
    ),
    referredName: stringValue(
      data.referredName,
      stringValue(data.inviteeName, "LINE 會員"),
    ),
    referredAvatarUrl:
      optionalString(data.referredAvatarUrl) ??
      optionalString(data.inviteeAvatarUrl),
    lastCompletedActivityId: optionalString(data.lastCompletedActivityId),
    lastCompletedActivityTitle: optionalString(data.lastCompletedActivityTitle),
    lastCompletedAt: dateValue(data.lastCompletedAt),
    rewardedActivityCount: numberValue(data.rewardedActivityCount),
    createdAt: dateValue(data.createdAt),
  };
}

function activityRecordFromData(
  id: string,
  data: Record<string, unknown>,
  fallbackStatus: VeevaActivityRegistration["status"],
): VeevaActivityRegistration {
  return {
    id,
    activityId: stringValue(data.activityId),
    activityTitle: stringValue(data.activityTitle, "未命名活動"),
    memberId: stringValue(data.memberId),
    memberName: stringValue(data.memberName, "LINE 會員"),
    status: enumValue<VeevaActivityRegistration["status"]>(
      data.status,
      fallbackStatus,
    ),
    registeredAt: dateValue(data.registeredAt),
    completedAt: dateValue(data.completedAt),
  };
}

function participantRewardIdFor(activity: VeevaActivity) {
  return activity.completionRewardId;
}

function activityRecordPriority(record: VeevaActivityRegistration) {
  if (record.status === "completed") return 4;
  if (record.status === "pendingReview") return 3;
  if (record.status === "rejected") return 2;
  if (record.status === "registered") return 1;
  return 0;
}

function referrerRewardIdFor(activity: VeevaActivity) {
  return activity.referrerRewardId;
}

function rewardGrantDocumentId(input: {
  memberId: string;
  rewardId: string;
  activityId: string;
  source: RewardIssueSource;
  sourceMemberId?: string;
}) {
  return firestoreDocumentId([
    input.memberId,
    input.rewardId,
    input.activityId,
    input.source,
    input.sourceMemberId ?? "self",
  ]);
}

function firestoreDocumentId(parts: string[]) {
  return parts.map(firestoreDocumentSegment).join("_");
}

function firestoreDocumentSegment(value: string) {
  const segment = value.trim().replace(/[/#?[\]]/g, "_");
  return segment || "unknown";
}

function normalizeEmployeeQrCode(code: string) {
  return code.replace(/[^a-zA-Z0-9_-]/g, "").trim();
}

function employeeQrSessionId() {
  try {
    const existing = window.localStorage.getItem(employeeQrSessionKey);
    if (existing) return existing;
    const sessionId = `eqr-${Date.now()}-${Math.random()
      .toString(36)
      .slice(2, 10)}`;
    window.localStorage.setItem(employeeQrSessionKey, sessionId);
    return sessionId;
  } catch {
    return `eqr-${Date.now()}`;
  }
}

function employeeQrVisitSessionId(code: string) {
  return firestoreDocumentId([code, employeeQrSessionId()]);
}

interface PendingEmployeeQrAttribution {
  code: string;
  activityId: string;
  employeeMemberId: string;
  visitSessionId: string;
  storedAt: string;
}

function storePendingEmployeeQrAttribution(input: PendingEmployeeQrAttribution) {
  try {
    window.localStorage.setItem(
      pendingEmployeeQrAttributionKey,
      JSON.stringify(input),
    );
  } catch {
    return;
  }
}

function readPendingEmployeeQrAttribution() {
  try {
    const raw = window.localStorage.getItem(pendingEmployeeQrAttributionKey);
    if (!raw) return undefined;
    const parsed = JSON.parse(raw) as PendingEmployeeQrAttribution;
    if (!parsed.code || !parsed.visitSessionId) return undefined;
    const storedAt = new Date(parsed.storedAt).getTime();
    if (!Number.isFinite(storedAt) || Date.now() - storedAt > 7 * 24 * 60 * 60 * 1000) {
      clearPendingEmployeeQrAttribution();
      return undefined;
    }
    return parsed;
  } catch {
    clearPendingEmployeeQrAttribution();
    return undefined;
  }
}

function clearPendingEmployeeQrAttribution() {
  try {
    window.localStorage.removeItem(pendingEmployeeQrAttributionKey);
  } catch {
    return;
  }
}

function stringValue(value: unknown, fallback = "") {
  if (typeof value === "string") return value;
  if (typeof value === "number") return String(value);
  return fallback;
}

function optionalString(value: unknown) {
  const text = stringValue(value).trim();
  return text || undefined;
}

function numberValue(value: unknown, fallback = 0) {
  if (typeof value === "number") return value;
  if (typeof value === "string") return Number.parseInt(value, 10) || fallback;
  return fallback;
}

function stringListValue(value: unknown) {
  if (Array.isArray(value)) {
    return value.map((item) => stringValue(item).trim()).filter(Boolean);
  }
  if (typeof value === "string") {
    return value
      .split(/\r?\n/)
      .map((item) => item.trim())
      .filter(Boolean);
  }
  return [];
}

function enumValue<T extends string>(value: unknown, fallback: T) {
  return typeof value === "string" && value ? (value as T) : fallback;
}

function dateValue(value: unknown) {
  if (value instanceof Date) return value;
  if (value instanceof Timestamp) return value.toDate();
  if (typeof value === "string") return new Date(value);
  return undefined;
}
