export function resolveTemplateUrl(value, couponUrl) {
  const configuredUrl = typeof value === 'string' ? value.trim() : '';
  if (!configuredUrl || isNoLinkValue(configuredUrl)) return null;
  if (configuredUrl === '{{couponUrl}}') return couponUrl;

  const resolved = configuredUrl.replaceAll('{{couponUrl}}', couponUrl);
  try {
    const url = new URL(resolved);
    return url.protocol === 'https:' || url.protocol === 'http:'
      ? resolved
      : null;
  } catch (_) {
    return null;
  }
}

function isNoLinkValue(value) {
  return ['無需連結', '無連結', '不需連結', 'none', 'no link'].includes(
    value.toLowerCase(),
  );
}
