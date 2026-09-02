bool isValidBoxQrId(String value) {
  return RegExp(
    r'^TM:BOX:'
    r'[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'4[0-9a-fA-F]{3}-'
    r'[89abAB][0-9a-fA-F]{3}-'
    r'[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}
