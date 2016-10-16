# Visual Studio Code Language Support for Ceylon

This extension provides support for editing and compiling Ceylon projects in Visual Studio
Code. Currently, the Dart backend is supported. Non-cross platform Ceylon modules for the
Java and JavaScript backends are ignored by this extension.

## Features

- Zero-configuration: open any Ceylon project folder and start editing (`.ceylon/config`
will be used for configuration if present)
- Multithreaded compiles: the module you are editing is immediately recompiled after each
edit while dependent modules are compiled in the background
- Syntax highlighting
- As you type warning and error reporting
![errors](images/screeshot-errors.png)
- Auto completion
![errors](images/screeshot-autocomplete.png)
- Documentation on hover
![hover](images/screeshot-hover.png)

## Requirements

- [Ceylon 1.3.0](https://ceylon-lang.org) ([download](https://ceylon-lang.org/download/))
- [Dart backend for Ceylon DP3](https://github.com/jvasileff/ceylon-dart).
  Simple two step commandline installation:
  `ceylon plugin install --force com.vasileff.ceylon.dart.cli/1.3.0-DP3`
  then `ceylon install-dart --out +USER`
- [Visual Studio Code](https://code.visualstudio.com/Download)

To run programs on the Dart VM (optional and not currently supported on Microsoft
Windows), either
[download](https://www.dartlang.org/downloads/) Dart or install it using Homebrew
as described in the Dart backend for Ceylon
[readme](https://github.com/jvasileff/ceylon-dart).

## Installation

After satisfying the requirements, download and install the extension:

1. Download the current preview version of the extension
([vscode-ceylon-0.0.1.vsix](https://jvasileff.github.io/vscode-ceylon/vscode-ceylon-0.0.1.vsix))
2. Launch Visual Studio Code
3. Open the Extensions View by clicking on the last icon on the left hand side of the
Visual Studio Code interface, or by choosing `View`->`Extensions`
4. Choose `Install from VSIX...` in the Extensions View command dropdown (to activate the
dropdown, click on the three horizontal dots in the top right of the Extensions View)
5. Select the file downloaded in step 1.

The extension must be able to locate the `ceylon` 1.3.0 executable (see Requirements
above). If not already configured as part of your Ceylon 1.3.0 installation, perform one
of the following steps:

- Configure the `ceylon.home` in the Visual Studio Code User Settings (`⌘,`
  on macOS). For example, `"ceylon.home": "/opt/ceylon-1.3.0"`
- Set the `CEYLON_HOME` environment variable
- Adjust the system `PATH` to include the directory containing the `ceylon` executable

Note that if the Ceylon installation can be found using more than one of the above
methods, the first will be used. That is, the order of precedence is the `ceylon.home`
setting, the `CEYLON_HOME` environment variable, and finally, the system `PATH`.

Additionally, Microsoft Windows users must create a `JAVA_HOME` environment variable
pointing to the path of the Java installation to use if one does not already exists. The
path may be something like `c:\Program Files\Java\jdk1.8.0_102`. To do this, search for
"advanced system settings", click the "Environment Variables" button, and then click
"New".

## Extension Settings

This extension contributes the following settings:

* `ceylon.home`: The directory of the Ceylon installation to use.
* `ceylon.generateOutput`: Write compiled binaries to the output repository.
  Note that output is produced regardless of whether or not the source files
  have been saved.
* `ceylon.serverLogPriority`: The logging level for the language server. For
  levels other than 'disabled', a log file will be created for each instance of
  the extension. Log files will be created in the '/tmp' directory if it exists,
  or the system default temporary directory otherwise.
* `ceylon.config.compiler.suppresswarning`: Override the suppresswarning
  setting.
* `ceylon.config.compiler.dartsuppresswarning`: Override the
  dartsuppresswarning setting.
* `ceylon.config.compiler.source`: Override the source repositories. Note that
  this will not take effect without restart.
* `ceylon.config.compiler.resource`: Override the resource repositories. Note
  that this will not take effect without restart.
* `ceylon.config.repositories.output`: Override the output repository
* `ceylon.config.repositories.lookup`: Override the lookup repositories

Note that the `ceylon.generateOutput` and `ceylon.config.*` settings are
intended to be used as workspace settings, but are entirely optional.

## Running and Testing Your Ceylon Program

In order to quickly run and test a module, it's recommended to enabled
`ceylon.generateOutput`, which is disabled by default. New binaries will be
created after every change, even for unsaved source files.

"Tasks" can easily be configured with Visual Studio Code to support calling
`ceylon compile-dart` (useful if `ceylon.generateOutput` is disabled) and
`ceylon run-dart`. It's of course possible to use tasks to call commands for other
backends too, for example, `compile-js`, `run-js`, and `test-js`.

A sample `tasks.json` to get you started:

```json
{
    // See https://go.microsoft.com/fwlink/?LinkId=733558
    // for the documentation about the tasks.json format
    "version": "0.1.0",
    "command": "ceylon",
    "isShellCommand": true,
    "suppressTaskName": true,
    "showOutput": "always",
    "tasks": [
        {
            "taskName": "compile",
            "args": ["compile-dart"],
            "isBuildCommand": true
        },
        {
            "taskName": "run",
            "args": ["run-dart", "com.example.mymodule"] 
        }
    ]
}
```

## Known Issues

This is pre-release software. Please be aware of the following known limitations:

- Source directory configuration changes made in `.ceylon/config` and Visual
  Studio Code settings will not take effect until restart
- When `ceylon.generateOutput` is enabled, binaries are continuously produced,
  even for unsaved edits.
- Changes to `ceylon.backend` (not available yet, coming soon) may leave the compiler
  in an inconsistent state. Restarting Visual Studio Code is recommended.

## Reporting Bugs

Please submit feature requests and bug reports using the
[Github issue tracker](https://github.com/jvasileff/vscode-ceylon/issues).

For bugs, if possible, please include:

- Steps to reproduce
- Portions of code being edited that triggered the bug, if relevant
- Stack traces and other errors or messages that appear in the user interface or the
  language server log. To enable logging, use the `ceylon.serverLogPriority`
  extension setting, which is described in the "Extension Settings" section above.

Please note that while error messages do appear as alerts in the user interface,
diagnostic information is truncated, and proper troubleshooting may require complete
information that is only available in the language server log.

## Release Notes

### 0.0.1

- add support for Microsoft Windows
- avoid hover and completion errors when viewing diffs

### 0.0.0

The initial preview release.
