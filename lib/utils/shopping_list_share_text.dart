import '../models/shopping_item.dart';
import 'quantity_format.dart';

String formatShoppingListForSharing(List<ShoppingItem> items) {
  final lines = <String>[
    'Shopping List',
    '',
    for (final item in items)
      '- [${item.isBought ? 'x' : ' '}] ${_formatItem(item)}',
  ];
  return lines.join('\n');
}

String _formatItem(ShoppingItem item) {
  final amount = item.amountText != null
      ? [
          item.amountText!,
          if (parseQuantity(item.amountText!) != null && item.unit.isNotEmpty)
            item.unit,
        ].join(' ')
      : (item.quantity == null
            ? ''
            : [
                formatQuantity(item.quantity!),
                if (item.unit.isNotEmpty) item.unit,
              ].join(' '));
  final note = item.note.isEmpty ? '' : ' (${item.note})';
  return [if (amount.isNotEmpty) amount, '${item.name}$note'].join(' ');
}
