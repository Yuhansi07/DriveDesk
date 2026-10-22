import { randomUUID } from 'node:crypto';
import { mkdir,readFile,writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { spawn } from 'node:child_process';
import { cfg } from './config.js';
import { ROLE_DETAILS,roleNames,effectiveRole,permitted } from './access.js';
import {sha256,newToken,verifyPassword,hashPassword,validEmail} from './security.js';
import {rentalDays,validDate,round2,quotePrice,recommendVehicles,anomalyFlags,distanceKm,plateFromOcr,licenseFields,forecastDemand,assistantReply} from './smart.js';
const bad=(status,message)=>Object.assign(new Error(message),{status});
const requireStr=(s,name,max=120)=>{if(typeof s!=='string'||!s.trim()||s.trim().length>max)throw bad(400,`${name} is required (max ${max} chars).`);return s.trim();};
const posInt=(v,name='ID')=>{const n=Number(v);if(!Number.isSafeInteger(n)||n<1)throw bad(400,`Invalid ${name}.`);return n;};
const num=(v,name,{min=0,max=1e8}={})=>{const n=Number(v);if(!Number.isFinite(n)||n<min||n>max)throw bad(400,`Invalid ${name}.`);return n;};
const money=v=>round2(num(v,'amount',{min:.01}));
const today=()=>new Date().toISOString().slice(0,10);
const dt=x=>typeof x==='string'?x.slice(0,10):x instanceof Date?x.toISOString().slice(0,10):String(x||'').slice(0,10);
const result=(data,status=200)=>({status,data});
const strDate=(x,name)=>{if(x!==null&&x!==undefined&&x!==''&&!validDate(x))throw bad(400,`Invalid ${name}; expected YYYY-MM-DD.`);return x||null;};
async function notifyCustomer(db,customerId,kind,message,eventKey){
 if(!customerId)return;
 await db.exec('INSERT INTO portal_notifications(customer_id,kind,message,event_key) VALUES (?,?,?,?) ON CONFLICT(event_key) DO NOTHING',[customerId,kind,message,eventKey]);
}
async function audit(db,user,action,entity,id,detail=''){await db.exec('INSERT INTO audits(actor_id,action,entity,entity_id,detail) VALUES (?,?,?,?,?)',[user?.id||null,action,entity,id||null,String(detail).slice(0,300)]);}
async function insert(tx,table,cols,vals){return tx.one(`INSERT INTO ${table} (${cols.join(',')}) VALUES (${cols.map(()=>'?').join(',')}) RETURNING *`,vals);}
async function vehicleBody(b){return {plate:requireStr(b.plate,'Plate',20).toUpperCase(),make:requireStr(b.make,'Make',70),model:requireStr(b.model,'Model',70),category:requireStr(b.category,'Category',40),year:num(b.year,'year',{min:1990,max:2100}),daily_rate:money(b.daily_rate),seats:num(b.seats??5,'seats',{min:1,max:60}),mileage_km:num(b.mileage_km??0,'mileage_km'),service_due_km:b.service_due_km==null?null:num(b.service_due_km,'service_due_km'),insurance_expiry:strDate(b.insurance_expiry,'insurance expiry'),status:b.status||'available'};}
const vehicleCols=['plate','make','model','category','year','daily_rate','seats','mileage_km','service_due_km','insurance_expiry','status'];
function customerBody(b){if(b.email&&!validEmail(b.email))throw bad(400,'Invalid email.');return {name:requireStr(b.name,'Customer name',100),phone:requireStr(b.phone,'Phone',30),email:b.email||null,license_no:requireStr(b.license_no,'Driving license',60),license_expiry:strDate(b.license_expiry,'license expiry')};}
const custCols=['name','phone','email','license_no','license_expiry'];
async function auth(db,headers){const token=String(headers.authorization||headers.Authorization||'').replace(/^Bearer\s+/i,'');if(!token)throw bad(401,'Please log in.');
  const user=await db.one('SELECT u.id,u.name,u.email,u.role,u.access_role,u.customer_id,u.is_active,s.expires_at FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=?',[sha256(token)]);
  if(!user||!user.is_active||new Date(user.expires_at)<=new Date())throw bad(401,'Session expired; log in again.');return {id:user.id,name:user.name,email:user.email,role:effectiveRole(user),customer_id:user.customer_id??null};
}
async function priceHistory(db){const rows=await db.all(`SELECT b.pickup_date,b.daily_rate,v.daily_rate AS base_rate,v.category,b.status
 FROM bookings b JOIN vehicles v ON v.id=b.vehicle_id WHERE b.status='completed' ORDER BY b.id DESC LIMIT 1000`);return rows.map(r=>({...r,pickup_date:dt(r.pickup_date)}));}
async function ensureAvailable(tx,vehicleId,from,to,exclude=null){const v=await tx.one('SELECT * FROM vehicles WHERE id=?',[vehicleId]);if(!v)throw bad(404,'Vehicle not found.');if(v.status!=='available')throw bad(409,'Vehicle is not in service.');
  const other=await tx.one(`SELECT id FROM bookings WHERE vehicle_id=? AND status IN ('pending','confirmed','active') AND pickup_date < ? AND return_date > ? AND (? IS NULL OR id<>?) LIMIT 1`,[vehicleId,to,from,exclude,exclude]);if(other)throw bad(409,'Vehicle has a conflicting booking.');return v;}
async function triggerAlerts(db){const bookings=await db.all(`SELECT b.id,b.return_date,v.plate FROM bookings b JOIN vehicles v ON v.id=b.vehicle_id WHERE b.status='active'`);
 const vehicles=await db.all('SELECT id,plate,insurance_expiry,service_due_km,mileage_km FROM vehicles');const now=Date.parse(today());let created=0;
 const add=async(kind,msg,key)=>{const changed=await db.exec('INSERT INTO notifications(kind,message,entity_key) VALUES (?,?,?) ON CONFLICT(entity_key) DO NOTHING',[kind,msg,key]);if(changed.changes===undefined || changed.changes>0)created++;};
 for(const b of bookings){const left=(Date.parse(dt(b.return_date))-now)/86400000;if(left<=2){await add('return_due',`${b.plate} rental #${b.id} is due ${dt(b.return_date)}.`,`due:${b.id}:${dt(b.return_date)}`);}}
 for(const v of vehicles){if(v.insurance_expiry){const days=(Date.parse(dt(v.insurance_expiry))-now)/86400000;if(days<=30)await add('insurance',`${v.plate} insurance expires ${dt(v.insurance_expiry)}.`,`insurance:${v.id}:${dt(v.insurance_expiry)}`);}
   if(v.service_due_km!=null && Number(v.mileage_km)>=Number(v.service_due_km)-500)await add('maintenance',`${v.plate} is near/past service due (${v.service_due_km} km).`,`service:${v.id}:${v.service_due_km}`);
 }
 return {created,note:'In-app notifications created/deduplicated. No SMS/email sent.'};
}
function imageBytes(b){const text=String(b.image_base64||'');if(text.length>1500000||text.length<30)throw bad(400,'Provide a base64 image smaller than 1 MB.');const raw=text.replace(/^data:image\/(jpeg|png|webp);base64,/,'');if(!/^[A-Za-z0-9+/=]+$/.test(raw))throw bad(400,'Invalid base64 image.');const buf=Buffer.from(raw,'base64');if(buf.length>1100000)throw bad(413,'Image too large.');
 const jpg=buf[0]===0xff&&buf[1]===0xd8;const png=buf.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));const webp=buf.toString('ascii',0,4)==='RIFF'&&buf.toString('ascii',8,12)==='WEBP';
 if(!jpg&&!png&&!webp)throw bad(400,'Only JPG/PNG/WebP supported.');return {buf,mime:jpg?'image/jpeg':png?'image/png':'image/webp',ext:jpg?'jpg':png?'png':'webp'};
}
async function tesseractOcr(buffer){if(!cfg.tesseract)throw bad(503,'Local OCR disabled. Install Tesseract and set ENABLE_TESSERACT=1, or use on-device ML Kit.');return new Promise((resolve,reject)=>{
  const p=spawn('tesseract',['stdin','stdout','-l','eng'],{stdio:['pipe','pipe','pipe']});let out='',err='';const timer=setTimeout(()=>p.kill(),20000);
  p.stdout.on('data',d=>out+=d.toString().slice(0,20000));p.stderr.on('data',d=>err+=d.toString().slice(0,2000));p.on('error',()=>{clearTimeout(timer);reject(bad(503,'Tesseract executable not found.'));});p.on('close',code=>{clearTimeout(timer);code===0?resolve(out):reject(bad(503,`Tesseract failed: ${err.slice(0,150)}`));});p.stdin.end(buffer);
 });}
async function damageDetect(b){const image=imageBytes(b);let response;try{response=await fetch(`${cfg.damageUrl}/detect`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({image_base64:image.buf.toString('base64')}),signal:AbortSignal.timeout(12000)});}catch{throw bad(503,'Damage ML service offline. Start optional_ai/service.py with a trained weights file.');}
 const data=await response.json().catch(()=>({error:'Invalid ML service response'}));if(!response.ok)throw bad(response.status===422?400:503,data.error||data.detail||'ML model unavailable.');return result(data);
}
const loginHits=new Map();
export function makeRoutes(db){return async function route({method,path,body={},query={},headers={},ip=''}){
  if(method==='GET' && path==='/api/health')return result({ok:true,name:'DriveDesk Pro',db_driver:cfg.driver});
  if(method==='GET' && path==='/api/features')return result({features:{pricing:'regression if history >=8; rule fallback otherwise',recommendations:'explainable content-based ranking',anomalies:'rules + optional zscore',ocr:cfg.tesseract?'Tesseract enabled':'requires Tesseract or Flutter ML Kit',damage:'requires trained external YOLO model',gps:'manual / simulated / external authorized tracker ingestion; not built-in hardware tracking',qr:'cryptographically random handover code + QR widget',notifications:'in-app scheduled checks',demand:'least-squares trend if >=4 months; average fallback otherwise',chatbot:'read-only rule-based Q&A (not an LLM)'}});
  if(method==='POST' && path==='/api/auth/login'){
    const key=String(ip).slice(0,90),rec=loginHits.get(key)||{n:0,ts:Date.now()};if(Date.now()-rec.ts>900000){rec.n=0;rec.ts=Date.now();}
    if(rec.n>=12)throw bad(429,'Too many attempts; retry in 15 minutes.');
    const email=requireStr(body.email,'Email',180).toLowerCase(),password=String(body.password||'');
    const user=await db.one('SELECT * FROM users WHERE email=?',[email]);
    if(!user || !user.is_active || !verifyPassword(password,user.password_hash)){rec.n++;loginHits.set(key,rec);throw bad(401,'Invalid credentials.');}
    loginHits.delete(key);await db.exec('UPDATE users SET last_login_at=? WHERE id=?',[new Date().toISOString(),user.id]);const token=newToken(),expires=new Date(Date.now()+cfg.ttlHours*3600000).toISOString();
    await db.exec('INSERT INTO sessions(token_hash,user_id,expires_at) VALUES (?,?,?)',[sha256(token),user.id,expires]);
    return result({token,expires_at:expires,user:{id:user.id,name:user.name,email:user.email,role:effectiveRole(user),customer_id:user.customer_id??null}});
  }
  const user=await auth(db,headers);
  if(!permitted(user.role,method,path))throw bad(403,'This account does not have permission for that action.');
  if(method==='GET'&&path==='/api/auth/me')return result({user});
  if(method==='POST'&&path==='/api/auth/logout'){await db.exec('DELETE FROM sessions WHERE token_hash=?',[sha256(String(headers.authorization).replace(/^Bearer\s+/i,''))]);return result({ok:true});}
  // Team accounts: only an admin can create/update/suspend users. Never return hashes.
  if(method==='GET'&&path==='/api/users'){
    if(user.role!=='admin')throw bad(403,'Admin only.');
    return result(await db.all('SELECT id,name,email,access_role AS role,customer_id,is_active,created_at,last_login_at FROM users ORDER BY id ASC'));
  }
  if(method==='GET'&&path==='/api/roles')return result(ROLE_DETAILS);
  if(method==='POST'&&path==='/api/auth/change-password'){
    const current=await db.one('SELECT password_hash FROM users WHERE id=?',[user.id]);
    if(!verifyPassword(String(body.current_password||''),current?.password_hash||''))throw bad(403,'Current password is incorrect.');
    if(typeof body.new_password!=='string'||body.new_password.length<8)throw bad(400,'New password must contain at least 8 characters.');
    const password=hashPassword(body.new_password);
    await db.transaction(async tx=>{await tx.exec('UPDATE users SET password_hash=? WHERE id=?',[password,user.id]);await tx.exec('DELETE FROM sessions WHERE user_id=? AND token_hash<>?',[user.id,sha256(String(headers.authorization).replace(/^Bearer\s+/i,''))]);});
    await audit(db,user,'change_password','users',user.id);
    return result({ok:true,message:'Password changed. Other sessions were signed out.'});
  }
  const userMatch=path.match(/^\/api\/users\/(\d+)$/);
  if(userMatch&&method==='PATCH'){
    if(user.role!=='admin')throw bad(403,'Admin only.');
    const id=posInt(userMatch[1]);
    const current=await db.one('SELECT id,name,email,access_role AS role,customer_id,is_active FROM users WHERE id=?',[id]);
    if(!current)throw bad(404,'User not found.');
    const role=body.role===undefined?current.role:(body.role==='staff'?'rental_agent':body.role);
    if(!roleNames.includes(role))throw bad(400,'Invalid role.');
    const customerId=role==='customer'?posInt(body.customer_id??current.customer_id,'customer ID'):null;
    if(customerId && !await db.one('SELECT id FROM customers WHERE id=?',[customerId]))throw bad(400,'Linked customer record does not exist.');
    const active=body.is_active===undefined?Boolean(current.is_active):body.is_active;
    if(typeof active!=='boolean')throw bad(400,'is_active must be a boolean.');
    if(id===user.id && (!active||role!=='admin'))throw bad(409,'You cannot disable or demote your own admin account.');
    const name=body.name===undefined?current.name:requireStr(body.name,'Name',120);
    const email=body.email===undefined?current.email:String(body.email).trim().toLowerCase();
    if(!validEmail(email))throw bad(400,'Invalid email.');
    const updated=await db.transaction(async tx=>{
      if(current.role==='admin' && (role!=='admin'||!active)){
        const count=await tx.one('SELECT COUNT(*) AS n FROM users WHERE access_role=? AND is_active=?',['admin',cfg.driver==='sqlite'?1:true]);
        if(Number(count.n)<=1)throw bad(409,'At least one active admin is required.');
      }
      const row=await tx.one('UPDATE users SET name=?,email=?,role=?,access_role=?,customer_id=?,is_active=? WHERE id=? RETURNING id,name,email,access_role AS role,customer_id,is_active,created_at,last_login_at',[name,email,role==='admin'?'admin':'staff',role,customerId,cfg.driver==='sqlite'?(active?1:0):active,id]);
      if(!active||role!==current.role)await tx.exec('DELETE FROM sessions WHERE user_id=?',[id]);
      return row;
    });
    await audit(db,user,'update','users',id,`${role}; active=${active}`);return result(updated);
  }
  const pwdMatch=path.match(/^\/api\/users\/(\d+)\/password$/);
  if(pwdMatch&&method==='PATCH'){
    if(user.role!=='admin')throw bad(403,'Admin only.');
    const id=posInt(pwdMatch[1]);
    if(!await db.one('SELECT id FROM users WHERE id=?',[id]))throw bad(404,'User not found.');
    if(typeof body.password!=='string'||body.password.length<8)throw bad(400,'Password must contain at least 8 characters.');
    const password=hashPassword(body.password);
    await db.transaction(async tx=>{await tx.exec('UPDATE users SET password_hash=? WHERE id=?',[password,id]);await tx.exec('DELETE FROM sessions WHERE user_id=?',[id]);});
    await audit(db,user,'reset_password','users',id);return result({ok:true,message:'Password reset. Existing sessions revoked.'});
  }
  if(method==='POST'&&path==='/api/users'){
    if(user.role!=='admin')throw bad(403,'Admin only.');
    if(!validEmail(body.email))throw bad(400,'Invalid email.');
    const role=body.role==='staff'?'rental_agent':body.role;if(!roleNames.includes(role))throw bad(400,'Invalid role.');
    const customerId=role==='customer'?posInt(body.customer_id,'customer ID'):null;
    if(customerId && !await db.one('SELECT id FROM customers WHERE id=?',[customerId]))throw bad(400,'Linked customer record does not exist.');
    if(typeof body.password!=='string'||body.password.length<8)throw bad(400,'Password must contain at least 8 characters.');
    const r=await insert(db,'users',['name','email','password_hash','role','access_role','customer_id'],[requireStr(body.name,'Name'),body.email.trim().toLowerCase(),hashPassword(body.password),role==='admin'?'admin':'staff',role,customerId]);await audit(db,user,'create','users',r.id);return result({id:r.id,name:r.name,email:r.email,role,is_active:true,customer_id:customerId},201);
  }
  // Scoped customer portal. Never trust customer_id from a request body.
  if(path.startsWith('/api/portal/')){
    if(user.role!=='customer'||!user.customer_id)throw bad(403,'Customer account is not linked to a profile.');
    const cid=user.customer_id;
    if(method==='GET'&&path==='/api/portal/me'){
      const person=await db.one('SELECT id,name,phone,email,license_no,license_expiry FROM customers WHERE id=?',[cid]);
      if(!person)throw bad(404,'Linked customer not found.');return result(person);
    }
    if(method==='PATCH'&&path==='/api/portal/me'){
      const name=requireStr(body.name,'Name',100),phone=requireStr(body.phone,'Phone',30),email=requireStr(body.email,'Email',180).toLowerCase();
      if(!validEmail(email))throw bad(400,'Invalid email address.');
      const license=requireStr(body.license_no,'Driving licence',60);
      const expiry=strDate(body.license_expiry,'Licence expiry');
      const profile=await db.transaction(async tx=>{
        const existing=await tx.one('SELECT id FROM customers WHERE id=?',[cid]);if(!existing)throw bad(404,'Customer not found.');
        // Keep login and linked customer contact in sync atomically.
        await tx.exec('UPDATE users SET name=?,email=? WHERE id=?',[name,email,user.id]);
        return tx.one('UPDATE customers SET name=?,phone=?,email=?,license_no=?,license_expiry=? WHERE id=? RETURNING id,name,phone,email,license_no,license_expiry',[name,phone,email,license,expiry,cid]);
      });
      await audit(db,user,'self_profile','customers',cid,'Customer-submitted data; licence must be verified by staff');return result(profile);
    }
    if(method==='GET'&&path==='/api/portal/config')return result({currency:'LKR',demo_payments:cfg.demoPayments&&cfg.driver==='sqlite'&&cfg.seed,real_gateway:false,live_gps_integration:false});
    if(method==='GET'&&path==='/api/portal/vehicles')return result(await db.all("SELECT id,plate,make,model,category,year,seats,daily_rate,status FROM vehicles WHERE status='available' ORDER BY id DESC"));
    if(method==='GET'&&path==='/api/portal/bookings'){
      return result(await db.all(`SELECT b.id,b.vehicle_id,b.pickup_date,b.return_date,b.days,b.daily_rate,b.total_amount,b.status,v.make,v.model,v.plate,v.category,v.seats,
      COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.booking_id=b.id),0) AS paid_amount,
      (SELECT refund_status FROM cancellation_requests c WHERE c.booking_id=b.id) AS refund_status
      FROM bookings b JOIN vehicles v ON v.id=b.vehicle_id WHERE b.customer_id=? ORDER BY b.id DESC`,[cid]));
    }
    if(method==='POST'&&path==='/api/portal/bookings'){
      const vid=posInt(body.vehicle_id),from=requireStr(body.pickup_date,'Pickup date'),to=requireStr(body.return_date,'Return date');
      let days;try{days=rentalDays(from,to);}catch(e){throw bad(400,e.message);}
      if(from<today())throw bad(400,'Pickup date cannot be in the past.');
      const saved=await db.transaction(async tx=>{
        const vehicle=await ensureAvailable(tx,vid,from,to);
        const customer=await tx.one('SELECT id,license_expiry FROM customers WHERE id=?',[cid]);
        if(!customer)throw bad(404,'Customer profile not found.');
        if(customer.license_expiry && dt(customer.license_expiry)<to)throw bad(409,'Your licence expires before return.');
        return insert(tx,'bookings',['vehicle_id','customer_id','pickup_date','return_date','days','daily_rate','total_amount','status'],[vid,cid,from,to,days,vehicle.daily_rate,round2(days*vehicle.daily_rate),'pending']);
      });
      await notifyCustomer(db,cid,'booking',`Booking #${saved.id} received. Our team will confirm it.`,`booking:${saved.id}:created`);
      await audit(db,user,'customer_request','bookings',saved.id);return result({id:saved.id,status:saved.status,total_amount:saved.total_amount},201);
    }
    if(method==='GET'&&path==='/api/portal/notifications')return result(await db.all('SELECT id,kind,message,is_read,created_at FROM portal_notifications WHERE customer_id=? ORDER BY id DESC LIMIT 80',[cid]));
    const readNotice=path.match(/^\/api\/portal\/notifications\/(\d+)\/read$/);
    if(readNotice&&method==='PATCH'){
      const saved=await db.one('UPDATE portal_notifications SET is_read=? WHERE id=? AND customer_id=? RETURNING id',[cfg.driver==='sqlite'?1:true,posInt(readNotice[1]),cid]);
      if(!saved)throw bad(404,'Notification not found.');return result({ok:true});
    }
    const detail=path.match(/^\/api\/portal\/bookings\/(\d+)\/(invoice|cancel|location|demo-pay)$/);
    if(detail){
      const bookingId=posInt(detail[1]),action=detail[2];
      const booking=await db.one('SELECT b.*,v.make,v.model,v.plate,v.category,c.name AS customer_name,c.phone AS customer_phone FROM bookings b JOIN vehicles v ON v.id=b.vehicle_id JOIN customers c ON c.id=b.customer_id WHERE b.id=? AND b.customer_id=?',[bookingId,cid]);
      if(!booking)throw bad(404,'Your booking was not found.');
      if(action==='invoice'&&method==='GET'){
        const pays=await db.all('SELECT id,amount,method,created_at FROM payments WHERE booking_id=? ORDER BY id ASC',[bookingId]);
        const total=round2(Number(booking.total_amount)),paid=round2(pays.reduce((n,p)=>n+Number(p.amount),0));
        const cancellation=await db.one('SELECT refund_due,refund_status FROM cancellation_requests WHERE booking_id=?',[bookingId]);
        return result({invoice_number:`DD-${String(bookingId).padStart(6,'0')}`,booking_id:bookingId,issued_at:booking.created_at,customer:booking.customer_name,vehicle:`${booking.make} ${booking.model}`,plate:booking.plate,pickup_date:dt(booking.pickup_date),return_date:dt(booking.return_date),days:booking.days,daily_rate:Number(booking.daily_rate),currency:'LKR',total,paid,balance:round2(Math.max(0,total-paid)),payments:pays,status:booking.status,cancellation,document_type:booking.status==='completed'?'final_rental_statement':'provisional_rental_statement',disclaimer:'Booking statement, not a tax invoice or proof of online payment.'});
      }
      if(action==='cancel'&&method==='POST'){
        const outcome=await db.transaction(async tx=>{
          const current=await tx.one('SELECT status,pickup_date FROM bookings WHERE id=? AND customer_id=?',[bookingId,cid]);
          if(!current)throw bad(404,'Your booking not found.');
          if(!['pending','confirmed'].includes(current.status)||dt(current.pickup_date)<=today())throw bad(409,'Only pending or confirmed future rentals can be cancelled before pickup day. Contact staff for exceptions.');
          const payment=await tx.one('SELECT COALESCE(SUM(amount),0) AS amount FROM payments WHERE booking_id=?',[bookingId]);
          const refundDue=round2(Number(payment.amount));
          const updated=await tx.one("UPDATE bookings SET status='cancelled',pickup_code_hash=NULL,pickup_code_expires_at=NULL WHERE id=? AND customer_id=? AND status IN ('pending','confirmed') RETURNING id,status",[bookingId,cid]);
          if(!updated)throw bad(409,'Booking changed; please refresh.');
          await insert(tx,'cancellation_requests',['booking_id','customer_id','refund_due','refund_status'],[bookingId,cid,refundDue,refundDue>0?'manual_review':'none']);
          return {status:updated.status,refund_due:refundDue,refund_status:refundDue>0?'manual_review':'none'};
        });
        await notifyCustomer(db,cid,'cancellation',`Booking #${bookingId} cancelled.${outcome.refund_due>0?' Any refund requires manual staff review.':''}`,`booking:${bookingId}:cancelled`);
        await audit(db,user,'self_cancel','bookings',bookingId);return result(outcome);
      }
      if(action==='location'&&method==='GET'){
        if(booking.status!=='active')return result({available:false,reason:'Tracking is only available for an active rental.',position:null});
        // Never show staff_manual or simulated points as live vehicle tracking.
        const pt=await db.one("SELECT latitude,longitude,recorded_at FROM location_events WHERE vehicle_id=? AND source='tracker' AND consent_confirmed=? ORDER BY id DESC LIMIT 1",[booking.vehicle_id,cfg.driver==='sqlite'?1:true]);
        if(!pt)return result({available:false,reason:'No authorized hardware GPS tracker is connected.',position:null});
        const recent=Date.now()-Date.parse(pt.recorded_at)<15*60000;
        return result({available:recent,reason:recent?null:'Last tracker position is stale.',position:recent?pt:null,source:'authorized_hardware_tracker',freshness_minutes:15});
      }
      if(action==='demo-pay'&&method==='POST'){
        if(!cfg.demoPayments||cfg.driver!=='sqlite'||!cfg.seed)throw bad(503,'Online payment gateway not configured. Use the staff-recorded payment process.');
        const paid=await db.transaction(async tx=>{
          const current=await tx.one('SELECT status,total_amount FROM bookings WHERE id=? AND customer_id=?',[bookingId,cid]);
          if(!current||current.status==='cancelled'||current.status==='completed')throw bad(409,'Booking cannot be paid at this stage.');
          const sums=await tx.one('SELECT COALESCE(SUM(amount),0) AS paid FROM payments WHERE booking_id=?',[bookingId]);
          const due=round2(Number(current.total_amount)-Number(sums.paid));
          if(due<=0.009)throw bad(409,'Booking already paid.');
          return insert(tx,'payments',['booking_id','amount','method','note'],[bookingId,due,'demo_gateway','SIMULATED PAYMENT — demo only, no real funds transferred']);
        });
        await notifyCustomer(db,cid,'payment',`Demo payment recorded for booking #${bookingId}. No real funds transferred.`,`booking:${bookingId}:demo-payment:${paid.id}`);
        await audit(db,user,'simulated_payment','bookings',bookingId,'No real funds transferred');return result({id:paid.id,amount:paid.amount,simulated:true,message:'Demo payment successful. No real money was charged.'},201);
      }
    }
  }
  // Driver sees jobs assigned to their own account; never the full rental register.
  if(method==='GET'&&path==='/api/driver/jobs')return result(await db.all(
    "SELECT b.id,b.pickup_date,b.return_date,b.status,v.plate,v.make,v.model,c.name AS customer_name FROM bookings b JOIN vehicles v ON v.id=b.vehicle_id JOIN customers c ON c.id=b.customer_id WHERE b.assigned_driver_id=? ORDER BY b.id DESC",[user.id]));
  let driverJob=path.match(/^\/api\/driver\/jobs\/(\d+)\/inspection$/);
  if(driverJob&&method==='POST'){
    const id=posInt(driverJob[1]),booking=await db.one('SELECT id,status FROM bookings WHERE id=? AND assigned_driver_id=?',[id,user.id]);
    if(!booking)throw bad(404,'Assigned job not found.');
    const phase=body.phase;
    if(phase!=='pickup'&&phase!=='return')throw bad(400,'Invalid inspection phase.');
    if((phase==='pickup'&&booking.status!=='confirmed')||(phase==='return'&&booking.status!=='active'))throw bad(409,'Inspection not allowed at this stage.');
    const note=requireStr(body.note,'Inspection notes',500);
    const r=await insert(db,'inspections',['booking_id','phase','reviewer_note'],[id,phase,note]);
    await audit(db,user,'driver_inspection','bookings',id,phase);return result({id:r.id,phase,booking_id:id},201);
  }
  if(method==='GET'&&path==='/api/drivers')return result(await db.all("SELECT id,name,email FROM users WHERE access_role='driver' AND is_active=? ORDER BY name",[cfg.driver==='sqlite'?1:true]));
  let assignment=path.match(/^\/api\/bookings\/(\d+)\/driver$/);
  if(assignment&&method==='PATCH'){
    const bookingId=posInt(assignment[1]);
    const target=body.driver_id===null?null:posInt(body.driver_id,'driver');
    if(target){const driver=await db.one("SELECT id FROM users WHERE id=? AND access_role='driver' AND is_active=?",[target,cfg.driver==='sqlite'?1:true]);if(!driver)throw bad(400,'Choose an active driver account.');}
    const row=await db.one('UPDATE bookings SET assigned_driver_id=? WHERE id=? RETURNING id,assigned_driver_id',[target,bookingId]);
    if(!row)throw bad(404,'Booking not found.');await audit(db,user,'assign_driver','bookings',bookingId,String(target??'unassigned'));return result(row);
  }
  if(method==='GET'&&path==='/api/dashboard'){
    const [v,c,b,p,active,maintenance]=await Promise.all([
      db.one('SELECT COUNT(*) AS n FROM vehicles'),db.one('SELECT COUNT(*) AS n FROM customers'),db.one('SELECT COUNT(*) AS n FROM bookings'),db.one('SELECT COALESCE(SUM(amount),0) AS amount FROM payments'),
      db.one("SELECT COUNT(*) AS n FROM bookings WHERE status='active'"),db.one("SELECT COUNT(*) AS n FROM vehicles WHERE status='maintenance'")]);
    const recent=await db.all('SELECT b.id,b.pickup_date,b.return_date,b.total_amount,b.status,v.plate,c.name AS customer_name FROM bookings b JOIN vehicles v ON v.id=b.vehicle_id JOIN customers c ON c.id=b.customer_id ORDER BY b.id DESC LIMIT 7');
    return result({vehicles:Number(v.n),customers:Number(c.n),bookings:Number(b.n),active:Number(active.n),maintenance:Number(maintenance.n),collected_revenue:round2(Number(p.amount)),recent_bookings:recent,currency:'LKR'});
  }
  if(method==='GET'&&path==='/api/vehicles')return result(await db.all('SELECT * FROM vehicles ORDER BY id DESC'));
  if(method==='POST'&&path==='/api/vehicles'){
    const v=await vehicleBody(body);if(!['available','maintenance'].includes(v.status))throw bad(400,'Invalid status.');
    const r=await insert(db,'vehicles',vehicleCols,vehicleCols.map(k=>v[k]));await audit(db,user,'create','vehicles',r.id);return result(r,201);
  }
  if(method==='GET'&&path==='/api/customers')return result(await db.all('SELECT * FROM customers ORDER BY id DESC'));
  if(method==='POST'&&path==='/api/customers'){
    const c=customerBody(body),r=await insert(db,'customers',custCols,custCols.map(k=>c[k]));await audit(db,user,'create','customers',r.id);return result(r,201);
  }
  let m=path.match(/^\/api\/(vehicles|customers)\/(\d+)$/);
  if(m){const table=m[1],id=posInt(m[2]);const existing=await db.one(`SELECT * FROM ${table} WHERE id=?`,[id]);if(!existing)throw bad(404,'Record not found.');
    if(method==='PUT'){
      const payload=table==='vehicles'?await vehicleBody(body):customerBody(body),keys=table==='vehicles'?vehicleCols:custCols;
      if(table==='vehicles'&&payload.status==='maintenance') {const booked=await db.one("SELECT id FROM bookings WHERE vehicle_id=? AND status IN ('pending','confirmed','active') LIMIT 1",[id]);if(booked)throw bad(409,'Complete or cancel open bookings before maintenance.');}
      const r=await db.one(`UPDATE ${table} SET ${keys.map(k=>`${k}=?`).join(',')} WHERE id=? RETURNING *`,[...keys.map(k=>payload[k]),id]);await audit(db,user,'update',table,id);return result(r);
    }
    if(method==='DELETE'){
      if(user.role!=='admin')throw bad(403,'Admin only.');const col=table==='vehicles'?'vehicle_id':'customer_id';const history=await db.one(`SELECT id FROM bookings WHERE ${col}=? LIMIT 1`,[id]);if(history)throw bad(409,'Cannot delete booking history.');
      await db.exec(`DELETE FROM ${table} WHERE id=?`,[id]);await audit(db,user,'delete',table,id);return result({deleted:true});
    }
  }
  if(method==='GET'&&path==='/api/bookings')return result(await db.all('SELECT b.*,v.plate,v.make,v.model,c.name AS customer_name,c.phone AS customer_phone FROM bookings b JOIN vehicles v ON v.id=b.vehicle_id JOIN customers c ON c.id=b.customer_id ORDER BY b.id DESC LIMIT 300'));
  if(method==='GET'&&path==='/api/availability'){
    const vid=posInt(query.vehicle_id),pickup=requireStr(query.pickup_date,'Pickup date'),ret=requireStr(query.return_date,'Return date');
    try{rentalDays(pickup,ret);}catch(e){throw bad(400,e.message);}
    const vehicle=await db.one('SELECT * FROM vehicles WHERE id=?',[vid]);if(!vehicle)throw bad(404,'Vehicle not found.');
    const overlap=await db.one("SELECT id FROM bookings WHERE vehicle_id=? AND status IN ('pending','confirmed','active') AND pickup_date<? AND return_date>? LIMIT 1",[vid,ret,pickup]);return result({available:vehicle.status==='available'&&!overlap,reason:overlap?'Date conflict':vehicle.status!=='available'?'Vehicle in maintenance':null});
  }
  if(method==='POST'&&path==='/api/bookings'){
    const vid=posInt(body.vehicle_id),cid=posInt(body.customer_id),from=requireStr(body.pickup_date,'Pickup date'),to=requireStr(body.return_date,'Return date');
    let days;try{days=rentalDays(from,to);}catch(e){throw bad(400,e.message);}if(from<today())throw bad(400,'Pickup date cannot be in the past.');
    const saved=await db.transaction(async tx=>{
      const vehicle=await ensureAvailable(tx,vid,from,to);const customer=await tx.one('SELECT * FROM customers WHERE id=?',[cid]);if(!customer)throw bad(404,'Customer not found.');
      if(customer.license_expiry && dt(customer.license_expiry)<to)throw bad(409,'Customer license expires before return.');
      const rate=body.use_suggested_price===true?quotePrice(vehicle,from,to,await priceHistory(tx)).recommended_daily_rate:Number(vehicle.daily_rate);
      return insert(tx,'bookings',['vehicle_id','customer_id','pickup_date','return_date','days','daily_rate','total_amount','status'],[vid,cid,from,to,days,rate,round2(days*rate),'pending']);
    });await audit(db,user,'create','bookings',saved.id);return result(saved,201);
  }
  // A single source of truth for the UI's gated rental workflow.
  m=path.match(/^\/api\/bookings\/(\d+)\/workflow$/);
  if(m&&method==='GET'){
    const id=posInt(m[1]);
    const booking=await db.one(`SELECT b.*,v.plate,v.make,v.model,c.name AS customer_name,c.license_expiry
      FROM bookings b JOIN vehicles v ON v.id=b.vehicle_id JOIN customers c ON c.id=b.customer_id WHERE b.id=?`,[id]);
    if(!booking)throw bad(404,'Booking not found.');
    const payments=await db.all('SELECT id,amount,method,created_at FROM payments WHERE booking_id=? ORDER BY id DESC',[id]);
    const inspections=await db.all('SELECT id,phase,reviewer_note,image_ref,created_at FROM inspections WHERE booking_id=? ORDER BY id DESC',[id]);
    const paid=round2(payments.reduce((total,p)=>total+Number(p.amount),0));
    const balance=round2(Math.max(0,Number(booking.total_amount)-paid));
    const pickupInspected=inspections.some(x=>x.phase==='pickup'),returnInspected=inspections.some(x=>x.phase==='return');
    const nextAction=booking.status==='pending'?'confirm':booking.status==='confirmed'?(!pickupInspected?'pickup_inspection':'qr_handover'):
      booking.status==='active'?(!returnInspected?'return_inspection':balance>0.009?'settle_payment':'complete'):booking.status;
    return result({booking,payments,inspections,paid,balance,pickup_inspected:pickupInspected,return_inspected:returnInspected,
      next_action:nextAction,requirements:{pickup_inspection_before_handover:true,return_inspection_before_completion:true,full_payment_before_completion:true}});
  }
  m=path.match(/^\/api\/bookings\/(\d+)\/status$/);
  if(m&&method==='PATCH'){
    const id=posInt(m[1]),allowed={pending:['confirmed','cancelled'],confirmed:['active','cancelled'],active:['completed'],completed:[],cancelled:[]};
    const current=await db.one('SELECT * FROM bookings WHERE id=?',[id]);if(!current)throw bad(404,'Booking not found.');
    const status=body.status;if(!allowed[current.status]?.includes(status))throw bad(409,`Cannot transition ${current.status} to ${status}.`);
    if(status==='active')throw bad(409,'Use QR handover endpoint to activate confirmed bookings.');
    const updated=await db.transaction(async tx=>{
      if(status!=='cancelled')await ensureAvailable(tx,current.vehicle_id,dt(current.pickup_date),dt(current.return_date),id);
      if(status==='completed'){
        const inspection=await tx.one("SELECT id FROM inspections WHERE booking_id=? AND phase='return' ORDER BY id DESC LIMIT 1",[id]);
        if(!inspection)throw bad(409,'Record a return inspection before completing the rental.');
        const paid=await tx.one('SELECT COALESCE(SUM(amount),0) AS paid FROM payments WHERE booking_id=?',[id]);
        if(Number(current.total_amount)-Number(paid.paid)>0.009)throw bad(409,'Settle the outstanding rental balance before completion.');
      }
      return tx.one(`UPDATE bookings SET status=?,returned_at=CASE WHEN ?='completed' THEN ? ELSE returned_at END WHERE id=? RETURNING *`,[status,status,new Date().toISOString(),id]);
    });
    await notifyCustomer(db,current.customer_id,'status',`Booking #${id} is now ${status}.`,`booking:${id}:status:${status}`);await audit(db,user,'status','bookings',id,status);return result(updated);
  }
  m=path.match(/^\/api\/bookings\/(\d+)\/qr$/);
  if(m&&method==='POST'){
    const id=posInt(m[1]),booking=await db.one('SELECT * FROM bookings WHERE id=?',[id]);if(!booking)throw bad(404,'Booking not found.');if(booking.status!=='confirmed')throw bad(409,'Confirm booking before issuing pickup QR.');
    if(!await db.one("SELECT id FROM inspections WHERE booking_id=? AND phase='pickup' LIMIT 1",[id]))throw bad(409,'Record pickup inspection before issuing pickup QR.');
    const code=newToken(),expires=new Date(Date.now()+24*3600000).toISOString();await db.exec('UPDATE bookings SET pickup_code_hash=?,pickup_code_expires_at=? WHERE id=?',[sha256(code),expires,id]);
    await audit(db,user,'generate_qr','bookings',id);return result({booking_id:id,code,qr_payload:`DRIVEDESK:PICKUP:${id}:${code}`,expires_at:expires,note:'Code displayed once. Scan or paste to authorize pickup.'});
  }
  m=path.match(/^\/api\/bookings\/(\d+)\/handover$/);
  if(m&&method==='POST'){
    const id=posInt(m[1]),code=requireStr(body.code,'Handover code',250);
    const booking=await db.one('SELECT * FROM bookings WHERE id=?',[id]);if(!booking)throw bad(404,'Booking not found.');
    if(booking.status!=='confirmed'||!booking.pickup_code_hash||new Date(booking.pickup_code_expires_at)<new Date())throw bad(409,'QR code expired or booking not confirmed.');
    const extracted=code.startsWith('DRIVEDESK:PICKUP:')?code.split(':').slice(3).join(':'):code;
    if(sha256(extracted)!==booking.pickup_code_hash)throw bad(403,'Incorrect handover code.');
    const changed=await db.transaction(async tx=>{
      await ensureAvailable(tx,booking.vehicle_id,dt(booking.pickup_date),dt(booking.return_date),id);
      const inspection=await tx.one("SELECT id FROM inspections WHERE booking_id=? AND phase='pickup' ORDER BY id DESC LIMIT 1",[id]);
      if(!inspection)throw bad(409,'Record a pickup condition inspection before handing over the vehicle.');
      return tx.one("UPDATE bookings SET status='active',pickup_at=?,pickup_code_hash=NULL,pickup_code_expires_at=NULL WHERE id=? AND status='confirmed' RETURNING *",[new Date().toISOString(),id]);
    });
    await notifyCustomer(db,booking.customer_id,'pickup',`Your rental #${id} is active. Enjoy your drive!`,`booking:${id}:pickup`);await audit(db,user,'handover','bookings',id);return result(changed);
  }
  if(method==='GET'&&path==='/api/payments')return result(await db.all('SELECT p.*,b.vehicle_id,b.customer_id FROM payments p JOIN bookings b ON b.id=p.booking_id ORDER BY p.id DESC LIMIT 300'));
  if(method==='POST'&&path==='/api/payments'){
    const id=posInt(body.booking_id),amount=money(body.amount),methodName=requireStr(body.method,'Method',30);
    if(!['cash','card','transfer','other'].includes(methodName))throw bad(400,'Invalid payment method.');
    const row=await db.transaction(async tx=>{
      const booking=await tx.one('SELECT * FROM bookings WHERE id=?',[id]);if(!booking||booking.status==='cancelled')throw bad(409,'Booking invalid or cancelled.');
      const sum=await tx.one('SELECT COALESCE(SUM(amount),0) AS total FROM payments WHERE booking_id=?',[id]);if(Number(sum.total)+amount>Number(booking.total_amount)+0.01)throw bad(409,'Payment exceeds booking total.');
      return insert(tx,'payments',['booking_id','amount','method','note'],[id,amount,methodName,String(body.note||'').slice(0,300)]);
    });const payBooking=await db.one('SELECT customer_id FROM bookings WHERE id=?',[id]);await notifyCustomer(db,payBooking?.customer_id,'payment',`Payment of LKR ${amount.toFixed(2)} recorded for rental #${id}.`,`booking:${id}:staff-payment:${row.id}`);await audit(db,user,'create','payments',row.id);return result(row,201);
  }
  if(method==='GET'&&path==='/api/smart/pricing'){
    const v=await db.one('SELECT * FROM vehicles WHERE id=?',[posInt(query.vehicle_id)]);if(!v)throw bad(404,'Vehicle not found.');
    try{return result(quotePrice(v,query.pickup_date,query.return_date,await priceHistory(db)));}catch(e){throw bad(400,e.message);}
  }
  if(method==='GET'&&path==='/api/smart/recommendations'){
    const days=num(query.days||1,'days',{min:1,max:365});const budget=query.budget?num(query.budget,'budget',{min:1}):Infinity;
    const list=recommendVehicles(await db.all('SELECT * FROM vehicles'),{budget,category:query.category||'',seats:query.seats||1,days});return result({method:'explainable_content_based_ranking',results:list,note:'Suggestions only; availability by date must be checked before booking.'});
  }
  if(method==='GET'&&path==='/api/smart/forecast'){
    const history=await db.all("SELECT pickup_date FROM bookings WHERE status='completed' ORDER BY pickup_date ASC");
    return result(forecastDemand(history.map(x=>({...x,pickup_date:dt(x.pickup_date)})),3));
  }
  if(method==='POST'&&path==='/api/smart/assistant'){
    const message=requireStr(body.message,'Question',300);
    const [vehicles,bookings]=await Promise.all([db.all('SELECT id,plate,make,model,category,daily_rate,status FROM vehicles'),db.all('SELECT id,status FROM bookings')]);
    return result({reply:assistantReply(message,vehicles,bookings),method:'database_grounded_rule_assistant',note:'No external LLM configured. Check availability for exact dates.'});
  }
  if(method==='GET'&&path==='/api/smart/anomalies'){
    const bookings=await db.all('SELECT id,total_amount,days,status FROM bookings ORDER BY id DESC LIMIT 400');
    return result({method:'heuristic_and_statistical',results:bookings.map(b=>anomalyFlags(b,bookings.filter(h=>h.id!==b.id))).filter(x=>x.flags.length).slice(0,50)});
  }
  if(method==='GET'&&path==='/api/locations'){
    const vid=posInt(query.vehicle_id);return result(await db.all('SELECT id,vehicle_id,latitude,longitude,source,consent_confirmed,recorded_at FROM location_events WHERE vehicle_id=? ORDER BY id DESC LIMIT 100',[vid]));
  }
  if(method==='POST'&&path==='/api/locations'){
    const vid=posInt(body.vehicle_id),lat=num(body.latitude,'latitude',{min:-90,max:90}),lng=num(body.longitude,'longitude',{min:-180,max:180}),source=body.source||'staff_manual';
    if(!['tracker','staff_manual','simulated'].includes(source))throw bad(400,'Invalid location source.');
    if(body.consent_confirmed!==true)throw bad(403,'Explicit consent confirmation required for location logging.');
    if(!await db.one('SELECT id FROM vehicles WHERE id=?',[vid]))throw bad(404,'Vehicle not found.');
    const geo=body.geofence_center_lat==null?null:distanceKm(lat,lng,num(body.geofence_center_lat,'geofence_center_lat',{min:-90,max:90}),num(body.geofence_center_lng,'geofence_center_lng',{min:-180,max:180}));
    const saved=await insert(db,'location_events',['vehicle_id','latitude','longitude','source','consent_confirmed'],[vid,lat,lng,source,cfg.driver==='sqlite'?1:true]);
    await audit(db,user,'log_location','vehicles',vid,source);return result({...saved,distance_from_center_km:geo===null?null:round2(geo),outside_geofence:geo===null?null:geo>num(body.geofence_radius_km||5,'geofence_radius_km',{min:0.01,max:10000})},201);
  }
  if(method==='POST'&&path==='/api/inspections'){
    const id=posInt(body.booking_id),phase=body.phase;if(!['pickup','return'].includes(phase))throw bad(400,'Phase must be pickup or return.');
    const booking=await db.one('SELECT id,status FROM bookings WHERE id=?',[id]);
    if(!booking)throw bad(404,'Booking not found.');
    if(phase==='pickup'&&booking.status!=='confirmed')throw bad(409,'Confirm the reservation before pickup inspection.');
    if(phase==='return'&&booking.status!=='active')throw bad(409,'Vehicle return inspection requires an active rental.');
    if(!String(body.reviewer_note||'').trim()&&!Array.isArray(body.findings)&&!body.image_base64)throw bad(400,'Provide an inspection note, finding or image.');
    const image=body.image_base64?imageBytes(body):null;let ref=null;if(image){await mkdir(resolve('uploads'),{recursive:true});ref=`${randomUUID()}.${image.ext}`;await writeFile(resolve('uploads',ref),image.buf,{flag:'wx'});}
    const findings=Array.isArray(body.findings)?body.findings.filter(x=>typeof x==='string').slice(0,20):[];
    const row=await insert(db,'inspections',['booking_id','phase','image_ref','findings_json','reviewer_note'],[id,phase,ref,JSON.stringify(findings),String(body.reviewer_note||'').slice(0,500)]);
    await audit(db,user,'inspect','bookings',id,phase);return result({...row,findings},201);
  }
  if(method==='GET'&&path==='/api/inspections'){
    const bookingId=posInt(query.booking_id);const list=await db.all('SELECT * FROM inspections WHERE booking_id=? ORDER BY id DESC',[bookingId]);return result(list.map(x=>({...x,findings:JSON.parse(x.findings_json)})));
  }
  m=path.match(/^\/api\/inspections\/(\d+)\/photo$/);
  if(method==='GET'&&m){const ins=await db.one('SELECT image_ref FROM inspections WHERE id=?',[posInt(m[1])]);if(!ins?.image_ref)throw bad(404,'Image not found.');
    const image=await readFile(resolve('uploads',ins.image_ref));return {status:200,binary:image,contentType:ins.image_ref.endsWith('.png')?'image/png':ins.image_ref.endsWith('.webp')?'image/webp':'image/jpeg'};
  }
  if(method==='POST'&&path==='/api/smart/ocr/plate'){const ocr=await tesseractOcr(imageBytes(body).buf);return result({engine:'tesseract_local',raw_text:ocr,plate:plateFromOcr(ocr),requires_human_confirmation:true});}
  if(method==='POST'&&path==='/api/smart/ocr/license'){const ocr=await tesseractOcr(imageBytes(body).buf);return result({engine:'tesseract_local',...licenseFields(ocr),requires_human_confirmation:true});}
  if(method==='POST'&&path==='/api/smart/damage')return damageDetect(body);
  if(method==='GET'&&path==='/api/notifications')return result(await db.all('SELECT * FROM notifications ORDER BY id DESC LIMIT 100'));
  if(method==='POST'&&path==='/api/notifications/run'){
    if(user.role!=='admin')throw bad(403,'Admin only.');return result(await triggerAlerts(db));
  }
  m=path.match(/^\/api\/notifications\/(\d+)\/read$/);
  if(m&&method==='PATCH'){await db.exec('UPDATE notifications SET is_read=? WHERE id=?',[cfg.driver==='sqlite'?1:true,posInt(m[1])]);return result({ok:true});}
  if(method==='GET'&&path==='/api/audit'){
    if(user.role!=='admin')throw bad(403,'Admin only.');return result(await db.all('SELECT * FROM audits ORDER BY id DESC LIMIT 100'));
  }
  throw bad(404,'Endpoint not found.');
};}
export {triggerAlerts};
