export type VeevaMemberStatus =
  | "guest"
  | "loggedIn"
  | "pendingReview"
  | "verified";

export type VeevaMemberAccountStatus = "active" | "disabled";

export type VeevaContentStatus =
  | "draft"
  | "scheduled"
  | "published"
  | "archived";

export type VeevaActivityType =
  | "survey"
  | "registration"
  | "referral"
  | "task"
  | "checkin"
  | "external";

export type VeevaRewardStatus = "active" | "paused" | "expired";

export interface VeevaMember {
  id: string;
  name: string;
  hospital: string;
  department: string;
  status: VeevaMemberStatus;
  accountStatus: VeevaMemberAccountStatus;
  earnedCoupons: number;
  invitedCount: number;
  shareCode: string;
  lineUserId?: string;
  avatarUrl?: string;
  email?: string;
  lineStatusMessage?: string;
  lineIdToken?: string;
  lineIdTokenUpdatedAt?: Date;
  createdAt?: Date;
  lastLineLoginAt?: Date;
  referredByMemberId?: string;
  referredByShareCode?: string;
  referredAt?: Date;
  referralRewardGrantedActivityId?: string;
  referralRewardGrantedRewardId?: string;
  referralRewardGrantedReferrerId?: string;
  referralRewardGrantedAt?: Date;
  isAdmin?: boolean;
  adminRole?: string;
}

export interface VeevaActivity {
  id: string;
  type: VeevaActivityType;
  label: string;
  title: string;
  description: string;
  reward: string;
  rewardId?: string;
  completionRewardId?: string;
  participantRewardId?: string;
  referrerRewardId?: string;
  status: VeevaContentStatus;
  active: boolean;
  periodText?: string;
  note?: string;
  imageUrl?: string;
  surveyUrl?: string;
  actionUrl?: string;
  location?: string;
  activityTime?: string;
  organizer?: string;
}

export interface VeevaActivityRegistration {
  id: string;
  activityId: string;
  activityTitle: string;
  memberId: string;
  memberName: string;
  status: "registered" | "completed";
  registeredAt?: Date;
  completedAt?: Date;
}

export interface VeevaSurveyEngagement {
  activityId: string;
  surveyUrl: string;
  score: number;
  completedByBehavior: boolean;
  startedAt: string;
  evaluatedAt: string;
  totalDurationMs: number;
  visibleDurationMs: number;
  iframeLoaded: boolean;
  iframeLoadCount: number;
  iframeFocusedCount: number;
  parentInteractionCount: number;
  pointerCount: number;
  touchCount: number;
  clickCount: number;
  keyCount: number;
  scrollCount: number;
  maxParentScrollDepth: number;
  hiddenCount: number;
  fastExit: boolean;
  requiredConditionsMet: boolean;
}

export interface VeevaNews {
  id: string;
  date: string;
  source: string;
  title: string;
  summary: string;
  status: VeevaContentStatus;
  category?: string;
  imageUrl?: string;
  content?: string;
  detailContent?: string;
  keyPoints?: string[];
  externalUrl?: string;
  helpfulCount?: number;
}

export interface VeevaReward {
  id: string;
  name: string;
  category: string;
  stock: number;
  issued: number;
  redeemed: number;
  voucherTotal: number;
  voucherAvailable: number;
  status: VeevaRewardStatus;
  expiresAt?: Date;
  imageUrl?: string;
  description?: string;
}

export interface VeevaMemberReward {
  id: string;
  memberId: string;
  rewardId: string;
  rewardName: string;
  rewardImageUrl?: string;
  redemptionUrl?: string;
  voucherId?: string;
  status: "pending" | "issued" | "redeemed" | "expired";
  source?: "manualAdmin" | "activityCompletion" | "referralActivityCompletion";
  activityId?: string;
  activityTitle?: string;
  sourceMemberId?: string;
  sourceMemberName?: string;
  issuedAt?: Date;
  redeemedAt?: Date;
  expiresAt?: Date;
}

export interface VeevaReferralRecord {
  id: string;
  referrerMemberId: string;
  referredMemberId: string;
  referrerShareCode: string;
  referredName: string;
  referredAvatarUrl?: string;
  lastCompletedActivityId?: string;
  lastCompletedActivityTitle?: string;
  lastCompletedAt?: Date;
  rewardedActivityCount?: number;
  createdAt?: Date;
}

export interface LiffProfile {
  userId: string;
  displayName: string;
  pictureUrl?: string;
  statusMessage?: string;
  email?: string;
}

export interface LiffSession {
  initialized: boolean;
  loggedIn: boolean;
  inClient: boolean;
  idToken?: string;
  accessToken?: string;
  idTokenExpiresAt?: Date;
  profile?: LiffProfile;
  os?: string;
  lineVersion?: string;
  liffVersion?: string;
  error?: string;
}

export interface BootstrapData {
  activities: VeevaActivity[];
  news: VeevaNews[];
  rewards: VeevaReward[];
}
