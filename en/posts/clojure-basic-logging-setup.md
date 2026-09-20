---
title: Clojure basic logging setup
author: Etienne Spillemaeker
published: 2026-09-20
---

Nothing groundbreaking here, just a simple config to get a clojure project going
with logback-classic as a logging backend, and the simple logging façade SLF4J. Most of the library I uses go through SLF4J, so I get their logs as a bonus (you may need adapters otherwise). Here's the `deps.edn` content you need:

```clojure
{:paths ["src" "resources"]
 :deps {ch.qos.logback/logback-classic {:mvn/version "1.6.3"}
        org.slf4j/slf4j-api {:mvn/version "2.0.19"}
       ...}}
```

Then, create a `logback.xml` file in the classpath. Typically, it goes in `resources`. Do not forget to add `resources` to `:paths` in your `deps.edn` file, otherwise it will have no effect.

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE configuration>

<configuration scan="true" scanPeriod="5 seconds">
  <import class="ch.qos.logback.classic.encoder.PatternLayoutEncoder"/>
  <import class="ch.qos.logback.core.ConsoleAppender"/>

  <appender name="STDOUT" class="ConsoleAppender">
    <encoder class="PatternLayoutEncoder">
      <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{50} -%kvp- %msg%n</pattern>
    </encoder>
  </appender>

    <!-- Quiet down noisy libs -->
  <logger name="org.eclipse.jetty" level="INFO"/>
  <logger name="datomic" level="warn"/>
  <logger name="org.apache.activemq" level="warn"/>
  <logger name="io.netty" level="warn"/>

  <root level="debug">
    <appender-ref ref="STDOUT"/>
  </root>
</configuration>
```

Finally, launch your repl, and test that it works:

```clojure
(import '[org.slf4j LoggerFactory])

(let [test-logger (LoggerFactory/getLogger "test-logger")
      backend (.getName (.getClass (LoggerFactory/getILoggerFactory)))]
    (.info test-logger
           "Logging is alive. SLF4J façade bound to backend: {}"
           backend))
```

This config will reload itself every 5 seconds, which will be handy to dial up or down the logging you want to see from the various components you use. For production environments, you'll probably want another way to configure this in order to set the loglevel at runtime.
