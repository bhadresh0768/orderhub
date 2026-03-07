const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
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

async function sendToAdmins(title, body, data = {}) {
  const adminsSnapshot = await db.collection("users")
      .where("role", "==", "admin")
      .get();
  if (adminsSnapshot.empty) return;

  const allTokens = [];
  adminsSnapshot.docs.forEach((doc) => {
    const tokens = doc.get("fcmTokens") || [];
    if (Array.isArray(tokens) && tokens.length > 0) {
      allTokens.push(...tokens);
    }
  });

  const uniqueTokens = [...new Set(allTokens)].filter((token) => !!token);
  if (uniqueTokens.length === 0) return;

  await messaging.sendEachForMulticast({
    tokens: uniqueTokens,
    notification: {title, body},
    data: Object.entries(data).reduce((acc, [key, value]) => {
      acc[key] = String(value);
      return acc;
    }, {}),
  });
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

exports.notifySupportTicketCreated = onDocumentCreated(
    "supportTickets/{ticketId}",
    async (event) => {
      const ticket = event.data && event.data.data();
      if (!ticket) return;

      const userName = (ticket.userName || "User").toString();
      const issueType = (ticket.issueType || "other").toString();
      await sendToAdmins(
          "New Support Ticket",
          `${userName} raised ${issueType} issue`,
          {ticketId: event.params.ticketId, type: "support_ticket_created"},
      );
    },
);

exports.notifySupportTicketStatusChanged = onDocumentUpdated(
    "supportTickets/{ticketId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      if (!before || !after) return;
      if (before.status === after.status) return;

      await sendToCustomer(
          after.userId,
          "Support Ticket Updated",
          `Ticket status: ${after.status}`,
          {ticketId: event.params.ticketId, type: "support_ticket_updated"},
      );
    },
);

exports.expireSubscriptionsDaily = onSchedule(
    {
      schedule: "10 0 * * *",
      timeZone: "Asia/Kolkata",
    },
    async () => {
      const now = new Date();
      let updatedCount = 0;
      let lastDoc = null;
      const pageSize = 500;

      while (true) {
        let query = db
            .collection("users")
            .where("subscriptionEndDate", "<=", now)
            .orderBy("subscriptionEndDate")
            .limit(pageSize);
        if (lastDoc) {
          query = query.startAfter(lastDoc);
        }

        const snapshot = await query.get();
        if (snapshot.empty) break;

        const batch = db.batch();
        let batchWrites = 0;
        for (const doc of snapshot.docs) {
          const user = doc.data();
          if (user.subscriptionActive !== true) continue;
          batch.update(doc.ref, {
            subscriptionActive: false,
            updatedAt: FieldValue.serverTimestamp(),
          });
          batchWrites++;
        }

        if (batchWrites > 0) {
          await batch.commit();
          updatedCount += batchWrites;
        }

        lastDoc = snapshot.docs[snapshot.docs.length - 1];
      }

      logger.info("Subscription expiry completed", {
        updatedCount,
        executedAt: now.toISOString(),
      });
    },
);
