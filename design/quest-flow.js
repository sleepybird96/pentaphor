(() => {
  'use strict';
  const root = document.getElementById('pentaphor');
  const q = selector => root.querySelector(selector);
  const qa = selector => [...root.querySelectorAll(selector)];
  const names = ['체력', '지식', '끈기', '매력', '용기'];
  const assets = window.PENTAPHOR_ART;
  const artById = Object.fromEntries(assets.map(art => [art.id, art]));
  const assetPath = id => '../assets/quest-art/' + artById[id].file;
  const escape = value => String(value).replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  let selectedArt = 'climbing', period = 'week', allocation = [1, 0, 0, 0, 1];
  let category = '전체', search = '', visibleCount = 12, filter = 'week';
  let stats = [42, 36, 28, 24, 18], lastAction = null, mode = 'preview';
  let growthFrame = 0, growthRun = 0, growth = null, syncTimer = 0;
  const design = {motion:true, bounce:20};
  const quests = [
    {id:1, name:'달리기', art:'running', period:'week', target:3, count:2, reward:[1,0,0,1,0], prior:1, bonus:false},
    {id:2, name:'책 읽기', art:'reading', period:'week', target:2, count:0, reward:[0,2,0,0,0], prior:0, bonus:false},
    {id:3, name:'화장실 청소', art:'bathroom-cleaning', period:'month', target:1, count:0, reward:[0,0,1,0,1], prior:1, bonus:false}
  ];
  const rewardText = values => values.map((value, i) => value ? names[i] + ' +' + value : '').filter(Boolean).join(' · ');
  const announce = text => { q('[data-live]').textContent = text; };
  function draft() {
    return {name:q('#quest-name').value.trim() || '나의 퀘스트', art:selectedArt, period, target:Math.max(1, Math.min(99, Math.floor(Number(q('#quest-target').value)) || 1)), reward:[...allocation], count:1, prior:0};
  }
  function showLeft(view) {
    qa('[data-left]').forEach(section => { section.hidden = section.dataset.left !== view; });
    if (view === 'library') { drawLibrary(); q('#art-search').focus({preventScroll:true}); }
    if (view === 'list') drawQuests();
    if (view === 'create') { syncPreview(); q('#quest-name').focus({preventScroll:true}); }
  }
  function drawAllocation() {
    const total = allocation.reduce((sum, value) => sum + value, 0);
    q('[data-budget]').textContent = total + ' / 2 P';
    if (!q('[data-allocations]').children.length) {
      q('[data-allocations]').innerHTML = names.map((name, i) => `<div class="allocation" data-allocation="${i}"><span class="allocation-label"><i class="stat-dot" aria-hidden="true"></i>${name}</span><div class="stepper"><button type="button" data-step="-1" data-stat="${i}" aria-label="${name} 포인트 줄이기">−</button><output aria-label="${name} 배분">0</output><button type="button" data-step="1" data-stat="${i}" aria-label="${name} 포인트 늘리기">＋</button></div></div>`).join('');
    }
    names.forEach((_, i) => {
      const row = q(`[data-allocation="${i}"]`);
      row.classList.toggle('is-active', allocation[i] > 0);
      row.querySelector('output').textContent = allocation[i];
      row.querySelector('[data-step="-1"]').disabled = allocation[i] === 0;
      row.querySelector('[data-step="1"]').disabled = total >= 2;
    });
    qa('[data-period]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.period === period)));
    q('[data-period-note]').textContent = period === 'week' ? '한 주의 마무리는 월요일 오전 9시까지.' : '이번 달 안에서, 편한 날에 채워가면 돼.';
    q('.form-body .helper').innerHTML = `한 번 완료할 때마다 최대 2포인트.<br>2${period === 'week' ? '주' : '개월'} 연속부터는 끈기 +1이 따로 쌓여.`;
  }
  function selectArt(id) {
    const art = artById[id];
    selectedArt = id;
    q('[data-draft-art]').src = assetPath(id);
    q('[data-draft-art]').alt = art.label + ' 활동 아트';
    q('[data-art-category]').textContent = art.category;
    q('.art-card').setAttribute('aria-label', '퀘스트 아트 선택, 현재 ' + art.label);
    showLeft('create');
    q('.art-card').focus({preventScroll:true});
    announce(art.label + ' 아트 선택. 퀘스트 이름과 보상은 자유롭게 정해줘.');
  }
  function drawLibrary() {
    const categories = ['전체', '운동', '배움', '창작·취미', '나 돌보기', '집안일', '관계·돌봄', '여가·탐험'];
    if (!q('[data-categories]').children.length) q('[data-categories]').innerHTML = categories.map(name => `<button type="button" data-category="${name}" aria-pressed="false">${name}</button>`).join('');
    qa('[data-category]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.category === category)));
    const matched = assets.filter(art => (category === '전체' || art.category === category) && (art.label + ' ' + art.id + ' ' + art.keywords).toLowerCase().includes(search));
    q('[data-library-count]').textContent = `${matched.length}개의 장면 · ${Math.min(matched.length, visibleCount)}개 표시`;
    q('[data-art-grid]').innerHTML = matched.slice(0, visibleCount).map(art => `<button class="art-option" type="button" data-art="${art.id}" aria-label="${escape(art.label)} 아트 선택" aria-pressed="${art.id === selectedArt}"><img src="${assetPath(art.id)}" alt="" width="1254" height="1254" loading="lazy"></button>`).join('') || '<p class="empty">아직 없는 장면이네.<br>다른 이름으로 찾아봐.</p>';
    q('[data-action="more"]').hidden = visibleCount >= matched.length;
  }
  function syncPreview() {
    clearTimeout(syncTimer);
    mode = 'preview';
    lastAction = null;
    const quest = draft();
    growth = {before:[...stats], after:stats.map((v,i) => v + quest.reward[i]), gains:[...quest.reward]};
    renderResult(quest, false);
    q('[data-preview-note]').textContent = '선택한 아트와 성장 배분이 달성 화면에도 이어져.';
    q('[data-action="undo"]').hidden = true;
    replay();
  }
  function renderResult(quest, bonus) {
    q('[data-result-art]').src = assetPath(quest.art);
    q('[data-result-art]').alt = artById[quest.art].label + ' 활동 아트';
    q('[data-result-category]').textContent = artById[quest.art].category;
    q('[data-result-name]').textContent = quest.name;
    q('[data-result-note]').textContent = quest.reward[4] > 0 ? '한 번의 도전이, 네 안에 남았어.' : '네가 보낸 시간이, 성장으로 남았어.';
    q('[data-rewards]').innerHTML = quest.reward.map((value,i) => value ? `<div class="reward-chip"><span>${names[i]}</span><strong>+${value}</strong></div>` : '').join('') || '<div class="reward-chip"><span>나를 위한 활동</span><strong>✓</strong></div>';
    q('[data-stamp]').textContent = '1회 완료 ✓';
    q('.done').innerHTML = 'WELL<br><span>DONE!</span>';
    q('[data-goal-label]').textContent = quest.period === 'week' ? '이번 주의 발걸음' : '이번 달의 발걸음';
    q('[data-goal-count]').innerHTML = `${quest.count} <small>/ ${quest.target}회</small>`;
    q('[data-goal-fill]').style.width = Math.min(100, quest.count / quest.target * 100) + '%';
    q('.goal-track').setAttribute('aria-valuemax', quest.target);
    q('.goal-track').setAttribute('aria-valuenow', Math.min(quest.count, quest.target));
    q('.goal-track').setAttribute('aria-valuetext', quest.count + '회 완료, 목표 ' + quest.target + '회');
    q('[data-goal-note]').textContent = quest.count >= quest.target ? '이번 목표 달성. 충분히 잘했어.' : '네 페이스로 이어가면 돼.';
    q('[data-streak]').hidden = !bonus;
    q('[data-streak-title]').innerHTML = `${quest.prior + 1}${quest.period === 'week' ? '주' : '개월'} 연속 달성 <b>끈기 +1</b>`;
    q('[data-action="continue"] span').textContent = '좋아, 이만큼 자랐어';
  }
  function replay() {
    const phone = q('#reward-phone');
    phone.classList.remove('celebrate');
    void phone.offsetWidth;
    phone.classList.add('celebrate');
    drawGrowth();
  }
  function drawQuests() {
    qa('[data-filter]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.filter === filter)));
    q('[data-quest-list]').innerHTML = quests.filter(quest => quest.period === filter).map(quest => `<article class="quest-row"><img src="${assetPath(quest.art)}" alt="" width="60" height="60"><div><h3>${escape(quest.name)}</h3><p>${rewardText(quest.reward) || '나를 위한 활동 기록'}</p><strong>${quest.count} / ${quest.target}회</strong></div><button class="complete-button" data-complete="${quest.id}" aria-label="${escape(quest.name)} 1회 완료">${quest.count >= quest.target ? '＋' : '✓'}</button></article>`).join('');
  }
  function complete(id) {
    const quest = quests.find(quest => quest.id === id);
    if (!quest) return;
    clearTimeout(syncTimer);
    lastAction = {id, count:quest.count, bonus:quest.bonus, stats:[...stats]};
    const bonus = quest.count < quest.target && quest.count + 1 >= quest.target && quest.prior >= 1 && !quest.bonus;
    quest.count += 1;
    if (bonus) quest.bonus = true;
    const gains = quest.reward.map((value,i) => value + (i === 2 && bonus ? 1 : 0));
    stats = stats.map((value,i) => value + gains[i]);
    growth = {before:lastAction.stats, after:[...stats], gains};
    mode = 'recorded';
    renderResult(quest, bonus);
    q('[data-action="undo"]').hidden = false;
    q('[data-preview-note]').textContent = '방금 기록한 퀘스트의 달성 화면이야.';
    drawQuests();
    replay();
    announce(quest.name + ' 완료. ' + rewardText(gains));
    if (window.matchMedia('(max-width:720px)').matches) q('#reward-phone').scrollIntoView({behavior:'instant', block:'start'});
  }
  function undo() {
    if (!lastAction) return;
    const quest = quests.find(quest => quest.id === lastAction.id);
    quest.count = lastAction.count;
    quest.bonus = lastAction.bonus;
    stats = [...lastAction.stats];
    growth = {before:[...stats], after:[...stats], gains:[0,0,0,0,0]};
    lastAction = null;
    mode = 'undone';
    renderResult(quest, false);
    q('#reward-phone').classList.remove('celebrate');
    q('.done').innerHTML = 'ALL<br><span>GOOD.</span>';
    q('[data-stamp]').textContent = '되돌리기 완료';
    q('[data-result-note]').textContent = '괜찮아. 횟수와 포인트를 되돌렸어.';
    q('[data-rewards]').innerHTML = '';
    q('[data-action="undo"]').hidden = true;
    q('[data-action="continue"] span').textContent = '내 퀘스트로 돌아가기';
    q('[data-preview-note]').textContent = '활동 횟수와 연속 달성 보너스까지 함께 되돌렸어.';
    drawGrowth();
    drawQuests();
    announce('기록과 포인트를 되돌렸어.');
  }
  root.addEventListener('click', event => {
    const button = event.target.closest('button');
    if (!button || button.disabled) return;
    if (button.dataset.art) { selectArt(button.dataset.art); return; }
    if (button.dataset.category) { category = button.dataset.category; visibleCount = 12; drawLibrary(); return; }
    if (button.dataset.period) { period = button.dataset.period; drawAllocation(); syncPreview(); return; }
    if (button.dataset.step) {
      const i = Number(button.dataset.stat), amount = Number(button.dataset.step);
      if ((amount < 0 && allocation[i] > 0) || (amount > 0 && allocation.reduce((a,b) => a+b,0) < 2)) allocation[i] += amount;
      drawAllocation(); syncPreview(); announce(rewardText(allocation) || '배분한 포인트 없음'); return;
    }
    if (button.dataset.filter) { filter = button.dataset.filter; drawQuests(); return; }
    if (button.dataset.complete) { complete(Number(button.dataset.complete)); return; }
    switch (button.dataset.action) {
      case 'library': showLeft('library'); break;
      case 'create': showLeft('create'); break;
      case 'list': showLeft('list'); break;
      case 'more': visibleCount += 12; drawLibrary(); break;
      case 'replay': replay(); break;
      case 'undo': undo(); break;
      case 'continue':
        showLeft('list');
        q('[data-list-toast]').textContent = mode === 'preview' ? '네가 고른 일들을, 편한 때에 이어가봐.' : '오늘의 기록은 여기까지. 다음에도 네 페이스로.';
        q('#creation-phone').scrollIntoView({behavior:'instant', block:'start'});
        break;
    }
  });
  q('#art-search').addEventListener('input', event => { search = event.target.value.trim().toLowerCase(); visibleCount = 12; drawLibrary(); });
  ['#quest-name', '#quest-target'].forEach(selector => q(selector).addEventListener('input', () => { clearTimeout(syncTimer); syncTimer = setTimeout(syncPreview, 180); }));
  q('#quest-form').addEventListener('submit', event => {
    event.preventDefault();
    clearTimeout(syncTimer);
    const name = q('#quest-name').value.trim(), target = Number(q('#quest-target').value);
    if (!name || !Number.isInteger(target) || target < 1 || target > 99) { q('#form-error').textContent = '이름과 1~99회 사이의 목표를 입력해줘.'; return; }
    quests.push({id:Math.max(...quests.map(quest => quest.id)) + 1, name, art:selectedArt, period, target, count:0, reward:[...allocation], prior:0, bonus:false});
    filter = period;
    q('#form-error').textContent = '';
    showLeft('list');
    q('[data-list-toast]').textContent = name + ', 네 퀘스트에 추가했어.';
    announce(name + ' 퀘스트 등록 완료.');
  });
  // The same vertex spring used in the earlier approved achievement prototype.
  function stopGrowth(){growthRun++;cancelAnimationFrame(growthFrame);}
  function drawGrowth(){
    stopGrowth();
    const cx=180,cy=132,r=91,max=Math.max(50,Math.ceil(Math.max(...growth.after)/10)*10);
    const active=growth.gains.map((v,i)=>v>0?i:-1).filter(i=>i>=0);
    const coord=(value,i,extra=0)=>{const angle=(-90+i*72)*Math.PI/180,rad=r*value/max+extra;return [cx+Math.cos(angle)*rad,cy+Math.sin(angle)*rad];};
    const points=values=>values.map((v,i)=>coord(v,i).map(n=>n.toFixed(2)).join(',')).join(' ');
    const positions=[[180,21,'middle'],[309,113,'middle'],[260,252,'middle'],[100,252,'middle'],[51,113,'middle']];
    const chartLabel=names.map((n,i)=>`${n} ${growth.before[i]}에서 ${growth.after[i]}`).join(', ');
    const grids=[.25,.5,.75,1].map(f=>`<polygon class="pa-growth-grid" points="${points(Array(5).fill(max*f))}"/>`).join('');
    const axes=Array.from({length:5},(_,i)=>{const p=coord(max,i);return `<line class="pa-growth-grid" x1="${cx}" y1="${cy}" x2="${p[0]}" y2="${p[1]}"/>`;}).join('');
    const labels=positions.map(([x,y,a],i)=>`<text class="pa-growth-label ${growth.gains[i]?'changed':''}" x="${x}" y="${y}" text-anchor="${a}">${names[i]}<tspan x="${x}" dy="18" data-growth-number="${i}">${growth.after[i]}</tspan></text>`).join('');
    const nodes=growth.after.map((v,i)=>{const p=coord(v,i);return `<circle class="pa-growth-point ${growth.gains[i]?'changed':''}" data-growth-point="${i}" cx="${p[0]}" cy="${p[1]}" r="${growth.gains[i]?4:2.6}"/>`;}).join('');
    const effects=active.map(i=>`<polyline class="pa-growth-edge" data-growth-edge="${i}"/><circle class="pa-growth-ring" data-growth-ring="${i}" r="0"/><text class="pa-growth-delta" data-growth-delta="${i}" text-anchor="middle">+${growth.gains[i]}</text>`).join('');
    q('[data-growth-radar]').innerHTML=`<svg class="pa-growth-radar" viewBox="0 0 360 282" role="img" aria-label="${chartLabel}">${grids}${axes}<polygon class="pa-growth-old" points="${points(growth.before)}"/><polygon class="pa-growth-shape" data-growth-shape points="${points(growth.after)}"/>${effects}${nodes}${labels}</svg>`;
    q('[data-growth-caption]').textContent=active.map(i=>`${names[i]} +${growth.gains[i]}`).join(' · ')||'또 하나의 활동 기록';
    const shape=q('[data-growth-shape]');
    const dots=names.map((_,i)=>q(`[data-growth-point="${i}"]`));
    const numbers=names.map((_,i)=>q(`[data-growth-number="${i}"]`));
    const effectsByAxis=active.map(i=>({i,edge:q(`[data-growth-edge="${i}"]`),ring:q(`[data-growth-ring="${i}"]`),delta:q(`[data-growth-delta="${i}"]`)}));
    const render=(elapsed,still)=>{
      const stage=names.map((_,i)=>{const order=active.indexOf(i);return order<0||still?1:Math.max(0,Math.min(1,(elapsed-650-order*190)/1150));});
      const coords=growth.after.map((v,i)=>{
        const p=stage[i],ease=1-Math.pow(1-p,3),value=growth.before[i]+(v-growth.before[i])*ease;
        const bump=still||!growth.gains[i]?0:design.bounce*Math.sin(p*Math.PI*4)*Math.pow(1-p,1.7);
        return coord(value,i,bump);
      });
      const joined=coords.map(p=>p.map(n=>n.toFixed(2)).join(',')).join(' ');
      shape.setAttribute('points',joined);
      dots.forEach((dot,i)=>{dot.setAttribute('cx',coords[i][0]);dot.setAttribute('cy',coords[i][1]);dot.setAttribute('r',growth.gains[i]?4+Math.max(0,Math.sin(stage[i]*Math.PI*4))*2*(1-stage[i]):2.6);numbers[i].textContent=stage[i]>.08?growth.after[i]:growth.before[i];});
      effectsByAxis.forEach(({i,edge,ring,delta})=>{
        const p=stage[i],pulse=Math.max(0,Math.sin(p*Math.PI*4));
        edge.setAttribute('points',[coords[(i+4)%5],coords[i],coords[(i+1)%5]].map(p=>p.join(',')).join(' '));
        edge.style.opacity=still?'.45':String(p===0?0:.35+pulse*.65);
        ring.setAttribute('cx',coords[i][0]);ring.setAttribute('cy',coords[i][1]);ring.setAttribute('r',5+(p*2%1)*22);ring.style.opacity=still?'0':String(p>0&&p<.93?(1-(p*2%1))*.7:0);
        const angle=(-90+i*72)*Math.PI/180;
        delta.setAttribute('x',coords[i][0]+(i===0?32:Math.cos(angle)*25));
        delta.setAttribute('y',coords[i][1]+(i===0?7:Math.sin(angle)*25+7));
        delta.style.opacity=p===0?'0':'1';
      });
    };
    const reduced=globalThis.matchMedia&&globalThis.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if(!design.motion||reduced){render(9999,true);return;}
    const run=growthRun;let started=null;
    const tick=time=>{if(run!==growthRun)return;if(started===null)started=time;const elapsed=time-started;render(elapsed,false);if(elapsed<1830+Math.max(0,active.length-1)*190)growthFrame=requestAnimationFrame(tick);else render(9999,true);};
    render(0,false);growthFrame=requestAnimationFrame(tick);
  }

  drawAllocation();
  syncPreview();
})();
