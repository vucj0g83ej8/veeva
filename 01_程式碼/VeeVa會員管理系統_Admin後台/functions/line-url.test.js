import test from 'node:test';
import assert from 'node:assert/strict';
import { resolveTemplateUrl } from './line-url.js';

const couponUrl = 'https://liff.line.me/example/coupons';

test('keeps valid web URLs and replaces the coupon placeholder', () => {
  assert.equal(resolveTemplateUrl('https://veeva.web.app/member', couponUrl),
    'https://veeva.web.app/member');
  assert.equal(resolveTemplateUrl('{{couponUrl}}', couponUrl), couponUrl);
});

test('omits actions for no-link labels and invalid URI schemes', () => {
  assert.equal(resolveTemplateUrl('無需連結', couponUrl), null);
  assert.equal(resolveTemplateUrl('javascript:alert(1)', couponUrl), null);
  assert.equal(resolveTemplateUrl('not-a-url', couponUrl), null);
});
