# Delete your Hisab account and data

This page explains how to delete your data and request account deletion for **Hisab** (the app and developer name as shown on the Google Play Store listing).

## Remove data from your device

1. Open the Hisab app.
2. Go to **Settings** → **Advanced** → **Delete all data**.
3. Confirm when prompted. This removes all local data (groups, expenses, participants, and settings) from your device and returns you to the onboarding screen.
4. If you were signed in, **sign out** (e.g. from the sign-in screen or Settings) so your session ends.

After this, no app data remains on your device. Data stored on our servers (if you used Online mode) is not removed by this step.

## Request deletion of your account and server data

To request deletion of your **account** and **all data stored on our servers** (e.g. groups, expenses, and profile data in our cloud database):

- **Open an issue** on our GitHub repository with the subject “Account deletion request” and the email address (or identifier) you used to sign in, or  
- **Contact the developer** through the app’s **About** section.

Once we process your request, we will delete your account and associated data from our systems. We do not retain backups of deleted user data; deletion is permanent.

## What is deleted

- **When you use “Delete all data” in the app:** All data on your device (local groups, expenses, participants, invites, and app settings) is deleted. Server-side data is not deleted by this action.
- **When you request account deletion:** Your auth account and all associated data stored on our servers (e.g. in Supabase) are deleted. We do not retain deleted user data.

## Retention

We do not retain deleted user data. After deletion, we have no additional retention period for that data.
