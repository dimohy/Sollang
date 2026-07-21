const vscode = require('vscode');
const { spawn } = require('child_process');

function format(document) {
    const compiler = vscode.workspace.getConfiguration('sollang').get('compilerPath', 'sollang');
    return new Promise((resolve, reject) => {
        const child = spawn(compiler, ['format', '--stdin'], {
            windowsHide: true,
            stdio: ['pipe', 'pipe', 'pipe']
        });
        const stdout = [];
        const stderr = [];
        child.stdout.on('data', chunk => stdout.push(chunk));
        child.stderr.on('data', chunk => stderr.push(chunk));
        child.on('error', reject);
        child.on('close', code => {
            if (code !== 0) {
                reject(new Error(Buffer.concat(stderr).toString('utf8').trim() || `Sollang formatter exited with ${code}`));
                return;
            }
            resolve(Buffer.concat(stdout).toString('utf8'));
        });
        child.stdin.end(document.getText(), 'utf8');
    });
}

function activate(context) {
    const provider = vscode.languages.registerDocumentFormattingEditProvider('sollang', {
        async provideDocumentFormattingEdits(document) {
            try {
                const text = await format(document);
                const source = document.getText();
                if (source === text) return [];
                let prefix = 0;
                while (prefix < source.length && prefix < text.length && source[prefix] === text[prefix]) prefix++;
                let suffix = 0;
                while (suffix < source.length - prefix && suffix < text.length - prefix
                    && source[source.length - suffix - 1] === text[text.length - suffix - 1]) suffix++;
                const range = new vscode.Range(
                    document.positionAt(prefix),
                    document.positionAt(source.length - suffix));
                return [vscode.TextEdit.replace(range, text.slice(prefix, text.length - suffix))];
            } catch (error) {
                void vscode.window.showErrorMessage(`Sollang formatting failed: ${error.message}`);
                return [];
            }
        }
    });
    context.subscriptions.push(provider);
}

function deactivate() {}

module.exports = { activate, deactivate };
