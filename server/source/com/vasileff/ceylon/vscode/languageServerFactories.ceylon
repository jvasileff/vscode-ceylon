import org.eclipse.lsp4j {
    MessageParams,
    MessageType,
    DiagnosticSeverity,
    Position,
    Range,
    Diagnostic
}

shared
MessageParams newMessageParams(String message, MessageType type) {
    value result = MessageParams();
    result.message = message;
    result.type = type;
    return result;
}

shared
Diagnostic newDiagnostic(
        String message,
        Range range = Range(Position(), Position()),
        DiagnosticSeverity? severity = null,
        String? code = null) {

    value result = Diagnostic();
    result.range = range;
    result.message = message;
    result.code = code;
    result.severity = severity;
    return result;
}

shared
Range newRange(Position start, Position end)
    =>  Range(start, end);

shared
Position newPosition(Integer line, Integer character)
    =>  Position(line, character);
