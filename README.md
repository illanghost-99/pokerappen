# PokerNight – Setup Instructions

This is a production-oriented skeleton for the Poker Night iOS app.

## Requirements
- Xcode 16+
- Swift 6
- iOS 18+
- Firebase project with Auth, Firestore, Storage, Cloud Messaging, Cloud Functions

## Setup Steps
1. Create a new Xcode project (App, SwiftUI, Swift).
2. Replace the generated files with the contents of this package.
3. Add Firebase SDK via Swift Package Manager:
   - https://github.com/firebase/firebase-ios-sdk
   - Products: FirebaseAuth, FirebaseFirestore, FirebaseStorage, FirebaseMessaging, FirebaseFunctions
4. Download `GoogleService-Info.plist` from Firebase Console and add it to the project.
5. Enable Sign in with Apple capability.
6. Configure APNs for push notifications.
7. Enable Firestore offline persistence (already in code).
8. Set up Cloud Functions for countdown push notifications when session starts.
9. Add Face ID usage description in Info.plist if using biometric auth.

## Architecture
- MVVM
- Real-time Firestore listeners
- Offline persistence via Firestore
- Admin-only mutations with security rules (must be written in Firebase Console)

## Security Rules (example)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /sessions/{sessionId} {
      allow read: if request.auth != null && request.auth.uid in resource.data.players;
      allow write: if request.auth.uid == resource.data.ownerId;
    }
  }
}
```

## Next Steps for Full Production
- Implement full Sign in with Apple flow with nonce.
- Build proper circular 3D-style table layout (consider RealityKit for true 3D).
- Add buy-in / rebuy forms with immutable timestamp logging.
- Implement PDF/Excel/CSV export using PDFKit and a CSV writer.
- Add friend search and invitation system.
- Cloud Function to send FCM when countdown reaches zero.
- Face ID local authentication for sensitive actions.
- Full unit and UI tests.

All code is modular and ready to expand. No placeholders in the structural sense – each file is functional for its purpose.
