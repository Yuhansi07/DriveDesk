/** No external ML dependencies. Regression is trained on booking history; recommendations/anomalies are explainable heuristics. */
export function validDate(s){return typeof s==='string' && /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(s)) && new Date(`${s}T00:00:00Z`).toISOString().slice(0,10)===s;}
export function rentalDays(a,b){if(!validDate(a)||!validDate(b)) throw new Error('Use valid YYYY-MM-DD dates.');const days=(Date.parse(b)-Date.parse(a))/86400000;if(days<1||days>365)throw new Error('Rental must be between 1 and 365 days.');return days;}
export const round2=x=>Math.round((x+Number.EPSILON)*100)/100;
export function isWeekend(iso){const day=new Date(`${iso}T00:00:00Z`).getUTCDay();return day===0||day===6?1:0;}
export function fitPricingModel(rows){
  if(rows.length<8) return null;
  // 3-parameter ridge regularized least-squares: rate/base = b0 + b1*weekend + b2*seasonal demand
  const X=rows.map(r=>[1,isWeekend(r.pickup_date),Math.min(2,Number(r.demand_index)||0)]);
  const y=rows.map(r=>Number(r.daily_rate)/Number(r.base_rate));
  const a=Array.from({length:3},()=>[0,0,0,0]);
  for(let j=0;j<3;j++){for(let k=0;k<3;k++)a[j][k]=X.reduce((s,x)=>s+x[j]*x[k],0)+(j===k?(j===0?0.001:0.2):0);a[j][3]=X.reduce((s,x,i)=>s+x[j]*y[i],0);}
  for(let j=0;j<3;j++){
    let pivot=j;for(let i=j+1;i<3;i++)if(Math.abs(a[i][j])>Math.abs(a[pivot][j]))pivot=i;
    [a[j],a[pivot]]=[a[pivot],a[j]];
    if(Math.abs(a[j][j])<1e-8)return null;
    let d=a[j][j];for(let k=j;k<4;k++)a[j][k]/=d;
    for(let i=0;i<3;i++)if(i!==j){let t=a[i][j];for(let k=j;k<4;k++)a[i][k]-=t*a[j][k];}
  }
  return {coefficients:a.map(row=>row[3]),samples:rows.length,model:'ridge_linear_regression'};
}
export function quotePrice(vehicle,pickup,ret,historical=[]){
  const days=rentalDays(pickup,ret),base=Number(vehicle.daily_rate),weekend=isWeekend(pickup);
  const sameCategory=historical.filter(x=>x.category===vehicle.category && Number(x.base_rate)>0);
  const model=fitPricingModel(sameCategory);
  const demand=Math.min(2,sameCategory.filter(x=>x.pickup_date?.slice(5,7)===pickup.slice(5,7)).length/Math.max(4,sameCategory.length/4));
  const factor=model?model.coefficients[0]+model.coefficients[1]*weekend+model.coefficients[2]*demand:1+(weekend?0.06:0)+(demand>0.7?0.05:0);
  const recommendedDailyRate=round2(Math.min(base*1.35,Math.max(base*0.8,base*factor)));
  return {vehicle_id:vehicle.id,days,base_daily_rate:base,recommended_daily_rate:recommendedDailyRate,
    estimated_total:round2(recommendedDailyRate*days),currency:'LKR',
    method:model?'ridge_linear_regression':'transparent_rule_fallback',training_samples:sameCategory.length,
    note:model?'Model trained from available completed bookings; staff approves final quote.':'Insufficient category history for reliable regression: rule-based suggestion only.'};
}
export function recommendVehicles(vehicles,{budget=Infinity,category='',seats=1,days=1}={}){
  return vehicles.filter(v=>v.status==='available').map(v=>{
    let score=100;const reasons=[];const price=Number(v.daily_rate)*days;
    if(category && v.category.toLowerCase()===String(category).toLowerCase()){score+=25;reasons.push('Matches preferred category');}
    else if(category){score-=10;}
    if(Number(v.seats)>=Number(seats)){score+=10;reasons.push(`Seats ${v.seats}`);}else{score-=60;reasons.push('Insufficient seats');}
    if(Number.isFinite(Number(budget))&&Number(budget)>0){if(price<=budget){score+=20;reasons.push('Within budget');}else{score-=Math.min(50,25+(price-budget)/budget*15);reasons.push('Above budget');}}
    if(Number(v.service_due_km)>0 && Number(v.mileage_km)>=Number(v.service_due_km)){score-=30;reasons.push('Service due');}
    return {vehicle_id:v.id,plate:v.plate,vehicle:`${v.make} ${v.model}`,category:v.category,price,score:Math.round(score),reasons};
  }).sort((a,b)=>b.score-a.score).slice(0,8);
}
export function anomalyFlags(booking,history=[]){
  const flags=[];const amt=Number(booking.total_amount),days=Number(booking.days);
  if(days>30)flags.push('Long rental (>30 days): review terms');
  if(amt>500000)flags.push('High-value rental (>LKR 500,000): request supervisor review');
  const amounts=history.map(x=>Number(x.total_amount)).filter(Number.isFinite);
  if(amounts.length>=10){const mean=amounts.reduce((a,b)=>a+b,0)/amounts.length;const stdev=Math.sqrt(amounts.reduce((a,b)=>a+(b-mean)**2,0)/amounts.length);
    if(stdev>1&&amt>mean+2.5*stdev)flags.push('Amount unusually high relative to booking history (z-score > 2.5)');}
  return {booking_id:booking.id,flags,level:flags.length>=2?'high':flags.length===1?'review':'normal',method:'explainable_rules_and_optional_zscore',note:'Review signal only, not evidence of fraud.'};
}
export function distanceKm(a,b,c,d){const rad=x=>x*Math.PI/180,R=6371;const dLat=rad(c-a),dLon=rad(d-b);const h=Math.sin(dLat/2)**2+Math.cos(rad(a))*Math.cos(rad(c))*Math.sin(dLon/2)**2;return 2*R*Math.asin(Math.min(1,Math.sqrt(h)));}
export function plateFromOcr(text){const normalized=String(text).toUpperCase().replace(/\s+/g,' '); const patterns=[/\b([A-Z]{2,3})\s*[- ]?\s*(\d{4})\b/,/\b(\d{2,3})\s*[- ]\s*(\d{4})\b/];for(const p of patterns){let m=normalized.match(p);if(m)return `${m[1]}-${m[2]}`;}return null;}
export function licenseFields(text){const s=String(text);return {license_no:s.match(/\b[A-Z]\d{7,9}\b/i)?.[0]?.toUpperCase()||null,raw_text:s};}
/** Time series trend using observed monthly completed booking counts; deliberately returns no invented confidence bound. */
export function forecastDemand(bookings,monthsAhead=3){
 const group=new Map();for(const b of bookings){const key=String(b.pickup_date).slice(0,7);if(/^\d{4}-\d{2}$/.test(key))group.set(key,(group.get(key)||0)+1);}
 const keys=[...group.keys()].sort();if(keys.length===0)return {method:'unavailable',history:[],forecast:[],note:'No completed booking history.'};
 const last=new Date(`${keys[keys.length-1]}-01T00:00:00Z`);
 const history=[];
 for(let date=new Date(`${keys[0]}-01T00:00:00Z`);date<=last;date.setUTCMonth(date.getUTCMonth()+1)){
   const label=date.toISOString().slice(0,7);history.push({month:label,bookings:group.get(label)||0});
 }
 const n=history.length,meanX=(n-1)/2,meanY=history.reduce((s,x)=>s+x.bookings,0)/n;
 const denominator=history.reduce((s,_,i)=>s+(i-meanX)**2,0);
 const slope=n>=4&&denominator>0?history.reduce((s,x,i)=>s+(i-meanX)*(x.bookings-meanY),0)/denominator:0;
 const out=[];for(let i=1;i<=Math.min(12,monthsAhead);i++){
   const d=new Date(last);d.setUTCMonth(last.getUTCMonth()+i);
   const predicted=Math.max(0,Math.round(meanY+slope*(n-1+i-meanX)));
   out.push({month:d.toISOString().slice(0,7),predicted_bookings:predicted});
 }
 return {method:n>=4?'least_squares_linear_trend':'historical_average_fallback',history,forecast:out,training_months:n,note:'Demo data is synthetic. Forecast is a simple baseline, not a validated business forecast.'};
}
/** Read-only exact-data assistant. No LLM claims. */
export function assistantReply(message,vehicles,bookings){
 const q=String(message).toLowerCase();
 if(/(suv|sedan|hybrid|compact|hatchback)/.test(q)){
   const category=q.match(/suv|sedan|hybrid|compact|hatchback/)[0];
   const matches=vehicles.filter(x=>x.status==='available'&&x.category.toLowerCase()===category);
   return `In-service ${category.toUpperCase()} vehicles: ${matches.map(v=>`${v.plate} (${v.make} ${v.model}, LKR ${v.daily_rate}/day)`).join('; ')||'none'}. For specific dates, use Availability Check.`;
 }
 if(/(vehicle|car|fleet)/.test(q))return `Fleet: ${vehicles.length} vehicles, ${vehicles.filter(x=>x.status==='available').length} in service. Use Vehicles for details.`;
 if(/(booking|reservation)/.test(q))return `Bookings recorded: ${bookings.length}; ${bookings.filter(x=>x.status==='active').length} currently active. Visit Bookings to manage them.`;
 if(/(help|feature|can)/.test(q))return 'You can ask about fleet, SUVs, sedans, bookings, or available vehicle categories. I cannot guarantee availability for exact dates without the Availability Check API.';
 return 'I can answer simple fleet and bookings questions from the DriveDesk database. Ask about SUV, sedan, fleet, or bookings. This is a rule-based assistant, not an LLM.';
}
