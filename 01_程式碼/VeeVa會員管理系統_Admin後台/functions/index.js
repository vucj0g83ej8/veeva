import { createHmac, timingSafeEqual } from 'node:crypto';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { resolveTemplateUrl } from './line-url.js';

initializeApp();

const db = getFirestore();
const linePushEndpoint = 'https://api.line.me/v2/bot/message/push';
const defaultLiffId = '2010298394-7PwRtpTY';
const lineChannelAccessToken = defineSecret('LINE_CHANNEL_ACCESS_TOKEN');
const lineChannelSecret = defineSecret('LINE_CHANNEL_SECRET');

export const lineWebhook = onRequest(
  {
    region: 'asia-east1',
    timeoutSeconds: 30,
    memory: '256MiB',
    secrets: [lineChannelSecret],
  },
  async (request, response) => {
    if (request.method !== 'POST') {
      response.status(405).send('Method Not Allowed');
      return;
    }

    const channelSecret = cleanString(lineChannelSecret.value());
    const signature = cleanString(request.get('x-line-signature'));
    if (
      !channelSecret ||
      !signature ||
      !isValidLineSignature(request.rawBody, signature, channelSecret)
    ) {
      logger.warn('Rejected LINE webhook with an invalid signature.');
      response.status(401).send('Invalid signature');
      return;
    }

    const events = Array.isArray(request.body?.events) ? request.body.events : [];
    await Promise.all(events.map(saveIncomingLineEvent));
    response.status(200).send('OK');
  },
);

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

export const sendLineMessageTest = onDocumentWritten(
  {
    document: 'lineMessageTests/{testId}',
    region: 'asia-east1',
    timeoutSeconds: 30,
    memory: '256MiB',
    secrets: [lineChannelAccessToken],
  },
  async (event) => {
    const snapshot = event.data?.after;
    const testId = event.params.testId;
    const data = snapshot?.data();
    if (!snapshot?.exists || !data) return;
    if (cleanString(data.status) !== 'pending') return;

    const lineUserId = cleanString(data.memberLineUserId);
    if (!lineUserId) {
      await markLineMessageTest(testId, {
        status: 'skipped',
        error: '此會員沒有可使用的 LINE 帳號識別碼。',
      });
      return;
    }

    await markLineMessageTest(testId, { status: 'sending' });
    const channelAccessToken = cleanString(lineChannelAccessToken.value());
    if (!channelAccessToken) {
      await markLineMessageTest(testId, {
        status: 'skipped',
        error: '尚未設定 LINE Channel Access Token。',
      });
      return;
    }

    try {
      const message = buildRewardIssuedFlexMessage({
        lineMessageType: data.messageType,
        lineMessageSnapshot: data.messageSnapshot,
        rewardName: 'LINE 測試訊息',
      });
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
        await markLineMessageTest(testId, {
          status: 'failed',
          error: `LINE 測試發送失敗 (${response.status})：${responseBody}`,
        });
        logger.error('LINE message test failed.', {
          testId,
          status: response.status,
          responseBody,
        });
        return;
      }

      await saveLineConversationMessage({
        lineUserId,
        messageId: `out-${testId}`,
        memberId: cleanString(data.memberId),
        memberName: cleanString(data.memberName),
        direction: 'outgoing',
        type: cleanString(data.messageType) || 'text',
        text: lineConversationSummary(data.messageType, data.messageSnapshot),
        messageSnapshot: isPlainObject(data.messageSnapshot)
          ? data.messageSnapshot
          : null,
        sentAt: new Date(),
      });
      await markLineMessageTest(testId, { status: 'sent' });
      logger.info('LINE message test sent.', { testId });
    } catch (error) {
      await markLineMessageTest(testId, {
        status: 'failed',
        error: `LINE 測試發送失敗：${error instanceof Error ? error.message : String(error)}`,
      });
      logger.error('LINE message test threw an error.', {
        testId,
        error,
      });
    }
  },
);

function isValidLineSignature(rawBody, signature, channelSecret) {
  if (!Buffer.isBuffer(rawBody)) return false;
  const expected = createHmac('sha256', channelSecret)
    .update(rawBody)
    .digest('base64');
  const actualBuffer = Buffer.from(signature);
  const expectedBuffer = Buffer.from(expected);
  return (
    actualBuffer.length === expectedBuffer.length &&
    timingSafeEqual(actualBuffer, expectedBuffer)
  );
}

async function saveIncomingLineEvent(event) {
  if (!isPlainObject(event) || event.type !== 'message') return;
  const lineUserId = cleanString(event.source?.userId);
  const messageId = cleanString(event.message?.id);
  if (!lineUserId || !messageId) return;

  const memberSnapshot = await db
    .collection('members')
    .where('lineUserId', '==', lineUserId)
    .limit(1)
    .get();
  const memberDocument = memberSnapshot.docs[0];
  const member = memberDocument?.data();
  const type = cleanString(event.message?.type) || 'unknown';

  await saveLineConversationMessage({
    lineUserId,
    messageId: `in-${messageId}`,
    memberId: memberDocument?.id || '',
    memberName: cleanString(member?.name),
    direction: 'incoming',
    type,
    text: incomingLineMessageText(event.message, type),
    sentAt:
      Number.isFinite(event.timestamp) && event.timestamp > 0
        ? new Date(event.timestamp)
        : new Date(),
  });
}

function incomingLineMessageText(message, type) {
  if (type === 'text') return cleanString(message?.text) || '[空白訊息]';
  const labels = {
    image: '[圖片]',
    sticker: '[貼圖]',
    video: '[影片]',
    audio: '[語音訊息]',
    file: `[檔案] ${cleanString(message?.fileName)}`.trim(),
    location: `[位置] ${cleanString(message?.title)}`.trim(),
  };
  return labels[type] || `[${type || '未知'}訊息]`;
}

async function saveLineConversationMessage({
  lineUserId,
  messageId,
  memberId,
  memberName,
  direction,
  type,
  text,
  messageSnapshot = null,
  sentAt,
}) {
  const conversation = db.collection('lineConversations').doc(lineUserId);
  const message = conversation.collection('messages').doc(messageId);
  const batch = db.batch();
  batch.set(
    message,
    {
      lineUserId,
      memberId: memberId || null,
      memberName: memberName || null,
      direction,
      type,
      text,
      messageSnapshot,
      sentAt,
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  batch.set(
    conversation,
    {
      lineUserId,
      memberId: memberId || null,
      memberName: memberName || null,
      lastMessage: text,
      lastDirection: direction,
      lastMessageAt: sentAt,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await batch.commit();
}

function buildRewardIssuedFlexMessage(data) {
  const messageType = cleanString(data.lineMessageType) || 'system';
  const snapshot = isPlainObject(data.lineMessageSnapshot)
    ? data.lineMessageSnapshot
    : null;
  if (messageType === 'text' && snapshot) {
    return buildTextLineMessage(snapshot);
  }
  if (messageType === 'rich' && snapshot) {
    return buildRichRewardIssuedFlexMessage(data, snapshot);
  }
  if (messageType === 'carousel' && snapshot) {
    return buildCarouselRewardIssuedFlexMessage(data, snapshot);
  }
  return buildSystemRewardIssuedFlexMessage(data);
}

function lineConversationSummary(messageType, snapshot) {
  const type = cleanString(messageType) || 'text';
  const text = cleanString(snapshot?.text);
  if (text) return text;
  const title = cleanString(snapshot?.title);
  if (type === 'rich') return `[單頁圖文] ${title || '圖文訊息'}`;
  if (type === 'carousel') return `[多頁圖文] ${title || '多頁訊息'}`;
  return '[LINE 訊息]';
}

function buildTextLineMessage(snapshot) {
  const text = cleanString(snapshot.text);
  if (!text) {
    throw new Error('文字訊息內容不可空白。');
  }
  return {
    type: 'text',
    text: text.slice(0, 5000),
  };
}

function buildSystemRewardIssuedFlexMessage(data) {
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

function buildRichRewardIssuedFlexMessage(data, template) {
  const rewardName = cleanString(data.rewardName) || '兌換券';
  const couponUrl = couponActionUrl(cleanString(data.memberRewardId));
  const imageUrl = usableImageUrl(cleanString(template.imageUrl));
  if (!imageUrl) return buildSystemRewardIssuedFlexMessage(data);
  const title = cleanString(template.title) || rewardName;
  const description = cleanString(template.description);
  const actionLabel = cleanString(template.actionLabel) || '立即查看';
  const targetUrl = resolveTemplateUrl(template.targetUrl, couponUrl);
  const cardSize = normalizeRichCardSize(template.cardSize);

  return {
    type: 'flex',
    altText:
      cleanString(template.altText) || `${rewardName} 已確認，可以正常使用`,
    contents: {
      type: 'bubble',
      size: cardSize,
      hero: {
        type: 'image',
        url: imageUrl,
        size: 'full',
        aspectRatio: '1:1',
        aspectMode: 'cover',
      },
      body: {
        type: 'box',
        layout: 'vertical',
        contents: [
          {
            type: 'text',
            text: title,
            weight: 'bold',
            size: cardSize === 'kilo' ? 'md' : 'xl',
            wrap: true,
          },
          ...(description
            ? [
                {
                  type: 'text',
                  text: description,
                  margin: 'md',
                  size: cardSize === 'kilo' ? 'xs' : 'sm',
                  color: '#727577',
                  wrap: true,
                },
              ]
            : []),
        ],
      },
      ...(targetUrl
        ? {
            footer: {
              type: 'box',
              layout: 'vertical',
              contents: [
                {
                  type: 'button',
                  style: 'primary',
                  color: '#FF9812',
                  ...(cardSize === 'kilo' ? { height: 'sm' } : {}),
                  action: {
                    type: 'uri',
                    label: actionLabel,
                    uri: targetUrl,
                  },
                },
              ],
            },
          }
        : {}),
    },
  };
}

function normalizeRichCardSize(value) {
  const size = cleanString(value);
  if (size === 'kilo' || size === 'giga') return size;
  return 'mega';
}

function buildCarouselRewardIssuedFlexMessage(data, template) {
  const rewardName = cleanString(data.rewardName) || '兌換券';
  const couponUrl = couponActionUrl(cleanString(data.memberRewardId));
  const templateId = normalizeCarouselTemplateId(template.templateId);
  const cards = Array.isArray(template.cards)
    ? template.cards
        .filter(isPlainObject)
        .slice(0, 10)
        .map((card) => buildCarouselBubble(card, couponUrl, templateId))
    : [];
  if (cards.length === 0) return buildSystemRewardIssuedFlexMessage(data);

  return {
    type: 'flex',
    altText:
      cleanString(template.altText) || `${rewardName} 已確認，可以正常使用`,
    contents: {
      type: 'carousel',
      contents: cards,
    },
  };
}

function buildCarouselBubble(card, couponUrl, templateId) {
  const title = cleanString(card.title) || '會員好禮';
  const description = cleanString(card.description);
  const imageUrl = usableImageUrl(cleanString(card.imageUrl));
  const actionLabel = cleanString(card.actionLabel) || '立即查看';
  const actionUrl = resolveTemplateUrl(card.actionUrl, couponUrl);
  if (templateId === 'fullImage' && imageUrl) {
    return {
      type: 'bubble',
      size: 'mega',
      hero: {
        type: 'image',
        url: imageUrl,
        size: 'full',
        aspectRatio: '1:1',
        aspectMode: 'cover',
        ...(actionUrl
          ? {
              action: {
                type: 'uri',
                label: actionLabel,
                uri: actionUrl,
              },
            }
          : {}),
      },
    };
  }

  const compact = templateId === 'compact';

  return {
    type: 'bubble',
    ...(compact ? { size: 'deca' } : {}),
    ...(imageUrl
      ? {
          hero: {
            type: 'image',
            url: imageUrl,
            size: 'full',
            aspectRatio: compact ? '1:1' : '20:13',
            aspectMode: 'cover',
          },
        }
      : {}),
    body: {
      type: 'box',
      layout: 'vertical',
      ...(compact ? { paddingAll: '12px' } : {}),
      contents: [
        {
          type: 'text',
          text: title,
          weight: 'bold',
          size: compact ? 'md' : 'xl',
          wrap: true,
        },
        ...(description
          ? [
              {
                type: 'text',
                text: description,
                margin: 'md',
                size: compact ? 'xs' : 'sm',
                color: '#727577',
                wrap: true,
              },
            ]
          : []),
      ],
    },
    ...(actionUrl
      ? {
          footer: {
            type: 'box',
            layout: 'vertical',
            ...(compact ? { paddingAll: '8px' } : {}),
            contents: [
              {
                type: 'button',
                style: 'primary',
                color: '#FF9812',
                ...(compact ? { height: 'sm' } : {}),
                action: {
                  type: 'uri',
                  label: actionLabel,
                  uri: actionUrl,
                },
              },
            ],
          },
        }
      : {}),
  };
}

function normalizeCarouselTemplateId(value) {
  const templateId = cleanString(value);
  if (templateId === 'compact' || templateId === 'fullImage') {
    return templateId;
  }
  return 'standard';
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function couponActionUrl(memberRewardId) {
  const couponPath = memberRewardId
    ? `/coupons?reward=${encodeURIComponent(memberRewardId)}`
    : '/coupons';
  const liffId = cleanString(process.env.LINE_LIFF_ID) || defaultLiffId;
  return `https://liff.line.me/${liffId}${couponPath}`;
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

async function markLineMessageTest(testId, result) {
  await db
    .collection('lineMessageTests')
    .doc(testId)
    .set(
      {
        status: result.status,
        error: result.error ?? null,
        sentAt: result.status === 'sent' ? FieldValue.serverTimestamp() : null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}
