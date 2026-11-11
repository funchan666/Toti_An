// Server-side helpers only. Do not expose service-account credentials to the app.
const publisherScope = 'https://www.googleapis.com/auth/androidpublisher';
const tokenEndpoint = 'https://oauth2.googleapis.com/token';
const packageName = 'com.toticonnect.meetcommuinity';

// This catalog is authoritative for crediting; never trust a client coin amount.
export const coinProducts: Readonly<Record<string, number>> = Object.freeze({
  'toti_coins_500.': 500,
  'toti_coins_1050': 1050,
  'toti_coins_1650': 1650,
  'toti_coins_2900': 2900,
  'toti_coins_6000': 6000,
  'toti_coins_12500': 12500,
  'toti_coins_33000': 33000,
  'toti_coins_72000': 72000,
  'toti_coins_115000': 115000,
});

type GooglePurchase = {
  purchaseState?: number;
  consumptionState?: number;
  productId?: string;
  orderId?: string;
  quantity?: number;
  obfuscatedExternalAccountId?: string;
};

function base64url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

function jsonBase64url(value: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(value)));
}

async function googleAccessToken(): Promise<string> {
  const raw = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new Error('Google Play service account is not configured');
  const credentials = JSON.parse(raw);
  if (typeof credentials.client_email !== 'string' ||
      typeof credentials.private_key !== 'string') {
    throw new Error('Invalid Google Play service account configuration');
  }
  const encodedKey = credentials.private_key
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const bytes = Uint8Array.from(atob(encodedKey), (character) => character.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8', bytes, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${jsonBase64url({ alg: 'RS256', typ: 'JWT' })}.${jsonBase64url({
    iss: credentials.client_email,
    scope: publisherScope,
    aud: tokenEndpoint,
    iat: now,
    exp: now + 3600,
  })}`;
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned),
  );
  const response = await fetch(tokenEndpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${base64url(new Uint8Array(signature))}`,
    }),
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error('Google authorization failed');
  const result = await response.json();
  if (typeof result.access_token !== 'string' || !result.access_token) {
    throw new Error('Google authorization failed');
  }
  return result.access_token;
}

function purchaseUrl(productId: string, purchaseToken: string): string {
  if (!Object.hasOwn(coinProducts, productId) ||
      purchaseToken.length < 1 || purchaseToken.length > 4096) {
    throw new Error('Invalid purchase');
  }
  return `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}` +
    `/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`;
}

// Call only from a server endpoint that first authenticates the Supabase user.
// A consumed purchase must never create a new credit; it may only confirm an
// existing ledger entry for this account and token during recovery.
export async function verifyGooglePurchase(
  productId: string,
  purchaseToken: string,
  expectedAccountId: string,
): Promise<{ coins: number; quantity: number; consumed: boolean; orderId: string | null }> {
  const url = purchaseUrl(productId, purchaseToken);
  if (!/^[a-f0-9]{64}$/.test(expectedAccountId)) throw new Error('Invalid account binding');
  const accessToken = await googleAccessToken();
  const response = await fetch(url, {
    headers: { authorization: `Bearer ${accessToken}` },
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error('Unable to verify purchase with Google Play');
  const purchase: GooglePurchase = await response.json();
  const quantity = purchase.quantity ?? 1;
  if (purchase.purchaseState !== 0 ||
      (purchase.consumptionState !== 0 && purchase.consumptionState !== 1) ||
      (purchase.productId != null && purchase.productId !== productId) ||
      purchase.obfuscatedExternalAccountId !== expectedAccountId ||
      !Number.isSafeInteger(quantity) || quantity < 1 || quantity > 100) {
    throw new Error('Purchase is not eligible for credit');
  }
  return {
    coins: coinProducts[productId] * quantity,
    quantity,
    consumed: purchase.consumptionState === 1,
    orderId: purchase.orderId ?? null,
  };
}

// Only consume after an atomic, idempotent server-side credit has been committed.
export async function consumeGooglePurchase(productId: string, purchaseToken: string): Promise<void> {
  const url = purchaseUrl(productId, purchaseToken);
  const accessToken = await googleAccessToken();
  const response = await fetch(`${url}:consume`, {
    method: 'POST',
    headers: { authorization: `Bearer ${accessToken}` },
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error('Unable to consume purchase with Google Play');
}
