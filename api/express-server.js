// Optional Express 5 transport. The same route engine, validations, DB, and tests are reused.
import express from 'express';
import {resolve} from 'node:path';
import {connectDb} from './db.js';
import {cfg} from './config.js';
import {seed} from './seed.js';
import {makeRoutes,triggerAlerts} from './routes.js';
const db=await connectDb();await seed(db);const dispatch=makeRoutes(db);
const app=express();app.disable('x-powered-by');app.use(express.json({limit:'1.5mb'}));
app.use('/demo',express.static(resolve('demo')));app.get('/',(_,res)=>res.redirect('/demo/'));
app.use((req,res,next)=>{const origin=req.headers.origin;if(origin&&!cfg.cors.includes(origin))return res.status(403).json({error:'Origin not allowed.'});
  res.set('Vary','Origin');res.set('Access-Control-Allow-Origin',origin||'null');res.set('Cache-Control','no-store');
  res.set('Access-Control-Allow-Headers','Content-Type,Authorization');res.set('Access-Control-Allow-Methods','GET,POST,PUT,PATCH,DELETE,OPTIONS');
  if(req.method==='OPTIONS')return res.status(204).end();next();});
app.all('/api/*path',async(req,res)=>{
 try{const r=await dispatch({method:req.method,path:req.path,body:req.body||{},query:req.query,headers:req.headers,ip:req.ip});
   if(r.binary){res.type(r.contentType);return res.status(r.status).send(r.binary);}return res.status(r.status).json(r.data);
 }catch(e){const status=e.status||(['23505','23P01','SQLITE_CONSTRAINT_UNIQUE'].includes(e.code)?409:500);if(status===500)console.error(e);return res.status(status).json({error:status===500?'Internal error.':status===409&&!e.status?'Unique value or booking date conflict.':e.message});}
});
const timer=setInterval(()=>triggerAlerts(db).catch(console.error),6*3600000);timer.unref();
const server=app.listen(cfg.port,cfg.host,()=>console.log(`DriveDesk Pro Express API (${cfg.driver}) http://${cfg.host}:${cfg.port}`));
for(const signal of ['SIGINT','SIGTERM'])process.on(signal,()=>{server.close();db.close().finally(()=>process.exit(0));});
