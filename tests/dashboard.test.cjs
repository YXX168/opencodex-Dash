const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function loadSource(file) {
  const html = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
  // 取主逻辑脚本：以 "use strict" 开头的那块，而非 <head> 里的主题预初始化小脚本。
  // 不再依赖 <script> 在文档中的顺序，避免将来增删内联脚本时误伤。
  const blocks = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
  const src = blocks.find(b => b.includes('"use strict";')) || blocks.at(-1);
  assert(src, '未找到主脚本块');
  return src.replace(/\nboot\(\);\s*$/, '');
}
const source = loadSource('opendash.html');
function env(src = source) {
  const els = new Map();
  const el = id => {if (!els.has(id)) els.set(id,{textContent:'—',innerHTML:'',title:'',children:[],firstChild:null,dataset:{},classList:{add(){},contains(){return false},toggle(){},remove(){}},setAttribute(){},getAttribute(){return null},querySelector(){return null},querySelectorAll(){return []},appendChild(c){this.children.push(c);return c},removeChild(c){const i=this.children.indexOf(c);if(i>=0)this.children.splice(i,1);return c}});return els.get(id)};
  const bodyClasses = new Set();
  const c = vm.createContext({console:{warn(){}},Date,Map,Set,JSON,Number,Math,Array,String,performance:{now:()=>1},AbortController, setTimeout,clearTimeout,requestAnimationFrame:()=>1,cancelAnimationFrame(){},getComputedStyle:()=>({fontFamily:"sans-serif"}),window:{setTimeout,clearTimeout,getComputedStyle:()=>({fontFamily:"sans-serif"})},requestAnimationFrame:fn=>setTimeout(fn,0),document:{hidden:false,getElementById:el,addEventListener:()=>{},removeEventListener:()=>{},documentElement:{dataset:{}},body:{classList:{add(c){bodyClasses.add(c)},remove(...cs){cs.forEach(x=>bodyClasses.delete(x))},toggle(c,v){v?bodyClasses.add(c):bodyClasses.delete(c)},contains(c){return bodyClasses.has(c)}},_classes:bodyClasses},createElement:(tag)=>({tagName:String(tag).toUpperCase(),children:[],textContent:'',className:'',title:'',dataset:{},setAttribute(k,v){this[k]=v},appendChild(x){this.children.push(x);return x}}),querySelectorAll:()=>[]},location:{origin:'http://localhost:10100'}});
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
test('一体化面板（深空极光与白天版）核心数据逻辑一致且不产生假数据',()=>{
  const {run,el}=env(source);
  const value=run(`(()=>{const now=Date.now();const first=Array.from({length:200},(_,i)=>({requestId:String(i),timestamp:now-200000+i*100,status:200}));const second=first.slice(-120).map(l=>({...l,status:429}));return [mergeLogs(first,second,now).length,mergeLogs(first,second,now).at(-1).status,mergeLogs(first,[],now+HISTORY_MS+1).length]})()`);
  assert.deepEqual(Array.from(value),[200,429,0]);
  run(`drawFlowChart=()=>{}; state.initialLogsLoaded=true; state.liveWindowLogs=[200,400,429].map(status=>({status}));renderFlowCard()`);
  assert.equal(el('flowOk').textContent,'1'); assert.equal(el('flowThr').textContent,'1'); assert.equal(el('flowFail').textContent,'1');
  assert.doesNotMatch(source,/seedDemo|demoLogs|Math\.random/);
});
test('动画首帧早于起点时数字不出现负值',()=>{
  const {run,c,el}=env();const frames=[];c.requestAnimationFrame=fn=>{frames.push(fn);return frames.length};
  run(`animateKpi('requests',100,fmtFull)`);frames[0](0);
  assert.equal(el('k-requests').textContent,'0');frames[1](1000);assert.equal(el('k-requests').textContent,'100');
});
test('API.usage 支持动态时间范围传参，默认为 7d', () => {
  const {run} = env();
  assert.equal(run('API.usage()'), '/api/usage?range=7d');
  assert.equal(run('API.usage("all")'), '/api/usage?range=all');
  assert.equal(run('API.usage("30d")'), '/api/usage?range=30d');
  assert.equal(run('API.usage("today")'), '/api/usage?range=today');
  run('state.usageRange = "all"');
  assert.equal(run('API.usage()'), '/api/usage?range=all');
});

test('rangeLabel 和 scopeLabel 在各范围下文案准确', () => {
  const {run} = env();
  run('state.usageRange = "all"; state.scope = "all"');
  assert.equal(run('rangeLabel()'), '所有时间');
  assert.equal(run('scopeLabel()'), '全部模型');
  run('state.usageRange = "30d"');
  assert.equal(run('rangeLabel()'), '近 30 天');
  run('state.usageRange = "today"');
  assert.equal(run('rangeLabel()'), '今日');
});

test('模型热度表支持 TOP 20 与 全部 数量切换', () => {
  const {run} = env();
  const fakeModels = [];
  for (let i = 0; i < 35; i++) {
    fakeModels.push({provider: 'openai', model: 'm-' + i, requests: 100 - i, totalTokens: 1000});
  }
  run('state.heatLimit = "20"; state.usageRange = "all"');
  const res20 = run('modelHeatData({models: ' + JSON.stringify(fakeModels) + '}, []).slice(0, state.heatLimit === "all" ? 35 : 20)');
  assert.equal(res20.length, 20);
  run('state.heatLimit = "all"');
  const resAll = run('modelHeatData({models: ' + JSON.stringify(fakeModels) + '}, []).slice(0, state.heatLimit === "all" ? 35 : 20)');
  assert.equal(resAll.length, 35);
});
test('顶部控制抽屉支持展开与收起，且保留 controlsToggle 与 controlsDrawer 对应属性', () => {
  const {run, el} = env();
  const drawer = el('controlsDrawer');
  const toggle = el('controlsToggle');
  drawer.classList = { contains: c => !!drawer.classList[c], add: c => drawer.classList[c] = true, remove: c => drawer.classList[c] = false };
  drawer.querySelectorAll = () => [];
  toggle.classList = { contains: c => !!toggle.classList[c], add: c => toggle.classList[c] = true, remove: c => toggle.classList[c] = false, toggle: (c, v) => toggle.classList[c] = v };
  let clickHandler = null;
  toggle.addEventListener = (evt, fn) => { if (evt === 'click') clickHandler = fn; };
  const attrs = new Map();
  drawer.setAttribute = (k, v) => attrs.set('d:' + k, String(v));
  drawer.getAttribute = (k) => attrs.get('d:' + k);
  toggle.setAttribute = (k, v) => attrs.set('t:' + k, String(v));
  toggle.getAttribute = (k) => attrs.get('t:' + k);
  run('initControlsDrawer()');
  assert.equal(typeof clickHandler, 'function');
  // 模拟点击展开
  clickHandler();
  assert.equal(toggle.getAttribute('aria-expanded'), 'true');
  assert.equal(drawer.getAttribute('aria-hidden'), 'false');
  // 模拟再次点击收起
  clickHandler();
  assert.equal(toggle.getAttribute('aria-expanded'), 'false');
  assert.equal(drawer.getAttribute('aria-hidden'), 'true');
});

test('Token与用量数值格式化：单位上限为M，不使用B，且大数自动省略冗余.0', () => {
  const {run} = env();
  assert.equal(run('fmt(1e8, 1)'), '100M');
  assert.equal(run('fmt(1e9, 1)'), '1000M');
  assert.equal(run('fmt(2488000000, 1)'), '2488M');
  assert.equal(run('fmt(24500000, 1)'), '24.5M');
  assert.equal(run('fmt(1234567890, 1)'), '1234.6M');
  assert.equal(run('fmt(5e9)'), '5000M');
  assert.doesNotMatch(run('fmt(1e9, 1)'), /B$/);
  assert.doesNotMatch(run('fmt(50e9, 1)'), /B$/);
});

test('KPI单位与数字结构规范，由CSS提供4px精致间距', () => {
  const {run} = env();
  assert.match(run('formatKpiHtml("100.0%")'), /100\.0<span class="unit">%/);
  assert.match(run('formatKpiHtml("8.0s")'), /8\.0<span class="unit">s/);
  assert.match(run('formatKpiHtml("2496.8M")'), /2496\.8<span class="unit">M/);
  assert.match(run('formatKpiHtml("$1,274.87")'), /<span class="unit">\$<\/span>1,274\.87/);
});

test('全量趋势数据多于 50 天时，激活横向滚动容器并按最多 50 根柱子计算槽宽', () => {
  const {run, el} = env();
  const scrollEl = el("trendScroll");
  let hasScrollable = false;
  scrollEl.classList = {
    toggle: (c, v) => { if (c === "scrollable") hasScrollable = !!v; },
    contains: (c) => c === "scrollable" && hasScrollable
  };
  scrollEl.clientWidth = 500;
  const canvas = el("trendChart"); canvas.style = {};
  canvas.getContext = () => ({ setTransform(){}, clearRect(){}, fillText(){}, beginPath(){}, moveTo(){}, lineTo(){}, stroke(){}, fill(){}, roundRect(){}, createLinearGradient(){ return { addColorStop(){} }; } });
  const yCanvas = el("trendYAxis"); yCanvas.style = {};
  yCanvas.getContext = () => ({ setTransform(){}, clearRect(){}, fillText(){} });

  // 7 天数据：不激活横向滚动
  const days7 = Array.from({length: 7}, (_, i) => ({date: "2026-09-0" + (i+1), requests: 10}));
  run('renderTrend')(days7);
  assert.equal(hasScrollable, false);

  // 80 天全量数据：激活横向滚动，canvas 宽度展开为 80 根柱子
  const days80 = Array.from({length: 80}, (_, i) => ({date: "2026-08-01", requests: 15}));
  run('renderTrend')(days80);
  assert.equal(hasScrollable, true);
  // 500px 视口 / 50 根 = 10px 一根；80 根 = 800px
  assert.equal(canvas.style.width, "800px");
});

test('mergeLogs 用 changed 标记实质变化：新增/更新/过期为 true，重复为 false', () => {
  const {run} = env();
  const now = Date.now();
  const mk = (id, ts, status, extra = {}) => ({requestId: id, timestamp: ts, status, ...extra});
  const js = (v) => JSON.stringify(v);
  const first = [mk('a', now - 1000, 200)];
  // 同一批次重复到达（同一引用）不算变化
  assert.equal(run(`mergeLogs(${js(first)}, ${js(first)}, ${now}).changed`), false);
  // 字段完全相同的重复对象（不同引用）也不算变化
  assert.equal(run(`mergeLogs(${js(first)}, [${js(mk('a', now - 1000, 200))}], ${now}).changed`), false);
  // 新增请求算变化
  assert.equal(run(`mergeLogs(${js(first)}, [${js(mk('b', now - 500, 200))}], ${now}).changed`), true);
  // 状态更新算变化，且新状态生效
  const upd = run(`mergeLogs(${js(first)}, [${js(mk('a', now - 1000, 500))}], ${now})`);
  assert.equal(upd.changed, true);
  assert.equal(upd.at(-1).status, 500);
  // 用量字段更新也算变化
  const tok = run(`mergeLogs(${js([mk('a', now - 1000, 200, {totalTokens: 10})])}, [${js(mk('a', now - 1000, 200, {totalTokens: 42}))}], ${now})`);
  assert.equal(tok.changed, true);
  // 过期剔除算变化
  const histMs = run(`HISTORY_MS`);
  const old = [mk('o', now - histMs - 1000, 200)];
  const exp = run(`mergeLogs(${js(old)}, [], ${now})`);
  assert.equal(exp.changed, true);
  assert.equal(exp.length, 0);
  // 空对空不算变化
  assert.equal(run(`mergeLogs([], [], ${now}).changed`), false);
});

test('renderLogs 数据与筛选无变化时跳过 DOM 重建', () => {
  const {run, el} = env();
  run(`state.logsVersion = 3; state.filterVersion = 0; state.logFilter = 'all'; state.scope = 'all';
       state.initialLogsLoaded = true; state.logs = []; state.logListSig = '';`);
  run(`renderLogs([])`);
  assert.equal(el('logCount').textContent, '0 条');
  const sig = run(`state.logListSig`);
  assert.ok(sig);
  // 无变化再次调用：应直接返回，logCount 保持被篡改的值
  el('logCount').textContent = 'TAMPERED';
  run(`renderLogs([])`);
  assert.equal(el('logCount').textContent, 'TAMPERED');
  assert.equal(run(`state.logListSig`), sig);
  // 数据版本递增后应重新渲染
  run(`state.logsVersion = 4; renderLogs([])`);
  assert.equal(el('logCount').textContent, '0 条');
  // 筛选条件变化也应重新渲染
  el('logCount').textContent = 'TAMPERED';
  run(`state.logFilter = 'error'; renderLogs([])`);
  assert.equal(el('logCount').textContent, '0 条');
});

test('roundRectPath 无原生实现时用贝塞尔回退', () => {
  const {run, c} = env();
  const calls = [];
  c.fakeCtx = {
    moveTo: (...a) => calls.push(['moveTo', ...a]),
    lineTo: (...a) => calls.push(['lineTo', ...a]),
    quadraticCurveTo: (...a) => calls.push(['quadraticCurveTo', ...a]),
    closePath: () => calls.push(['closePath']),
  };
  run(`roundRectPath(fakeCtx, 10, 20, 100, 50, 3)`);
  assert.ok(calls.some(x => x[0] === 'quadraticCurveTo'), '应使用二次贝塞尔绘制圆角');
  assert.ok(calls.some(x => x[0] === 'closePath'), '应闭合路径');
  // 有原生实现时直接透传（跨 vm 上下文比较时用 JSON 序列化避免原型差异）
  calls.length = 0;
  c.fakeCtx.roundRect = (...a) => calls.push(['roundRect', ...a]);
  run(`roundRectPath(fakeCtx, 10, 20, 100, 50, 3)`);
  assert.equal(JSON.stringify(calls), '[["roundRect",10,20,100,50,[3,3,0,0]]]');
});

test('下拉菜单支持键盘：方向键移动、回车选中、Esc 关闭', () => {
  const {run, c} = env();
  const fired = [];
  const mkEl = () => ({
    classList: { _s: new Set(), add(x) { this._s.add(x); }, remove(x) { this._s.delete(x); },
      toggle(x, v) { v ? this._s.add(x) : this._s.delete(x); }, contains(x) { return this._s.has(x); } },
    attrs: {},
    setAttribute(k, v) { this.attrs[k] = v; },
    listeners: {},
    addEventListener(e, fn) { (this.listeners[e] ??= []).push(fn); },
    emit(e, ev) { (this.listeners[e] || []).forEach(fn => fn(ev)); },
    textContent: '',
  });
  const toggle = mkEl();
  toggle.focus = () => fired.push('focus:toggle');
  const opts = ['today', '7d', '30d'].map((v, i) => {
    const o = mkEl();
    o.dataset = { value: v }; o.textContent = v; o.tabIndex = -1;
    if (i === 1) o.classList.add('selected');
    o.focus = () => fired.push('focus:' + v);
    return o;
  });
  const root = mkEl();
  root.querySelector = (sel) => sel === '.dropdown-toggle' ? toggle : null;
  root.querySelectorAll = (sel) => sel === '.dropdown-option' ? opts : [];
  c.fakeRoot = root;
  run(`document.getElementById = (id) => id === 'testDrop' ? fakeRoot : null;
      document.querySelectorAll = (sel) => (sel === '.dropdown.open' && fakeRoot.classList.contains('open')) ? [fakeRoot] : [];
      initDropdown('testDrop', (v) => { fakeRoot.picked = v; });`);
  // 点击打开：当前选中项获得焦点
  toggle.emit('click', { stopPropagation() {} });
  assert.equal(toggle.attrs['aria-expanded'], 'true');
  assert.ok(root.classList.contains('open'));
  assert.deepEqual(Array.from(fired), ['focus:7d']);
  // 方向键下移到 30d
  opts[1].emit('keydown', { key: 'ArrowDown', preventDefault() {} });
  assert.deepEqual(Array.from(fired), ['focus:7d', 'focus:30d']);
  // 方向键上移回到 7d
  opts[2].emit('keydown', { key: 'ArrowUp', preventDefault() {} });
  assert.deepEqual(Array.from(fired), ['focus:7d', 'focus:30d', 'focus:7d']);
  // End 跳到末尾，回车选中
  opts[1].emit('keydown', { key: 'End', preventDefault() {} });
  assert.deepEqual(Array.from(fired), ['focus:7d', 'focus:30d', 'focus:7d', 'focus:30d']);
  opts[2].emit('keydown', { key: 'Enter', preventDefault() {} });
  assert.equal(root.picked, '30d');
  assert.equal(toggle.attrs['aria-expanded'], 'false');
  assert.ok(!root.classList.contains('open'));
  assert.equal(toggle.textContent, '30d');
  assert.ok(opts[2].classList.contains('selected'));
  assert.deepEqual(Array.from(fired).at(-1), 'focus:toggle');
  // 重新打开后 Esc 关闭并回到按钮
  fired.length = 0;
  toggle.emit('click', { stopPropagation() {} });
  assert.ok(root.classList.contains('open'));
  opts[2].emit('keydown', { key: 'Escape', preventDefault() {} });
  assert.ok(!root.classList.contains('open'));
  assert.deepEqual(Array.from(fired).at(-1), 'focus:toggle');
});

test('applyTheme 切换主题时保留 body 上其它类', () => {
  const {run, c} = env();
  // applyTheme 会触发图表重绘，测试环境用空函数代替（只验证主题类切换逻辑）
  run(`drawFlowChart = () => {}; updateRateTarget = () => {}; startRateAnimation = () => {}; renderFlowCard = () => {};`);
  run(`document.body.classList.add('backgrounded');
      applyTheme('dark');
      document.body.classList.add('backgrounded');
      applyTheme('light');`);
  const cls = c.document.body._classes;
  assert.ok(cls.has('theme-light'), '应有 theme-light');
  assert.ok(!cls.has('theme-dark'), '不应残留 theme-dark');
  assert.ok(cls.has('backgrounded'), 'backgrounded 不应被主题切换清除');
  assert.equal(run(`state.theme`), 'light');
  assert.equal(c.document.documentElement.dataset.theme, 'light');
});

test('双主题样式表的 @keyframes 不重名（避免 disabled 表污染全局解析）', () => {
  const fs = require('fs');
  const path = require('path');
  const html = fs.readFileSync(path.join(__dirname, '..', 'opendash.html'), 'utf8');
  const block = (id) => {
    const s = html.indexOf(`<style id="${id}">`);
    if (s === -1) throw new Error(`找不到 <style id="${id}">`);
    const e = html.indexOf('</style>', s);
    return html.slice(s, e);
  };
  const names = (css) => new Set([...css.matchAll(/@keyframes\s+([\w-]+)/g)].map(m => m[1]));
  const light = names(block('theme-light'));
  const dark = names(block('theme-dark'));
  const clash = [...light].filter(n => dark.has(n));
  assert.deepEqual(clash, [], `重名 keyframes: ${clash.join(', ')}`);
  // 每个 @keyframes 在所属表内至少有一处引用（防止改名改漏）
  for (const [css, set, label] of [[block('theme-light'), light, 'light'], [block('theme-dark'), dark, 'dark']]) {
    for (const n of set) {
      const uses = (css.match(new RegExp(`(?<![\\w-])${n}(?![\\w-])`, 'g')) || []).length;
      assert.ok(uses >= 2, `${label} 表 @keyframes ${n} 疑似无引用（${uses} 处）`);
    }
  }
});
