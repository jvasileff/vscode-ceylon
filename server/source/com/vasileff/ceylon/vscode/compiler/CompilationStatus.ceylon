shared class CompilationStatus
        of success | errorTypeChecker | errorDartBackend {
    shared new success {}
    shared new errorTypeChecker {}
    shared new errorDartBackend {}
}
