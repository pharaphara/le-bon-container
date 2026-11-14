package io.github.pharaphara.lbc.browser;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;

import io.github.pharaphara.lbc.config.Home;
import jakarta.annotation.PreDestroy;
import io.github.pharaphara.lbc.config.LbcProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * An ordinary browser, started the way a person starts one.
 *
 * <p>This is the difference between a browser that announces being driven and one
 * that does not. Letting the library launch the browser adds the automation flag,
 * and navigator.webdriver comes back true. Starting a desktop browser with a
 * debugging port open, and merely attaching to it, leaves it false.
 *
 * <p>Nothing is forged and nothing is hidden. A flag is simply not added.
 *
 * <p>This used to live in the container's entrypoint, in shell, which worked right
 * up to the point where there was no shell: a Windows install starts a java main
 * and nothing else. So it moved here, where it also knows more than a script could
 * — which browsers this machine actually has, and which of them is the real one
 * rather than the copy a test framework downloaded.
 */
@Component
public class Chrome implements AutoCloseable {

    private static final Logger log = LoggerFactory.getLogger(Chrome.class);

    /** The port everyone expects, used when it is free. */
    private static final int PREFERRED_PORT = 9222;

    private static final long READY_MS = 30_000;

    /** How long a browser that was asked to close gets to finish doing it. */
    private static final long CLOSE_MS = 15_000;
    private static final long STEP_MS = 250;

    private final LbcProperties props;

    private Process process;
    private Path exe;
    private String cdpUrl;
    private boolean asked;

    public Chrome(LbcProperties props) {
        this.props = props;
    }

    /**
     * A browser to talk to, or null when this machine has none to start.
     *
     * <p>Null is not a failure: it means the caller should fall back to letting the
     * library launch its own, which is louder but works.
     */
    public synchronized String start() {
        if (cdpUrl != null) {
            return cdpUrl;
        }
        if (!"attach".equalsIgnoreCase(props.browser())) {
            return null;
        }
        // Somebody else's browser, already listening. Theirs is better than ours:
        // it has their history, their cookies and their clearance.
        if (listening(PREFERRED_PORT)) {
            cdpUrl = "http://127.0.0.1:" + PREFERRED_PORT;
            log.info("a browser is already listening on {}, talking to that one", PREFERRED_PORT);
            return cdpUrl;
        }
        exe = available();
        if (exe == null) {
            log.warn("no chrome, edge or chromium found on this machine, so the library will"
                    + " launch its own, and that one announces being automated");
            return null;
        }
        int port = freePort();
        try {
            Files.createDirectories(props.profile());
            // A persistent profile remembers which machine last used it, by hostname,
            // and a container gets a new one every time it is recreated. Chromium then
            // finds a lock it believes another machine still holds and refuses to open
            // the profile at all. Nothing is running yet here, so the lock is stale.
            clearStaleLocks(props.profile());
            process = new ProcessBuilder(command(port))
                    .redirectOutput(ProcessBuilder.Redirect.DISCARD)
                    .redirectError(ProcessBuilder.Redirect.DISCARD)
                    .start();
        } catch (IOException e) {
            log.warn("could not start {}: {}", exe, e.getMessage());
            process = null;
            return null;
        }
        if (!waitForPort(port)) {
            log.warn("{} did not open its debugging port within {} s", exe, READY_MS / 1000);
            close();
            return null;
        }
        cdpUrl = "http://127.0.0.1:" + port;
        log.info("started {} on port {}, profile {}", exe.getFileName(), port, props.profile());
        return cdpUrl;
    }

    /** True when the browser is ours to close, rather than one we found running. */
    public synchronized boolean ours() {
        return process != null && process.isAlive();
    }

    /**
     * Say that the browser has been asked, over the protocol, to close itself.
     *
     * <p>Which changes what {@link #close()} is allowed to do: wait, rather than
     * terminate something that is already on its way out.
     */
    public synchronized void closingItself() {
        this.asked = true;
    }

    public synchronized Path executable() {
        return exe;
    }

    /**
     * Which browser would be used, without starting anything.
     *
     * <p>For the banner, which has to say what is about to happen before it has
     * happened.
     */
    public synchronized Path available() {
        if (exe == null) {
            exe = find();
        }
        return exe;
    }

    private List<String> command(int port) {
        List<String> cmd = new ArrayList<>();
        cmd.add(exe.toString());
        cmd.add("--remote-debugging-port=" + port);
        cmd.add("--remote-allow-origins=*");
        cmd.add("--user-data-dir=" + props.profile());
        cmd.add("--lang=" + System.getenv().getOrDefault("LBC_LANG", "fr-FR"));
        cmd.add("--accept-lang=" + System.getenv()
                .getOrDefault("LBC_ACCEPT_LANG", "fr-FR,fr,en-US,en"));
        cmd.add("--window-size=1440,900");
        cmd.add("--no-first-run");
        cmd.add("--no-default-browser-check");
        if (props.headless()) {
            cmd.add("--headless=new");
        }
        if (!Home.windows() && !Home.mac()) {
            // A container has no sandbox helper, and a small /dev/shm. A desktop has
            // both, and switching off its sandbox to no purpose would be rude.
            cmd.add("--no-sandbox");
            cmd.add("--disable-dev-shm-usage");
        }
        cmd.addAll(props.chromeArgs());
        cmd.add("about:blank");
        return cmd;
    }

    /**
     * The browser this machine has, preferring the one a person uses.
     *
     * <p>Order matters more than it looks. A browser somebody installed and has been
     * reading the web with carries a profile, a history and a reputation; the copy a
     * test framework downloaded carries none of that, and the sites that hand out
     * walls can tell. So the real ones come first, and Playwright's own is the last
     * resort — which, in the container, is also the only one there is.
     */
    private Path find() {
        for (Path p : candidates()) {
            if (p != null && Files.isExecutable(p)) {
                return p;
            }
        }
        return null;
    }

    private List<Path> candidates() {
        List<Path> out = new ArrayList<>();
        if (Home.windows()) {
            String local = System.getenv("LOCALAPPDATA");
            String files = System.getenv("ProgramFiles");
            String x86 = System.getenv("ProgramFiles(x86)");
            add(out, local, "Google\\Chrome\\Application\\chrome.exe");
            add(out, files, "Google\\Chrome\\Application\\chrome.exe");
            add(out, x86, "Google\\Chrome\\Application\\chrome.exe");
            add(out, x86, "Microsoft\\Edge\\Application\\msedge.exe");
            add(out, files, "Microsoft\\Edge\\Application\\msedge.exe");
            add(out, local, "Chromium\\Application\\chrome.exe");
            out.addAll(playwright("chrome-win", "chrome.exe"));
        } else if (Home.mac()) {
            out.add(Path.of("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"));
            out.add(Path.of("/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"));
            out.add(Path.of("/Applications/Chromium.app/Contents/MacOS/Chromium"));
            out.addAll(playwright("chrome-mac", "Chromium.app/Contents/MacOS/Chromium"));
        } else {
            // The container's browser lives here, and it is the only one it has.
            out.addAll(playwright("chrome-linux", "chrome"));
            out.add(Path.of("/usr/bin/google-chrome"));
            out.add(Path.of("/usr/bin/google-chrome-stable"));
            out.add(Path.of("/usr/bin/chromium"));
            out.add(Path.of("/usr/bin/chromium-browser"));
            out.add(Path.of("/snap/bin/chromium"));
        }
        return out;
    }

    private static void add(List<Path> out, String base, String rest) {
        if (base != null && !base.isBlank()) {
            out.add(Path.of(base, rest));
        }
    }

    /**
     * Playwright's own browsers, newest version first.
     *
     * <p>The layout is $PLAYWRIGHT_BROWSERS_PATH/chromium-<build>/<platform dir>/, and
     * the build number is whatever the library was pinned to, so it is read off the
     * disk rather than guessed. Both chromium- and chromium_headless_shell- exist
     * there; only the first one has a window, which is the whole point here.
     */
    private List<Path> playwright(String platformDir, String binary) {
        List<Path> roots = new ArrayList<>();
        String env = System.getenv("PLAYWRIGHT_BROWSERS_PATH");
        if (env != null && !env.isBlank() && !"0".equals(env)) {
            roots.add(Path.of(env));
        }
        if (Home.windows()) {
            add(roots, System.getenv("LOCALAPPDATA"), "ms-playwright");
        } else if (Home.mac()) {
            roots.add(Path.of(System.getProperty("user.home", "."),
                    "Library", "Caches", "ms-playwright"));
        } else {
            roots.add(Path.of(System.getProperty("user.home", "."), ".cache", "ms-playwright"));
        }
        List<Path> out = new ArrayList<>();
        for (Path root : roots) {
            if (!Files.isDirectory(root)) {
                continue;
            }
            try (Stream<Path> builds = Files.list(root)) {
                builds.filter(p -> p.getFileName().toString().startsWith("chromium-"))
                        .sorted(Comparator.comparing((Path p) -> p.getFileName().toString())
                                .reversed())
                        // chrome-linux on one build, chrome-linux64 on another: both
                        // spellings have shipped, so try the exact name and a suffix.
                        .forEach(build -> {
                            out.add(build.resolve(platformDir).resolve(binary));
                            out.add(build.resolve(platformDir + "64").resolve(binary));
                        });
            } catch (IOException ignored) {
                // A directory we cannot list is a directory with no browser in it.
            }
        }
        return out;
    }

    private static void clearStaleLocks(Path profile) {
        try (Stream<Path> files = Files.list(profile)) {
            files.filter(p -> p.getFileName().toString().startsWith("Singleton"))
                    .forEach(p -> {
                        try {
                            Files.deleteIfExists(p);
                        } catch (IOException ignored) {
                            // Windows has no such locks, and a lock we cannot delete
                            // will announce itself clearly enough on its own.
                        }
                    });
        } catch (IOException ignored) {
            // A brand new profile has nothing to clear.
        }
    }

    private static boolean listening(int port) {
        try (Socket s = new Socket()) {
            s.connect(new InetSocketAddress("127.0.0.1", port), 300);
            return true;
        } catch (IOException e) {
            return false;
        }
    }

    private boolean waitForPort(int port) {
        long deadline = System.currentTimeMillis() + READY_MS;
        while (System.currentTimeMillis() < deadline) {
            if (listening(port)) {
                return true;
            }
            if (process != null && !process.isAlive()) {
                return false;
            }
            try {
                Thread.sleep(STEP_MS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return false;
            }
        }
        return false;
    }

    /** The expected port when it is free, any free port when it is not. */
    private static int freePort() {
        if (!listening(PREFERRED_PORT)) {
            return PREFERRED_PORT;
        }
        try (ServerSocket s = new ServerSocket(0)) {
            return s.getLocalPort();
        } catch (IOException e) {
            return PREFERRED_PORT;
        }
    }

    /**
     * Stop the browser we started, and only that one.
     *
     * <p>Terminating Chromium leaves the profile marked as having crashed, and the
     * next window opens with a bar asking to restore it. The clean way out is
     * {@link Browser#close()}, which asks the browser over the protocol to close
     * itself; when that has happened, all this has to do is wait.
     *
     * <p>Waiting is not politeness, and it is the whole of a bug that only showed
     * on Windows. Process.destroy sends a term signal on Unix, which Chromium
     * handles by shutting down properly, and calls TerminateProcess on Windows,
     * which it cannot handle at all. So a browser that had just been asked to leave
     * was being killed halfway through writing its own preferences: the profile
     * stayed marked Crashed, and a child process outlived the server. Measured on a
     * Windows runner, where macOS and Linux had been passing all along.
     */
    @Override
    @PreDestroy
    public synchronized void close() {
        if (process == null) {
            cdpUrl = null;
            asked = false;
            return;
        }
        try {
            if (asked) {
                process.waitFor(CLOSE_MS, java.util.concurrent.TimeUnit.MILLISECONDS);
            }
            if (process.isAlive()) {
                // Nobody asked it, or it did not go: the blunt way, for a browser
                // that would otherwise outlive the thing that started it.
                process.descendants().forEach(ProcessHandle::destroy);
                process.destroy();
                if (!process.waitFor(5, java.util.concurrent.TimeUnit.SECONDS)) {
                    process.destroyForcibly();
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        process = null;
        cdpUrl = null;
        asked = false;
    }
}
