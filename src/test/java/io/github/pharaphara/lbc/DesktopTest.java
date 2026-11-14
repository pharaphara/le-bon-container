package io.github.pharaphara.lbc;

import java.nio.file.Path;
import java.util.List;

import io.github.pharaphara.lbc.browser.Chrome;
import io.github.pharaphara.lbc.config.Home;
import io.github.pharaphara.lbc.config.LbcProperties;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The same application installed on somebody's machine, where there is no
 * container to be told where things go.
 *
 * <p>Nothing here starts a browser. What is worth pinning down is the part that
 * used to be two absolute paths written for Linux, and the moment the tool decides
 * not to start anything at all.
 */
class DesktopTest {

    @Test
    void thereIsAlwaysSomewhereToPutTheProfile() {
        LbcProperties props = LbcProperties.defaults();
        assertNotNull(props.profile(), "a profile directory is never optional");
        assertNotNull(props.data(), "neither is somewhere to keep the searches");
        assertTrue(props.profile().isAbsolute(), props.profile().toString());
        assertTrue(props.data().isAbsolute(), props.data().toString());
        // The two must not be the same directory: one holds a browser profile, the
        // other one folder per search, and forgetting a search deletes a folder.
        assertFalse(props.profile().equals(props.data()));
    }

    @Test
    void theDirectoriesAreNamedAfterTheApplication() {
        Path dir = Home.dir("profile");
        assertEquals("profile", dir.getFileName().toString());
        assertEquals("le-bon-container", dir.getParent().getFileName().toString());
    }

    @Test
    void theContainerKeepsBeingToldWhereItsVolumesAre() {
        // What the image sets, which must still win over any default.
        LbcProperties props = new LbcProperties(Path.of("/profile"), Path.of("/data"),
                false, null, null, "http://localhost:7900", null, 0, null, null);
        assertEquals(Path.of("/profile"), props.profile());
        assertEquals(Path.of("/data"), props.data());
        assertEquals("http://localhost:7900", props.viewer());
    }

    @Test
    void attachIsTheDefaultWayToDriveABrowser() {
        assertEquals("attach", LbcProperties.defaults().browser());
        assertFalse(LbcProperties.defaults().attachedByHand(),
                "no cdp url was named, so nobody else's browser is involved");
    }

    @Test
    void offMeansNothingIsStarted() {
        LbcProperties props = new LbcProperties(null, null, false, "off", null, null,
                null, 0, null, null);
        // No process, no port, no browser: the only guarantee that a setting named
        // off actually leaves the machine alone.
        assertNull(new Chrome(props).start());
    }

    @Test
    void stdioIsOneFlagRatherThanThreeProperties() {
        String[] out = LbcApplication.arguments(new String[] {"--stdio"});
        List<String> args = List.of(out);
        assertFalse(args.contains("--stdio"), "the shorthand is translated, not passed on");
        assertTrue(args.contains("--spring.profiles.active=stdio"), args.toString());
        // Over standard input, a log line on standard output is a parse error at
        // the other end, so a file is named before anything can be written.
        assertTrue(args.stream().anyMatch(a -> a.startsWith("--logging.file.name=")),
                args.toString());
    }

    @Test
    void aLogFileNamedByHandIsLeftAlone() {
        String[] out = LbcApplication.arguments(
                new String[] {"--stdio", "--logging.file.name=/tmp/mine.log"});
        assertEquals(1, List.of(out).stream()
                .filter(a -> a.startsWith("--logging.file.name=")).count());
        assertTrue(List.of(out).contains("--logging.file.name=/tmp/mine.log"));
    }

    @Test
    void withoutTheFlagNothingIsAdded() {
        String[] given = {"--server.port=9000"};
        assertArrayEquals(given, LbcApplication.arguments(given));
    }

    @Test
    void aViewerIsOptionalAndNobodyIsSentToAnUrlThatIsNotThere() {
        assertNull(LbcProperties.defaults().viewer(), "a desktop has no viewer page");
    }
}
