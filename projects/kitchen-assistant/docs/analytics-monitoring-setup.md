# Analytics & Monitoring Setup Guide for Kitchen Assistant
**Target Stack:** Expo (Managed/EAS), Supabase, React Native

This guide covers the implementation of **Sentry** (Error Monitoring) and **PostHog** (Product Analytics) for the Kitchen Assistant app.

---

## 1. Sentry Setup (Error Monitoring)

Sentry is critical for catching crashes in production before users report them.

### Step 1: Install Dependencies
Run the Sentry wizard, which automates the configuration (modifies `app.json`, installs packages, and sets up source maps).

```bash
npx @sentry/wizard@latest -s -i reactNative
```

**During the wizard:**
1.  Select your Sentry project (create one if needed: `kitchen-assistant`).
2.  It will install `@sentry/react-native`.
3.  It will add the `sentry-expo` plugin to your `app.json`.

### Step 2: Manual Configuration Check
Ensure your `app.json` or `app.config.ts` has the plugin configured:

```json
{
  "expo": {
    "plugins": [
      [
        "@sentry/react-native/expo",
        {
          "organization": "your-org-slug",
          "project": "kitchen-assistant",
          "url": "https://sentry.io/"
        }
      ]
    ]
  }
}
```

### Step 3: Initialize in Code
In your root file (usually `app/_layout.tsx` or `App.tsx`), initialize Sentry **as early as possible**:

```typescript
import * as Sentry from '@sentry/react-native';

Sentry.init({
  dsn: "YOUR_SENTRY_DSN",
  debug: false, // Set true in dev if needed
  // Enable native crashes
  enableNative: true,
});

// Wrap your root component
export default Sentry.wrap(App);
```

### Step 4: Source Maps (EAS Build)
To get readable stack traces, you need to upload source maps during the build.
1.  Get your **Auth Token** from Sentry (Settings -> Developer Settings -> Auth Tokens).
2.  Add it to EAS secrets:
    ```bash
    eas secret:create --scope project --name SENTRY_AUTH_TOKEN --value "your_token_here"
    ```

---

## 2. PostHog Setup (Product Analytics)

PostHog is used for tracking user behavior (features used, retention, funnels).

### Step 1: Install Dependencies
PostHog requires a few Expo modules to gather device info.

```bash
npx expo install posthog-react-native expo-file-system expo-application expo-device expo-localization
```

### Step 2: Initialize Provider
Wrap your app in the PostHog provider. Create a new file `components/PostHogProvider.tsx`:

```typescript
import { PostHogProvider } from 'posthog-react-native';

export function AnalyticsProvider({ children }: { children: React.ReactNode }) {
  return (
    <PostHogProvider 
      apiKey="YOUR_POSTHOG_API_KEY"
      options={{
        host: "https://us.i.posthog.com", // or eu.i.posthog.com
        enableSessionReplay: false, // Not fully supported in RN yet, stick to events
      }}
    >
      {children}
    </PostHogProvider>
  );
}
```

### Step 3: Tracking Events
In your components:

```typescript
import { usePostHog } from 'posthog-react-native';

const MyComponent = () => {
  const posthog = usePostHog();

  const handleScan = () => {
    posthog.capture('item_scanned', {
      type: 'barcode',
      success: true
    });
  };
};
```

---

## 3. Best Practices

1.  **Environment Variables:** Do not hardcode API keys. Use `.env` files and `expo-constants` or `process.env`.
    *   `EXPO_PUBLIC_SENTRY_DSN`
    *   `EXPO_PUBLIC_POSTHOG_API_KEY`
2.  **Privacy:** Update the Privacy Policy (already created) to mention these processors.
3.  **Development Noise:** You might want to disable tracking in development:

```typescript
if (!__DEV__) {
  Sentry.init({...});
}
```

## 4. Verification

1.  **Throw a test error:**
    ```typescript
    <Button title="Break me" onPress={() => { throw new Error("Test Sentry"); }} />
    ```
2.  **Check Sentry Dashboard:** The error should appear within seconds.
3.  **Check PostHog:** Verify "Live Events" stream when you open the app.
