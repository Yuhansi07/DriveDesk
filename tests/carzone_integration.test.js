import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {once} from 'node:events';

test('CarZone staff-assisted showroom: fleet/customer load, availability, pending booking, rental desk record',async t=>{
 const temp=await mkdtemp(join(tmpdir(),'drivedesk-carzone-'));
 const proc=spawn(process.execPath,['api/server.js'],{cwd:process.cwd(),env:{...process.env,DB_DRIVER:'sqlite',DB_PATH:join(temp,'demo.db'),PORT:'0',SEED_DEMO:'1'},stdio:['ignore','pipe','pipe']});
 t.after(async()=>{proc.kill('SIGTERM');await once(proc,'exit').catch(()=>{});await rm(temp,{recursive:true,force:true});});
 let stdout='',stderr='';proc.stdout.on('data',x=>stdout+=x);proc.stderr.on('data',x=>stderr+=x);
 for(let n=0;n<120&&!stdout.includes('http://');n++)await new Promise(r=>setTimeout(r,40));
 const base=stdout.match(/http:\/\/127\.0\.0\.1:\d+/)?.[0];assert.ok(base,stderr);
 let token;
 async function call(method,path,body,origin){const r=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(origin?{'Origin':origin}:{}),...(token?{'Authorization':`Bearer ${token}`}:{})},...(body?{body:JSON.stringify(body)}:{})});return {code:r.status,data:await r.json()};}
 const login=await call('POST','/api/auth/login',{email:'staff@drivedesk.local',password:'Staff@12345'},'http://localhost:8080');
 assert.equal(login.code,200);token=login.data.token;
 const fleet=await call('GET','/api/vehicles');const customers=await call('GET','/api/customers');
 assert.equal(fleet.code,200);assert.equal(customers.code,200);
 const vehicle=fleet.data.find(v=>v.status==='available'&&v.category==='Sedan');const customer=customers.data[0];
 assert.ok(vehicle&&customer);
 function future(offset){const d=new Date();d.setUTCDate(d.getUTCDate()+offset);return d.toISOString().slice(0,10);}
 const pickup=future(47),returnDate=future(50),q=new URLSearchParams({vehicle_id:vehicle.id,pickup_date:pickup,return_date:returnDate});
 assert.equal((await call('GET',`/api/availability?${q}`)).data.available,true);
 const created=await call('POST','/api/bookings',{vehicle_id:vehicle.id,customer_id:customer.id,pickup_date:pickup,return_date:returnDate,use_suggested_price:false});
 assert.equal(created.code,201,JSON.stringify(created));assert.equal(created.data.status,'pending');
 assert.equal(created.data.days,3);
 const listings=await call('GET','/api/bookings');
 assert.equal(listings.code,200);const row=listings.data.find(v=>v.id===created.data.id);
 assert.ok(row);assert.equal(row.customer_name,customer.name);assert.equal(row.plate,vehicle.plate);
 assert.equal((await call('GET',`/api/bookings/${created.data.id}/workflow`)).code,200);
 assert.equal((await call('GET',`/api/availability?${q}`)).data.available,false);
 assert.equal((await call('POST','/api/bookings',{vehicle_id:vehicle.id,customer_id:customer.id,pickup_date:pickup,return_date:returnDate})).code,409);
 const preview=await fetch(`${base}/demo/modern.css`);
 assert.equal(preview.status,200);assert.match(await preview.text(),/dark\/teal/i);
});
