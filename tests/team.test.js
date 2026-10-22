import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {once} from 'node:events';

test('team accounts: create, roles, login, revoke sessions, reset passwords, audit',async t=>{
 const dir=await mkdtemp(join(tmpdir(),'dd-team-'));
 const child=spawn(process.execPath,['api/server.js'],{cwd:process.cwd(),env:{...process.env,PORT:'0',DB_PATH:join(dir,'team.db'),DB_DRIVER:'sqlite',SEED_DEMO:'1'},stdio:['ignore','pipe','pipe']});
 t.after(async()=>{child.kill('SIGTERM');await once(child,'exit').catch(()=>{});await rm(dir,{recursive:true,force:true});});
 let out='',err='';child.stdout.on('data',b=>out+=b);child.stderr.on('data',b=>err+=b);
 for(let i=0;i<120&&!out.includes('http://');i++)await new Promise(r=>setTimeout(r,50));
 const base=out.match(/http:\/\/127\.0\.0\.1:\d+/)?.[0];assert.ok(base,`startup: ${out} ${err}`);
 async function call(method,path,body,token=''){
  const r=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{'Authorization':'Bearer '+token}:{})},...(body?{body:JSON.stringify(body)}:{})});
  return {status:r.status,body:await r.json()};
 }
 const admin=(await call('POST','/api/auth/login',{email:'admin@drivedesk.local',password:'Demo@12345'}));assert.equal(admin.status,200);
 const a=admin.body.token;
 const initial=await call('GET','/api/users',null,a);assert.equal(initial.status,200);
 assert.ok(initial.body.length>=2);
 assert.ok(initial.body.every(u=>!('password_hash' in u)));
 const weak=await call('POST','/api/users',{name:'A',email:'hello@example.com',password:'short',role:'staff'},a);assert.equal(weak.status,400);
 const created=await call('POST','/api/users',{name:'Rental Clerk',email:'clerk@example.com',password:'ClerkPass123',role:'staff'},a);assert.equal(created.status,201,JSON.stringify(created));
 const id=created.body.id;
 let clerk=await call('POST','/api/auth/login',{email:'clerk@example.com',password:'ClerkPass123'});assert.equal(clerk.status,200);
 const tkn=clerk.body.token;
 assert.equal((await call('GET','/api/users',null,tkn)).status,403);
 assert.equal((await call('GET','/api/dashboard',null,tkn)).status,200);
 assert.equal((await call('PATCH',`/api/users/${id}`,{role:'admin'},tkn)).status,403);
 assert.equal((await call('PATCH',`/api/users/${admin.body.user.id}`,{is_active:false},a)).status,409);
 const paused=await call('PATCH',`/api/users/${id}`,{is_active:false},a);assert.equal(paused.status,200);
 assert.equal((await call('GET','/api/dashboard',null,tkn)).status,401);
 assert.equal((await call('POST','/api/auth/login',{email:'clerk@example.com',password:'ClerkPass123'})).status,401);
 assert.equal((await call('PATCH',`/api/users/${id}`,{is_active:true},a)).status,200);
 clerk=await call('POST','/api/auth/login',{email:'clerk@example.com',password:'ClerkPass123'});assert.equal(clerk.status,200);
 assert.equal((await call('PATCH',`/api/users/${id}/password`,{password:'abc'},a)).status,400);
 assert.equal((await call('PATCH',`/api/users/${id}/password`,{password:'SecureNewPass123'},a)).status,200);
 assert.equal((await call('GET','/api/dashboard',null,clerk.body.token)).status,401);
 assert.equal((await call('POST','/api/auth/login',{email:'clerk@example.com',password:'ClerkPass123'})).status,401);
 clerk=await call('POST','/api/auth/login',{email:'clerk@example.com',password:'SecureNewPass123'});assert.equal(clerk.status,200);
 assert.equal((await call('POST','/api/auth/change-password',{current_password:'wrong',new_password:'ClerkThirdPass1'},clerk.body.token)).status,403);
 assert.equal((await call('POST','/api/auth/change-password',{current_password:'SecureNewPass123',new_password:'ClerkThirdPass1'},clerk.body.token)).status,200);
 assert.equal((await call('GET','/api/dashboard',null,clerk.body.token)).status,200);
 const audits=await call('GET','/api/audit',null,a);assert.equal(audits.status,200);
 assert.ok(audits.body.some(x=>x.action==='reset_password'));
});
