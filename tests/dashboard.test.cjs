const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function loadSource(file) {
  return fs.readFileSync(path.join(__dirname, '..', file), 'utf8').match(/<script>([\s\S]*?)<\/script>/)[1].replace(/\nboot\(\);\s*$/, '');
}
const source = loadSource('opendash-light.html');
const sourceDark = loadSource('opendash-dark.html');
function env(src = source) {
  const els = new Map();
  const el = id => {if (!els.has(id)) els.set(id,{textContent:'—',innerHTML:'',title:'',classList:{add(){},contains(){return false},toggle(){}},setAttribute(){},querySelectorAll(){return []}});return els.get(id)};
  const c = vm.createContext({console:{warn(){}},Date,Map,Set,JSON,Number,Math,Array,String,performance:{now:()=>1},AbortController, setTimeout,clearTimeout,requestAnimationFrame:()=>1,cancelAnimationFrame(){},window:{setTimeout,clearTimeout},document:{hidden:false,getElementById:el,body:{classList:{toggle(){}}},querySelectorAll:()=>[]},location:{origin:'http://localhost:10100'}});
  vm.runInContext(source,c);
  const run = code => vm.runInContext(code,c);
  return {c,run,el};
}
test('首批历史不会被下一批120条覆盖；重复请求更新状态，过期日志被移除',()=>{
  const {run}=env();
  const value=run(`(()=>{const now=Date.now();const first=Array.from({length:200},(_,i)=>({requestId:String(i),timestamp:now-200000+i*100,status:200}));const second=first.slice(-120).map(l=>({...l,status:429}));return [mergeLogs(first,second,now).length,mergeLogs(first,second,now).at(-1).status,mergeLogs(first,[],now+HISTORY_MS+1).length]})()`);
  assert.deepEqual(Array.from(value),[200,429,0]);
});
test('401、400和500归为失败；仅429为限流',()=>{
  const {run,el}=env();
  run(`drawFlowChart=()=>{}; state.initialLogsLoaded=true; state.liveWindowLogs=[200,400,401,429,500].map(status=>({status}));renderFlowCard()`);
  assert.equal(el('flowOk').textContent,'1'); assert.equal(el('flowThr').textContent,'1'); assert.equal(el('flowFail').textContent,'3');
});
test('零累计也渲染0；无延迟上报显示破折号',()=>{
  const {run,el}=env();run(`animateKpi('requests',0,fmtFull); drawFlowChart=()=>{}; state.liveWindowLogs=[{timestamp:Date.now(),status:200}];renderLiveKpis()`);
  assert.equal(el('k-requests').textContent,'0');assert.equal(el('k-latency').textContent,'—');
});
test('全部历史不因模型禁用而消失；启用模式按供应商区分同名模型',()=>{
  const {run}=env();
  run(`state.catalog={ready:true,providersReady:true,modelsReady:true,activeProviders:new Set(['a','b']),disabledKeys:new Set(['a/m']),disabledPlain:new Set(['m']),enabledPlain:new Set()}`);
  assert.equal(run(`visibleModel('a','m')`),true);
  run(`state.scope='active'`);
  assert.equal(run(`visibleModel('a','m')`),false);assert.equal(run(`visibleModel('b','m')`),true);
  run(`state.catalog.modelsReady=false`);assert.equal(run(`visibleModel('a','m')`),true);
});
test('不把requestedModel别名再次叠加到用量累计',()=>{
  const {run}=env();assert.equal(run(`modelHeatData({models:[{provider:'a',model:'m',requests:5}]},[{provider:'a',model:'m',requestedModel:'combo'}]).length`),1);
});
test('趋势全部模式使用账本总数；启用模式筛选模型',()=>{
  const {run}=env();assert.equal(run(`filteredUsageDays({days:[{date:'2026-09-05',requests:10,models:[{provider:'a',model:'m',requests:3}]}]})[0].requests`),10);
});
test('只成功读取配置不能标记为已连接；接口失败保留旧数据提示',()=>{
  const {run,el}=env();run(`state.pollSlots.catalog.lastSuccess=Date.now();updateConnectionStatus()`);assert.equal(el('statusText').textContent,'正在连接');
  run(`state.pollSlots.usage.lastSuccess=Date.now();state.pollSlots.logs.lastSuccess=Date.now();updateConnectionStatus()`);assert.equal(el('statusText').textContent,'实时同步');
  run(`state.pollSlots.logs.consec=1;updateConnectionStatus()`);assert.match(el('statusText').textContent,/重试中/);
});
test('空模型数据结束加载，显示明确空态',()=>{
  const {run}=env();run(`let empty='';showEmpty=(el,text)=>empty=text;renderModelBars([])`);assert.equal(run('empty'),'当前范围暂无模型用量');
});
test('授权过期时只重取一次会话并重试读取',async()=>{
  const {run,c}=env();let calls=0;c.fetch=async()=>({status:++calls===1?401:200,ok:calls>1,json:async()=>({ok:true})});
  run(`let renewed=0;renewSession=async()=>{renewed++}`);const result=await run(`fetchJsonTimeout('/api/logs',1000)`);assert.equal(result.ok,true);assert.equal(run('renewed'),1);assert.equal(calls,2);
});
test('数据接口故障不会自动生成演示业务数据',()=>{assert.doesNotMatch(source,/seedDemo|demoLogs|Math\.random/)});
test('黑夜版（深空极光）核心数据逻辑与白天版一致',()=>{
  const {run,el}=env(sourceDark);
  const value=run(`(()=>{const now=Date.now();const first=Array.from({length:200},(_,i)=>({requestId:String(i),timestamp:now-200000+i*100,status:200}));const second=first.slice(-120).map(l=>({...l,status:429}));return [mergeLogs(first,second,now).length,mergeLogs(first,second,now).at(-1).status,mergeLogs(first,[],now+HISTORY_MS+1).length]})()`);
  assert.deepEqual(Array.from(value),[200,429,0]);
  run(`drawFlowChart=()=>{}; state.initialLogsLoaded=true; state.liveWindowLogs=[200,400,429].map(status=>({status}));renderFlowCard()`);
  assert.equal(el('flowOk').textContent,'1'); assert.equal(el('flowThr').textContent,'1'); assert.equal(el('flowFail').textContent,'1');
  assert.doesNotMatch(sourceDark,/seedDemo|demoLogs|Math\.random/);
});
test('动画首帧早于起点时数字不出现负值',()=>{
  const {run,c,el}=env();const frames=[];c.requestAnimationFrame=fn=>{frames.push(fn);return frames.length};
  run(`animateKpi('requests',100,fmtFull)`);frames[0](0);
  assert.equal(el('k-requests').textContent,'0');frames[1](1000);assert.equal(el('k-requests').textContent,'100');
});
