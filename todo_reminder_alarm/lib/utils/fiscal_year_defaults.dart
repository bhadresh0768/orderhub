int defaultFiscalYearStartMonthForCountryCode(String? countryCode) {
  switch ((countryCode ?? '').trim().toUpperCase()) {
    case 'IN':
      return 4;
    case 'AU':
    case 'NZ':
    case 'EG':
      return 7;
    default:
      return 1;
  }
}
