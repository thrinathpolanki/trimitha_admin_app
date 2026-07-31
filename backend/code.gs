/**
 * ============================================================================
 *  PERSONAL ADMIN SYSTEM — BACKEND (Google Apps Script)
 * ============================================================================
 *  This single file is your ENTIRE backend / REST API.
 *  It talks to two Google Sheets ("Master" and "Blogs") and Google Drive.
 *
 *  HOW TO INSTALL — read SETUP_GUIDE.md first. Short version:
 *   1. Go to https://script.google.com -> New Project.
 *   2. Delete the default code, paste this whole file in.
 *   3. Run the function `setupProject` once (see guide) to auto-create
 *      your Sheets + Drive folder and print your Web App config.
 *   4. Deploy > New deployment > Web app > Execute as Me > Who has access:
 *      Anyone. Copy the Web App URL — every HTML page and the mobile app
 *      will call this same URL.
 * ============================================================================
 */

// ---------------------------------------------------------------------------
// 0. CONFIG — do not hardcode secrets here. Everything lives in
//    Script Properties (Project Settings > Script Properties) so this code
//    never has to be edited again after first setup.
// ---------------------------------------------------------------------------
const PROPS = PropertiesService.getScriptProperties();

const CONFIG = {
  get MASTER_SHEET_ID() { return PROPS.getProperty('MASTER_SHEET_ID'); },
  get BLOGS_SHEET_ID() { return PROPS.getProperty('BLOGS_SHEET_ID'); },
  get DRIVE_FOLDER_ID() { return PROPS.getProperty('DRIVE_FOLDER_ID'); },
  get ADMIN_USERNAME() { return PROPS.getProperty('ADMIN_USERNAME'); },
  get ADMIN_PASSWORD_HASH() { return PROPS.getProperty('ADMIN_PASSWORD_HASH'); },
  get API_KEY() { return PROPS.getProperty('API_KEY'); },
  get TOKEN_SECRET() { return PROPS.getProperty('TOKEN_SECRET'); },
  get ADMIN_EMAIL() { return PROPS.getProperty('ADMIN_EMAIL'); },
  get EMAIL_NOTIFICATIONS_ENABLED() { return PROPS.getProperty('EMAIL_NOTIFICATIONS_ENABLED') === 'true'; },
  // Paste the ENTIRE contents of the Firebase service-account JSON file here
  // (Firebase console > Project settings > Service accounts > Generate new
  // private key). Used to send real push notifications. See FIREBASE_SETUP.md.
  get FCM_SERVICE_ACCOUNT_JSON() { return PROPS.getProperty('FCM_SERVICE_ACCOUNT_JSON'); },
  get ALLOWED_ORIGINS() {
    const raw = PROPS.getProperty('ALLOWED_ORIGINS') || '';
    return raw.split(',').map(s => s.trim()).filter(Boolean);
  }
};

// Maps the "page" identifier sent by each website to the sheet it writes to.
const PAGE_TO_SHEET = {
  contact: 'Trimitha',
  index: 'Thrinath',
  portfolio: 'Thrinath',
  coo: 'Thripura'
};

const CONTACT_HEADERS = [
  'Timestamp', 'ContactID', 'Name', 'Email', 'Subject', 'Message',
  'Source', 'Status', 'Starred', 'Notes'
];
const COL = {}; // column index lookup, built once below
CONTACT_HEADERS.forEach((h, i) => COL[h] = i);

const BLOG_HEADERS = [
  'Timestamp', 'BlogID', 'Title', 'Category', 'Overview', 'Content', 'Status',
  'Image', 'Slug', 'Date', 'Author', 'Views', 'Featured', 'SEOKeywords',
  'MetaDescription', 'Deleted'
];
const BLOG_COL = {};
BLOG_HEADERS.forEach((h, i) => BLOG_COL[h] = i);

// ---------------------------------------------------------------------------
// 1. ONE-TIME SETUP — run this manually from the script editor.
//    SELF-HEALING: safe to run again any time. It checks what already
//    exists (spreadsheet, each tab, each header row, the Drive folder) and
//    only creates whatever is missing — it will never wipe existing data.
//    If your sheets are missing tabs or columns right now, just run this
//    function again to repair them.
// ---------------------------------------------------------------------------
function setupProject() {
  // 1a. Master spreadsheet with its 3 contact sheets
  const masterSS = ensureSpreadsheet_('MASTER_SHEET_ID', 'Master');
  ['Trimitha', 'Thrinath', 'Thripura'].forEach(name => ensureSheetTab_(masterSS, name, CONTACT_HEADERS));
  removeLeftoverDefaultTab_(masterSS);

  // 1b. Blogs spreadsheet
  const blogsSS = ensureSpreadsheet_('BLOGS_SHEET_ID', 'Blogs');
  ensureSheetTab_(blogsSS, 'Blogs', BLOG_HEADERS);
  removeLeftoverDefaultTab_(blogsSS);

  // 1c. Drive folder for blog images
  const folderId = ensureDriveFolder_();

  // 1d. Admin account — CHANGE THIS PASSWORD IMMEDIATELY after first login
  //     via the changePassword API (or by running setMyPassword() below).
  //     This default only exists so you can log in the very first time.
  if (!PROPS.getProperty('ADMIN_USERNAME')) {
    PROPS.setProperty('ADMIN_USERNAME', 'admin');
    PROPS.setProperty('ADMIN_PASSWORD_HASH', hash_('ChangeMe123!'));
  }

  // 1e. API key (used by the public website forms, NOT a secret admin key)
  if (!PROPS.getProperty('API_KEY')) {
    PROPS.setProperty('API_KEY', Utilities.getUuid());
  }

  // 1f. Token signing secret (used for admin login sessions)
  if (!PROPS.getProperty('TOKEN_SECRET')) {
    PROPS.setProperty('TOKEN_SECRET', Utilities.getUuid() + Utilities.getUuid());
  }

  // 1g. Where notification emails would go IF you ever turn them on —
  //     defaults to your own account, but emails are OFF (see 1g2).
  if (!PROPS.getProperty('ADMIN_EMAIL')) {
    PROPS.setProperty('ADMIN_EMAIL', Session.getEffectiveUser().getEmail());
  }

  // 1g2. Email notifications — explicitly OFF. Contact form submissions
  //      never send you an email; real-time alerts belong to the mobile
  //      app (Phase 3), which polls /dashboard and /notifications instead.
  if (!PROPS.getProperty('EMAIL_NOTIFICATIONS_ENABLED')) {
    PROPS.setProperty('EMAIL_NOTIFICATIONS_ENABLED', 'false');
  }

  Logger.log('=========================================================');
  Logger.log('SETUP COMPLETE (or repaired). Save these values:');
  Logger.log('Master Sheet URL: https://docs.google.com/spreadsheets/d/' + masterSS.getId());
  Logger.log('Blogs Sheet URL: https://docs.google.com/spreadsheets/d/' + blogsSS.getId());
  Logger.log('Drive Folder ID: ' + folderId);
  Logger.log('Website API_KEY (public, safe to put in website JS): ' + PROPS.getProperty('API_KEY'));
  Logger.log('Default admin login -> username: admin | password: ChangeMe123! (unless you already changed it)');
  Logger.log('Email notifications: OFF (no email is ever sent on form submission unless you run enableEmailNotifications())');
  Logger.log('=========================================================');
}

// Opens the spreadsheet if a valid ID is already stored; otherwise creates
// a new one and stores its ID. Handles the case where the stored ID is
// stale (e.g. the file was deleted) by recreating it.
function ensureSpreadsheet_(propKey, name) {
  const id = PROPS.getProperty(propKey);
  if (id) {
    try {
      return SpreadsheetApp.openById(id);
    } catch (err) {
      Logger.log('Stored ' + propKey + ' was invalid, creating a new spreadsheet.');
    }
  }
  const ss = SpreadsheetApp.create(name);
  PROPS.setProperty(propKey, ss.getId());
  return ss;
}

// Creates the tab if it doesn't exist, and writes the header row if it's
// missing — but never touches a tab that already has data in row 1.
function ensureSheetTab_(ss, sheetName, headers) {
  let sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    sheet = ss.insertSheet(sheetName);
  }
  const firstRow = sheet.getRange(1, 1, 1, Math.max(1, sheet.getLastColumn())).getValues()[0];
  const hasHeaders = firstRow.join('') !== '';
  if (!hasHeaders) {
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.setFrozenRows(1);
  }
  return sheet;
}

// Google auto-creates a "Sheet1" tab on every new spreadsheet. Remove it
// once our real tabs exist, but only if it's still empty and unused.
function removeLeftoverDefaultTab_(ss) {
  const def = ss.getSheetByName('Sheet1');
  if (def && ss.getSheets().length > 1 && def.getLastRow() === 0) {
    ss.deleteSheet(def);
  }
}

// Verifies the stored Drive folder still exists; recreates/finds it if not.
function ensureDriveFolder_() {
  const id = PROPS.getProperty('DRIVE_FOLDER_ID');
  if (id) {
    try {
      DriveApp.getFolderById(id);
      return id;
    } catch (err) {
      Logger.log('Stored DRIVE_FOLDER_ID was invalid, locating/creating the folder again.');
    }
  }
  const existing = DriveApp.getFoldersByName('Blog Images');
  const folder = existing.hasNext() ? existing.next() : DriveApp.createFolder('Blog Images');
  PROPS.setProperty('DRIVE_FOLDER_ID', folder.getId());
  return folder.getId();
}

// ---------------------------------------------------------------------------
// 1h. MIGRATION — run this ONCE after updating to this version of Code.gs
//     if you already had data in the old (16-column) schema.
// ---------------------------------------------------------------------------

// Converts your 3 contact tabs to the new 10-column schema
// (Timestamp, ContactID, Name, Email, Subject, Message, Source, Status,
// Starred, Notes). Safe to run once — it re-maps every existing row by
// COLUMN NAME (not position), so old data lands in the right place and
// any column you're removing (like the old Phone/IP/Device columns) is
// simply dropped.
function migrateContactSheetsToNewSchema() {
  ['Trimitha', 'Thrinath', 'Thripura'].forEach(name => {
    const sheet = getSheet_(CONFIG.MASTER_SHEET_ID, name);
    const values = sheet.getDataRange().getValues();
    if (values.length === 0) {
      sheet.getRange(1, 1, 1, CONTACT_HEADERS.length).setValues([CONTACT_HEADERS]);
      sheet.setFrozenRows(1);
      return;
    }
    const oldHeaders = values[0];
    const oldRows = values.slice(1);

    const newRows = oldRows.map(row =>
      CONTACT_HEADERS.map(h => {
        const idx = oldHeaders.indexOf(h);
        return idx === -1 ? '' : row[idx];
      })
    );

    sheet.clearContents();
    sheet.getRange(1, 1, 1, CONTACT_HEADERS.length).setValues([CONTACT_HEADERS]);
    if (newRows.length) {
      sheet.getRange(2, 1, newRows.length, CONTACT_HEADERS.length).setValues(newRows);
    }
    sheet.setFrozenRows(1);
  });
  Logger.log('Contact sheets migrated to: ' + CONTACT_HEADERS.join(', '));
}

// Converts the Blogs tab to the current schema (re-maps everything by
// column name, dropping anything no longer in BLOG_HEADERS). Safe to run
// once, any time your sheet's columns have drifted from BLOG_HEADERS.
function migrateBlogsSheetToNewSchema() {
  const sheet = getSheet_(CONFIG.BLOGS_SHEET_ID, 'Blogs');
  const values = sheet.getDataRange().getValues();
  if (values.length === 0) {
    sheet.getRange(1, 1, 1, BLOG_HEADERS.length).setValues([BLOG_HEADERS]);
    sheet.setFrozenRows(1);
    return;
  }
  const oldHeaders = values[0];
  const oldRows = values.slice(1);

  const newRows = oldRows.map(row =>
    BLOG_HEADERS.map(h => {
      const idx = oldHeaders.indexOf(h);
      return idx !== -1 ? row[idx] : '';
    })
  );

  sheet.clearContents();
  sheet.getRange(1, 1, 1, BLOG_HEADERS.length).setValues([BLOG_HEADERS]);
  if (newRows.length) {
    sheet.getRange(2, 1, newRows.length, BLOG_HEADERS.length).setValues(newRows);
  }
  sheet.setFrozenRows(1);
  Logger.log('Blogs sheet migrated to: ' + BLOG_HEADERS.join(', '));
}

// ---------------------------------------------------------------------------
// 1i. OPTIONAL ONE-OFF HELPERS — run these manually from the script editor
//     whenever you want to change a setting. Each is safe to run any time.
// ---------------------------------------------------------------------------

// Sets your own admin password instead of the default "ChangeMe123!".
// EDIT the string below, select "setMyPassword" in the function dropdown,
// click Run, then change the string back to something you don't mind
// leaving in the file (it will just overwrite the same hash again).
function setMyPassword() {
  const myNewPassword = 'Thrinath+Susmitha26';
  if (myNewPassword.length < 8) {
    Logger.log('Password must be at least 8 characters. Nothing was changed.');
    return;
  }
  PROPS.setProperty('ADMIN_PASSWORD_HASH', hash_(myNewPassword));
  Logger.log('Admin password updated. You can now log in with the new password.');
}

// Restricts which websites are allowed to submit the contact form.
// Run this once you know your live domain(s). Leave it un-run (or set to
// an empty string) while you're still testing locally — when
// ALLOWED_ORIGINS is empty, the check is skipped entirely.
function setAllowedOrigins() {
  const myDomains = [
    'https://trimitha.co.in',
    'https://www.trimitha.co.in',
    'https://polankithrinath.co.in'
    // add every real domain your 5 pages will be hosted on, exact match
    // including https:// and no trailing slash
  ];
  PROPS.setProperty('ALLOWED_ORIGINS', myDomains.join(','));
  Logger.log('Allowed origins set to: ' + myDomains.join(', '));
}

// ---------------------------------------------------------------------------
// NOTIFICATIONS — off by default. Real-time alerts go to the mobile app
// (Phase 3) via polling /dashboard (unreadNotifications count) and
// /notifications (the actual list), not email. Run enableEmailNotifications()
// only if you ALSO want a backup email for every submission.
// ---------------------------------------------------------------------------
function enableEmailNotifications() {
  PROPS.setProperty('EMAIL_NOTIFICATIONS_ENABLED', 'true');
  Logger.log('Email notifications are now ON.');
}

function disableEmailNotifications() {
  PROPS.setProperty('EMAIL_NOTIFICATIONS_ENABLED', 'false');
  Logger.log('Email notifications are now OFF.');
}

// ---------------------------------------------------------------------------
// 2. ENTRY POINTS
// ---------------------------------------------------------------------------


function doGet(e) {
  try {
    const action = e.parameter.action;
    let result;
    switch (action) {
      case 'blogs': result = listBlogs_(e.parameter); break;
      case 'adminBlogs': result = withAuth_(e, () => listBlogsAdmin_(e.parameter)); break;
      case 'blog': result = getBlog_(e.parameter.slug); break;
      case 'dashboard': result = withAuth_(e, dashboard_); break;
      case 'whoami': result = whoAmI_(e.parameter.token); break;
      case 'forms': result = withAuth_(e, () => listForms_(e.parameter)); break;
      case 'search': result = withAuth_(e, () => searchAll_(e.parameter.q)); break;
      case 'statistics': result = withAuth_(e, () => statistics_(e.parameter)); break;
      case 'notifications': result = withAuth_(e, () => listNotifications_(e.parameter)); break;
      case 'export': result = withAuth_(e, () => exportData_(e.parameter.type)); break;
      default: result = { success: false, error: 'Unknown action: ' + action };
    }
    return jsonOut_(result);
  } catch (err) {
    return jsonOut_({ success: false, error: String(err) });
  }
}

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const action = data.action;
    let result;
    switch (action) {
      case 'submitForm': result = submitContact_(data); break;
      case 'login': result = login_(data); break;
      case 'changePassword': result = withAuth_(data, () => changePassword_(data)); break;
      case 'deleteContact': result = withAuth_(data, () => deleteContact_(data)); break;
      case 'updateContact': result = withAuth_(data, () => updateContact_(data)); break;
      case 'createBlog': result = withAuth_(data, () => createBlog_(data)); break;
      case 'updateBlog': result = withAuth_(data, () => updateBlog_(data)); break;
      case 'deleteBlog': result = withAuth_(data, () => deleteBlog_(data)); break;
      case 'incrementView': result = incrementView_(data.slug); break;
      case 'uploadImage': result = withAuth_(data, () => uploadImage_(data)); break;
      case 'markNotificationRead': result = withAuth_(data, () => markNotificationRead_(data)); break;
      case 'markAllRead': result = withAuth_(data, markAllNotificationsRead_); break;
      case 'registerDevice': result = withAuth_(data, () => registerDevice_(data)); break;
      case 'unregisterDevice': result = withAuth_(data, () => unregisterDevice_(data)); break;
      default: result = { success: false, error: 'Unknown action: ' + action };
    }
    return jsonOut_(result);
  } catch (err) {
    return jsonOut_({ success: false, error: String(err) });
  }
}

// ---------------------------------------------------------------------------
// 3. AUTH HELPERS
// ---------------------------------------------------------------------------
function hash_(str) {
  const bytes = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, str);
  return bytes.map(b => ('0' + (b & 0xFF).toString(16)).slice(-2)).join('');
}

function login_(data) {
  if (data.username !== CONFIG.ADMIN_USERNAME || hash_(data.password) !== CONFIG.ADMIN_PASSWORD_HASH) {
    return { success: false, error: 'Invalid username or password' };
  }
  const expiry = Date.now() + (1000 * 60 * 60 * 24 * 7); // 7 day session
  const payload = data.username + '|' + expiry;
  const sig = hash_(payload + CONFIG.TOKEN_SECRET);
  const token = Utilities.base64EncodeWebSafe(payload + '|' + sig);
  return { success: true, token: token, expiresAt: expiry };
}

function verifyToken_(token) {
  try {
    const decoded = Utilities.newBlob(Utilities.base64DecodeWebSafe(token)).getDataAsString();
    const parts = decoded.split('|');
    const username = parts[0], expiry = Number(parts[1]), sig = parts[2];
    if (Date.now() > expiry) return null;
    const expectedSig = hash_(username + '|' + expiry + CONFIG.TOKEN_SECRET);
    if (sig !== expectedSig) return null;
    return username;
  } catch (err) {
    return null;
  }
}

// Wraps any admin-only function. `src` is either the doGet event (has
// e.parameter.token) or the doPost JSON body (has data.token).
function withAuth_(src, fn) {
  const token = src.parameter ? src.parameter.token : src.token;
  const username = verifyToken_(token);
  if (!username) return { success: false, error: 'Unauthorized. Please log in again.' };
  return fn();
}

// Lets the app display who's logged in (Settings screen profile header)
// without needing a separate "get profile" data model.
function whoAmI_(token) {
  const username = verifyToken_(token);
  if (!username) return { success: false, error: 'Unauthorized. Please log in again.' };
  return { success: true, username: username };
}

function changePassword_(data) {
  if (hash_(data.oldPassword) !== CONFIG.ADMIN_PASSWORD_HASH) {
    return { success: false, error: 'Old password is incorrect' };
  }
  if (!data.newPassword || data.newPassword.length < 8) {
    return { success: false, error: 'New password must be at least 8 characters' };
  }
  PROPS.setProperty('ADMIN_PASSWORD_HASH', hash_(data.newPassword));
  return { success: true, message: 'Password updated' };
}

// ---------------------------------------------------------------------------
// 4. CONTACT FORM SUBMISSION (public — protected by API key + rate limit)
// ---------------------------------------------------------------------------
function submitContact_(data) {
  // API key check (public key, just stops random bots hitting the endpoint)
  if (data.apiKey !== CONFIG.API_KEY) {
    return { success: false, error: 'Invalid request' };
  }

  // Origin check — ONLY enforced once you've run setAllowedOrigins().
  // IMPORTANT LIMITATION: Apps Script web apps cannot read the real HTTP
  // Origin header, so this checks the origin the CLIENT reports about
  // itself, which a determined attacker could fake. Treat this as a soft
  // "keep honest scrapers off my key" layer, not real CORS enforcement —
  // the API key + rate limit + honeypot + duplicate check below are your
  // real protection.
  const allowed = CONFIG.ALLOWED_ORIGINS;
  if (allowed.length && data.origin && !allowed.includes(data.origin)) {
    return { success: false, error: 'Request origin not allowed' };
  }

  // Honeypot: a hidden field named "website" that real users never fill in
  if (data.website) {
    return { success: true }; // silently pretend success to the bot
  }

  const sheetName = PAGE_TO_SHEET[data.page];
  if (!sheetName) return { success: false, error: 'Invalid page identifier' };

  if (!data.name || !data.email || !data.message) {
    return { success: false, error: 'Name, email and message are required' };
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email)) {
    return { success: false, error: 'Invalid email address' };
  }

  // Rate limit: max 1 submission per 20 seconds per IP+page (best effort —
  // Apps Script does not give a reliable client IP, so this uses whatever
  // the client reports; treat as a soft protection layer, not a hard one)
  const cache = CacheService.getScriptCache();
  const rateKey = 'rl_' + (data.clientId || 'anon') + '_' + data.page;
  if (cache.get(rateKey)) {
    return { success: false, error: 'Please wait before submitting again' };
  }
  cache.put(rateKey, '1', 20);

  // Duplicate detection: same email+message in the last 5 minutes
  const sheet = getSheet_(CONFIG.MASTER_SHEET_ID, sheetName);
  const values = sheet.getDataRange().getValues();
  const fiveMinAgo = Date.now() - 5 * 60 * 1000;
  for (let i = values.length - 1; i > 0 && i > values.length - 20; i--) {
    const row = values[i];
    if (row[COL.Email] === data.email && row[COL.Message] === data.message && new Date(row[COL.Timestamp]).getTime() > fiveMinAgo) {
      return { success: false, error: 'Duplicate submission detected' };
    }
  }

  const contactId = Utilities.getUuid();
  // Row order MUST match CONTACT_HEADERS exactly:
  // Timestamp, ContactID, Name, Email, Subject, Message, Source, Status, Starred, Notes
  sheet.appendRow([
    new Date(), contactId,
    sanitize_(data.name), sanitize_(data.email),
    sanitize_(data.subject || 'General Inquiry'), sanitize_(data.message),
    data.page, 'Unread', false, ''
  ]);

  // Email is OFF by default — see NOTIFICATIONS section below.
  if (CONFIG.EMAIL_NOTIFICATIONS_ENABLED) {
    notifyAdmin_(sheetName, data);
  }

  // Real push notification (Firebase Cloud Messaging) — this is what
  // actually alerts the phone even when the app is fully closed. Runs
  // regardless of the email toggle above; silently does nothing if
  // FIREBASE_SETUP.md hasn't been completed yet (see sendPushToAllDevices_).
  sendPushToAllDevices_(
    'New ' + sheetName + ' contact',
    sanitize_(data.name) + ': ' + sanitize_(data.subject || 'General Inquiry'),
    { type: 'contact', sheet: sheetName, contactId: contactId }
  );

  return { success: true, contactId: contactId };
}

// Basic XSS protection — strips tags. Sheets store text, not HTML, so this
// mainly protects any place the frontend later renders this text as HTML.
function sanitize_(str) {
  return String(str).replace(/<[^>]*>/g, '').trim().slice(0, 5000);
}

function notifyAdmin_(sheetName, data) {
  // Only called when EMAIL_NOTIFICATIONS_ENABLED is turned on — off by
  // default. Real-time alerts for the mobile app come from polling
  // /dashboard and /notifications instead (see Phase 3).
  try {
    MailApp.sendEmail({
      to: CONFIG.ADMIN_EMAIL,
      subject: '🔔 New ' + sheetName + ' contact: ' + data.name,
      htmlBody:
        '<h3>New contact form submission</h3>' +
        '<p><b>Source:</b> ' + sheetName + ' (' + data.page + ')</p>' +
        '<p><b>Name:</b> ' + sanitize_(data.name) + '</p>' +
        '<p><b>Email:</b> ' + sanitize_(data.email) + '</p>' +
        '<p><b>Subject:</b> ' + sanitize_(data.subject || '-') + '</p>' +
        '<p><b>Message:</b><br>' + sanitize_(data.message) + '</p>'
    });
  } catch (err) {
    // Email quota exceeded or similar — never let this break form submission
    Logger.log('Notification email failed: ' + err);
  }
}

// ---------------------------------------------------------------------------
// PUSH NOTIFICATIONS (Firebase Cloud Messaging, HTTP v1 API)
//
// This is what makes the mobile app get a real notification even when it's
// fully closed. Setup required — see FIREBASE_SETUP.md — otherwise every
// function below is a safe no-op (checked via CONFIG.FCM_SERVICE_ACCOUNT_JSON).
// ---------------------------------------------------------------------------

// Registered device tokens are stored as a single JSON array under one
// Script Property. Fine at this scale (one admin, a handful of devices);
// swap for a "Devices" sheet if you ever need more than that.
function getDeviceTokens_() {
  const raw = PROPS.getProperty('DEVICE_TOKENS');
  if (!raw) return [];
  try {
    const arr = JSON.parse(raw);
    return Array.isArray(arr) ? arr : [];
  } catch (err) {
    return [];
  }
}

function saveDeviceTokens_(tokens) {
  PROPS.setProperty('DEVICE_TOKENS', JSON.stringify(tokens));
}

// Called by the app (action=registerDevice) right after login / whenever
// FCM hands it a fresh token.
function registerDevice_(data) {
  if (!data.fcmToken) return { success: false, error: 'Missing fcmToken' };
  const tokens = getDeviceTokens_();
  if (tokens.indexOf(data.fcmToken) === -1) {
    tokens.push(data.fcmToken);
    saveDeviceTokens_(tokens);
  }
  return { success: true };
}

// Called by the app (action=unregisterDevice) on explicit logout, so a
// signed-out device stops receiving pushes meant for the admin.
function unregisterDevice_(data) {
  if (data.fcmToken) {
    saveDeviceTokens_(getDeviceTokens_().filter(function (t) { return t !== data.fcmToken; }));
  }
  return { success: true };
}

function removeDeviceTokens_(staleTokens) {
  if (!staleTokens.length) return;
  const remaining = getDeviceTokens_().filter(function (t) { return staleTokens.indexOf(t) === -1; });
  saveDeviceTokens_(remaining);
}

// Base64url-encodes a UTF-8 string per RFC 7515 (no padding), needed for JWT.
function base64UrlEncode_(str) {
  return Utilities.base64EncodeWebSafe(Utilities.newBlob(str).getBytes()).replace(/=+$/, '');
}

// Exchanges the Firebase service-account key for a short-lived OAuth2
// access token (self-signed JWT -> Google's token endpoint), which is what
// FCM's HTTP v1 API requires instead of the old legacy server-key scheme.
// Cached for ~50 minutes at a time to avoid re-signing on every call.
function getFcmAccessToken_() {
  const cache = CacheService.getScriptCache();
  const cached = cache.get('fcm_access_token');
  if (cached) return cached;

  const svc = JSON.parse(CONFIG.FCM_SERVICE_ACCOUNT_JSON);
  const nowSec = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claimSet = {
    iss: svc.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: nowSec,
    exp: nowSec + 3600
  };

  const toSign = base64UrlEncode_(JSON.stringify(header)) + '.' + base64UrlEncode_(JSON.stringify(claimSet));
  const signatureBytes = Utilities.computeRsaSha256Signature(toSign, svc.private_key);
  const jwt = toSign + '.' + Utilities.base64EncodeWebSafe(signatureBytes).replace(/=+$/, '');

  const resp = UrlFetchApp.fetch('https://oauth2.googleapis.com/token', {
    method: 'post',
    contentType: 'application/x-www-form-urlencoded',
    payload: {
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    },
    muteHttpExceptions: true
  });

  const json = JSON.parse(resp.getContentText());
  if (!json.access_token) {
    throw new Error('FCM auth failed: ' + resp.getContentText());
  }
  // Cache for a bit less than the token's real lifetime, to be safe.
  cache.put('fcm_access_token', json.access_token, (json.expires_in || 3600) - 60);
  return json.access_token;
}

// Sends `title`/`body` (+ optional `data` payload) to every registered
// device via FCM's HTTP v1 API. Never throws — a push failure (or push not
// being configured at all yet) must never break a form submission.
function sendPushToAllDevices_(title, body, data) {
  try {
    if (!CONFIG.FCM_SERVICE_ACCOUNT_JSON) return; // not set up yet — no-op
    const tokens = getDeviceTokens_();
    if (!tokens.length) return;

    const projectId = JSON.parse(CONFIG.FCM_SERVICE_ACCOUNT_JSON).project_id;
    const accessToken = getFcmAccessToken_();
    const url = 'https://fcm.googleapis.com/v1/projects/' + projectId + '/messages:send';

    const stringData = {};
    Object.keys(data || {}).forEach(function (k) { stringData[k] = String(data[k]); });

    const staleTokens = [];
    tokens.forEach(function (token) {
      const message = {
        message: {
          token: token,
          notification: { title: title, body: body },
          android: {
            priority: 'high',
            notification: { channel_id: 'contact_submissions' }
          },
          data: stringData
        }
      };
      const resp = UrlFetchApp.fetch(url, {
        method: 'post',
        contentType: 'application/json; charset=UTF-8',
        headers: { Authorization: 'Bearer ' + accessToken },
        payload: JSON.stringify(message),
        muteHttpExceptions: true
      });
      const code = resp.getResponseCode();
      if (code >= 400) {
        const text = resp.getContentText();
        // Token no longer valid (app uninstalled, token rotated, etc) —
        // stop trying to push to it.
        if (text.indexOf('UNREGISTERED') !== -1 || text.indexOf('NOT_FOUND') !== -1 ||
            text.indexOf('INVALID_ARGUMENT') !== -1) {
          staleTokens.push(token);
        } else {
          Logger.log('FCM send failed (' + code + '): ' + text);
        }
      }
    });

    removeDeviceTokens_(staleTokens);
  } catch (err) {
    Logger.log('sendPushToAllDevices_ failed: ' + err);
  }
}

// ---------------------------------------------------------------------------
// 5. CONTACT / FORMS MANAGEMENT (admin only)
// ---------------------------------------------------------------------------
function listForms_(params) {
  const sheetName = params.sheet; // Trimitha | Thrinath | Thripura
  if (!['Trimitha', 'Thrinath', 'Thripura'].includes(sheetName)) {
    return { success: false, error: 'Invalid sheet name' };
  }
  const sheet = getSheet_(CONFIG.MASTER_SHEET_ID, sheetName);
  const values = sheet.getDataRange().getValues();
  const headers = values[0];
  let rows = values.slice(1).map((row, idx) => rowToObj_(headers, row, idx + 2));

  if (params.search) {
    const q = params.search.toLowerCase();
    rows = rows.filter(r =>
      String(r.Name).toLowerCase().includes(q) ||
      String(r.Email).toLowerCase().includes(q) ||
      String(r.Message).toLowerCase().includes(q));
  }
  if (params.status) rows = rows.filter(r => r.Status === params.status);
  if (params.starred === 'true') rows = rows.filter(r => r.Starred === true);

  rows.sort((a, b) => new Date(b.Timestamp) - new Date(a.Timestamp)); // newest first
  return { success: true, data: rows, total: rows.length };
}

function rowToObj_(headers, row, rowNumber) {
  const obj = { _row: rowNumber };
  headers.forEach((h, i) => obj[h] = row[i]);
  return obj;
}

function updateContact_(data) {
  const sheet = getSheet_(CONFIG.MASTER_SHEET_ID, data.sheet);
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  if (data.status !== undefined) sheet.getRange(data.row, headers.indexOf('Status') + 1).setValue(data.status);
  if (data.starred !== undefined) sheet.getRange(data.row, headers.indexOf('Starred') + 1).setValue(data.starred);
  if (data.notes !== undefined) sheet.getRange(data.row, headers.indexOf('Notes') + 1).setValue(data.notes);
  return { success: true };
}

function deleteContact_(data) {
  // Soft delete: mark Status = "Deleted" instead of removing the row,
  // so nothing is ever permanently lost (acts as your Recycle Bin).
  const sheet = getSheet_(CONFIG.MASTER_SHEET_ID, data.sheet);
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  sheet.getRange(data.row, headers.indexOf('Status') + 1).setValue('Deleted');
  return { success: true };
}

// ---------------------------------------------------------------------------
// 6. BLOG — public read
// ---------------------------------------------------------------------------
// Apps Script's biggest latency cost for a public blog page is re-reading
// the whole sheet on every request. These cache the read-heavy parts for a
// short window (CacheService, 30s) so repeat page loads are much faster;
// any write (new/edited post, like, comment) busts the cache immediately
// so nobody ever sees stale data for more than an instant.
function getPublishedBlogsCached_() {
  const cache = CacheService.getScriptCache();
  const cached = cache.get('blogs_published_v1');
  if (cached) return JSON.parse(cached);

  const sheet = getSheet_(CONFIG.BLOGS_SHEET_ID, 'Blogs');
  const values = sheet.getDataRange().getValues();
  const headers = values[0];
  const rows = values.slice(1)
    .map((row, idx) => rowToObj_(headers, row, idx + 2))
    .filter(r => r.Status === 'Published' && !r.Deleted);

  cache.put('blogs_published_v1', JSON.stringify(rows), 30);
  return rows;
}

function bustBlogsCache_() {
  const cache = CacheService.getScriptCache();
  cache.remove('blogs_published_v1');
}

function listBlogs_(params) {
  let rows = getPublishedBlogsCached_();

  if (params.category) rows = rows.filter(r => r.Category === params.category);
  if (params.search) {
    const q = params.search.toLowerCase();
    rows = rows.filter(r => String(r.Title).toLowerCase().includes(q) || String(r.Overview).toLowerCase().includes(q));
  }
  rows.sort((a, b) => new Date(b.Date || b.Timestamp) - new Date(a.Date || a.Timestamp));

  const page = Number(params.page || 1);
  const pageSize = Number(params.pageSize || 9);
  const start = (page - 1) * pageSize;
  const paged = rows.slice(start, start + pageSize);
  const featured = rows.find(r => r.Featured === true);

  // Never leak internal columns to the public. Includes full Content now —
  // opening an article no longer makes a second network call, it just
  // reads this same data already sitting in the browser. Falls back to
  // Timestamp if Date (publish date) was left blank — e.g. a row added by hand.
  const strip = r => ({
    Title: r.Title, Category: r.Category, Overview: r.Overview, Content: r.Content, Image: r.Image,
    Slug: r.Slug, Date: r.Date || r.Timestamp, Author: r.Author, Views: Number(r.Views) || 0,
    Featured: r.Featured
  });

  return { success: true, data: paged.map(strip), total: rows.length, page, pageSize, featured: featured ? strip(featured) : null };
}

// Admin-only variant of listBlogs_ — returns EVERY status (Draft,
// Published, Archived), with row numbers, so the mobile app's Blog
// Management screen can see and manage drafts. The public listBlogs_
// deliberately only ever shows Published posts to the website; this is
// separate on purpose so that distinction can never leak.
function listBlogsAdmin_(params) {
  const sheet = getSheet_(CONFIG.BLOGS_SHEET_ID, 'Blogs');
  const values = sheet.getDataRange().getValues();
  const headers = values[0];
  let rows = values.slice(1)
    .map((row, idx) => rowToObj_(headers, row, idx + 2))
    .filter(r => !r.Deleted);

  if (params.status) rows = rows.filter(r => r.Status === params.status);
  if (params.search) {
    const q = params.search.toLowerCase();
    rows = rows.filter(r => String(r.Title).toLowerCase().includes(q));
  }
  rows.sort((a, b) => new Date(b.Date || b.Timestamp) - new Date(a.Date || a.Timestamp));

  return { success: true, data: rows, total: rows.length };
}

function getBlog_(slug) {
  if (!slug) return { success: false, error: 'Missing slug' };
  const sheet = getSheet_(CONFIG.BLOGS_SHEET_ID, 'Blogs');
  const values = sheet.getDataRange().getValues();
  const headers = values[0];
  const slugCol = headers.indexOf('Slug');
  // row[slugCol] must itself be non-empty — otherwise a blank Slug cell
  // (e.g. a row typed directly into the sheet) could match an empty query.
  const idx = values.findIndex((row, i) => i > 0 && row[slugCol] && row[slugCol] === slug);
  if (idx === -1) return { success: false, error: 'Blog not found' };

  const rowNum = idx + 1;
  const obj = rowToObj_(headers, values[idx], rowNum + 1);
  if (obj.Status !== 'Published' || obj.Deleted) return { success: false, error: 'Blog not found' };

  // Increment views
  const viewsCol = headers.indexOf('Views') + 1;
  sheet.getRange(rowNum + 1, viewsCol).setValue((Number(obj.Views) || 0) + 1);

  // Fall back to Timestamp if Date (publish date) was left blank
  if (!obj.Date) obj.Date = obj.Timestamp;
  obj.Views = (Number(obj.Views) || 0) + 1; // reflects the increment just made above

  // Related blogs: same category, excluding this one
  const related = values.slice(1)
    .map((row, i) => rowToObj_(headers, row, i + 2))
    .filter(r => r.Status === 'Published' && !r.Deleted && r.Category === obj.Category && r.Slug !== slug)
    .slice(0, 3)
    .map(r => ({ Title: r.Title, Image: r.Image, Slug: r.Slug, Date: r.Date || r.Timestamp }));

  delete obj._row;
  return { success: true, data: obj, related: related };
}

// Deliberately tiny and isolated: just bumps Views for one post by slug.
// The frontend calls this in the background, without waiting for it, right
// after opening a post using data it already has in memory — so a slow or
// even failing view-count update can never block or break opening the
// article itself.
function incrementView_(slug) {
  if (!slug) return { success: false, error: 'Missing slug' };
  const sheet = getSheet_(CONFIG.BLOGS_SHEET_ID, 'Blogs');
  const values = sheet.getDataRange().getValues();
  const headers = values[0];
  const slugCol = headers.indexOf('Slug');
  const viewsCol = headers.indexOf('Views');
  const idx = values.findIndex((row, i) => i > 0 && row[slugCol] && row[slugCol] === slug);
  if (idx === -1) return { success: false, error: 'Post not found' };

  const updated = (Number(values[idx][viewsCol]) || 0) + 1;
  sheet.getRange(idx + 1, viewsCol + 1).setValue(updated);
  bustBlogsCache_();
  return { success: true, views: updated };
}

// ---------------------------------------------------------------------------
// 7. BLOG MANAGEMENT (admin only)
// ---------------------------------------------------------------------------
function slugify_(title) {
  return String(title).toLowerCase().trim()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-') + '-' + Math.floor(Math.random() * 10000);
}

// Run this ONCE from the script editor if any blog row shows up blank or
// won't open. Any row typed directly into the sheet (rather than created
// through the actual "create blog" flow) can end up with an empty Slug
// cell, which every slug-based lookup deliberately refuses to match.
// This fills in a real slug for any row that's missing one.
function backfillMissingSlugs_() {
  const sheet = getSheet_(CONFIG.BLOGS_SHEET_ID, 'Blogs');
  const values = sheet.getDataRange().getValues();
  if (values.length < 2) { Logger.log('No blog rows found.'); return; }
  const headers = values[0];
  const slugCol = headers.indexOf('Slug');
  const titleCol = headers.indexOf('Title');
  let fixed = 0;

  values.slice(1).forEach((row, i) => {
    if (!row[slugCol]) {
      const newSlug = slugify_(row[titleCol] || 'untitled');
      sheet.getRange(i + 2, slugCol + 1).setValue(newSlug);
      fixed++;
    }
  });

  bustBlogsCache_();
  Logger.log('Backfilled ' + fixed + ' missing slug(s).');
}

function createBlog_(data) {
  const sheet = getSheet_(CONFIG.BLOGS_SHEET_ID, 'Blogs');
  const blogId = Utilities.getUuid();
  const slug = data.slug ? data.slug : slugify_(data.title);
  // Always store Date as a real datetime value, never as raw text, so
  // sorting ("newest first") and any date formatting stay reliable
  // regardless of what string format the client sends.
  const publishDate = data.publishDate ? new Date(data.publishDate) : new Date();
  sheet.appendRow([
    new Date(), blogId, data.title, data.category, data.overview, data.content,
    data.status || 'Draft', data.image || '', slug, publishDate,
    data.author || 'Admin', 0, !!data.featured, data.seoKeywords || '', data.metaDescription || '',
    false
  ]);
  bustBlogsCache_();
  return { success: true, blogId: blogId, slug: slug };
}

function updateBlog_(data) {
  const sheet = getSheet_(CONFIG.BLOGS_SHEET_ID, 'Blogs');
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  const fieldMap = {
    title: 'Title', category: 'Category', overview: 'Overview', content: 'Content',
    status: 'Status', image: 'Image', author: 'Author', featured: 'Featured',
    seoKeywords: 'SEOKeywords', metaDescription: 'MetaDescription', publishDate: 'Date'
  };
  Object.keys(fieldMap).forEach(key => {
    if (data[key] !== undefined) {
      const value = key === 'publishDate' ? new Date(data[key]) : data[key];
      sheet.getRange(data.row, headers.indexOf(fieldMap[key]) + 1).setValue(value);
    }
  });
  bustBlogsCache_();
  return { success: true };
}

function deleteBlog_(data) {
  // Soft delete
  const sheet = getSheet_(CONFIG.BLOGS_SHEET_ID, 'Blogs');
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  sheet.getRange(data.row, headers.indexOf('Deleted') + 1).setValue(true);
  bustBlogsCache_();
  return { success: true };
}

// ---------------------------------------------------------------------------
// 8. IMAGE UPLOAD (admin only) — data.imageBase64 must be a raw base64
//    string (no "data:image/..." prefix — strip that on the client first)
// ---------------------------------------------------------------------------
function uploadImage_(data) {
  if (!data.imageBase64) {
    return { success: false, error: 'No image data received' };
  }

  const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
  const mimeType = data.mimeType || 'image/jpeg';
  if (!allowedTypes.includes(mimeType)) {
    return { success: false, error: 'Unsupported image type. Use JPEG, PNG, WEBP, or GIF.' };
  }

  const bytes = Utilities.base64Decode(data.imageBase64);

  // Keep well under Apps Script's request/response size limits and avoid
  // filling up Drive with huge uncompressed photos from a phone camera.
  const MAX_BYTES = 8 * 1024 * 1024; // 8 MB
  if (bytes.length > MAX_BYTES) {
    return { success: false, error: 'Image is too large (max 8 MB). Please compress or resize it first.' };
  }

  const folder = DriveApp.getFolderById(CONFIG.DRIVE_FOLDER_ID);
  const blob = Utilities.newBlob(bytes, mimeType, data.filename || (Utilities.getUuid() + '.jpg'));
  const file = folder.createFile(blob);
  file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
  const url = 'https://lh3.googleusercontent.com/d/' + file.getId(); // direct-viewable image URL
  return { success: true, url: url, fileId: file.getId() };
}

// ---------------------------------------------------------------------------
// 9. DASHBOARD / STATISTICS / SEARCH / EXPORT (admin only)
// ---------------------------------------------------------------------------
function dashboard_() {
  const counts = { Trimitha: 0, Thrinath: 0, Thripura: 0, todayTotal: 0 };
  const today = new Date(); today.setHours(0, 0, 0, 0);

  ['Trimitha', 'Thrinath', 'Thripura'].forEach(name => {
    const sheet = getSheet_(CONFIG.MASTER_SHEET_ID, name);
    const values = sheet.getDataRange().getValues().slice(1);
    const active = values.filter(r => r[COL.Status] !== 'Deleted');
    counts[name] = active.length;
    counts.todayTotal += active.filter(r => new Date(r[COL.Timestamp]) >= today).length;
  });

  const blogSheet = getSheet_(CONFIG.BLOGS_SHEET_ID, 'Blogs');
  const blogRows = blogSheet.getDataRange().getValues().slice(1).filter(r => !r[BLOG_COL.Deleted]);
  const published = blogRows.filter(r => r[BLOG_COL.Status] === 'Published').length;
  const drafts = blogRows.filter(r => r[BLOG_COL.Status] === 'Draft').length;

  const unread = ['Trimitha', 'Thrinath', 'Thripura'].reduce((sum, name) => {
    const sheet = getSheet_(CONFIG.MASTER_SHEET_ID, name);
    const values = sheet.getDataRange().getValues().slice(1);
    return sum + values.filter(r => r[COL.Status] === 'Unread').length;
  }, 0);

  return {
    success: true,
    data: {
      totalContacts: counts.Trimitha + counts.Thrinath + counts.Thripura,
      todayContacts: counts.todayTotal,
      trimithaContacts: counts.Trimitha,
      thrinathContacts: counts.Thrinath,
      thripuraContacts: counts.Thripura,
      publishedBlogs: published,
      draftBlogs: drafts,
      unreadNotifications: unread
    }
  };
}

function statistics_(params) {
  // Submissions grouped by source and by day, for dashboard charts
  const bySource = {}; const byDay = {};
  ['Trimitha', 'Thrinath', 'Thripura'].forEach(name => {
    const sheet = getSheet_(CONFIG.MASTER_SHEET_ID, name);
    const values = sheet.getDataRange().getValues().slice(1);
    bySource[name] = values.filter(r => r[COL.Status] !== 'Deleted').length;
    values.forEach(r => {
      const day = Utilities.formatDate(new Date(r[COL.Timestamp]), Session.getScriptTimeZone(), 'yyyy-MM-dd');
      byDay[day] = (byDay[day] || 0) + 1;
    });
  });
  return { success: true, bySource: bySource, byDay: byDay };
}

function searchAll_(query) {
  if (!query) return { success: true, data: [] };
  const q = query.toLowerCase();
  const results = [];
  ['Trimitha', 'Thrinath', 'Thripura'].forEach(name => {
    const sheet = getSheet_(CONFIG.MASTER_SHEET_ID, name);
    const values = sheet.getDataRange().getValues();
    const headers = values[0];
    values.slice(1).forEach((row, idx) => {
      const obj = rowToObj_(headers, row, idx + 2);
      if (String(obj.Name).toLowerCase().includes(q) || String(obj.Email).toLowerCase().includes(q) || String(obj.Message).toLowerCase().includes(q)) {
        results.push({ type: 'contact', sheet: name, ...obj });
      }
    });
  });
  return { success: true, data: results };
}

function exportData_(type) {
  if (type === 'contacts') {
    const out = {};
    ['Trimitha', 'Thrinath', 'Thripura'].forEach(name => {
      out[name] = getSheet_(CONFIG.MASTER_SHEET_ID, name).getDataRange().getValues();
    });
    return { success: true, data: out };
  }
  if (type === 'blogs') {
    return { success: true, data: getSheet_(CONFIG.BLOGS_SHEET_ID, 'Blogs').getDataRange().getValues() };
  }
  return { success: false, error: 'Invalid export type' };
}

// Notifications = Unread contacts across all sheets by default; pass
// ?all=true to also include already-Read ones (for a full history view).
function listNotifications_(params) {
  const includeRead = params.all === 'true';
  const all = [];
  ['Trimitha', 'Thrinath', 'Thripura'].forEach(name => {
    const sheet = getSheet_(CONFIG.MASTER_SHEET_ID, name);
    const values = sheet.getDataRange().getValues();
    const headers = values[0];
    values.slice(1).forEach((row, idx) => {
      const obj = rowToObj_(headers, row, idx + 2);
      if (obj.Status === 'Deleted') return;
      if (!includeRead && obj.Status !== 'Unread') return;
      all.push({ sheet: name, ...obj });
    });
  });
  all.sort((a, b) => new Date(b.Timestamp) - new Date(a.Timestamp));
  return { success: true, data: all };
}

function markNotificationRead_(data) {
  return updateContact_({ sheet: data.sheet, row: data.row, status: 'Read' });
}

// Marks every currently-Unread contact, across all three sheets, as Read.
function markAllNotificationsRead_() {
  let count = 0;
  ['Trimitha', 'Thrinath', 'Thripura'].forEach(name => {
    const sheet = getSheet_(CONFIG.MASTER_SHEET_ID, name);
    const values = sheet.getDataRange().getValues();
    const headers = values[0];
    const statusCol = headers.indexOf('Status');
    values.slice(1).forEach((row, idx) => {
      if (row[statusCol] === 'Unread') {
        sheet.getRange(idx + 2, statusCol + 1).setValue('Read');
        count++;
      }
    });
  });
  return { success: true, updated: count };
}

// ---------------------------------------------------------------------------
// 10. UTILITIES
// ---------------------------------------------------------------------------
function getSheet_(spreadsheetId, sheetName) {
  const ss = SpreadsheetApp.openById(spreadsheetId);
  const sheet = ss.getSheetByName(sheetName);
  if (!sheet) throw new Error('Sheet not found: ' + sheetName);
  return sheet;
}

function jsonOut_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
