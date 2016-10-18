'use strict';

// Initial script copied/adapted from link below (MIT License)
// https://github.com/georgewfraser/vscode-javac/blob/a2a6fda/lib/Main.ts

import * as VSCode from 'vscode';
import * as Path from 'path';
import * as FS from 'fs';
import * as PortFinder from 'portfinder';
import * as Net from 'net';
import * as ChildProcess from 'child_process';
import {
    LanguageClient, LanguageClientOptions, SettingMonitor, ServerOptions, StreamInfo
} from 'vscode-languageclient';

PortFinder.basePort = 55747;

// this method is called when your extension is activated
// your extension is activated the very first time the command is executed
export function activate(context: VSCode.ExtensionContext) {
    console.log('Ceylon: activating');

    let ceylonExecutablePath = findExecutable('ceylon');
    console.log(`Ceylon: path ${ceylonExecutablePath}`);

    if (ceylonExecutablePath == null) {
        VSCode.window.showErrorMessage(
            "Couldn't locate ceylon in ceylon.home, $CEYLON_HOME or $PATH");
        return;
    }

    // Options to control the language client
    let clientOptions: LanguageClientOptions = {
        // Register the server for ceylon documents
        documentSelector: ['ceylon'],
        synchronize: {
            // Synchronize the setting section 'ceylon' to the server
            configurationSection: 'ceylon',
            fileEvents: [
                VSCode.workspace.createFileSystemWatcher('**/.ceylon/config'),
                VSCode.workspace.createFileSystemWatcher('**/*.ceylon')
            ]
        }
    }

    function createServer(): Promise<StreamInfo> {
        return new Promise((resolve, reject) => {
            PortFinder.getPort((err, port) => {
                console.log(`Ceylon: port ${port}`);
                // make sure we can run Ceylon, and check the version.
                ChildProcess.execFile(ceylonExecutablePath, ["--version"], null,
                        ((error: Error, stdout, stderr) => {
                    if (error) {
                        VSCode.window.showErrorMessage(
                            "JAVA_HOME not set? Unable to verify the Ceylon version " +
                            "installed at " + ceylonExecutablePath +
                            ": " + error.message);
                        return;
                    }
                    let version = stdout.trim().substring(15);
                    if (!version.startsWith("1.3.0")) {
                        VSCode.window.showErrorMessage(
                            "Unsupported Ceylon version " + version + ". " +
                            "This version of the Ceylon Language VSCode Plugin " +
                            "requires Ceylon 1.3.0 and may not function correctly.");
                    }
                }));

                // TODO Specify repository 'remote=aether:settings.xml' for the
                //      snapshot maven dependencies. Or, include the deps in a flat repo?
                let cwd = context.asAbsolutePath("nodir");
                let lib = context.asAbsolutePath("lib");
                let settings = context.asAbsolutePath("settings.xml");
                let modules = context.asAbsolutePath("out/modules");

                let args = [
                    'run',
                    `--cwd=${cwd}`,
                    '--rep', lib,
                    '--rep', modules,
                    '--rep', "aether:" + settings,
                    '--auto-export-maven-dependencies',
                    'com.vasileff.ceylon.vscode/0.0.1',
                    port.toString(),
                    VSCode.workspace
                        .getConfiguration("ceylon")
                        .get("serverLogPriority").toString()
                ];

                Net.createServer(socket => {
                    resolve({
                        reader: socket,
                        writer: socket
                    });
                }).listen(port, () => {
                    let options = { stdio: 'inherit', cwd: VSCode.workspace.rootPath };

                    console.log("Ceylon: starting server: " + args);
                    // Run the ceylon language server
                    ChildProcess.execFile(ceylonExecutablePath, args, options);
                });
            });
        });
    }

    // Create the language client and start the client.
    let client = new LanguageClient('Ceylon Langauge Client', createServer, clientOptions);
    let disposable = client.start();

	// Push the disposable to the context's subscriptions so that the
	// client can be deactivated on extension deactivation
	context.subscriptions.push(disposable);
}

function findExecutable(binname: string) {
	binname = correctBinname(binname);

    // First search ceylon.home configuration option
    let ceylonHome = VSCode.workspace.getConfiguration("ceylon").get("home");
    if (ceylonHome) {
        let binpath = Path.join(ceylonHome, 'bin', binname);
        if (FS.existsSync(binpath)) {
            return binpath;
        }
    }

	// Then search each CEYLON_HOME bin folder
	if (process.env['CEYLON_HOME']) {
		let workspaces = process.env['CEYLON_HOME'].split(Path.delimiter);
		for (let i = 0; i < workspaces.length; i++) {
			let binpath = Path.join(workspaces[i], 'bin', binname);
			if (FS.existsSync(binpath)) {
				return binpath;
			}
		}
	}

	// Then search PATH parts
	if (process.env['PATH']) {
		let pathparts = process.env['PATH'].split(Path.delimiter);
		for (let i = 0; i < pathparts.length; i++) {
			let binpath = Path.join(pathparts[i], binname);
			if (FS.existsSync(binpath)) {
				return binpath;
			}
		}
	}

	// Else return the binary name directly (this will likely always fail downstream)
	return null;
}

function correctBinname(binname: string) {
	if (process.platform === 'win32')
		return binname + '.bat';
	else
		return binname;
}

// this method is called when your extension is deactivated
export function deactivate() {
    console.log("Ceylon: deactivating");
}
