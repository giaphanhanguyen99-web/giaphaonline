package vn.coinguon.app;

import android.app.Activity;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;

import androidx.browser.customtabs.CustomTabsIntent;

/**
 * Android prototype launcher. Authentication remains in the user's trusted browser session,
 * so Google OAuth does not run inside an embedded WebView.
 */
public final class MainActivity extends Activity {
    private static final Uri START_URL = Uri.parse(
        "https://raw.githack.com/giaphanhanguyen99-web/giaphaonline/gia-pha-development-2026-11-25/index.html"
    );

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        CustomTabsIntent tab = new CustomTabsIntent.Builder()
            .setShowTitle(true)
            .setUrlBarHidingEnabled(false)
            .setToolbarColor(Color.rgb(24, 55, 81))
            .build();
        tab.launchUrl(this, START_URL);
        finish();
    }
}
