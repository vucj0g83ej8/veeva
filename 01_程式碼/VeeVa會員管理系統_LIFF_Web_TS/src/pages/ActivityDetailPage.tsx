import {
  ArrowLeft,
  CalendarDays,
  CheckCircle2,
  ChevronDown,
  Clock3,
  ExternalLink,
  MapPin,
  Megaphone,
  Microscope,
  NotebookPen,
  Send,
  Share2,
  Stethoscope,
  Tag,
  UserRound,
  UsersRound,
} from "lucide-react";
import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import type { VeevaAppState } from "../hooks/useVeevaApp";
import type { VeevaActivity, VeevaActivityRegistration } from "../types/veeva";
import { activityFlowFor } from "../utils/activityFlow";

interface PageProps {
  app: VeevaAppState;
}

export function ActivityDetailPage({ app }: PageProps) {
  const { activityId = "" } = useParams();
  const decodedActivityId = safeDecode(activityId);
  const activity = app.bootstrap.activities.find(
    (item) => item.id === decodedActivityId,
  );

  if (!activity) {
    return (
      <section className="empty-state">
        <Megaphone size={30} />
        <h2>找不到活動</h2>
        <p>這個活動可能已下架或尚未發布。</p>
        <Link className="secondary-button" to="/activities">
          <ArrowLeft size={18} />
          回活動列表
        </Link>
      </section>
    );
  }

  return <ActivityDetailContent activity={activity} app={app} />;
}

function ActivityDetailContent({
  activity,
  app,
}: {
  activity: VeevaActivity;
  app: VeevaAppState;
}) {
  const flow = useMemo(() => activityFlowFor(activity), [activity]);
  const navigate = useNavigate();
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [shareBusy, setShareBusy] = useState(false);
  const autoShareHandledRef = useRef(false);
  const autoShareRequested = isAutoShareRequested();
  const location = activity.location ?? fallbackLocation(activity);
  const activityTime = activity.activityTime ?? "依活動公告為準";
  const organizer = activity.organizer ?? "VeeVa Member";
  const memberActivityRecord = useMemo(
    () =>
      app.memberActivityRecords.find(
        (record) => record.activityId === activity.id,
      ),
    [activity.id, app.memberActivityRecords],
  );
  if (!shouldShowActivityDetail(activity, memberActivityRecord)) {
    return (
      <section className="empty-state">
        <Megaphone size={30} />
        <h2>活動尚未開放</h2>
        <p>這個活動目前未上架或已封存。</p>
        <Link className="secondary-button" to="/activities">
          <ArrowLeft size={18} />
          回活動列表
        </Link>
      </section>
    );
  }

  const statusLabel = activityStatusLabel(activity, memberActivityRecord);
  const registrationStatus =
    activity.type === "registration" ? memberActivityRecord?.status : undefined;
  const registrationLocked =
    registrationStatus === "registered" || registrationStatus === "completed";
  const surveyCompleted =
    activity.type === "survey" && memberActivityRecord?.status === "completed";
  const surveyPendingReview =
    activity.type === "survey" &&
    memberActivityRecord?.status === "pendingReview";
  const noticeItems = noticeItemsFor(activity);
  const primaryButtonLabel =
    surveyPendingReview
      ? "審核中"
      : surveyCompleted
      ? "已填寫"
      : registrationStatus === "completed"
      ? "已完成"
      : registrationStatus === "registered"
        ? "已報名"
        : busy
          ? "處理中"
          : flow.actionLabel;

  async function handlePrimaryAction() {
    setMessage("");

    if (activity.type === "survey") {
      if (surveyCompleted || surveyPendingReview) {
        return;
      }
      if (!activity.surveyUrl) {
        setMessage("這個問卷活動尚未設定問卷連結。");
        return;
      }
      if (!app.member) {
        await app.login();
        return;
      }
      navigate(`/activities/${encodeURIComponent(activity.id)}/survey`);
      return;
    }

    if (activity.type === "external" || activity.type === "task") {
      if (!activity.actionUrl) {
        setMessage("這個活動尚未設定操作連結，請等待主辦單位更新。");
        return;
      }
      window.open(activity.actionUrl, "_blank", "noopener,noreferrer");
      return;
    }

    if (activity.type === "referral") {
      await app.shareInvite();
      return;
    }

    if (!app.member) {
      await app.login();
      return;
    }

    if (activity.type === "registration") {
      if (registrationLocked) {
        return;
      }
      setBusy(true);
      try {
        const { registerActivity } =
          await import("../services/veevaRepository");
        await registerActivity({ activity, member: app.member });
        await app.refreshMemberData();
        setMessage("已完成報名，我們會保留你的活動報名紀錄。");
      } catch (error) {
        setMessage(error instanceof Error ? error.message : String(error));
      } finally {
        setBusy(false);
      }
      return;
    }

    if (activity.type === "checkin") {
      setMessage("簽到功能會搭配現場 QR Code 或指定驗證流程使用。");
    }
  }

  async function handleShareAction() {
    if (shareBusy) return;

    setMessage("");
    setShareBusy(true);
    const shareUrl = new URL(
      `/activities/${encodeURIComponent(activity.id)}`,
      window.location.origin,
    ).toString();

    try {
      if (!app.member) {
        await app.login();
        return;
      }
      setMessage("正在開啟 LINE 分享視窗...");
      const liffShare = await import("../services/liff");
      const shared = await liffShare.shareActivityCard(
        activity,
        app.member.shareCode,
      );
      if (!shared) {
        setMessage("已取消分享。");
        return;
      }
      setMessage("已開啟 LINE 分享視窗。");
      return;
    } catch (error) {
      if (
        error instanceof Error &&
        error.message === "LINE_CARD_SHARE_UNSUPPORTED"
      ) {
        try {
          await copyTextToClipboard(shareUrl);
          setMessage(
            "目前不是 LINE 卡片分享環境，已先複製活動連結。請在 LINE 內開啟活動頁即可分享圖文卡片。",
          );
        } catch {
          setMessage(
            `目前不是 LINE 卡片分享環境，請在 LINE 內開啟活動頁分享圖文卡片，或手動複製連結：${shareUrl}`,
          );
        }
        return;
      }
      if (error instanceof DOMException && error.name === "AbortError") {
        setMessage("已取消分享。");
        return;
      }
      try {
        await copyTextToClipboard(shareUrl);
        setMessage(
          error instanceof Error
            ? `${error.message} 已先複製活動連結。`
            : "目前無法開啟 LINE 分享功能，已先複製活動連結。",
        );
      } catch {
        setMessage(
          error instanceof Error
            ? error.message
            : "目前無法開啟 LINE 分享功能。",
        );
      }
    } finally {
      setShareBusy(false);
    }
  }

  useEffect(() => {
    if (
      !autoShareRequested ||
      autoShareHandledRef.current ||
      !app.memberProfileReady ||
      app.initializing ||
      app.authenticating ||
      shareBusy
    ) {
      return;
    }

    autoShareHandledRef.current = true;
    clearAutoShareSearchParams();
    void handleShareAction();
  }, [
    app.authenticating,
    app.initializing,
    app.memberProfileReady,
    autoShareRequested,
    shareBusy,
  ]);

  return (
    <article className="activity-detail-page">
      <div className="activity-detail-nav">
        <Link
          aria-label="回活動列表"
          className="activity-detail-back"
          to="/activities"
        >
          <ArrowLeft size={24} />
        </Link>
        <strong>活動資訊</strong>
        <span aria-hidden="true" />
      </div>

      <div className="activity-detail-content">
        <section className={`activity-detail-hero ${activity.type}`}>
          {activity.imageUrl ? (
            <img
              className="activity-detail-hero-image"
              src={activity.imageUrl}
              alt=""
            />
          ) : (
            <div className={`activity-detail-hero-art ${activity.type}`}>
              <ActivityHeroIcon type={activity.type} />
            </div>
          )}

          <div className="activity-detail-hero-copy">
            <span className="activity-detail-status-chip">{statusLabel}</span>
            <div className="activity-detail-hero-date">
              <CalendarDays size={16} />
              <span>{activity.periodText ?? "期間未設定"}</span>
            </div>
            <h2>{activity.title}</h2>
            <p>{activity.description}</p>
            <div className="activity-detail-hero-location">
              <MapPin size={18} />
              <span>{location}</span>
            </div>
          </div>
        </section>

        <div className="activity-detail-actions">
          <button
            className="activity-detail-primary-button"
            disabled={
              busy ||
              app.busy ||
              registrationLocked ||
              surveyCompleted ||
              surveyPendingReview
            }
            type="button"
            onClick={() => void handlePrimaryAction()}
          >
            {surveyPendingReview ? (
              <Clock3 size={18} />
            ) : registrationLocked || surveyCompleted ? (
              <CheckCircle2 size={18} />
            ) : (
              buttonIconFor(activity)
            )}
            {primaryButtonLabel}
          </button>
          <button
            className="activity-detail-secondary-button"
            disabled={shareBusy}
            type="button"
            onClick={() => void handleShareAction()}
          >
            <Share2 size={20} />
            {shareBusy ? "開啟中" : "分享"}
          </button>
        </div>

        {message && (
          <div className="success-message activity-detail-message">
            <CheckCircle2 size={18} />
            <span>{message}</span>
          </div>
        )}

        <section className="activity-detail-card" aria-label="活動詳情">
          <h3 className="activity-detail-section-title">活動詳情</h3>
          <ActivityInfoRow
            icon={<CalendarDays size={20} />}
            label="活動日期"
            value={activity.periodText ?? "期間未設定"}
          />
          <ActivityInfoRow
            icon={<Clock3 size={20} />}
            label="活動時間"
            value={activityTime}
          />
          <ActivityInfoRow
            icon={<MapPin size={20} />}
            label="活動地點"
            value={location}
          />
          <ActivityInfoRow
            icon={<UserRound size={20} />}
            label="主辦單位"
            value={organizer}
          />
          <ActivityInfoRow
            icon={<Tag size={20} />}
            label="活動類型"
            value={flow.label}
          />
        </section>

        {activity.note && (
          <section className="activity-detail-card">
            <div className="activity-detail-card-title-row">
              <h3>活動內容</h3>
              <ChevronDown size={18} />
            </div>
            <p>{activity.note}</p>
          </section>
        )}

        {noticeItems.length > 0 && (
          <section className="activity-detail-card">
            <h3>注意事項</h3>
            <ul className="activity-detail-notes">
              {noticeItems.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </section>
        )}
      </div>
    </article>
  );
}

function ActivityInfoRow({
  icon,
  label,
  value,
  trailing,
}: {
  icon: ReactNode;
  label: string;
  value: string;
  trailing?: ReactNode;
}) {
  return (
    <div
      className={`activity-detail-info-row${trailing ? " has-trailing" : ""}`}
    >
      <span className="activity-detail-info-icon">{icon}</span>
      <span className="activity-detail-info-label">{label}</span>
      <strong>{value}</strong>
      {trailing && (
        <span className="activity-detail-info-trailing">{trailing}</span>
      )}
    </div>
  );
}

function ActivityHeroIcon({ type }: { type: VeevaActivity["type"] }) {
  const iconProps = { size: 108, strokeWidth: 1.45 };
  if (type === "survey") return <NotebookPen {...iconProps} />;
  if (type === "registration") return <UsersRound {...iconProps} />;
  if (type === "task") return <Microscope {...iconProps} />;
  if (type === "checkin") return <Stethoscope {...iconProps} />;
  return <Megaphone {...iconProps} />;
}

function buttonIconFor(activity: VeevaActivity) {
  if (activity.type === "survey" || activity.type === "external") {
    return <ExternalLink size={18} />;
  }
  if (activity.type === "referral") {
    return <Send size={18} />;
  }
  return <Megaphone size={18} />;
}

function activityStatusLabel(
  activity: VeevaActivity,
  record?: VeevaActivityRegistration,
) {
  if (activity.type === "survey" && record?.status === "completed") {
    return "已填寫";
  }
  if (activity.type === "survey" && record?.status === "pendingReview") {
    return "審核中";
  }
  if (activity.type === "survey") {
    return "填寫問卷";
  }
  if (record?.status === "completed") return "已完成";
  if (record?.status === "registered") return "已報名";
  if (activity.status === "archived" || !activity.active) return "已結束";
  if (activity.label.includes("即將")) return "即將開始";
  if (activity.label.includes("報名")) return "報名中";
  if (activity.type === "registration") return "報名中";
  return activity.label || "進行中";
}

function fallbackLocation(activity: VeevaActivity) {
  if (activity.type === "survey") return "線上問卷";
  if (activity.type === "external" || activity.type === "task")
    return "線上活動";
  return "活動地點待通知";
}

function shouldShowActivityDetail(
  activity: VeevaActivity,
  record?: VeevaActivityRegistration,
) {
  if (record) return true;
  if (!activity.active) return false;
  return activity.status !== "draft" && activity.status !== "archived";
}

function isAutoShareRequested() {
  const params = new URLSearchParams(window.location.search);
  return params.get("share") === "1" || params.get("open") === "share";
}

function clearAutoShareSearchParams() {
  const url = new URL(window.location.href);
  url.searchParams.delete("share");
  if (url.searchParams.get("open") === "share") {
    url.searchParams.delete("open");
  }
  window.history.replaceState(
    null,
    "",
    `${url.pathname}${url.search}${url.hash}`,
  );
}

function noticeItemsFor(activity: VeevaActivity) {
  return activity.noticeItems ?? [];
}

async function copyTextToClipboard(text: string) {
  if (window.navigator.clipboard?.writeText) {
    try {
      await window.navigator.clipboard.writeText(text);
      return;
    } catch {
      // Fall back to the legacy copy path for LINE and mobile browsers.
    }
  }

  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.setAttribute("readonly", "true");
  textarea.style.position = "fixed";
  textarea.style.left = "-9999px";
  textarea.style.top = "0";
  document.body.appendChild(textarea);
  textarea.select();
  textarea.setSelectionRange(0, textarea.value.length);
  const copied = document.execCommand("copy");
  textarea.remove();

  if (!copied) {
    throw new Error("目前無法複製活動連結，請手動複製網址分享。");
  }
}

function safeDecode(value: string) {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}
