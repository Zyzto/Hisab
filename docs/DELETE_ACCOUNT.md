# Delete your Hisab account and data

This page explains how to delete your data and request account deletion for **Hisab** (the app and developer name as shown on the Google Play Store listing).

## Remove data from your device (Delete local data)

1. Open the Hisab app.
2. Go to **Settings** → **Advanced** → **Delete local data**.
3. Read the summary of what will be deleted, wait for the 30-second countdown, then confirm. This removes all local data (groups, expenses, participants, invites) from this device and returns you to the onboarding screen. You are not signed out; you can continue in local-only mode or sign in again.

After this, no app data remains on your device. Data stored on our servers (if you used Online mode) is not removed by this step.

## Remove your data from the server (Delete cloud data)

When signed in and online:

1. Go to **Settings** → **Advanced** → **Delete cloud data**.
2. Read the summary (group memberships, ownership transfer for groups you own, sole-member groups that will be deleted, device tokens, invite records). You can optionally check **Also delete local data on this device** to wipe the device and return to onboarding after cloud deletion.
3. Wait for the 30-second countdown, then confirm. The app leaves all your groups (transferring ownership to the next member by join date where you are owner; groups where you are the only member are deleted), removes your device tokens and invite-usage records from the server, then signs you out. If you chose to also delete local data, the device is wiped and you are taken to onboarding.

Server-side app data (group memberships, device_tokens, invite_usages) is removed by this action. Your auth account (email/social login) is not deleted; you can request that separately (see below).

## Request deletion of your account and server data

To request deletion of your **account** and **all data stored on our servers** (e.g. groups, expenses, and profile data in our cloud database):

- **Open an issue** on our GitHub repository with the subject “Account deletion request” and the email address (or identifier) you used to sign in, or  
- **Contact the developer** through the app’s **About** section.

Once we process your request, we will delete your account and associated data from our systems. We do not retain backups of deleted user data; deletion is permanent.

## What is deleted

- **Delete local data:** All data on this device (local groups, expenses, participants, invites) is deleted. Server-side data is not deleted. You are not signed out.
- **Delete cloud data:** Your presence on the server is removed: you leave all groups (ownership is transferred where applicable; groups where you are the only member are deleted), your device tokens and invite-usage records are deleted, and you are signed out. Optionally you can also delete local data on the device. Your auth account (login) is not deleted by this action.
- **When you request account deletion:** Your auth account and all associated data stored on our servers (e.g. in Supabase) are deleted. We do not retain deleted user data.

## Retention

We do not retain deleted user data. After deletion, we have no additional retention period for that data.
