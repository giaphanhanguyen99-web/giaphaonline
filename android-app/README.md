# Cội Nguồn Android prototype

This is an Android launcher prototype for the Development website. It opens the site in an Android Custom Tab, which keeps Google and Supabase authentication in the user's normal browser context instead of an embedded WebView.

## Build

Open this directory in Android Studio, or use the repository's `Android Development APK` GitHub Actions workflow to build a debug APK.

## Current scope

- Android launcher icon and app label.
- Opens the Development website over HTTPS in a Custom Tab.
- Uses the browser's existing sign-in session.
- Requires network access.
- Not release-signed and not ready for Play Store publication.
- Native push notifications and offline data are not included.
