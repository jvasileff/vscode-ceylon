import ceylon.file {
    parsePath,
    Directory,
    temporaryDirectory,
    Writer
}
import ceylon.logging {
    logger,
    addLogWriter,
    Priority,
    Category,
    Logger,
    defaultPriority,
    info,
    trace,
    warn,
    debug,
    fatal,
    error
}

variable Boolean loggingEnabled = true;

shared
void setLogPriority(String | Priority | Null priority) {
    loggingEnabled
        =   !(priority?.equals("disabled") else false);

    defaultPriority
        =   switch(priority)
            case (is Priority) priority
            case ("trace") trace
            case ("debug") debug
            case ("info") info
            case ("warn") warn
            case ("error") error
            case ("fatal") fatal
            else fatal;
}

Writer logWriter = (() {
    // logWriter won't be initialized (the log file won't be created) until
    // the first the first message is logged

    value directory
        =   if (is Directory d = parsePath("/tmp").resource)
            then d else temporaryDirectory;

    value tempFile
        =   directory.TemporaryFile {
                "ceylon-language-server-log-";
                ".log";
            };

    return tempFile.Overwriter("UTF-8");
})();

shared
Logger log = (() {
    void writeToLog(String s) {
        logWriter.write(s);
        logWriter.flush();
    }

    addLogWriter {
        void log(Priority p, Category c, String m, Throwable? t) {
            if (loggingEnabled) {
                writeToLog("[``system.milliseconds``] ``p.string``: ``m``\n");
                if (exists t) {
                    printStackTrace(t, writeToLog);
                }
            }
        }
    };

    value log = logger(`module`);
    log.info("Logger initialized.");
    return log;
})();
