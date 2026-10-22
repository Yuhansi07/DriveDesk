/* DriveDesk Pro 2.1 — coordinated, server-validated rental workflow.
   Browser demo: no ML model is represented as trained unless explicitly configured. */
const workflowDraft = {
  step: 0, customer_id: null, vehicle_id: null, pickup_date: todayPlus(7),
  return_date: todayPlus(10), budget: 60000, seats: 5, category: '',
  suggestions: null, use_suggested_price: false, quote: null
};
let rentalSelected = null;
let latestPickupToken = '';
const statusNames = ['Pending', 'Confirmed', 'Active', 'Completed'];
const formatD = n => Number(n || 0).toLocaleString('en-LK');
const suggestionReasons = x => Array.isArray(x.reasons) ? x.reasons.join(' · ') : '';
const infoNotice = (text, warning=false) => `<div class="wf-notice ${warning?'warning':''}">${esc(text)}</div>`;
function progressBars(current, labels) {
  return `<div class="wf-progress">${labels.map((name,i)=>`<div class="wf-step ${i===current?'current':i<current?'done':''}">
   <span>${i<current?'✓':String(i+1).padStart(2,'0')}</span><div><strong>${esc(name)}</strong><small>${i<current?'Completed':i===current?'Current step':'Up next'}</small></div></div>`).join('')}</div>`;
}
function miniStat(label, val) {return `<div class="wf-mini"><span>${esc(label)}</span><strong>${esc(val)}</strong></div>`;}
function actionButton(label,id,primary=true) {return `<button class="${primary?'primary':'secondary'}" id="${id}">${label}</button>`;}
function selectOptions(list,selected,makeLabel) {return list.map(x=>`<option value="${Number(x.id)}" ${Number(selected)===Number(x.id)?'selected':''}>${esc(makeLabel(x))}</option>`).join('');}
function dateValid(a,b){return /^\d{4}-\d\d-\d\d$/.test(a)&&/^\d{4}-\d\d-\d\d$/.test(b)&&a>=todayPlus(0)&&b>a;}
function setRental(id){rentalSelected=Number(id);navigate('Rental desk');}
window.openRental = setRental;
async function renderNewRental(){
 const [customers,vehicles]=await Promise.all([get('/api/customers'),get('/api/vehicles')]);
 if(!workflowDraft.customer_id && customers.length)workflowDraft.customer_id=Number(customers[0].id);
 const availableVehicles=vehicles.filter(v=>v.status==='available');
 if(!workflowDraft.vehicle_id && availableVehicles.length)workflowDraft.vehicle_id=Number(availableVehicles[0].id);
 const w=workflowDraft, car=vehicles.find(v=>Number(v.id)===Number(w.vehicle_id));
 const customer=customers.find(c=>Number(c.id)===Number(w.customer_id));
 let body='';
 if(w.step===0){
  body=`<div class="wf-panel"><div class="wf-panel-heading"><div><div class="wf-eyebrow">CUSTOMER DETAILS</div><h2>Who is renting the vehicle?</h2><p>Choose an existing profile or register a new customer first.</p></div><div class="wf-symbol">♙</div></div>
   <label>Registered customer</label><select id="wizard-customer">${selectOptions(customers,w.customer_id,c=>`${c.name} · ${c.phone}`)}</select>
   ${customer?`<div class="wf-profile"><div class="wf-profile-icon">${esc(customer.name?.slice(0,1).toUpperCase())}</div><div><strong>${esc(customer.name)}</strong><p>${esc(customer.phone)} · License ${esc(customer.license_no)} · Expires ${esc(day(customer.license_expiry)||'not recorded')}</p></div><span class="wf-indicator">✓ Registered</span></div>`:''}
   ${!customers.length?infoNotice('No customers yet. Register one first.',true):''}
   <div class="wf-actions">${actionButton('Go to customers →','wizard-customers',false)}${actionButton('Continue to vehicle →','wizard-next')}</div></div>`;
 }else if(w.step===1){
  body=`<div class="wf-panel"><div class="wf-panel-heading"><div><div class="wf-eyebrow">AVAILABILITY & VEHICLE MATCHING</div><h2>Find the right vehicle</h2><p>Match preferences with the fleet, then verify exact booking dates.</p></div><div class="wf-symbol">▰</div></div>
   <div class="wf-grid two"><div><label>Pickup date</label><input id="wizard-start" type="date" min="${todayPlus(0)}" value="${esc(w.pickup_date)}"></div><div><label>Return date (exclusive)</label><input id="wizard-end" type="date" min="${todayPlus(1)}" value="${esc(w.return_date)}"></div>
   <div><label>Budget (LKR for full stay)</label><input id="wizard-budget" type="number" min="1" value="${Number(w.budget)}"></div><div><label>Minimum seats</label><input id="wizard-seats" type="number" min="1" max="60" value="${Number(w.seats)}"></div>
   <div><label>Preferred class</label><select id="wizard-category"><option value="">Any vehicle</option>${[...new Set(vehicles.map(x=>x.category))].map(c=>`<option ${w.category===c?'selected':''}>${esc(c)}</option>`).join('')}</select></div>
   <div class="wf-top-pad">${actionButton('✦ Find recommended vehicles','wizard-match',false)}</div></div>
   <div class="wf-options-header"><h3>${w.suggestions?'Recommended matches':'Choose a vehicle'}</h3><small>Ranking is advisory. Booking dates are checked before continuing.</small></div>
   <div class="wf-cars">${(w.suggestions&&w.suggestions.length?w.suggestions.map(r=>({...vehicles.find(v=>Number(v.id)===Number(r.vehicle_id)),_rank:r})):availableVehicles).map(v=>`
    <button type="button" class="wf-car ${Number(v.id)===Number(w.vehicle_id)?'chosen':''}" data-wizard-car="${Number(v.id)}"><span class="wf-car-icon">▰</span><span><strong>${esc(v.make)} ${esc(v.model)}</strong><small>${esc(v.plate)} · ${esc(v.category)} · ${esc(v.seats)} seats${v._rank?` · Score ${esc(v._rank.score)}`:''}</small>${v._rank?`<small>${esc(suggestionReasons(v._rank))}</small>`:''}</span><span class="wf-car-price">${fmt(v.daily_rate)}<small>per day</small></span><span class="wf-tick">✓</span></button>`).join('')||infoNotice('No available fleet vehicles.',true)}</div>
   <div class="wf-actions">${actionButton('← Customer','wizard-back',false)}${actionButton('Check availability →','wizard-next')}</div></div>`;
 }else if(w.step===2){
  body=`<div class="wf-panel"><div class="wf-panel-heading"><div><div class="wf-eyebrow">AI-ASSISTED PRICING</div><h2>Review the rental quote</h2><p>Human-reviewed pricing based on transparent rules or historical regression.</p></div><div class="wf-symbol">◈</div></div>
   ${car?`<div class="wf-quote"><div><small>${esc(car.plate)} · ${esc(car.make)} ${esc(car.model)}</small><h2>${fmt(w.use_suggested_price && w.quote?w.quote.estimated_total:Number(car.daily_rate)*(w.quote?.days||1))}</h2><p>Estimated rental total for ${Number(w.quote?.days||1)} day(s)</p></div><span class="wf-quote-icon">↗</span></div>`:''}
   <div class="wf-compare"><div><span>Standard daily rate</span><strong>${fmt(car?.daily_rate)}</strong></div><div><span>Recommended daily rate</span><strong>${fmt(w.quote?.recommended_daily_rate)}</strong></div><div><span>Pricing model</span><strong>${esc(w.quote?.method||'Loading')}</strong></div><div><span>Training observations</span><strong>${esc(w.quote?.training_samples??0)}</strong></div></div>
   <label class="wf-choice"><input type="checkbox" id="wizard-smart" ${w.use_suggested_price?'checked':''}><span><strong>Apply recommended rate to this booking</strong><small>Optional, explainable, and reviewed by staff.</small></span></label>
   ${infoNotice(w.quote?.note||'Smart recommendation is informational; staff approval is required.')}
   <div class="wf-actions">${actionButton('← Vehicle','wizard-back',false)}${actionButton('Continue to review →','wizard-next')}</div></div>`;
 }else{
  const amount = w.use_suggested_price && w.quote ? Number(w.quote.estimated_total) : Number(car?.daily_rate||0)*Number(w.quote?.days||1);
  body=`<div class="wf-panel"><div class="wf-panel-heading"><div><div class="wf-eyebrow">FINAL REVIEW</div><h2>Confirm reservation details</h2><p>Submitting creates a <strong>pending</strong> booking, ready for approval and pickup checks.</p></div><div class="wf-symbol">✓</div></div>
   <div class="wf-review">${miniStat('Customer',customer?.name||'—')}${miniStat('Vehicle',car?`${car.make} ${car.model} (${car.plate})`:'—')}${miniStat('Rental dates',`${w.pickup_date} → ${w.return_date}`)}${miniStat('Pricing',w.use_suggested_price?'Suggested daily rate':'Standard daily rate')}</div>
   <div class="wf-total"><span>Total to invoice</span><strong>${fmt(amount)}</strong></div>
   ${infoNotice('Booking saved only after backend availability and customer license validation. Payment and pickup happen later.')}
   <div class="wf-actions">${actionButton('← Review pricing','wizard-back',false)}${actionButton('Create reservation & open rental desk →','wizard-create')}</div></div>`;
 }
 return headline('New rental','A guided, validated reservation process from customer selection to confirmation.')+progressBars(w.step,['Customer','Vehicle & dates','Smart pricing','Review'])+
  `<div class="wf-layout"><div>${body}</div><aside class="wf-side"><div class="wf-side-inner"><div class="wf-eyebrow">LIVE RESERVATION</div><h3>Booking summary</h3>
     ${miniStat('Customer',customer?.name||'Select customer')}${miniStat('Vehicle',car?`${car.make} ${car.model}`:'Select vehicle')}${miniStat('Dates',`${w.pickup_date} → ${w.return_date}`)}
     <div class="wf-help"><strong>How the system works</strong><p>01 Select customer → 02 match & check dates → 03 review price → 04 create → 05 complete pickup and return in Rental Desk.</p></div></div></aside></div>`;
}

async function doWizardNext(){
 const w=workflowDraft;
 if(w.step===0){if(!w.customer_id)throw Error('Register and select a customer before continuing.');w.step=1;}
 else if(w.step===1){
  if(!w.vehicle_id)throw Error('Choose a vehicle.');
  if(!dateValid(w.pickup_date,w.return_date))throw Error('Choose valid future dates. Return date must be after pickup.');
  const a=await get(`/api/availability?vehicle_id=${w.vehicle_id}&pickup_date=${w.pickup_date}&return_date=${w.return_date}`);
  if(!a.available)throw Error('Vehicle unavailable: '+(a.reason||'date conflict'));
  w.quote=await get(`/api/smart/pricing?vehicle_id=${w.vehicle_id}&pickup_date=${w.pickup_date}&return_date=${w.return_date}`);w.step=2;
 }else if(w.step===2)w.step=3;
 await navigate('New rental');
}
async function createFromWizard(){const w=workflowDraft;
 const saved=await post('/api/bookings',{vehicle_id:w.vehicle_id,customer_id:w.customer_id,pickup_date:w.pickup_date,return_date:w.return_date,use_suggested_price:w.use_suggested_price});
 rentalSelected=Number(saved.id);workflowDraft.step=0;workflowDraft.quote=null;workflowDraft.suggestions=null;
 alertUi(`Booking #${saved.id} saved! Next: confirm it in Rental Desk.`);await navigate('Rental desk');
}
function workflowMilestones(w){
 const b=w.booking;
 const levels=['pending','confirmed','active','completed'];
 const i=levels.indexOf(b.status);
 return `<div class="wf-milestones">${levels.map((name,n)=>`<div class="wf-milestone ${i>=n?'reached':''} ${i===n?'now':''}"><span>${i>n?'✓':n+1}</span><strong>${name}</strong></div>`).join('')}</div>`;
}
function workflowHint(w){return ({confirm:'Confirm this pending reservation to schedule handover.',pickup_inspection:'Inspect the vehicle and record condition before QR handover.',qr_handover:'Generate a one-time pickup code, then verify it to activate the rental.',return_inspection:'Record vehicle return condition before final settlement.',settle_payment:'Record the outstanding balance to unlock completion.',complete:'The rental is ready to close.',completed:'This rental is complete.',cancelled:'This reservation has been cancelled.'})[w.next_action]||'Review the next step.';}
async function renderRentalDesk(){
 const list=await get('/api/bookings');if(!list.length)return headline('Rental desk','Manage pickup, payments and return.')+infoNotice('There are no bookings yet. Create one with New rental.',true)+actionButton('Create new rental','desk-create');
 if(!rentalSelected||!list.some(b=>Number(b.id)===rentalSelected))rentalSelected=Number((list.find(b=>!['completed','cancelled'].includes(b.status))||list[0]).id);
 const w=await get(`/api/bookings/${rentalSelected}/workflow`),b=w.booking;
 let actions='';
 if(b.status==='pending')actions=`<div class="wf-operation"><div><strong>01 · Approve the booking</strong><p>Verify customer information and rental dates.</p></div>${actionButton('Confirm booking','desk-confirm')}</div>`;
 if(b.status==='confirmed')actions=`<div class="wf-operation"><div><strong>02 · Pickup condition inspection</strong><p>Record visible vehicle condition. Photo optional; condition notes required.</p></div>${w.pickup_inspected?'<span class="wf-indicator">✓ Inspection recorded</span>':''}</div>
 <div class="wf-grid"><label>Pickup condition notes<textarea id="desk-inspection-note" rows="2" placeholder="Example: No visible scratches, fuel 3/4, odometer 42,000 km"></textarea></label>
 <label>Attach optional pickup photo (under 1 MB)<input type="file" id="desk-inspection-photo" accept="image/png,image/jpeg,image/webp"></label></div>
 ${actionButton('Save pickup inspection','desk-inspect-pickup',false)}
 <div class="wf-operation"><div><strong>03 · Secure QR handover</strong><p>Use a one-time code; the vehicle becomes Active only after verification.</p></div>${w.pickup_inspected?actionButton('Generate pickup code','desk-qr',false):'<button class="secondary" disabled title="Record pickup inspection first">Generate code (locked)</button>'}</div>
 <div class="wf-field-action"><input id="desk-code" placeholder="Paste pickup code / DRIVEDESK:PICKUP payload" value="${esc(latestPickupToken)}">${w.pickup_inspected?actionButton('Verify & start rental','desk-handover'):'<button class="primary" disabled>Verify (locked)</button>'}</div>`;
 if(b.status==='active')actions=`<div class="wf-operation"><div><strong>04 · Return condition inspection</strong><p>Record any new damage or return observations before closing the rental.</p></div>${w.return_inspected?'<span class="wf-indicator">✓ Return inspected</span>':''}</div>
 <div class="wf-grid"><label>Return condition notes<textarea id="desk-inspection-note" rows="2" placeholder="Example: Vehicle returned, fuel 3/4, no visible damage"></textarea></label>
 <label>Attach optional return photo (under 1 MB)<input type="file" id="desk-inspection-photo" accept="image/png,image/jpeg,image/webp"></label></div>
 ${actionButton('Save return inspection','desk-inspect-return',false)}
 <div class="wf-operation"><div><strong>05 · Collect balance & settle</strong><p>Payments are linked to this reservation. Total outstanding updates automatically.</p></div><span class="wf-amount">${fmt(w.balance)}</span></div>
 ${w.balance>0.009?`<div class="wf-grid two"><div><label>Amount to collect (LKR)</label><input id="desk-pay-amount" type="number" min="0.01" step="0.01" value="${w.balance}"></div><div><label>Payment method</label><select id="desk-pay-method"><option value="cash">Cash</option><option value="card">Card</option><option value="transfer">Bank transfer</option><option value="other">Other</option></select></div></div>${actionButton('Record payment','desk-pay',false)}`:infoNotice('Payment settled. Balance is zero.')}
 <div class="wf-operation"><div><strong>06 · Complete rental</strong><p>Return inspection + fully paid balance are both required.</p></div>${actionButton('Complete rental','desk-finish')}</div>`;
 if(b.status==='completed'||b.status==='cancelled')actions=`<div class="wf-done">${b.status==='completed'?'✓ Rental complete. Payments and inspections remain available in history.':'Reservation cancelled.'}</div>`;
 return headline('Rental desk','One workspace for approval, inspection, secure pickup, payment and closing.')+
 `<div class="wf-deskbar"><div><label>Open reservation</label><select id="desk-booking">${selectOptions(list,rentalSelected,x=>`#${x.id} · ${x.plate} · ${x.customer_name} · ${x.status}`)}</select></div>${actionButton('+ New rental','desk-create',false)}</div>`+
 workflowMilestones(w)+`<div class="wf-layout"><div><div class="wf-panel"><div class="wf-panel-heading"><div><div class="wf-eyebrow">BOOKING #${Number(b.id)} · ${esc(String(b.status).toUpperCase())}</div><h2>${esc(b.make)} ${esc(b.model)} <span class="wf-plate">${esc(b.plate)}</span></h2><p>${esc(b.customer_name)} · ${day(b.pickup_date)} to ${day(b.return_date)}</p></div>${pill(b.status)}</div>
 <div class="wf-task-hint">➜ <strong>Next:</strong> ${esc(workflowHint(w))}</div>${actions}
 </div><div class="wf-panel"><div class="wf-panel-heading"><div><div class="wf-eyebrow">DOCUMENTATION</div><h2>Inspection & payment history</h2></div></div>
 <div class="wf-history">${w.inspections.map(i=>`<div class="wf-history-row"><span class="wf-history-icon">⌕</span><div><strong>${esc(i.phase)} inspection</strong><p>${esc(i.reviewer_note||'Photo recorded')}${i.image_ref?' · Photo attached':''} · ${day(i.created_at)}</p></div></div>`).join('')||'<p class="muted">No inspections yet</p>'}</div>
 <div class="wf-history">${w.payments.map(p=>`<div class="wf-history-row"><span class="wf-history-icon">◈</span><div><strong>${fmt(p.amount)}</strong><p>${esc(p.method)} · ${day(p.created_at)}</p></div></div>`).join('')||'<p class="muted">No payments yet</p>'}</div></div></div>
 <aside class="wf-side"><div class="wf-side-inner"><div class="wf-eyebrow">FINANCIAL SUMMARY</div><h3>Booking #${Number(b.id)}</h3>${miniStat('Contract total',fmt(b.total_amount))}${miniStat('Collected',fmt(w.paid))}${miniStat('Outstanding',fmt(w.balance))}
 <div class="wf-help"><strong>Completion checklist</strong><p>${w.pickup_inspected?'✓':'○'} Pickup inspection<br>${b.status==='active'||b.status==='completed'?'✓':'○'} QR pickup verified<br>${w.return_inspected?'✓':'○'} Return inspection<br>${w.balance<=.009?'✓':'○'} Payment settled</p></div>
 <button class="secondary full-link" id="desk-reminders">See business alerts →</button></div></aside></div>`;
}
async function uploadInspection(phase){
 const note=document.getElementById('desk-inspection-note')?.value.trim()||'';
 const file=document.getElementById('desk-inspection-photo')?.files[0];
 if(!note&&!file)throw Error('Write a condition note or choose an image first.');
 if(file&&file.size>950000)throw Error('Image is too large. Choose a photo under 950 KB.');
 let image_base64=null;
 if(file){image_base64=await new Promise((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(String(reader.result).split(',')[1]);reader.onerror=()=>reject(Error('Could not read image.'));reader.readAsDataURL(file);});}
 await post('/api/inspections',{booking_id:rentalSelected,phase,reviewer_note:note,findings:note?[note]:[],image_base64});
 alertUi(phase+' inspection saved');await navigate('Rental desk');
}
function wfHandle(fn){return async()=>{try{await fn();}catch(e){alertUi(e.message);}};}
function wireWorkflow(page){
 if(page==='Overview')document.querySelectorAll('[data-new-rental]').forEach(x=>x.onclick=()=>navigate('New rental'));
 if(page==='Bookings'){
  const newBtn=document.getElementById('new-booking');if(newBtn)newBtn.onclick=()=>navigate('New rental');
  document.querySelectorAll('[data-open-rental]').forEach(b=>b.onclick=()=>setRental(b.dataset.openRental));
 }
 if(page==='More tools'){const btn=document.getElementById('smart-rental-link');if(btn)btn.onclick=()=>navigate('New rental');}
 if(page==='New rental'){
  const w=workflowDraft;
  const c=document.getElementById('wizard-customer');if(c)c.onchange=()=>w.customer_id=Number(c.value);
  for(const [id,key,change] of [['wizard-start','pickup_date','change'],['wizard-end','return_date','change'],['wizard-budget','budget','input'],['wizard-seats','seats','input'],['wizard-category','category','change']]){
   const el=document.getElementById(id);if(el)el.addEventListener(change,()=>{w[key]=['budget','seats'].includes(key)?Number(el.value):el.value;w.quote=null;w.suggestions=null;});
  }
  document.querySelectorAll('[data-wizard-car]').forEach(b=>b.onclick=()=>{w.vehicle_id=Number(b.dataset.wizardCar);w.quote=null;document.querySelectorAll('[data-wizard-car]').forEach(e=>e.classList.toggle('chosen',e===b));});
  const smart=document.getElementById('wizard-smart');if(smart)smart.onchange=()=>{w.use_suggested_price=smart.checked;navigate('New rental');};
  const next=document.getElementById('wizard-next');if(next)next.onclick=wfHandle(doWizardNext);
  const back=document.getElementById('wizard-back');if(back)back.onclick=()=>{w.step=Math.max(0,w.step-1);navigate('New rental');};
  const submit=document.getElementById('wizard-create');if(submit)submit.onclick=wfHandle(createFromWizard);
  const clients=document.getElementById('wizard-customers');if(clients)clients.onclick=()=>navigate('Customers');
  const match=document.getElementById('wizard-match');if(match)match.onclick=wfHandle(async()=>{
   const days=Math.max(1,Math.round((Date.parse(w.return_date)-Date.parse(w.pickup_date))/86400000));
   if(!dateValid(w.pickup_date,w.return_date))throw Error('Select valid rental dates first.');
   const q=new URLSearchParams({budget:String(w.budget),seats:String(w.seats),days:String(days),category:w.category});
   const res=await get('/api/smart/recommendations?'+q.toString());w.suggestions=res.results;
   if(res.results.length)w.vehicle_id=Number(res.results[0].vehicle_id);
   await navigate('New rental');
  });
 }
 if(page==='Rental desk'){
  const booking=document.getElementById('desk-booking');if(booking)booking.onchange=()=>setRental(booking.value);
  const create=document.getElementById('desk-create');if(create)create.onclick=()=>navigate('New rental');
  const confirm=document.getElementById('desk-confirm');if(confirm)confirm.onclick=wfHandle(async()=>{await patch(`/api/bookings/${rentalSelected}/status`,{status:'confirmed'});alertUi('Reservation confirmed',{next:'Next: capture pickup condition and generate a handover code.'});await navigate('Rental desk');});
  const qr=document.getElementById('desk-qr');if(qr)qr.onclick=wfHandle(async()=>{const token=await post(`/api/bookings/${rentalSelected}/qr`,{});latestPickupToken=token.qr_payload;
   const inp=document.getElementById('desk-code');if(inp)inp.value=token.qr_payload;
   openModal(`<h2>Secure pickup code</h2><p>Copy or scan this one-time code during the physical handover. Flutter displays the scannable QR graphic.</p><div class="result">${esc(token.qr_payload)}</div><p class="tip">Expires ${esc(token.expires_at)} · This code is displayed only once.</p><button class="primary full" onclick="closeModal()">I saved the code</button>`);});
  const handover=document.getElementById('desk-handover');if(handover)handover.onclick=wfHandle(async()=>{
   const code=document.getElementById('desk-code').value.trim();if(!code)throw Error('Generate and enter a pickup code.');
   await post(`/api/bookings/${rentalSelected}/handover`,{code});latestPickupToken='';alertUi('Rental is active',{next:'The pickup was verified. Track payments and prepare for return inspection.'});await navigate('Rental desk');
  });
  for(const phase of ['pickup','return']){const el=document.getElementById('desk-inspect-'+phase);if(el)el.onclick=wfHandle(()=>uploadInspection(phase));}
  const pay=document.getElementById('desk-pay');if(pay)pay.onclick=wfHandle(async()=>{
   const amount=Number(document.getElementById('desk-pay-amount').value),method=document.getElementById('desk-pay-method').value;
   if(!(amount>0))throw Error('Enter a payment amount.');await post('/api/payments',{booking_id:rentalSelected,amount,method,note:'Rental desk settlement'});
   alertUi('Payment recorded',{next:'Outstanding balance has been updated.'});await navigate('Rental desk');
  });
  const finish=document.getElementById('desk-finish');if(finish)finish.onclick=wfHandle(async()=>{
   await patch(`/api/bookings/${rentalSelected}/status`,{status:'completed'});alertUi('Rental completed',{next:'Booking is closed and shown in rental history.'});await navigate('Rental desk');
  });
  const alerts=document.getElementById('desk-reminders');if(alerts)alerts.onclick=()=>navigate('Reminders');
 }
}
window.wireWorkflow=wireWorkflow;
