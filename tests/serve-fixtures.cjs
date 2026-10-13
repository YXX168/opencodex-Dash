// Local UI fixtures: no live configuration, upstream calls, or credentials.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const html = fs.readFileSync(path.join(__dirname,'../opendash.html'),'utf8');
// 黑夜版 fixture：在主题预初始化脚本之前写入 localStorage，
// 首屏即按深空极光渲染（新版读 <head> 内脚本，旧版在 boot() 里读，均兼容）。
const DARK_BOOT = '<script>try{localStorage.setItem("opendash-theme","dark")}catch(e){}</script>';
const themes = {
  light: html,
  dark: html.replace('<head>', '<head>' + DARK_BOOT),
};
const server = http.createServer((req,res)=>{
  const url = new URL(req.url,'http://127.0.0.1:10109');
  if (url.pathname.endsWith('.html')) {
    const mode=url.pathname.includes('offline')?'offline':'empty';
    const theme=url.pathname.includes('dark')?'dark':'light';
    res.setHeader('Content-Type','text/html; charset=utf-8');
    res.end(themes[theme].replaceAll('/api/',`/${mode}/api/`));return;
  }
  if (url.pathname==='/opencodex-session') {res.writeHead(200,{'Content-Type':'text/html'});res.end(`<meta name="opencodex-session-token" content="ocx_session_fixture"><meta name="opencodex-session-csrf" content="fixture"><meta name="opencodex-session-origin" content="http://127.0.0.1:10109">`);return;}
  if (url.pathname.startsWith('/offline/')) {res.writeHead(503,{'Content-Type':'application/json'});res.end('{"error":"fixture offline"}');return;}
  const data=url.pathname.includes('/api/usage') ? {summary:{requests:0,totalTokens:0,estimatedCostUsd:0},models:[],providers:[],days:[]} : url.pathname.includes('/api/logs') ? {logs:[],total:0} : url.pathname.includes('/api/models') ? [] : {providers:{}};
  res.setHeader('Content-Type','application/json');res.end(JSON.stringify(data));
});
server.listen(10109,'127.0.0.1',()=>console.log('Fixture server: http://127.0.0.1:10109/empty.html /empty-dark.html /offline.html /offline-dark.html'));
