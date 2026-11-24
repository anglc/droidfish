/*
 * ColaChess UI helpers (tablet / wide layout).
 */
package org.petero.droidfish;

import android.app.UiModeManager;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.Configuration;

public final class ColaUi {
    private ColaUi() {}

    /** True on Android TV / Google TV devices and emulators. */
    public static boolean isTelevision(Context context) {
        UiModeManager uiMode =
                (UiModeManager) context.getSystemService(Context.UI_MODE_SERVICE);
        if (uiMode != null
                && uiMode.getCurrentModeType() == Configuration.UI_MODE_TYPE_TELEVISION) {
            return true;
        }
        PackageManager pm = context.getPackageManager();
        return pm != null && pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK);
    }

    /** True for typical 7"+ tablets, TV, and large foldable inner screens. */
    public static boolean isTablet(Context context) {
        if (isTelevision(context))
            return true;
        return context.getResources().getConfiguration().smallestScreenWidthDp >= 600;
    }

    /** Board + side panel instead of stacked phone portrait layout. */
    public static boolean useSideBySideMainLayout(Context context) {
        Configuration c = context.getResources().getConfiguration();
        return c.orientation == Configuration.ORIENTATION_LANDSCAPE || isTablet(context);
    }
}