import 'package:eazyaccount/shared/services/accounting_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tryParseShoppingListText', () {
    test('splits slash-separated shopping nouns into separate items', () {
      final parsed = AccountingRepository.tryParseShoppingListText(
        'มาม่า/แก้ว/ฝักชี/ฝรั่ง',
      );

      expect(
        parsed?.items.map((item) => item.name),
        ['มาม่า', 'แก้ว', 'ฝักชี', 'ฝรั่ง'],
      );
    });

    test('splits known spoken shopping nouns when speech omits spaces', () {
      final parsed = AccountingRepository.tryParseShoppingListText(
        'ซื้อมาม่าแก้วฝักชีฝรั่งไว้ในลิสต์',
      );

      expect(
        parsed?.items.map((item) => item.name),
        ['มาม่า', 'แก้ว', 'ฝักชี', 'ฝรั่ง'],
      );
    });

    test('keeps measurement-only shopping text as one item name', () {
      final parsed = AccountingRepository.tryParseShoppingListText(
        'ซื้อท่อ 2 นิ้ว',
      );

      expect(parsed?.items.map((item) => item.name), ['ท่อ 2 นิ้ว']);
    });
  });
}
