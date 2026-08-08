const hud=document.getElementById('hud');
const money=new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0});
const setText=(id,value)=>{const el=document.getElementById(id);if(el)el.textContent=value;};
window.addEventListener('message',(event)=>{
  const data=event.data||{};
  if(data.action==='visible'){
    hud.classList.toggle('hidden',!data.visible);
    return;
  }
  if(data.action!=='update')return;
  hud.classList.toggle('hidden',data.visible===false);
  setText('name',data.name||'Citizen');
  setText('job',data.job||'Civilian');
  setText('district',String(data.district||'county').replaceAll('_',' '));
  setText('cash',money.format(Number(data.cash)||0));
  setText('bank',money.format(Number(data.bank)||0));
  document.getElementById('health').style.width=`${Math.max(0,Math.min(100,Number(data.health)||0))}%`;
  document.getElementById('armor').style.width=`${Math.max(0,Math.min(100,Number(data.armor)||0))}%`;
  document.getElementById('voice').classList.toggle('talking',Boolean(data.talking));
});
