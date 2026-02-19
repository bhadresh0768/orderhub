# OrderHub

Order management platform with three roles:
- Customer app
- Business owner app (including B2B ordering)
- Admin panel (Flutter web)

## Setup

1. Install dependencies:
```bash
flutter pub get
```

2. Configure Firebase for this app:
```bash
flutterfire configure
```

3. Deploy Firebase security rules and indexes:
```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
```

4. Install and deploy Cloud Functions for push notifications:
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

5. Run:
```bash
flutter run
```

## Implemented Modules

- Role-based auth and dashboards (`customer`, `businessOwner`, `admin`)
- Business registration with moderation status (`pending`, `approved`, `suspended`)
- Customer/business search and filtering (name, category, city)
- Customer and B2B order creation with:
  - Multi-items
  - Priority (`low`, `medium`, `fast`)
  - Schedule date/time
  - Payment status/method/remark
  - Attachments via URL or file upload to Firebase Storage
  - Delivery tracking states
- Business order management (approve, complete, payment update, delivery stage updates)
- Order history and reporting:
  - Filters (status, priority, time window)
  - KPIs and advanced analytics
  - CSV export via clipboard
- Admin moderation:
  - User role updates and active/block toggle
  - Business approve/suspend/delete
  - Order cancel/delete
- Local notification workflow for order status/payment/delivery changes
- Push notifications (FCM) to customer when:
  - Order is placed
  - Order/payment/delivery status changes
- Public business profile screen with shareable deep links

## Deep Links

- App deep link format: `orderhub://business/{businessId}`
- Web link format: `https://orderhub.app/business/{businessId}`
- Android intent filters and iOS URL scheme are configured in:
  - `android/app/src/main/AndroidManifest.xml`
  - `ios/Runner/Info.plist`

For production HTTPS app links (`https://orderhub.app/...`), publish domain verification files:
- Android: `https://orderhub.app/.well-known/assetlinks.json`
- iOS: `https://orderhub.app/.well-known/apple-app-site-association`

## Firebase Files

- Firestore rules: `firestore.rules`
- Storage rules: `storage.rules`
- Firestore indexes: `firestore.indexes.json`
