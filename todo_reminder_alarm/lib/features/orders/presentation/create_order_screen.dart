import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/delivery_address.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../models/order_unit.dart';
import '../../../models/payment.dart';
import '../../../providers.dart';

part 'create_order_body.dart';
part 'create_order_catalog_actions.dart';
part 'create_order_item_actions.dart';
part 'create_order_address_actions.dart';
part 'create_order_submit_actions.dart';

final _createOrderUiProvider = StateProvider.autoDispose
    .family<_CreateOrderUiState, String>(
      (ref, id) => const _CreateOrderUiState(),
    );

class _CreateOrderUiState {
  const _CreateOrderUiState({
    this.items = const [],
    this.itemAttachmentsDraft = const [],
    this.itemUnitCode = 'piece',
    this.itemUnitLabel,
    this.itemUnitSymbol,
    this.editingItemIndex,
    this.priority = OrderPriority.medium,
    this.paymentMethod = PaymentMethod.cash,
    this.confirmedOnline = false,
    this.loading = false,
    this.uploadingItemImage = false,
    this.loadingSuggestions = false,
    this.catalogItems = const [],
    this.itemSuggestions = const [],
    this.deliveryAddressRef = _profileAddressRef,
    this.inlineError,
  });

  final List<OrderItem> items;
  final List<OrderAttachment> itemAttachmentsDraft;
  final String itemUnitCode;
  final String? itemUnitLabel;
  final String? itemUnitSymbol;
  final int? editingItemIndex;
  final OrderPriority priority;
  final PaymentMethod paymentMethod;
  final bool confirmedOnline;
  final bool loading;
  final bool uploadingItemImage;
  final bool loadingSuggestions;
  final List<String> catalogItems;
  final List<String> itemSuggestions;
  final String deliveryAddressRef;
  final String? inlineError;

  _CreateOrderUiState copyWith({
    List<OrderItem>? items,
    List<OrderAttachment>? itemAttachmentsDraft,
    String? itemUnitCode,
    Object? itemUnitLabel = _createOrderUnset,
    Object? itemUnitSymbol = _createOrderUnset,
    Object? editingItemIndex = _createOrderUnset,
    OrderPriority? priority,
    PaymentMethod? paymentMethod,
    bool? confirmedOnline,
    bool? loading,
    bool? uploadingItemImage,
    bool? loadingSuggestions,
    List<String>? catalogItems,
    List<String>? itemSuggestions,
    String? deliveryAddressRef,
    Object? inlineError = _createOrderUnset,
  }) {
    return _CreateOrderUiState(
      items: items ?? this.items,
      itemAttachmentsDraft: itemAttachmentsDraft ?? this.itemAttachmentsDraft,
      itemUnitCode: itemUnitCode ?? this.itemUnitCode,
      itemUnitLabel: itemUnitLabel == _createOrderUnset
          ? this.itemUnitLabel
          : itemUnitLabel as String?,
      itemUnitSymbol: itemUnitSymbol == _createOrderUnset
          ? this.itemUnitSymbol
          : itemUnitSymbol as String?,
      editingItemIndex: editingItemIndex == _createOrderUnset
          ? this.editingItemIndex
          : editingItemIndex as int?,
      priority: priority ?? this.priority,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      confirmedOnline: confirmedOnline ?? this.confirmedOnline,
      loading: loading ?? this.loading,
      uploadingItemImage: uploadingItemImage ?? this.uploadingItemImage,
      loadingSuggestions: loadingSuggestions ?? this.loadingSuggestions,
      catalogItems: catalogItems ?? this.catalogItems,
      itemSuggestions: itemSuggestions ?? this.itemSuggestions,
      deliveryAddressRef: deliveryAddressRef ?? this.deliveryAddressRef,
      inlineError: inlineError == _createOrderUnset
          ? this.inlineError
          : inlineError as String?,
    );
  }
}

const _createOrderUnset = Object();
const _profileAddressRef = '__profile__';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({
    super.key,
    required this.business,
    required this.customer,
    this.requesterBusiness,
    this.initialItems = const [],
    this.existingOrder,
  });

  final BusinessProfile business;
  final AppUser customer;
  final BusinessProfile? requesterBusiness;
  final List<OrderItem> initialItems;
  final Order? existingOrder;

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _packSizeController = TextEditingController();
  final _itemNoteController = TextEditingController();
  final _notesController = TextEditingController();
  final _paymentRemarkController = TextEditingController();
  final Map<String, List<String>> _prefixSuggestionCache = {};
  Timer? _searchDebounce;
  late final String _draftOrderId;
  final ImagePicker _imagePicker = ImagePicker();
  bool _defaultDeliveryAddressInitialized = false;

  _CreateOrderUiState get _ui =>
      ref.read(_createOrderUiProvider(_draftOrderId));
  void _updateUi(
    _CreateOrderUiState Function(_CreateOrderUiState state) update,
  ) {
    final notifier = ref.read(_createOrderUiProvider(_draftOrderId).notifier);
    notifier.state = update(notifier.state);
  }

  @override
  void initState() {
    super.initState();
    _draftOrderId = widget.existingOrder?.id ?? const Uuid().v4();
    unawaited(_initializeItemCatalog());
    final existing = widget.existingOrder;
    if (existing != null) {
      _notesController.text = existing.notes ?? '';
      _paymentRemarkController.text = existing.payment.remark ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateUi(
          (state) => state.copyWith(
            items: existing.items,
            priority: existing.priority,
            paymentMethod: existing.payment.method,
            confirmedOnline: existing.payment.confirmedByCustomer ?? false,
          ),
        );
      });
    } else if (widget.initialItems.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateUi((state) => state.copyWith(items: widget.initialItems));
      });
    }
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    _packSizeController.dispose();
    _itemNoteController.dispose();
    _notesController.dispose();
    _paymentRemarkController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildCreateOrderScaffold(context);
}
