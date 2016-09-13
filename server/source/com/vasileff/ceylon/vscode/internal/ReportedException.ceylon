"A wrapper for an exception that has already been reported to the user."
shared class ReportedException(Throwable cause) extends Exception(null, cause) {}