package io.github.pharaphara.lbc.browser;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.locks.ReentrantLock;
import java.util.function.Function;

import com.microsoft.playwright.BrowserContext;
import com.microsoft.playwright.BrowserType;
import com.microsoft.playwright.Frame;
import com.microsoft.playwright.Page;
import com.microsoft.playwright.Playwright;
import io.github.pharaphara.lbc.LbcException;
import jakarta.annotation.PreDestroy;
import io.github.pharaphara.lbc.config.LbcProperties;
import org.springframework.stereotype.Component;

/**
 * One real browser, one tab, one lock.
 *
 * <p>Two ways to get one. Either this process starts Chromium on a profile
 * directory, which is the turnkey case, or it attaches over the devtools
 * protocol to a browser that is already running, which lets you bring your own
 * and keep the session you already signed into.
 *
 * <p>Nothing here disguises anything. No user agent is forged, no navigator
 * property is patched, and the flag that hides automation is deliberately not
 * passed. A real browser with a real session is the answer to a wall, and when
 * that is not enough a human clicks once.
 */
@Component
@SuppressWarnings("unchecked")
public class Browser implements AutoCloseable {

    /** What a page looks like from the outside: enough to spot a wall. */
    public record PageView(String title, String url, String text, List<String> frames) {
    }

    private final LbcProperties props;
    private final Chrome chrome;
    private final ReentrantLock lock = new ReentrantLock();

    private Playwright playwright;
    private BrowserContext context;
    private com.microsoft.playwright.Browser attached;
    private Page page;
    private volatile String webKey;

    public Browser(LbcProperties props, Chrome chrome) {
        this.props = props;
        this.chrome = chrome;
    }

    /**
     * Run some work with the tab, one caller at a time.
     *
     * <p>Every browser step goes through here. Without it a second request could
     * navigate the tab midway through a collection, and we would page through one
     * search's payload against another search's results.
     */
    public <T> T with(Function<Page, T> work) {
        lock.lock();
        try {
            return work.apply(page());
        } finally {
            lock.unlock();
        }
    }

    public synchronized Page page() {
        if (page != null && !page.isClosed()) {
            return page;
        }
        if (context == null) {
            start();
        }
        List<Page> open = context.pages();
        page = open.isEmpty() ? context.newPage() : open.get(0);
        watchForTheWebKey(page);
        return page;
    }

    private void start() {
        // Either somebody named a browser to talk to, or one is started here the way
        // a person would start it. Only when this machine has none at all does the
        // library launch its own, and that one announces being automated.
        String cdp = props.attachedByHand() ? props.cdpUrl() : chrome.start();
        settleTheDriver();
        try {
            playwright = Playwright.create();
            if (cdp != null && !cdp.isBlank()) {
                attached = playwright.chromium().connectOverCDP(cdp);
                // The first context is THE profile, with the consents already
                // accepted and the session signed in by hand. A fresh one would
                // start from nothing.
                context = attached.contexts().isEmpty()
                        ? attached.newContext() : attached.contexts().get(0);
            } else {
                List<String> args = new ArrayList<>(List.of(
                        // A container has no sandbox helper, and a small /dev/shm.
                        "--no-sandbox", "--disable-dev-shm-usage"));
                args.addAll(props.chromeArgs());
                // The last resort: no browser on this machine to start, or someone
                // asked for this explicitly with lbc.browser=launch.
                context = playwright.chromium().launchPersistentContext(props.profile(),
                        new BrowserType.LaunchPersistentContextOptions()
                                .setHeadless(props.headless())
                                .setLocale("fr-FR")
                                .setTimezoneId("Europe/Paris")
                                .setViewportSize(1440, 900)
                                .setArgs(args));
            }
        } catch (RuntimeException e) {
            close();
            throw new LbcException(LbcException.Kind.BROWSER,
                    "cannot start the browser: " + e,
                    cdp == null
                            ? "check that this machine has a browser and a display"
                            : "check that " + cdp + " is reachable");
        }
    }

    /**
     * Give the library's node runtime a home of its own.
     *
     * <p>Playwright ships a node runtime inside a jar and unpacks it on first use,
     * by default into the system temp directory. On Windows that is a directory the
     * system empties behind your back, so 35 MB came out again on every start. A
     * directory next to the profile means it happens once.
     */
    private static void settleTheDriver() {
        if (System.getProperty("playwright.driver.tmpdir") != null) {
            return;
        }
        java.nio.file.Path dir = io.github.pharaphara.lbc.config.Home.dir("driver");
        try {
            java.nio.file.Files.createDirectories(dir);
            System.setProperty("playwright.driver.tmpdir", dir.toString());
        } catch (java.io.IOException ignored) {
            // The default temp directory is a perfectly good fallback.
        }
    }

    /**
     * Learn the site's public web key from a request the page makes itself.
     *
     * <p>It is not a secret: every visitor's browser sends it in the clear. But it
     * does change now and then, so listening beats hardcoding, and the constant
     * stays only as a starting point.
     */
    private void watchForTheWebKey(Page p) {
        p.onRequest(request -> {
            if (request.url().contains("api.leboncoin.fr")) {
                String k = request.headers().get("api_key");
                if (k != null && !k.isBlank()) {
                    webKey = k;
                }
            }
        });
    }

    /**
     * What this browser looks like from inside a page.
     *
     * <p>Read on a blank page, so it costs no request anywhere. Worth having: the
     * difference between a browser somebody launched and a browser some code
     * launched is visible from JavaScript, and it is the first thing to check when
     * one setup sails through and another gets stopped.
     */
    public Map<String, Object> identity() {
        return with(p -> {
            if (p.url() == null || p.url().isBlank() || "about:blank".equals(p.url())) {
                p.navigate("about:blank");
            }
            Object raw = p.evaluate("""
                    () => ({
                      webdriver: navigator.webdriver,
                      userAgent: navigator.userAgent,
                      languages: (navigator.languages || []).join(','),
                      plugins: (navigator.plugins || []).length,
                      cores: navigator.hardwareConcurrency,
                      platform: navigator.platform
                    })""");
            return raw instanceof Map<?, ?> m ? new java.util.LinkedHashMap<String, Object>(
                    (Map<String, Object>) m) : new java.util.LinkedHashMap<String, Object>();
        });
    }

    /**
     * How this browser is being driven, in the words of what actually happened.
     *
     * <p>Worth saying precisely, because it is the whole difference between a
     * setup that reads the site and one that collects walls, and "started here"
     * covered two cases that could not be less alike: an ordinary browser we
     * started and merely talk to, and one the library launched with the flag that
     * announces it.
     */
    public synchronized String driving() {
        if (props.attachedByHand()) {
            return "attached to " + props.cdpUrl();
        }
        if (attached != null) {
            java.nio.file.Path exe = chrome.executable();
            return (exe != null ? "started " + exe.getFileName() + " and talking to it"
                    : "attached to a browser that was already running")
                    + " over its debugging port, profile " + props.profile();
        }
        if (context != null) {
            return "launched by the library, which announces automation, profile "
                    + props.profile();
        }
        java.nio.file.Path exe = chrome.available();
        return exe != null
                ? "not started yet: " + exe.getFileName() + " will be, profile " + props.profile()
                : "not started yet, and this machine has no desktop browser to start, so the"
                        + " library will launch its own, which announces automation";
    }

    /** The key seen on the wire, or null if the page has not called home yet. */
    public String webKey() {
        return webKey;
    }

    public boolean running() {
        return context != null && page != null && !page.isClosed();
    }

    public PageView view() {
        Page p = page();
        String text;
        try {
            text = p.innerText("body");
        } catch (RuntimeException e) {
            text = "";
        }
        List<String> frames = new ArrayList<>();
        for (Frame f : p.frames()) {
            if (f.url() != null && !f.url().isBlank()) {
                frames.add(f.url());
            }
        }
        return new PageView(safe(p::title), p.url(), text, frames);
    }

    private static String safe(java.util.function.Supplier<String> s) {
        try {
            return s.get();
        } catch (RuntimeException e) {
            return "";
        }
    }

    /**
     * Let go of the browser.
     *
     * <p>A browser somebody else started is theirs: we disconnect and leave its tabs
     * alone, because closing the last tab of a real profile would quit it and take
     * the signed in session down with it. A browser we started ourselves is ours to
     * close, and asking it to close itself over the protocol is what keeps the
     * profile from being marked as crashed, which is the difference between a clean
     * next start and a bar offering to restore the session.
     *
     * <p>Annotated, and not merely AutoCloseable: Spring infers a destroy method
     * for an {@code @Bean} and not for a scanned component, so without this the
     * browser outlived the process that started it. In a container nothing noticed,
     * because stopping the container took everything with it. On a desktop it left
     * an orphaned window and a profile marked as crashed.
     */
    @Override
    @PreDestroy
    public synchronized void close() {
        try {
            if (attached != null) {
                if (chrome.ours()) {
                    attached.close();
                }
                attached = null;
            } else if (context != null) {
                context.close();
            }
        } catch (RuntimeException ignored) {
            // Shutting down is not worth an exception.
        } finally {
            context = null;
            page = null;
            chrome.close();
            if (playwright != null) {
                try {
                    playwright.close();
                } catch (RuntimeException ignored) {
                    // Same.
                }
                playwright = null;
            }
        }
    }
}
