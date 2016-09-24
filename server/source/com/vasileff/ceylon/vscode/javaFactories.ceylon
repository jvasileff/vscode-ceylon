import java.util.\ifunction {
    Consumer,
    Supplier
}
import java.lang {
    NullPointerException,
    Runnable
}

shared
Supplier<Result> supplier<Result>(Result?() get) =>
        let (outerGet = get) object
        satisfies Supplier<Result> {
    get() => outerGet();
};

shared
Consumer<Arg> consumer<Arg>(Anything(Arg) | Anything(Arg?) f)
        given Arg satisfies Object => object
        satisfies Consumer<Arg> {
    accept = maybeFun(f);
};

shared
Runnable runnable(Anything() run) =>
        let (outerRun = run) object
        satisfies Runnable {
    run = outerRun;
};

Result(Arg?) maybeFun<Result, Arg>(Result(Arg?) | Result(Arg) f)
    =>  let (nullFunction = if (is Anything(Arg?) f) then f else null)
        ((Arg? t) {
            if (exists nullFunction) {
                return nullFunction(t);
            }
            if (!exists t) {
                throw NullPointerException();
            }
            return f(t);
        });
