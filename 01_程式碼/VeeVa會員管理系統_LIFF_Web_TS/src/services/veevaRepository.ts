import {
  collection,
  doc,
  type DocumentReference,
  getDoc,
  getDocs,
  increment,
  limit,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  where,
} from "firebase/firestore";
import { firestore } from "./firebase";
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
} from "../types/veeva";
import { shareCodeFromId } from "../utils/shareCode";

type RewardIssueSource =
  | "manualAdmin"
  | "activityCompletion"
  | "referralActivityCompletion";

interface RewardIssueResult {
  issued: boolean;
  reason?:
    | "alreadyIssued"
    | "missingReward"
    | "inactiveReward"
    | "expiredReward"
    | "outOfStock";
}

interface VoucherAllocation {
  id: string;
  url: string;
  ref: DocumentReference;
}

export async function loadBootstrap(): Promise<BootstrapData> {
  const [activitySnap, newsSnap, rewardSnap] = await Promise.all([
    getDocs(query(collection(firestore, "activities"), limit(60))),
    getDocs(query(collection(firestore, "news"), limit(60))),
    getDocs(query(collection(firestore, "rewards"), limit(80))),
  ]);

  return {
    activities: activitySnap.docs.map((item) =>
      activityFromData(item.id, item.data()),
    ),
    news: newsSnap.docs.map((item) => newsFromData(item.id, item.data())),
    rewards: rewardSnap.docs.map((item) =>
      rewardFromData(item.id, item.data()),
    ),
  };
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

export async function loadMemberRewards(memberId: string) {
  const rewardsSnap = await getDocs(
    query(
      collection(firestore, "memberRewards"),
      where("memberId", "==", memberId),
      limit(50),
    ),
  );
  return rewardsSnap.docs.map((item) =>
    memberRewardFromData(item.id, item.data()),
  );
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
    if (record.status === "completed") {
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
}

export async function completeActivity(input: {
  activity: VeevaActivity;
  member: VeevaMember;
}) {
  const completionId = firestoreDocumentId([
    input.member.id,
    input.activity.id,
  ]);
  const completionRef = doc(firestore, "activityCompletions", completionId);

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
      status: "completed",
      surveyUrl: input.activity.surveyUrl ?? null,
      updatedAt: serverTimestamp(),
    };

    if (!completionSnapshot.exists() || !completionData?.completedAt) {
      payload.createdAt = serverTimestamp();
      payload.completedAt = serverTimestamp();
    }

    transaction.set(completionRef, payload, { merge: true });
  });

  const memberReward = await issueMemberRewardForActivityCompletion(
    input.activity,
    input.member,
  );
  const referrerReward = await issueReferrerRewardForActivityCompletion(
    input.activity,
    input.member,
  );

  return {
    completionId,
    memberRewardIssued: memberReward.issued,
    memberRewardReason: memberReward.reason,
    referrerRewardIssued: referrerReward.issued,
    referrerRewardReason: referrerReward.reason,
  };
}

async function issueMemberRewardForActivityCompletion(
  activity: VeevaActivity,
  member: VeevaMember,
) {
  const rewardId = participantRewardIdFor(activity);
  if (!rewardId) {
    return {
      issued: false,
      reason: "missingReward",
    } satisfies RewardIssueResult;
  }

  return issueMemberRewardIfNeeded({
    activity,
    member,
    rewardId,
    source: "activityCompletion",
  });
}

async function issueReferrerRewardForActivityCompletion(
  activity: VeevaActivity,
  completedBy: VeevaMember,
) {
  const rewardId = referrerRewardIdFor(activity);
  if (!rewardId) {
    return {
      issued: false,
      reason: "missingReward",
    } satisfies RewardIssueResult;
  }
  const inviteeRef = doc(firestore, "members", completedBy.id);
  const voucherCandidate = await findAvailableVoucherForReward(rewardId);

  return runTransaction(firestore, async (transaction) => {
    const inviteeSnapshot = await transaction.get(inviteeRef);
    const inviteeData = inviteeSnapshot.data();
    const invitee =
      inviteeSnapshot.exists() && inviteeData
        ? memberFromData(inviteeSnapshot.id, inviteeData)
        : completedBy;
    const referrerId = invitee.referredByMemberId?.trim();

    if (!referrerId) {
      return {
        issued: false,
        reason: "missingReward",
      } satisfies RewardIssueResult;
    }
    if (
      invitee.referralRewardGrantedAt ||
      invitee.referralRewardGrantedActivityId
    ) {
      return {
        issued: false,
        reason: "alreadyIssued",
      } satisfies RewardIssueResult;
    }

    const rewardRef = doc(firestore, "rewards", rewardId);
    const referrerRef = doc(firestore, "members", referrerId);
    const grantRef = doc(
      firestore,
      "memberRewards",
      rewardGrantDocumentId({
        memberId: referrerId,
        rewardId,
        activityId: activity.id,
        source: "referralActivityCompletion",
        sourceMemberId: invitee.id,
      }),
    );
    const [existingGrant, rewardSnapshot, referrerSnapshot] =
      await Promise.all([
        transaction.get(grantRef),
        transaction.get(rewardRef),
        transaction.get(referrerRef),
      ]);

    if (existingGrant.exists()) {
      return {
        issued: false,
        reason: "alreadyIssued",
      } satisfies RewardIssueResult;
    }

    const rewardData = rewardSnapshot.data();
    if (!rewardSnapshot.exists() || !rewardData) {
      return {
        issued: false,
        reason: "missingReward",
      } satisfies RewardIssueResult;
    }
    const referrerData = referrerSnapshot.data();
    if (!referrerSnapshot.exists() || !referrerData) {
      return {
        issued: false,
        reason: "missingReward",
      } satisfies RewardIssueResult;
    }

    const reward = rewardFromData(rewardSnapshot.id, rewardData);
    if (reward.status !== "active") {
      return {
        issued: false,
        reason: "inactiveReward",
      } satisfies RewardIssueResult;
    }
    if (reward.expiresAt && reward.expiresAt.getTime() < Date.now()) {
      return {
        issued: false,
        reason: "expiredReward",
      } satisfies RewardIssueResult;
    }
    if (reward.stock <= 0) {
      return {
        issued: false,
        reason: "outOfStock",
      } satisfies RewardIssueResult;
    }

    const referrer = memberFromData(referrerSnapshot.id, referrerData);
    const voucher = reward.voucherTotal > 0 ? voucherCandidate : undefined;
    if (reward.voucherTotal > 0 && !voucher) {
      return {
        issued: false,
        reason: "outOfStock",
      } satisfies RewardIssueResult;
    }
    const voucherSnapshot = voucher
      ? await transaction.get(voucher.ref)
      : undefined;
    if (
      voucher &&
      (!voucherSnapshot?.exists() ||
        voucherSnapshot.data()?.status !== "available")
    ) {
      return {
        issued: false,
        reason: "outOfStock",
      } satisfies RewardIssueResult;
    }

    transaction.set(grantRef, {
      memberId: referrer.id,
      memberName: referrer.name,
      memberLineUserId: referrer.lineUserId ?? referrer.id,
      rewardId: reward.id,
      rewardName: reward.name,
      rewardCategory: reward.category,
      rewardImageUrl: reward.imageUrl ?? null,
      redemptionUrl: voucher?.url ?? null,
      voucherId: voucher?.id ?? null,
      status: "issued",
      source: "referralActivityCompletion",
      activityId: activity.id,
      activityTitle: activity.title,
      sourceMemberId: invitee.id,
      sourceMemberName: invitee.name,
      issuedAt: serverTimestamp(),
      expiresAt: reward.expiresAt ? Timestamp.fromDate(reward.expiresAt) : null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    transaction.set(
      referrerRef,
      {
        earnedCoupons: increment(1),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
    transaction.set(
      rewardRef,
      {
        stock: increment(-1),
        issued: increment(1),
        ...(voucher ? { voucherAvailable: increment(-1) } : {}),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
    if (voucher) {
      transaction.set(
        voucher.ref,
        {
          status: "issued",
          memberId: referrer.id,
          memberName: referrer.name,
          memberLineUserId: referrer.lineUserId ?? referrer.id,
          issuedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    }
    transaction.set(
      inviteeRef,
      {
        referralRewardGrantedActivityId: activity.id,
        referralRewardGrantedRewardId: reward.id,
        referralRewardGrantedReferrerId: referrer.id,
        referralRewardGrantedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
    transaction.set(
      doc(firestore, "referrals", `${referrer.id}_${invitee.id}`),
      {
        lastCompletedActivityId: activity.id,
        lastCompletedActivityTitle: activity.title,
        lastCompletedAt: serverTimestamp(),
        firstRewardedActivityId: activity.id,
        firstRewardedActivityTitle: activity.title,
        rewardGrantedAt: serverTimestamp(),
        rewardedActivityCount: increment(1),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );

    return { issued: true } satisfies RewardIssueResult;
  });
}

async function issueMemberRewardIfNeeded(input: {
  activity: VeevaActivity;
  member: VeevaMember;
  rewardId: string;
  source: RewardIssueSource;
  sourceMember?: VeevaMember;
}): Promise<RewardIssueResult> {
  const rewardId = input.rewardId.trim();
  if (!rewardId) {
    return { issued: false, reason: "missingReward" };
  }

  const rewardRef = doc(firestore, "rewards", rewardId);
  const memberRef = doc(firestore, "members", input.member.id);
  const voucherCandidate = await findAvailableVoucherForReward(rewardId);
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
      return {
        issued: false,
        reason: "alreadyIssued",
      } satisfies RewardIssueResult;
    }

    const rewardSnapshot = await transaction.get(rewardRef);
    const rewardData = rewardSnapshot.data();
    if (!rewardSnapshot.exists() || !rewardData) {
      return {
        issued: false,
        reason: "missingReward",
      } satisfies RewardIssueResult;
    }

    const reward = rewardFromData(rewardSnapshot.id, rewardData);
    if (reward.status !== "active") {
      return {
        issued: false,
        reason: "inactiveReward",
      } satisfies RewardIssueResult;
    }
    if (reward.expiresAt && reward.expiresAt.getTime() < Date.now()) {
      return {
        issued: false,
        reason: "expiredReward",
      } satisfies RewardIssueResult;
    }
    if (reward.stock <= 0) {
      return {
        issued: false,
        reason: "outOfStock",
      } satisfies RewardIssueResult;
    }

    const voucher = reward.voucherTotal > 0 ? voucherCandidate : undefined;
    if (reward.voucherTotal > 0 && !voucher) {
      return {
        issued: false,
        reason: "outOfStock",
      } satisfies RewardIssueResult;
    }
    const voucherSnapshot = voucher
      ? await transaction.get(voucher.ref)
      : undefined;
    if (
      voucher &&
      (!voucherSnapshot?.exists() ||
        voucherSnapshot.data()?.status !== "available")
    ) {
      return {
        issued: false,
        reason: "outOfStock",
      } satisfies RewardIssueResult;
    }

    transaction.set(grantRef, {
      memberId: input.member.id,
      memberName: input.member.name,
      memberLineUserId: input.member.lineUserId ?? input.member.id,
      rewardId: reward.id,
      rewardName: reward.name,
      rewardCategory: reward.category,
      rewardImageUrl: reward.imageUrl ?? null,
      redemptionUrl: voucher?.url ?? null,
      voucherId: voucher?.id ?? null,
      status: "issued",
      source: input.source,
      activityId: input.activity.id,
      activityTitle: input.activity.title,
      sourceMemberId: input.sourceMember?.id ?? null,
      sourceMemberName: input.sourceMember?.name ?? null,
      issuedAt: serverTimestamp(),
      expiresAt: reward.expiresAt ? Timestamp.fromDate(reward.expiresAt) : null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    transaction.set(
      memberRef,
      {
        earnedCoupons: increment(1),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
    transaction.set(
      rewardRef,
      {
        stock: increment(-1),
        issued: increment(1),
        ...(voucher ? { voucherAvailable: increment(-1) } : {}),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
    if (voucher) {
      transaction.set(
        voucher.ref,
        {
          status: "issued",
          memberId: input.member.id,
          memberName: input.member.name,
          memberLineUserId: input.member.lineUserId ?? input.member.id,
          issuedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    }

    return { issued: true } satisfies RewardIssueResult;
  });
}

async function findAvailableVoucherForReward(
  rewardId: string,
): Promise<VoucherAllocation | undefined> {
  const voucherSnapshot = await getDocs(
    query(
      collection(firestore, "rewardVouchers"),
      where("rewardId", "==", rewardId),
      where("status", "==", "available"),
      limit(1),
    ),
  );
  const voucherDoc = voucherSnapshot.docs[0];
  if (!voucherDoc) return undefined;
  const url = optionalString(voucherDoc.data().url);
  if (!url) return undefined;
  return {
    id: voucherDoc.id,
    url,
    ref: voucherDoc.ref,
  };
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
    surveyUrl: optionalString(data.surveyUrl),
    actionUrl: optionalString(data.actionUrl),
    location: optionalString(data.location),
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
    helpfulCount: numberValue(data.helpfulCount, 12),
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
  const segment = value.trim().replace(/[\/#?\[\]]/g, "_");
  return segment || "unknown";
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
