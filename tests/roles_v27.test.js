import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {once} from 'node:events';

test('seven roles are seeded and API enforces least-privilege customer / driver / staff access',async t=>{
 const dir=await mkdtemp(join(tmpdir(),'dd-roles-'));
 const child=spawn(process.execPath,['api/server.js'],{cwd:process.cwd(),env:{...process.env,PORT:'0',DB_PATH:join(dir,'roles.db'),DB_DRIVER:'sqlite',SEED_DEMO:'1'},stdio:['ignore','pipe','pipe']});
 t.after(async()=>{child.kill();await once(child,'exit').catch(()=>{});await rm(dir,{recursive:true,force:true});});
 let stdout='',stderr='';child.stdout.on('data',b=>stdout+=b);child.stderr.on('data',b=>stderr+=b);
 for(let i=0;i<120&&!stdout.includes('http://');i++)await new Promise(r=>setTimeout(r,50));
 const base=stdout.match(/http:\/\/127\.0\.0\.1:\d+/)?.[0];assert.ok(base,`${stdout} ${stderr}`);
 async function req(m,p,b,tk){const res=await fetch(base+p,{method:m,headers:{'Content-Type':'application/json',...(tk?{Authorization:`Bearer ${tk}`}:{})},...(b!==undefined?{body:JSON.stringify(b)}:{})});return {status:res.status,data:await res.json()};}
 async function login(email,password){const r=await req('POST','/api/auth/login',{email,password});assert.equal(r.status,200,`${email} ${JSON.stringify(r)}`);return r.data;}
 const pairs=[['admin','admin@drivedesk.local','Demo@12345'],['manager','manager@drivedesk.local','Manager@12345'],['rental_agent','booking@drivedesk.local','Booking@12345'],['fleet_officer','fleet@drivedesk.local','Fleet@12345'],['finance_officer','finance@drivedesk.local','Finance@12345'],['driver','driver@drivedesk.local','Driver@12345'],['customer','customer@drivedesk.local','Customer@12345']];
 const users={};for(const [role,email,password] of pairs){const user=await login(email,password);assert.equal(user.user.role,role);users[role]=user;}
 const tk=role=>users[role].token;
 const roles=await req('GET','/api/roles',undefined,tk('admin'));assert.equal(roles.status,200);assert.equal(Object.keys(roles.data).length,7);
 const team=await req('GET','/api/users',undefined,tk('admin'));assert.equal(team.status,200);assert.ok(team.data.length>=8);
 const deny=[
  ['customer','/api/customers'],['customer','/api/bookings'],['driver','/api/bookings'],['driver','/api/customers'],
  ['finance_officer','/api/customers'],['rental_agent','/api/users'],['manager','/api/users'],['fleet_officer','/api/customers']
 ];
 for(const [role,path] of deny)assert.equal((await req('GET',path,undefined,tk(role))).status,403,`${role} ${path}`);
 assert.equal((await req('POST','/api/vehicles',{plate:'ABC-1234'},tk('finance_officer'))).status,403);
 assert.equal((await req('POST','/api/payments',{booking_id:1,amount:10,method:'cash'},tk('fleet_officer'))).status,403);
 const own=await req('GET','/api/portal/bookings',undefined,tk('customer'));assert.equal(own.status,200);
 const adminBookings=await req('GET','/api/bookings',undefined,tk('admin'));assert.equal(adminBookings.status,200);
 assert.ok(own.data.length>0 && own.data.length<adminBookings.data.length);
 assert.ok(own.data.every(x=>!('customer_phone' in x)));
 assert.equal((await req('GET','/api/portal/me',undefined,tk('customer'))).status,200);
 assert.equal((await req('GET','/api/portal/bookings',undefined,tk('driver'))).status,403);
 const cars=await req('GET','/api/portal/vehicles',undefined,tk('customer'));assert.equal(cars.status,200);assert.ok(cars.data.length>0);
 const future=new Date(Date.now()+60*86400e3).toISOString().slice(0,10);
 const later=new Date(Date.now()+63*86400e3).toISOString().slice(0,10);
 const book=await req('POST','/api/portal/bookings',{vehicle_id:cars.data[0].id,pickup_date:future,return_date:later,customer_id:2},tk('customer'));
 assert.equal(book.status,201,JSON.stringify(book));
 const updated=await req('GET','/api/portal/bookings',undefined,tk('customer'));assert.ok(updated.data.some(x=>x.id===book.data.id));
 const createdBooking=adminBookings.data[0];
 const driverId=users.driver.user.id;
 const assign=await req('PATCH',`/api/bookings/${createdBooking.id}/driver`,{driver_id:driverId},tk('admin'));assert.equal(assign.status,200,JSON.stringify(assign));
 const jobs=await req('GET','/api/driver/jobs',undefined,tk('driver'));assert.equal(jobs.status,200);assert.ok(jobs.data.some(x=>x.id===createdBooking.id));
 const noJob=await req('POST','/api/driver/jobs/999999/inspection',{phase:'pickup',note:'Fine'},tk('driver'));assert.equal(noJob.status,404);
 const anon=await req('GET','/api/portal/bookings');assert.equal(anon.status,401);
 const suspended=await req('PATCH',`/api/users/${driverId}`,{is_active:false},tk('admin'));assert.equal(suspended.status,200);
 assert.equal((await req('GET','/api/driver/jobs',undefined,tk('driver'))).status,401);
});
