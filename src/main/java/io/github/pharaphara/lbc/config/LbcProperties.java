package io.github.pharaphara.lbc.config;

import java.nio.file.Path;
import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Everything an operator can change, and nothing else.
 *
 * @param profile    browser profile directory. The session lives here, so a manual
 *                   sign in only ever happens once. Defaults to this machine's own
 *                   data directory, which the container overrides by environment.
 * @param data       where searches are stored, one folder per search.
 * @param headless   false by default: a human must be able to see the page to pass
 *                   a check, and that needs a display.
 * @param browser    how to get one. "attach" starts an ordinary desktop browser
 *                   with a debugging port and talks to it, which is the only way it
 *                   does not announce being automated. "launch" lets the library
 *                   start it instead, which is simpler and louder. "off" never
 *                   starts anything, for a browser you start yourself.
 * @param cdpUrl     attach to a browser that is already running instead of starting
 *                   one. Bring your own browser, and its session.
 * @param vncUrl     where a human can reach the browser when a wall needs a click.
 *                   Empty on a desktop, where the window is simply there.
 * @param chromeArgs extra browser arguments, for the rare host that needs one.
 * @param maxAds     hard stop on ads per search.
 * @param autonomy   read, reply or full. Only read does anything today, and the rest
 *                   is the messaging work still to come.
 * @param pace       how gently to ask. See {@link Pace}.
 */
@ConfigurationProperties("lbc")
public record LbcProperties(
        Path profile,
        Path data,
        boolean headless,
        String browser,
        String cdpUrl,
        String vncUrl,
        List<String> chromeArgs,
        int maxAds,
        String autonomy,
        Pace pace) {

    /**
     * How gently to ask.
     *
     * <p>These are the numbers that decide whether the site treats you as a visitor
     * or as a nuisance, and they were not guessed: a browser that has been reading
     * this kind of site daily for months settles around one to three seconds between
     * requests, and slower still between full page renders. Going faster does not
     * collect more, it collects for less time, because a restricted address collects
     * nothing at all.
     *
     * @param callMinMs        shortest pause between two data calls
     * @param callMaxMs        longest pause between two data calls
     * @param renderMinMs      shortest pause between two page renders, which cost the
     *                         site far more than a data call
     * @param renderMaxMs      longest pause between two page renders
     * @param callsPerMinute   ceiling, whatever the pauses say
     * @param pagesMax         hard stop on pages per collection
     * @param renderedPagesMax pages per call when reading rendered pages, which is
     *                         the slow way in and should stay modest
     */
    public record Pace(int callMinMs, int callMaxMs, int renderMinMs, int renderMaxMs,
                       int callsPerMinute, int pagesMax, int renderedPagesMax) {

        public Pace {
            callMinMs = callMinMs > 0 ? callMinMs : 1500;
            callMaxMs = callMaxMs > callMinMs ? callMaxMs : callMinMs + 2000;
            renderMinMs = renderMinMs > 0 ? renderMinMs : 6000;
            renderMaxMs = renderMaxMs > renderMinMs ? renderMaxMs : renderMinMs + 4000;
            callsPerMinute = callsPerMinute > 0 ? callsPerMinute : 20;
            pagesMax = pagesMax > 0 ? pagesMax : 20;
            renderedPagesMax = renderedPagesMax > 0 ? renderedPagesMax : 3;
        }

        public static Pace defaults() {
            return new Pace(0, 0, 0, 0, 0, 0, 0);
        }

        /** A pause between two data calls, never the same twice. */
        public long callPause() {
            return callMinMs + (long) (Math.random() * (callMaxMs - callMinMs));
        }

        /** A pause between two page renders. */
        public long renderPause() {
            return renderMinMs + (long) (Math.random() * (renderMaxMs - renderMinMs));
        }
    }

    public LbcProperties {
        // No absolute path belongs in here: the container is told where its two
        // directories are, and anywhere else they follow the convention of the
        // machine. See Home.
        profile = profile != null ? profile : Home.dir("profile");
        data = data != null ? data : Home.dir("data");
        browser = browser != null && !browser.isBlank() ? browser : "attach";
        chromeArgs = chromeArgs != null ? chromeArgs : List.of();
        maxAds = maxAds > 0 ? maxAds : 2000;
        autonomy = autonomy != null ? autonomy : "read";
        pace = pace != null ? pace : Pace.defaults();
    }

    public static LbcProperties defaults() {
        return new LbcProperties(null, null, false, null, null, null, null, 0, null, null);
    }

    /** Kept for readability at the call sites. */
    public int maxPages() {
        return pace.pagesMax();
    }

    /** True when the browser is somebody else's, named by its debugging port. */
    public boolean attachedByHand() {
        return cdpUrl != null && !cdpUrl.isBlank();
    }

    /**
     * Where to send a human who has to look at the page.
     *
     * <p>In a container the browser runs on a screen nobody watches, so there is a
     * page to open. On a desktop the window is on the desktop, and telling someone
     * to open a URL to find it would be nonsense.
     */
    public String viewer() {
        return vncUrl != null && !vncUrl.isBlank() ? vncUrl : null;
    }
}
