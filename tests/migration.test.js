import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {once} from 'node:events';

test('existing v2.5 database upgrades user columns without losing customer records',async t=>{
 const dir=await mkdtemp(join(tmpdir(),'dd-upgrade-'));const file=join(dir,'legacy.db');
 t.after(async()=>rm(dir,{recursive:true,force:true}));
 const db=new DatabaseSync(file);
 db.exec("CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,email TEXT UNIQUE NOT NULL,password_hash TEXT NOT NULL,role TEXT NOT NULL CHECK(role IN ('admin','staff')),created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);");
 db.exec("CREATE TABLE customers (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,phone TEXT NOT NULL,email TEXT,license_no TEXT NOT NULL,license_expiry TEXT,created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);");
 db.exec("INSERT INTO customers(name,phone,license_no) VALUES ('Legacy Client','0771111111','B00000')");db.close();
 const child=spawn(process.execPath,['api/server.js'],{cwd:process.cwd(),env:{...process.env,PORT:'0',DB_PATH:file,DB_DRIVER:'sqlite',SEED_DEMO:'1'},stdio:['ignore','pipe','pipe']});
 let out='',err='';child.stdout.on('data',x=>out+=x);child.stderr.on('data',x=>err+=x);
 for(let i=0;i<120&&!out.includes('http://');i++)await new Promise(r=>setTimeout(r,50));
 assert.match(out,/http:\/\//,`Failed migration: ${err}`);
 child.kill('SIGTERM');await once(child,'exit');
 const verify=new DatabaseSync(file);
 const fields=verify.prepare('PRAGMA table_info(users)').all().map(x=>x.name);
 assert.ok(fields.includes('is_active')&&fields.includes('last_login_at'));
 assert.equal(verify.prepare("SELECT COUNT(*) AS n FROM customers WHERE name='Legacy Client'").get().n,1);
 verify.close();
});
