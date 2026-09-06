// Local UI fixtures: no live configuration, upstream calls, or credentials.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const html = fs.readFileSync(path.join(__dirname,'../opendash.html'),'utf8');
const server = http.createServer((req,res)=>{
  const url = new URL(req.url,'http://127.0.0.1:10109');
  if (url.pathname.endsWith('.html')) {
    const mode=url.pathname.includes('offline')?'offline':'empty';
    res.setHeader('Content-Type','text/html; charset=utf-8');
    res.end(html.replaceAll('/api/',`/${mode}/api/`));return;
  }
  if (url.pathname==='/opencodex-session') {res.writeHead(200,{'Content-Type':'text/html'});res.end(`<meta name="opencodex-session-token" content="ocx_session_fixture"><meta name="opencodex-session-csrf" content="fixture"><meta name="opencodex-session-origin" content="http://127.0.0.1:10109">`);return;}
  if (url.pathname.startsWith('/offline/')) {res.writeHead(503,{'Content-Type':'application/json'});res.end('{"error":"fixture offline"}');return;}
  const data=url.pathname.includes('/api/usage') ? {summary:{requests:0,totalTokens:0,estimatedCostUsd:0},models:[],providers:[],days:[]} : url.pathname.includes('/api/logs') ? {logs:[],total:0} : url.pathname.includes('/api/models') ? [] : {providers:{}};
  res.setHeader('Content-Type','application/json');res.end(JSON.stringify(data));
});
server.listen(10109,'127.0.0.1',()=>console.log('Fixture server: http://127.0.0.1:10109/empty.html and /offline.html'));
