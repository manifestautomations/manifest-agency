# Kitchen Assistant: App Store Submission Checklist
**Target:** iOS App Store & Google Play Store
**Tooling:** Expo EAS (Expo Application Services)

This guide outlines the steps to get Kitchen Assistant from code to "Waiting for Review".

---

## 1. Prerequisites (Accounts & Credentials)

### Apple Developer Program ($99/year)
- [ ] Enrolled as Individual or Organization
- [ ] Accepted latest License Agreement in [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Created App ID in Developer Portal (handled by EAS if credentials configured)

### Google Play Console ($25 one-time)
- [ ] Created Developer Account
- [ ] Verified Identity (ID upload required)
- [ ] Created App Entry (Listing)

---

## 2. Configuration (Codebase)

### `app.json` / `app.config.ts`
- [ ] **Bundle Identifier:** Unique ID (e.g., `com.manifest.kitchenassistant`)
    - iOS: `ios.bundleIdentifier`
    - Android: `android.package`
- [ ] **Version Code:**
    - iOS: `ios.buildNumber` (String, e.g., "1")
    - Android: `android.versionCode` (Integer, e.g., 1)
- [ ] **Permissions:** Ensure only used permissions are requested (Camera). Add usage descriptions:
    - `ios.infoPlist.NSCameraUsageDescription`: "Used to scan barcodes for pantry tracking."

### `eas.json`
- [ ] Configure `submit` profile:
    ```json
    {
      "submit": {
        "production": {
          "ios": {
            "appleId": "your-apple-id@email.com",
            "ascAppId": "YOUR_APP_STORE_CONNECT_APP_ID",
            "appleTeamId": "YOUR_TEAM_ID"
          },
          "android": {
            "serviceAccountKeyPath": "./google-play-service-account.json",
            "track": "internal" 
          }
        }
      }
    }
    ```

---

## 3. Assets Preparation

### Visual Assets
- [ ] **App Icon:** 1024x1024px (No transparency) -> `assets/icon.png`
- [ ] **Splash Screen:** 1242x2436px -> `assets/splash.png`
- [ ] **Screenshots:**
    - iOS: 6.5" Display (1284x2778) and 5.5" Display (1242x2208)
    - Android: Phone (1080x1920) and 7-inch Tablet
    - *Tip: Use the concepts defined in `app-store-listing.md`*

### Legal & Data
- [ ] **Privacy Policy URL:** Hosted link (can use GitHub Pages or a simple Vercel page with `privacy-policy.md` content)
- [ ] **Support URL:** Link to GitHub Issues or a contact form
- [ ] **Data Safety Form (Google):** Declare data collection (Email, User ID, Product Interaction)

---

## 4. The Build & Submit Process

### Step 1: Build the Production Binary
```bash
eas build --platform all --profile production
```
*Wait for cloud build to finish.*

### Step 2: Submit to Stores
```bash
eas submit --platform all --profile production
```
*Follow the interactive prompts to log in to Apple/Google.*

---

## 5. Store-Specific Steps

### Apple App Store
1.  **TestFlight:** EAS submits to TestFlight automatically.
2.  **Internal Testing:** Add yourself as a tester.
3.  **Promote to Production:**
    - Go to App Store Connect -> My Apps.
    - Select the build from TestFlight.
    - Paste metadata from `app-store-listing.md`.
    - Upload screenshots.
    - Submit for Review.

### Google Play Store
1.  **Internal Testing Track:** EAS uploads here by default.
2.  **Promote to Production:**
    - Releases -> Overview -> Promote to Production.
    - Paste metadata.
    - Upload screenshots.
    - Submit for Review.

---

## 6. Common Rejection Reasons (Avoid These)
1.  **Broken Links:** Ensure Privacy Policy and Support links work.
2.  **Crashes:** Test the *release* build (not just Expo Go) locally if possible (`npx expo run:ios --configuration Release`).
3.  **Incomplete Info:** Test login credentials must be provided to Apple Reviewers if the app requires login.
4.  **Placeholder Content:** No "Lorem Ipsum" in the app.

---

*Last Updated: 2026-01-29*
