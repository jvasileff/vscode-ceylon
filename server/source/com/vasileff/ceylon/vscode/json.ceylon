import ceylon.interop.java {
    javaString,
    CeylonIterable
}
import ceylon.language {
    newMap=map
}

import java.lang {
    JString=String,
    JBoolean=Boolean,
    JInteger=Integer,
    JDouble=Double
}
import java.util {
    JMap=Map,
    JList=List
}

shared
alias JsonValue
    =>  JsonObject | JsonArray | Null
            | String | Boolean | Integer | Float;

shared
alias JavaJsonValue
    =>  JMap<String, Anything> | JList<Anything> | Null
            | JString | JBoolean | JInteger | JDouble;

shared suppressWarnings("uncheckedTypeArguments")
JsonValue wrapJavaJson(JavaJsonValue o) {
    if (is JMap<out Anything, out Anything> o ) {
        assert (is JMap<out JString, out Anything> o );
        return JsonObject(o);
    }
    if (is JList<out Anything> o) {
        return JsonArray(o);
    }
    return switch (o)
        case (is JString) o.string
        case (is JBoolean) o.booleanValue()
        case (is JInteger) o.longValue()
        case (is JDouble) o.doubleValue()
        case (is Null) null;
}

shared
JsonValue forceWrapJavaJson(Anything o) {
    assert (is JavaJsonValue o );
    return wrapJavaJson(o);
}

shared
class JsonObject(JMap<out JString, out Anything> delegate)
        satisfies Map<String, JsonValue> {

    // watch out, delegate may have nulls!

    shared actual
    Map<String, JsonValue> clone()
        =>  newMap(this);

    shared actual
    Boolean defines(Object key)
        =>  if (is String key)
            then delegate.containsKey(javaString(key))
            else false;

    shared actual
    JsonValue get(Object key)
        =>  if (is String key)
            then forceWrapJavaJson(delegate.get(javaString(key)))
            else null;

    shared
    JsonArray? getArrayOrNull(String key)
        =>  switch (result = get(key))
            case (is JsonArray) result
            else null;

    shared
    JsonArray getArray(String key) {
        assert (exists result = getArrayOrNull(key));
        return result;
    }

    shared
    Boolean? getBooleanOrNull(String key)
        =>  switch (result = get(key))
            case (is Boolean) result
            else null;

    shared
    Boolean getBoolean(String key) {
        assert (exists result = getBooleanOrNull(key));
        return result;
    }

    shared
    Float? getFloatOrNull(String key)
        =>  switch (result = get(key))
            case (is Float) result
            else null;

    shared
    Float getFloat(String key) {
        assert (exists result = getFloatOrNull(key));
        return result;
    }

    shared
    Integer? getIntegerOrNull(String key)
        =>  switch (result = get(key))
            case (is Integer) result
            else null;

    shared
    Integer getInteger(String key) {
        assert (exists result = getIntegerOrNull(key));
        return result;
    }

    shared
    JsonObject? getObjectOrNull(String key)
        =>  switch (result = get(key))
            case (is JsonObject) result
            else null;

    shared
    JsonObject getObject(String key) {
        assert (exists result = getObjectOrNull(key));
        return result;
    }

    shared
    String? getStringOrNull(String key)
        =>  switch (result = get(key))
            case (is String) result
            else null;

    shared
    String getString(String key) {
        assert (exists result = getStringOrNull(key));
        return result;
    }

    shared actual
    Iterator<String->JsonValue> iterator()
        =>  CeylonIterable<JString>(delegate.keySet()).map((key)
            =>  key.string -> get(key.string)).iterator();

    shared actual
    Integer hash
        =>  (super of Map<>).hash;

    shared actual
    Boolean equals(Object that)
        =>  (super of Map<>).equals(that);
}

shared
class JsonArray(JList<out Anything> delegate) satisfies List<JsonValue> {
    // watch out, delegate may have nulls!

    value iterable = CeylonIterable<Anything>(delegate);

    shared actual
    Iterator<JsonValue> iterator()
        =>  iterable.map(forceWrapJavaJson).iterator();

    shared actual
    JsonValue? getFromFirst(Integer index)
        =>  if (exists sj = delegate.get(index))
            then forceWrapJavaJson(sj)
            else null;

    shared
    JsonArray? getArrayOrNull(Integer index)
        =>  switch (result = getFromFirst(index))
            case (is JsonArray) result
            else null;

    shared
    JsonArray getArray(Integer index) {
        assert (exists result = getArrayOrNull(index));
        return result;
    }

    shared
    Boolean? getBooleanOrNull(Integer index)
        =>  switch (result = getFromFirst(index))
            case (is Boolean) result
            else null;

    shared
    Boolean getBoolean(Integer index) {
        assert (exists result = getBooleanOrNull(index));
        return result;
    }

    shared
    Float? getFloatOrNull(Integer index)
        =>  switch (result = getFromFirst(index))
            case (is Float) result
            else null;

    shared
    Float getFloat(Integer index) {
        assert (exists result = getFloatOrNull(index));
        return result;
    }

    shared
    Integer? getIntegerOrNull(Integer index)
        =>  switch (result = getFromFirst(index))
            case (is Integer) result
            else null;

    shared
    Integer getInteger(Integer index) {
        assert (exists result = getIntegerOrNull(index));
        return result;
    }

    shared
    JsonObject? getObjectOrNull(Integer index)
        =>  switch (result = getFromFirst(index))
            case (is JsonObject) result
            else null;

    shared
    JsonObject getObject(Integer index) {
        assert (exists result = getObjectOrNull(index));
        return result;
    }

    shared
    String? getStringOrNull(Integer index)
        =>  switch (result = getFromFirst(index))
            case (is String) result
            else null;

    shared
    String getString(Integer index) {
        assert (exists result = getStringOrNull(index));
        return result;
    }

    shared actual
    Integer? lastIndex
        =>  delegate.size() - 1;

    shared actual
    Integer hash
        =>  (super of List<Anything>).hash;

    shared actual
    Boolean equals(Object that)
        =>  (super of List<Anything>).equals(that);
}
