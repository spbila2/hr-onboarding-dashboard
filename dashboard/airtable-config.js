// חיבור הדאשבורד ל-Airtable.
// ב-token מדביקים Personal Access Token עם הרשאת קריאה בלבד (data.records:read),
// שמוגבל ל-base "קליטת עובדים" בלבד. אחרי ההגשה כדאי למחוק אותו ב-airtable.com/create/tokens.
window.AIRTABLE_CONFIG = {
  baseId: 'apphvloFwyopeXu51',
  tableId: 'tblOd7xx8DQcj1LD2',
  token: 'pato98KDmaQjgOrwv.f63a79d72d06372b1cbfcf6e3f1ed7abf2104e8951214f9372b886fd282f2b2a'
};
