package io.github.pharaphara.lbc.config;

import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;

import io.github.pharaphara.lbc.browser.Chrome;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.boot.web.server.context.WebServerInitializedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * What an operator needs to know in the first five seconds, including the one
 * thing no software can do for them.
 *
 * <p>This used to be a heredoc at the end of the container's entrypoint, which
 * covered the case where someone reads the logs and no other. A desktop install is
 * a window that opens on a double click, and if that window says nothing then
 * nothing is what the person has to go on. It also belongs here for a plainer
 * reason: the shell was guessing at half of it, while this knows which browser was
 * actually found and which port the server actually took.
 */
@Component
public class Banner {

    private final LbcProperties props;
    private final Chrome chrome;
    private final boolean stdio;

    private int port = 8788;

    public Banner(LbcProperties props, Chrome chrome,
                  @Value("${spring.ai.mcp.server.stdio:false}") boolean stdio) {
        this.props = props;
        this.chrome = chrome;
        this.stdio = stdio;
    }

    @EventListener
    void serverStarted(WebServerInitializedEvent event) {
        port = event.getWebServer().getPort();
    }

    /**
     * Open the browser now rather than on the first question.
     *
     * <p>The gesture this tool cannot do for itself is a human looking at a page
     * and clicking once. That is far easier to ask for while the window is already
     * open and the person is still sitting there, than halfway through a
     * conversation with an assistant that has just been handed a wall.
     */
    @EventListener
    void ready(ApplicationReadyEvent event) {
        String driving = props.attachedByHand()
                ? "attached to " + props.cdpUrl()
                : started();
        // Spoken to over standard input, that stream belongs to the client, and a
        // banner on it is a parse error rather than a greeting. Standard error is
        // where a client shows what its server had to say.
        PrintStream out = stdio ? System.err : System.out;
        out.println(text(driving));
        out.flush();
    }

    private String started() {
        Path exe = chrome.available();
        if (exe == null) {
            return "no browser found on this machine. Install Google Chrome, Microsoft"
                    + " Edge or Chromium, or set LBC_CDP_URL to one you run yourself";
        }
        String url = chrome.start();
        return url == null
                ? exe + ", which did not start: the library will launch its own instead"
                : exe.getFileName() + " on " + url;
    }

    private String text(String driving) {
        String viewer = props.viewer() != null
                ? props.viewer()
                : "the window on this machine's desktop";
        String spokenTo = stdio
                ? "on standard input, by whoever started this"
                : "http://localhost:" + port + "/mcp";
        boolean used = Files.exists(props.profile().resolve("Default").resolve("Cookies"));
        return """

                  le bon container
                  Il a la tete de l emploi.

                  MCP       %s
                  Browser   %s
                  Profile   %s
                            %s
                  Searches  %s
                  Driving   %s

                  Open the browser once and pass the anti robot check by hand, and sign in if
                  you want to. Nothing here forges a fingerprint or buys a captcha, so that one
                  click is the trade. The profile remembers it.
                """.formatted(spokenTo, viewer, props.profile(),
                used ? "already used, so the fast path may already be open"
                        : "brand new, so the data calls will be refused and the rendered"
                        + " pages read instead, about 35 ads per page",
                props.data(), driving);
    }
}
