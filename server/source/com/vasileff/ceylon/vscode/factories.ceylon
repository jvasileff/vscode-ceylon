import io.typefox.lsapi.impl {
    MessageParamsImpl,
    DiagnosticImpl,
    PositionImpl,
    RangeImpl
}
import io.typefox.lsapi {
    MessageParams,
    MessageType,
    DiagnosticSeverity
}

MessageParams newMessageParams(String message, MessageType type) {
    value result = MessageParamsImpl();
    result.message = message;
    result.type = type;
    return result;
}

DiagnosticImpl newDiagnostic(
        String message, RangeImpl range, DiagnosticSeverity? severity = null,
        String? code = null) {

    value result = DiagnosticImpl();
    result.range = range;
    result.message = message;
    result.code = code;
    result.severity = severity;
    return result;
}

RangeImpl newRange(PositionImpl start, PositionImpl end)
    =>  RangeImpl(start, end);

PositionImpl newPosition(Integer line, Integer character)
    =>  PositionImpl(line, character);
