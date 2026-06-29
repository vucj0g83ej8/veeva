import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

initializeApp();

const db = getFirestore();
const linePushEndpoint = 'https://api.line.me/v2/bot/message/push';
const defaultLiffId = '2010298394-7PwRtpTY';
const lineChannelAccessToken = defineSecret('LINE_CHANNEL_ACCESS_TOKEN');
export const sendRewardIssuedLineMessage = onDocumentWritten(
  {
    document: 'memberNotifications/{notificationId}',
    region: 'asia-east1',
    timeoutSeconds: 30,
    memory: '256MiB',
    secrets: [lineChannelAccessToken],
  },
  async (event) => {
    const snapshot = event.data?.after;
    const notificationId = event.params.notificationId;
    const data = snapshot?.data();
    if (!snapshot?.exists || !data) return;
    if (data.type !== 'rewardIssued') return;
    if (cleanString(data.linePushStatus) !== 'pending') return;

    const lineUserId = cleanString(data.memberLineUserId);
    if (!lineUserId) {
      await markLinePush(notificationId, {
        status: 'skipped',
        error: 'missing memberLineUserId',
      });
      return;
    }

    await markLinePush(notificationId, { status: 'sending' });

    const channelAccessToken = cleanString(lineChannelAccessToken.value());
    if (!channelAccessToken) {
      await markLinePush(notificationId, {
        status: 'skipped',
        error: 'missing LINE_CHANNEL_ACCESS_TOKEN',
      });
      logger.warn('LINE_CHANNEL_ACCESS_TOKEN is not configured.');
      return;
    }

    const message = buildRewardIssuedFlexMessage(data);
    const response = await fetch(linePushEndpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${channelAccessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: lineUserId,
        messages: [message],
      }),
    });

    if (!response.ok) {
      const responseBody = await response.text().catch(() => '');
      await markLinePush(notificationId, {
        status: 'failed',
        error: `LINE push failed ${response.status}: ${responseBody}`,
      });
      logger.error('LINE push failed.', {
        notificationId,
        status: response.status,
        responseBody,
      });
      return;
    }

    await markLinePush(notificationId, { status: 'sent' });
    logger.info('LINE reward notification sent.', { notificationId });
  },
);

function buildRewardIssuedFlexMessage(data) {
  const rewardName = cleanString(data.rewardName) || '兌換券';
  const activityTitle = cleanString(data.activityTitle);
  const bodyText =
    cleanString(data.body) ||
    (activityTitle
      ? `「${activityTitle}」已確認完成，兌換券可以正常使用。`
      : `你的「${rewardName}」已確認，可以正常使用。`);
  const actionUrl = couponActionUrl(cleanString(data.memberRewardId));
  const heroUrl = usableImageUrl(cleanString(data.rewardImageUrl));

  const bubble = {
    type: 'bubble',
    size: 'mega',
    ...(heroUrl
      ? {
          hero: {
            type: 'image',
            url: heroUrl,
            size: 'full',
            aspectRatio: '20:13',
            aspectMode: 'cover',
          },
        }
      : {}),
    body: {
      type: 'box',
      layout: 'vertical',
      spacing: 'md',
      contents: [
        {
          type: 'text',
          text: '兌換券已確認',
          weight: 'bold',
          color: '#007D8A',
          size: 'sm',
        },
        {
          type: 'text',
          text: rewardName,
          weight: 'bold',
          size: 'xl',
          color: '#1F2626',
          wrap: true,
        },
        {
          type: 'text',
          text: bodyText,
          size: 'sm',
          color: '#5A6666',
          wrap: true,
        },
      ],
    },
    footer: {
      type: 'box',
      layout: 'vertical',
      spacing: 'sm',
      contents: [
        {
          type: 'button',
          style: 'primary',
          color: '#007D8A',
          height: 'sm',
          action: {
            type: 'uri',
            label: '立即使用',
            uri: actionUrl,
          },
        },
      ],
    },
  };

  return {
    type: 'flex',
    altText: `${rewardName} 已確認，可以正常使用`,
    contents: bubble,
  };
}

function couponActionUrl(memberRewardId) {
  const statePath = memberRewardId
    ? `/coupons?reward=${encodeURIComponent(memberRewardId)}`
    : '/coupons';
  const liffId = cleanString(process.env.LINE_LIFF_ID) || defaultLiffId;
  return `https://liff.line.me/${liffId}?liff.state=${encodeURIComponent(
    statePath,
  )}`;
}

function usableImageUrl(value) {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' ? value : null;
  } catch (_) {
    return null;
  }
}

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

async function markLinePush(notificationId, result) {
  await db
    .collection('memberNotifications')
    .doc(notificationId)
    .set(
      {
        linePushStatus: result.status,
        linePushError: result.error ?? null,
        linePushedAt:
          result.status === 'sent' ? FieldValue.serverTimestamp() : null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}
