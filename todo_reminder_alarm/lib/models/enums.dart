enum UserRole { customer, businessOwner, deliveryBoy, admin }

enum BusinessStatus { pending, approved, suspended }

enum OrderPriority { low, medium, fast }

enum OrderStatus { pending, approved, inProgress, completed, cancelled }

enum OrderRequesterType { customer, businessOwner }

enum PaymentStatus { pending, done }

enum PaymentMethod { cash, check, onlineTransfer }

enum PaymentCollectedBy { businessOwner, deliveryBoy }

enum DeliveryStatus { pending, packed, dispatched, outForDelivery, delivered }

enum QuantityUnit { piece, kilogram, gram, liter }

enum SupportIssueType { order, payment, account, delivery, other }

enum SupportPriority { low, medium, high }

enum SupportTicketStatus { open, inProgress, resolved, closed }

String enumToString(Object value) => value.toString().split('.').last;

T enumFromString<T extends Object>(List<T> values, String? value, T fallback) {
  if (value == null) return fallback;
  return values.firstWhere(
    (element) => enumToString(element) == value,
    orElse: () => fallback,
  );
}
