# Developing the VSCode Extension

For a detailed documentation on developing Visual Studio Code extensions, see the
[Extending Visual Studio Code documentation](https://code.visualstudio.com/Docs/extensions/overview).
The notes below cover specifics on the Ceylon extension.

### Directory Structure and Quick Start

There are two components to the extension:

* The "client", which can be found in the `client/` subdirectory, is the extension that
runs as part of the Visual Studio Code process, and is responsible for launching the
server. Most of the interesting code is in `client/tsconfig.json` and
`client/src/extension.ts`.
* The "server", which can be found in the `server/` subdirectory, is a Ceylon program that
performs compilation, completion, hover, etc., on behalf of the client. Communication
between the client and server is performed over a TCP socket.

## Developing the Client

1. Be sure to have `npm` installed and available on your path.
2. In the `client/` directory, run `npm install` to download all required dependencies
into the `node_modules` directory.
3. Open the `client/` subdirectory in Visual Studio Code.

While editing `client/src/extension.ts` in Visual Studio Code, a debug session can be
launched by pressing `F5`. Note, however, that the server must first be compiled and
installed to `client/out/modules` (see below.)

Note that the Ceylon extension only works for "workspaces". That is, when opening a
directory that is the root of a Ceylon project in Visual Studio Code. When initiating
a debug session, you may need to open a workspace, close the debug instance
of Visual Studio Code (if not automatically closed), and then launch a second debug
session. Debug sessions default to using the previously opened workspace.

## Developing the Server

1. See version specific notes below regarding dependencies.
2. Compile using the cli `ceylon compile --out ../client/out/modules`. Note that
*currently* the output directory `../client/out/modules` is configured in
`server/.ceylon/config`, although that may change as it causes problems with the
Ceylon/Eclipse plugin.

The `client/lib` directory containes compiled modules that must be available when
compiling and running the server. Currently, for `1.3.0`, this includes a custom build of
`ceylon.markdown`.

### Debugging with Eclipse

To debug the server:

1. Edit `client/src/extension.ts` to not launch the server (comment out
`ChildProcess.execFile ...`)
2. Launch a debug session within Visual Studio Code as described in "Developing the
Client" (`F5`)
3. Debug the `qr` toplevel function in `run.ceylon`, using the port as reported in
the Visual Studio Debug Console in step 2.

## Packaging and Installing the Extension

The plugin can be quickly installed by copying the `client` directory to
`~/.vscode/extensions/`, but only *after* compiling the client. Details TODO. 

However, it is preferable to create a lean `.vsix` installable package

TODO

## Specifics for Ceylon 1.3.0 (master branch)

The following dependencies should be available on herd, and do not need to be compiled:

* `com.vasileff.ceylon.structures/1.0.0` ([github](https://github.com/jvasileff/ceylon-structures))
* `com.vasileff.ceylon.dart.compiler/1.3.0-DP3` ([github](https://github.com/jvasileff/ceylon-dart))

Make sure the extension is configured to use `Ceylon 1.3.0` as described in README.md.

## Specifics for Ceylon 1.3.1 (topic-1.3.1 branch)

The following dependencies must be compiled and available in `~/.ceylon/repo`

* Ceylon Dist & SDK 1.3.1-SNAPSHOT
* `com.vasileff.ceylon.structures/1.1.0-SNAPSHOT` ([github](https://github.com/jvasileff/ceylon-structures))
* `ceylon.ast/1.3.1-SNAPSHOT`
* `com.vasileff.ceylon.dart.compiler/1.3.1-DP5-SNAPSHOT` ([github](https://github.com/jvasileff/ceylon-dart)). 
Install branch `topic-1.3.1` with `./gradlew install`.
* Other? (I think that's it.)

Make sure the extension is configured to use `Ceylon 1.3.1` as described in README.md.
