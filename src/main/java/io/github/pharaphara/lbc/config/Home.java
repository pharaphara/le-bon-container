package io.github.pharaphara.lbc.config;

import java.nio.file.Path;
import java.util.Locale;

/**
 * Where a machine keeps things, which is not the same on every machine.
 *
 * <p>The container is told where to put its two directories, by environment, and
 * does not come through here. A desktop install is not told anything, so it has to
 * know the convention of the system it landed on: a profile and a pile of searches
 * belong under the user's own data directory, never next to the executable, which
 * on Windows is a directory an ordinary user cannot write to.
 */
public final class Home {

    private static final String APP = "le-bon-container";

    private Home() {
    }

    public static boolean windows() {
        return os().contains("win");
    }

    public static boolean mac() {
        return os().contains("mac") || os().contains("darwin");
    }

    /** The directory this application owns, created by whoever writes in it. */
    public static Path dir(String name) {
        return base().resolve(APP).resolve(name);
    }

    private static Path base() {
        if (windows()) {
            String local = env("LOCALAPPDATA");
            return local != null ? Path.of(local) : userHome().resolve("AppData").resolve("Local");
        }
        if (mac()) {
            return userHome().resolve("Library").resolve("Application Support");
        }
        String xdg = env("XDG_DATA_HOME");
        return xdg != null ? Path.of(xdg) : userHome().resolve(".local").resolve("share");
    }

    private static Path userHome() {
        return Path.of(System.getProperty("user.home", "."));
    }

    private static String env(String name) {
        String v = System.getenv(name);
        return v == null || v.isBlank() ? null : v;
    }

    private static String os() {
        return System.getProperty("os.name", "").toLowerCase(Locale.ROOT);
    }
}
