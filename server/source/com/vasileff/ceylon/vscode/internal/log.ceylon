import ceylon.file {
    parsePath,
    Directory
}

shared
void log(String msg)
    =>  logToFile((system.milliseconds / 100).string + ": " + msg + "\n");

Anything(String) logToFile = (() {
    assert (is Directory d = parsePath("/tmp").resource);
    value tempFile = d.TemporaryFile("ideLogfile", ".txt");
    value writer = tempFile.Overwriter();
    value log = (String s) {
        writer.write(s);
        writer.flush();
    };
    log("Logger initialized.");
    return log;
})();
