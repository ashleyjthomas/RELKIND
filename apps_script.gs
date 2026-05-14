/**
 * Twizzle Town — Google Sheets receiver
 *
 * Paste this entire file into your Google Sheet:
 *   Extensions → Apps Script → replace the default code → Save.
 *
 * Then Deploy → New deployment:
 *   Type:           Web app
 *   Description:    Twizzle Town data receiver
 *   Execute as:     Me (your account)
 *   Who has access: Anyone
 *
 * Copy the Web app URL it gives you and paste it into index.html
 * as the value of SHEETS_WEBHOOK.
 */

const SHEET_NAME = 'Data';   // tab to write into; will be created if missing

function doPost(e) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let sheet = ss.getSheetByName(SHEET_NAME);
    if (!sheet) sheet = ss.insertSheet(SHEET_NAME);

    const data = JSON.parse(e.postData.contents);
    const incomingHeaders = data.headers || Object.keys(data.row || {});
    const row = data.row || {};

    // First row: write headers
    if (sheet.getLastRow() === 0) {
      sheet.appendRow(incomingHeaders);
      sheet.setFrozenRows(1);
    }

    // Read whatever headers are actually in the sheet (in case order drifts)
    const sheetHeaders = sheet
      .getRange(1, 1, 1, Math.max(sheet.getLastColumn(), 1))
      .getValues()[0];

    // Build the row in the sheet's column order
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
    .createTextOutput('Twizzle Town receiver is live.')
    .setMimeType(ContentService.MimeType.TEXT);
}
