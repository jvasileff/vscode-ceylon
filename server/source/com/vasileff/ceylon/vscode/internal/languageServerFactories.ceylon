import io.typefox.lsapi {
    MessageParams,
    MessageType,
    DiagnosticSeverity
}
import io.typefox.lsapi.impl {
    MessageParamsImpl,
    DiagnosticImpl,
    PositionImpl,
    RangeImpl
}

shared
MessageParams newMessageParams(String message, MessageType type) {
    value result = MessageParamsImpl();
    result.message = message;
    result.type = type;
    return result;
}

shared
DiagnosticImpl newDiagnostic(
        String message,
        RangeImpl range
            =   RangeImpl(PositionImpl(), PositionImpl()),
        DiagnosticSeverity? severity = null,
        String? code = null) {

    value result = DiagnosticImpl();
    result.range = range;
    result.message = message;
    result.code = code;
    result.severity = severity;
    return result;
}

shared
RangeImpl newRange(PositionImpl start, PositionImpl end)
    =>  RangeImpl(start, end);

shared
PositionImpl newPosition(Integer line, Integer character)
    =>  PositionImpl(line, character);
