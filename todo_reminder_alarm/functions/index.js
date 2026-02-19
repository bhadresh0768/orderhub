const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

async function sendToCustomer(customerId, title, body, data = {}) {
  const userDoc = await db.collection("users").doc(customerId).get();
  if (!userDoc.exists) return;

  const tokens = userDoc.get("fcmTokens") || [];
  if (!Array.isArray(tokens) || tokens.length === 0) return;

  const result = await messaging.sendEachForMulticast({
    tokens,
    notification: {title, body},
    data: Object.entries(data).reduce((acc, [key, value]) => {
      acc[key] = String(value);
      return acc;
    }, {}),
  });

  const invalidTokens = [];
  result.responses.forEach((response, index) => {
    if (response.success) return;
    const code = response.error && response.error.code;
    if (
      code === "messaging/invalid-registration-token" ||
      code === "messaging/registration-token-not-registered"
    ) {
      invalidTokens.push(tokens[index]);
    }
  });

  if (invalidTokens.length > 0) {
    await db.collection("users").doc(customerId).update({
      fcmTokens: FieldValue.arrayRemove(...invalidTokens),
    });
  }
}

exports.notifyOrderPlaced = onDocumentCreated("orders/{orderId}", async (event) => {
  const order = event.data && event.data.data();
  if (!order) return;

  await sendToCustomer(
      order.customerId,
      "Order Placed",
      `Your order ${event.params.orderId.slice(0, 6)} was placed successfully.`,
      {orderId: event.params.orderId, type: "order_placed"},
  );
});

exports.notifyOrderStatusChanged = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;

  const orderStatusChanged = before.status !== after.status;
  const paymentStatusChanged =
    (before.payment && before.payment.status) !== (after.payment && after.payment.status);
  const deliveryStatusChanged =
    (before.delivery && before.delivery.status) !== (after.delivery && after.delivery.status);

  if (!orderStatusChanged && !paymentStatusChanged && !deliveryStatusChanged) return;

  const updates = [];
  if (orderStatusChanged) updates.push(`Order: ${after.status}`);
  if (paymentStatusChanged) updates.push(`Payment: ${after.payment.status}`);
  if (deliveryStatusChanged) updates.push(`Delivery: ${after.delivery.status}`);

  await sendToCustomer(
      after.customerId,
      "Order Updated",
      updates.join(" | "),
      {orderId: event.params.orderId, type: "order_updated"},
  );
});
