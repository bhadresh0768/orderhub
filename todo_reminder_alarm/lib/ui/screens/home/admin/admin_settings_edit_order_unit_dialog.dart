part of 'admin_settings_screen.dart';

class _EditOrderUnitDialog extends StatefulWidget {
  const _EditOrderUnitDialog({required this.unit, required this.normalizeCode});

  final OrderUnit unit;
  final String Function(String input) normalizeCode;

  @override
  State<_EditOrderUnitDialog> createState() => _EditOrderUnitDialogState();
}

class _EditOrderUnitDialogState extends State<_EditOrderUnitDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _labelController;
  late final TextEditingController _symbolController;
  late final TextEditingController _sortController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.unit.code);
    _labelController = TextEditingController(text: widget.unit.label);
    _symbolController = TextEditingController(text: widget.unit.symbol);
    _sortController = TextEditingController(
      text: widget.unit.sortOrder.toString(),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _labelController.dispose();
    _symbolController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  void _save() {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unit name is required')));
      return;
    }
    final fallbackCode = widget.normalizeCode(label);
    final codeInput = widget.normalizeCode(_codeController.text);
    final code = codeInput.isEmpty ? fallbackCode : codeInput;
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid unit name or code (letters/numbers)'),
        ),
      );
      return;
    }
    final symbol = _symbolController.text.trim().isEmpty
        ? label
        : _symbolController.text.trim();
    final sortOrder = int.tryParse(_sortController.text.trim()) ?? 0;
    Navigator.of(context).pop(
      OrderUnit(
        code: code,
        label: label,
        symbol: symbol,
        sortOrder: sortOrder,
        isActive: widget.unit.isActive,
        createdAt: widget.unit.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Unit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _labelController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Unit Name',
                hintText: 'Example: Tray',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _codeController,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'Unit Code (optional)',
                hintText: 'Auto from name if empty',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _symbolController,
              decoration: const InputDecoration(
                labelText: 'Unit Symbol (optional)',
                hintText: 'Defaults to unit name if empty',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _sortController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sort Order (optional)',
                hintText: '0',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
