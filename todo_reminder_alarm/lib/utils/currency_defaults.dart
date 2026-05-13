String defaultCurrencySymbolForCountryCode(String? countryCode) {
  switch ((countryCode ?? '').trim().toUpperCase()) {
    case 'IN':
      return '₹';
    case 'US':
    case 'CA':
    case 'AU':
    case 'NZ':
    case 'SG':
      return r'$';
    case 'GB':
      return '£';
    case 'JP':
    case 'CN':
      return '¥';
    case 'KR':
      return '₩';
    case 'TH':
      return '฿';
    case 'VN':
      return '₫';
    case 'PH':
      return '₱';
    case 'RU':
      return '₽';
    case 'TR':
      return '₺';
    case 'AE':
      return 'د.إ';
    case 'SA':
      return '﷼';
    case 'EU':
    case 'DE':
    case 'FR':
    case 'IT':
    case 'ES':
    case 'NL':
    case 'IE':
    case 'PT':
    case 'GR':
    case 'BE':
    case 'AT':
    case 'FI':
    case 'LU':
      return '€';
    default:
      return 'Rs.';
  }
}
