import java.util.\ifunction {
    Consumer
}
import java.lang {
    NullPointerException
}

Consumer<Arg> consumer<Arg>(Anything(Arg) | Anything(Arg?) f)
given Arg satisfies Object => object
        satisfies Consumer<Arg> {
    accept = maybeFun(f);
};

Result(Arg?) maybeFun<Result, Arg>(Result(Arg?) | Result(Arg) f)
        =>  let (nullFunction
        = if (is Anything(Arg?) f) then f else null)
((Arg? t) {
    if (exists nullFunction) {
        return nullFunction(t);
    }
    if (!exists t) {
        throw NullPointerException();
    }
    return f(t);
});
