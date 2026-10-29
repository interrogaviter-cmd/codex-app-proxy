import fs from 'node:fs';

const [guidePath, configPath] = process.argv.slice(2);
if (!guidePath || !configPath) {
  throw new Error('Usage: node verify-start-here.mjs <START-HERE.html> <default_config.json>');
}

const html = fs.readFileSync(guidePath, 'utf8');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

const required = [
  'id="preset"', 'id="proxyType"', 'id="proxyHost"', 'id="proxyPort"',
  'id="disableQuic"', 'id="logMode"', 'id="logSummary"', 'id="bypassList"', 'id="save"', 'id="resetAll"',
  'id="jsonOutput"', 'id="commandOutput"', 'V2RayN', 'Clash Verge Rev',
  'Clash / Mihomo', '通用 SOCKS5', '出厂配置', '恢复全部出厂值',
  'START-HERE.html', 'CodexProxyLauncher.exe', '仅错误（推荐）', '始终记录', '日志已关闭'
];
for (const marker of required) {
  if (!html.includes(marker)) throw new Error(`START-HERE missing marker: ${marker}`);
}

if (/<script\b[^>]*\bsrc\s*=/i.test(html) || /<link\b[^>]*\bhref\s*=/i.test(html)) {
  throw new Error('START-HERE must not load external scripts or stylesheets');
}

const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/gi)].map(match => match[1]);
if (scripts.length !== 1) throw new Error(`Expected one inline script, found ${scripts.length}`);
new Function(scripts[0]);

// Exercise the actual command generator without loading the browser UI.
const generatorEnd = scripts[0].indexOf("    $('preset').addEventListener");
if (generatorEnd < 0) throw new Error('Could not locate guide command generator');
const { commandFor, validate } = new Function(`${scripts[0].slice(0, generatorEnd)}\nreturn { commandFor, validate };`)();
const safeConfig = { proxy: { type: 'http', host: '127.0.0.1', port: 10808 }, bypass_list: ['localhost', '<-loopback>', '10.*', '[::1]', 'https://example.com'], disable_quic: true };
const expectedCommand = `& (Join-Path (Get-AppxPackage -Name OpenAI.Codex).InstallLocation "app\\ChatGPT.exe") '--proxy-server=http://127.0.0.1:10808' '--proxy-bypass-list=localhost;<-loopback>;10.*;[::1];https://example.com' --disable-quic`;
if (validate(safeConfig) || commandFor(safeConfig) !== expectedCommand) throw new Error('Safe PowerShell command changed unexpectedly');
for (const attack of ["localhost'", 'localhost"', 'localhost’$(Write-Output INJECTED)', '$(Write-Output INJECTED)', 'localhost;Write-Output INJECTED', 'localhost\nWrite-Output INJECTED']) {
  for (const testCase of [{ ...safeConfig, proxy: { ...safeConfig.proxy, host: attack } }, { ...safeConfig, bypass_list: [attack] }]) {
    if (!validate(testCase) || commandFor(testCase)) throw new Error('Unsafe input was accepted for a PowerShell command');
  }
}
if (process.env.CODEX_PROXY_PRINT_TEST_COMMAND === '1') console.log(expectedCommand);

if (config.proxy.type !== 'http' || config.proxy.host !== '127.0.0.1' || config.proxy.port !== 10808) {
  throw new Error('default_config.json no longer matches the documented factory proxy');
}
if (config.disable_quic !== true || !Array.isArray(config.bypass_list) || config.bypass_list.length < 4) {
  throw new Error('default_config.json is missing required safe defaults');
}
if (config.log_mode !== 'errors') {
  throw new Error('default_config.json log_mode must default to errors');
}
for (const value of ['http', '127.0.0.1', '10808']) {
  if (!html.includes(value)) throw new Error(`START-HERE does not expose factory value: ${value}`);
}

console.log('START-HERE verification passed');
