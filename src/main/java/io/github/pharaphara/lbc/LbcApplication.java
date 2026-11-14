package io.github.pharaphara.lbc;

import java.util.ArrayList;
import java.util.List;

import io.github.pharaphara.lbc.config.Home;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/** LBC, le bon container. */
@SpringBootApplication
@ConfigurationPropertiesScan
public class LbcApplication {

    public static void main(String[] args) {
        SpringApplication.run(LbcApplication.class, arguments(args));
    }

    /**
     * Turn --stdio into what it means.
     *
     * <p>Two ways to be talked to, and they suit different places. A long running
     * server on a port is what a container wants: the browser and its profile stay
     * warm between calls, and several clients can share them. Standard input is what
     * a desktop wants: the client starts the program itself, so there is nothing to
     * launch first and nothing left running afterwards.
     *
     * <p>The long form of this is three properties, and a person configuring a
     * client should not have to know any of them.
     *
     * <p>The log file comes along with it, and that is not a detail: over standard
     * input, every byte written to standard output has to be protocol. A log line
     * landing there is not noise, it is a parse error at the other end, so the log
     * goes to a file and the banner goes to standard error, which clients show.
     */
    static String[] arguments(String[] args) {
        List<String> out = new ArrayList<>(List.of(args));
        if (!out.remove("--stdio")) {
            return args;
        }
        out.add("--spring.profiles.active=stdio");
        if (out.stream().noneMatch(a -> a.startsWith("--logging.file.name="))) {
            out.add("--logging.file.name=" + Home.dir("lbc.log"));
        }
        return out.toArray(String[]::new);
    }
}
