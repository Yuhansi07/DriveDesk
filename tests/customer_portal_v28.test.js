import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {once} from 'node:events';

async function server(t,extra={}){
 const dir=await mkdtemp(join(tmpdir(),'dd-v28-'));
 const child=spawn(process.execPath,['api/server.js'],{cwd:process.cwd(),env:{...process.env,PORT:'0',DB_PATH:join(dir,'customer.db'),DB_DRIVER:'sqlite',SEED_DEMO:'1',...extra},stdio:['ignore','pipe','pipe']});
 t.after(async()=>{child.kill();await once(child,'exit').catch(()=>{});await rm(dir,{recursive:true,force:true});});
 let stdout='',stderr='';child.stdout.on('data',b=>stdout+=b);child.stderr.on('data',b=>stderr+=b);
 for(let i=0;i<130&&!stdout.includes('http://');i++)await new Promise(r=>setTimeout(r,50));
 const base=stdout.match(/http:\/\/127\.0\.0\.1:\d+/)?.[0];assert.ok(base,`${stdout} ${stderr}`);
 async function req(m,p,b,token){const res=await fetch(base+p,{method:m,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},...(b!==undefined?{body:JSON.stringify(b)}:{})});return {status:res.status,data:await res.json()};}
 async function login(email,password){const r=await req('POST','/api/auth/login',{email,password});assert.equal(r.status,200,JSON.stringify(r));return r.data.token;}
 return {req,login};
}
const future=(days)=>new Date(Date.now()+days*86400e3).toISOString().slice(0,10);

test('v2.8 customer owns profile, cancels own booking, sees invoice/alerts; cannot see other customer',async t=>{
 const {req,login}=await server(t,{ENABLE_DEMO_PAYMENTS:'0'});
 const customer=await login('customer@drivedesk.local','Customer@12345');
 const admin=await login('admin@drivedesk.local','Demo@12345');
 const me=await req('GET','/api/portal/me',undefined,customer);assert.equal(me.status,200);
 const edited=await req('PATCH','/api/portal/me',{name:'Updated Demo',phone:'0712345678',email:'customer@drivedesk.local',license_no:'DEMO-LIC-0001',license_expiry:future(290)},customer);
 assert.equal(edited.status,200,JSON.stringify(edited));assert.equal(edited.data.name,'Updated Demo');
 const adminMe=await req('GET','/api/portal/me',undefined,admin);assert.equal(adminMe.status,403);
 const cars=await req('GET','/api/portal/vehicles',undefined,customer);assert.equal(cars.status,200);
 const create=await req('POST','/api/portal/bookings',{vehicle_id:cars.data[0].id,pickup_date:future(110),return_date:future(113),customer_id:1},customer);
 assert.equal(create.status,201,JSON.stringify(create));const id=create.data.id;
 const bookingList=await req('GET','/api/portal/bookings',undefined,customer);
 assert.equal(bookingList.status,200);assert.ok(bookingList.data.some(b=>b.id===id));
 const statement=await req('GET',`/api/portal/bookings/${id}/invoice`,undefined,customer);
 assert.equal(statement.status,200);assert.equal(statement.data.customer,'Updated Demo');assert.equal(statement.data.paid,0);
 const guess=await req('GET','/api/portal/bookings/1/invoice',undefined,customer);assert.equal(guess.status,404);
 const cancel=await req('POST',`/api/portal/bookings/${id}/cancel`,{},customer);assert.equal(cancel.status,200);assert.equal(cancel.data.status,'cancelled');
 assert.equal((await req('POST',`/api/portal/bookings/${id}/cancel`,{},customer)).status,409);
 assert.equal((await req('POST',`/api/portal/bookings/${id}/demo-pay`,{},customer)).status,503);
 const notifications=await req('GET','/api/portal/notifications',undefined,customer);assert.equal(notifications.status,200);
 assert.ok(notifications.data.some(n=>n.message.includes(`#${id}`)));
 const note=notifications.data[0].id;
 assert.equal((await req('PATCH',`/api/portal/notifications/${note}/read`,{},customer)).status,200);
 assert.equal((await req('PATCH','/api/portal/notifications/999999/read',{},customer)).status,404);
 assert.equal((await req('GET',`/api/portal/bookings/${id}/location`,undefined,customer)).data.available,false);
 assert.equal((await req('GET','/api/portal/notifications',undefined,admin)).status,403);
});

test('v2.8 explicitly labelled local demo payment records balance, never charges real funds',async t=>{
 const {req,login}=await server(t,{ENABLE_DEMO_PAYMENTS:'1'});
 const customer=await login('customer@drivedesk.local','Customer@12345');
 const admin=await login('admin@drivedesk.local','Demo@12345');
 const cfg=await req('GET','/api/portal/config',undefined,customer);
 assert.equal(cfg.data.demo_payments,true);assert.equal(cfg.data.real_gateway,false);
 const cars=(await req('GET','/api/portal/vehicles',undefined,customer)).data;
 const create=await req('POST','/api/portal/bookings',{vehicle_id:cars[0].id,pickup_date:future(170),return_date:future(173)},customer);
 assert.equal(create.status,201,JSON.stringify(create));const id=create.data.id;
 const payment=await req('POST',`/api/portal/bookings/${id}/demo-pay`,{},customer);
 assert.equal(payment.status,201,JSON.stringify(payment));assert.equal(payment.data.simulated,true);
 const invoice=await req('GET',`/api/portal/bookings/${id}/invoice`,undefined,customer);
 assert.equal(invoice.data.paid,invoice.data.total);assert.equal(invoice.data.balance,0);
 assert.equal(invoice.data.payments[0].method,'demo_gateway');
 assert.equal((await req('POST',`/api/portal/bookings/${id}/demo-pay`,{},customer)).status,409);
 const refund=await req('POST',`/api/portal/bookings/${id}/cancel`,{},customer);
 assert.equal(refund.status,200);assert.equal(refund.data.refund_status,'manual_review');
 assert.equal(refund.data.refund_due,invoice.data.total);
 assert.equal((await req('POST',`/api/portal/bookings/${id}/demo-pay`,{},customer)).status,409);
 const staffPayments=(await req('GET','/api/payments',undefined,admin)).data;
 assert.ok(staffPayments.some(x=>x.booking_id===id&&x.method==='demo_gateway'));
});
