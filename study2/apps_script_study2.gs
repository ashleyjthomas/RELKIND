/**
 * Twizzle Town — STUDY 2 Google Sheets receiver
 * ==================================================================
 * Deploy this on the STUDY-2 spreadsheet ONLY:
 *   https://docs.google.com/spreadsheets/d/16UH4Z1uO1yL9Lh5scfa7DOxx6NiYI00vPmgp4mQsLMk/
 *
 * SETUP (once):
 *   1. Open the sheet above.
 *   2. Extensions → Apps Script.
 *   3. Replace the default `function myFunction() {}` with the entire
 *      contents of this file. Save (⌘S).
 *   4. Deploy → New deployment → Select type: "Web app".
 *        Description:     "Twizzle Study 2 data receiver"
 *        Execute as:      Me
 *        Who has access:  Anyone
 *   5. Copy the /exec URL it hands back.
 *   6. Paste that URL into RELKIND/study2/index.html as the value of
 *      SHEETS_WEBHOOK (top of the <script> block).
 *
 * After deploying: visit the /exec URL in a browser once. You should see
 * "Twizzle Town STUDY 2 receiver is live" as plain text. If you see a
 * "please authorize" page, walk through the OAuth consent (Google will
 * warn that the app isn't verified — click Advanced → Go to the app).
 *
 * The sheet tab named `Data` is created on first hit; the first row is
 * written as headers (frozen). Every subsequent hit appends one row.
 *
 * REDEPLOY: any time you edit this script, do Deploy → Manage deployments
 * → pencil icon on the active deployment → New version → Deploy. The /exec
 * URL stays the same. Do NOT create a fresh deployment (that generates a
 * NEW URL and breaks the game until you paste the new URL back into HTML).
 * ==================================================================
 */

const SHEET_NAME = 'Data';   // tab to write into; created if missing
const STUDY_TAG  = 'study2'; // sanity check on incoming rows

function doPost(e) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let sheet = ss.getSheetByName(SHEET_NAME);
    if (!sheet) sheet = ss.insertSheet(SHEET_NAME);

    const data = JSON.parse(e.postData.contents);
    const incomingHeaders = data.headers || Object.keys(data.row || {});
    const row = data.row || {};

    // Optional guardrail: refuse rows that aren't from Study 2 so we don't
    // accidentally mingle Study 1 data if a webhook URL gets swapped.
    if (row.study && row.study !== STUDY_TAG) {
      return ContentService
        .createTextOutput(JSON.stringify({
          ok: false,
          error: 'Wrong study tag: expected "' + STUDY_TAG +
                 '", got "' + row.study + '"'
        }))
        .setMimeType(ContentService.MimeType.JSON);
    }

    // First row: write headers and freeze
    if (sheet.getLastRow() === 0) {
      sheet.appendRow(incomingHeaders);
      sheet.setFrozenRows(1);
    }

    // Read whatever headers are actually in the sheet (in case order drifts)
    const sheetHeaders = sheet
      .getRange(1, 1, 1, Math.max(sheet.getLastColumn(), 1))
      .getValues()[0];

    // If the incoming payload has columns the sheet doesn't yet know about,
    // append them so we never silently drop fields.
    const newCols = incomingHeaders.filter(function (h) {
      return sheetHeaders.indexOf(h) === -1;
    });
    if (newCols.length) {
      sheet.getRange(1, sheetHeaders.length + 1, 1, newCols.length)
           .setValues([newCols]);
      newCols.forEach(function (c) { sheetHeaders.push(c); });
    }

    // Build the row in the sheet's column order (blank for missing fields)
    const rowValues = sheetHeaders.map(function (h) {
      const v = row[h];
      return v === undefined || v === null ? '' : v;
    });
    sheet.appendRow(rowValues);

    return ContentService
      .createTextOutput(JSON.stringify({ ok: true }))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ ok: false, error: String(err) }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

// Sanity check: visit the deployed URL in a browser to confirm it's reachable.
function doGet() {
  return ContentService
    .createTextOutput('Twizzle Town STUDY 2 receiver is live.')
    .setMimeType(ContentService.MimeType.TEXT);
}
