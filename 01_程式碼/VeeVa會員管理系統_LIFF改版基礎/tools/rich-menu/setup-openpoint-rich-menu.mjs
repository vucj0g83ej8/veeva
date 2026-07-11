import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const CHANNEL_ACCESS_TOKEN = process.env.LINE_CHANNEL_ACCESS_TOKEN;
const IMAGE_PATH = fileURLToPath(new URL('./veeva-openpoint-rich-menu.jpg', import.meta.url));
const SURVEY_URL =
  process.env.VEEVA_RICH_MENU_SURVEY_URL ||
  process.env.VEEVA_RICH_MENU_URL ||
  'https://liff.line.me/2010298394-7PwRtpTY/activities/survey-coffee';
const INVITE_URL =
  process.env.VEEVA_RICH_MENU_INVITE_URL ||
  'https://liff.line.me/2010298394-7PwRtpTY/activities/survey-coffee?share=1';
const MEMBER_URL =
  process.env.VEEVA_RICH_MENU_MEMBER_URL ||
  'https://liff.line.me/2010298394-7PwRtpTY/member';

if (!CHANNEL_ACCESS_TOKEN) {
  console.error('Missing LINE_CHANNEL_ACCESS_TOKEN.');
  console.error('Usage: LINE_CHANNEL_ACCESS_TOKEN="..." node tools/rich-menu/setup-openpoint-rich-menu.mjs');
  process.exit(1);
}

const messagingApi = 'https://api.line.me/v2/bot';
const dataApi = 'https://api-data.line.me/v2/bot';

async function lineFetch(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${CHANNEL_ACCESS_TOKEN}`,
      ...(options.headers ?? {}),
    },
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(`${options.method ?? 'GET'} ${url} failed: ${response.status} ${text}`);
  }

  return text ? JSON.parse(text) : null;
}

async function main() {
  const richMenu = {
    size: {
      width: 2500,
      height: 1686,
    },
    selected: true,
    name: 'VeeVa 7-ELEVEN 商品卡問卷選單',
    chatBarText: '填問卷送商品卡',
    areas: [
      {
        bounds: {
          x: 0,
          y: 0,
          width: 2500,
          height: 966,
        },
        action: {
          type: 'uri',
          uri: SURVEY_URL,
        },
      },
      {
        bounds: {
          x: 0,
          y: 966,
          width: 833,
          height: 720,
        },
        action: {
          type: 'uri',
          uri: SURVEY_URL,
        },
      },
      {
        bounds: {
          x: 833,
          y: 966,
          width: 834,
          height: 720,
        },
        action: {
          type: 'uri',
          uri: INVITE_URL,
        },
      },
      {
        bounds: {
          x: 1667,
          y: 966,
          width: 833,
          height: 720,
        },
        action: {
          type: 'uri',
          uri: MEMBER_URL,
        },
      },
    ],
  };

  const created = await lineFetch(`${messagingApi}/richmenu`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(richMenu),
  });

  const image = await readFile(IMAGE_PATH);
  await lineFetch(`${dataApi}/richmenu/${created.richMenuId}/content`, {
    method: 'POST',
    headers: {
      'Content-Type': 'image/jpeg',
    },
    body: image,
  });

  await lineFetch(`${messagingApi}/user/all/richmenu/${created.richMenuId}`, {
    method: 'POST',
  });

  console.log(`Created rich menu: ${created.richMenuId}`);
  console.log(`Set as default rich menu.`);
  console.log(`Survey URL: ${SURVEY_URL}`);
  console.log(`Invite URL: ${INVITE_URL}`);
  console.log(`Member URL: ${MEMBER_URL}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
