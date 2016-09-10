import ceylon.file {
    parsePath,
    Directory,
    temporaryDirectory
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

shared
void setLogPriority(String | Priority | Null priority)
    =>  defaultPriority
        =   switch(priority)
            case (is Priority) priority
            case ("trace") trace
            case ("debug") debug
            case ("info") info
            case ("warn") warn
            case ("error") error
            case ("fatal") fatal
            else fatal;

shared
Logger log = (() {
    // TODO allow logging to be disabled?
    //      support logging to the base directory?
    value directory
        =   if (is Directory d = parsePath("/tmp").resource)
            then d else temporaryDirectory;

    value tempFile
        =   directory.TemporaryFile {
                "ceylon-language-server-log-";
                ".log";
            };

    value writer
        =   tempFile.Overwriter();

    void writeToLog(String s) {
        writer.write(s);
        writer.flush();
    }

    addLogWriter {
        void log(Priority p, Category c, String m, Throwable? t) {
            writeToLog("[``system.milliseconds``] ``p.string``: ``m``\n");
            if (exists t ) {
                printStackTrace(t, writeToLog);
            }
        }
    };

    value log = logger(`module`);
    log.info("Logger initialized.");
    return log;
})();
