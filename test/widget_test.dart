// Phase 1 smoke test. The full app requires a live Supabase session
// (initialized in main()), so widget-level tests here stick to pure logic
// until a fake/mock Supabase client is introduced for the data-layer phases.

import 'package:flutter_test/flutter_test.dart';
import 'package:khata_app/core/utils/formatters.dart';

void main() {
  group('Formatters', () {
    test('formats currency with thousands separators', () {
      expect(Formatters.currency(20000), 'Rs. 20,000');
      expect(Formatters.currency(0), 'Rs. 0');
    });

    test('signedCurrency prefixes credit/debit sign', () {
      expect(Formatters.signedCurrency(5000), '+ Rs. 5,000');
      expect(Formatters.signedCurrency(-5000), '− Rs. 5,000');
      expect(Formatters.signedCurrency(0), 'Rs. 0');
    });
  });
}
