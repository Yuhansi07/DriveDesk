import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {join} from 'node:path';
import {connectDb} from './db.js';
import {cfg} from './config.js';
import {seed} from './seed.js';
import {makeRoutes,triggerAlerts} from './routes.js';
const db=await connectDb();await seed(db);const dispatch=makeRoutes(db);
const json=(res,status,data,origin)=>{res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Access-Control-Allow-Origin':origin||'null','Vary':'Origin'});res.end(JSON.stringify(data));};
const server=createServer(async(req,res)=>{
  const origin=req.headers.origin,cors=origin&&cfg.cors.includes(origin)?origin:null;
  if(origin&&!cors){json(res,403,{error:'Origin not allowed.'});return;}
  if(req.method==='OPTIONS'){res.writeHead(204,{'Access-Control-Allow-Origin':cors||'null','Access-Control-Allow-Methods':'GET,POST,PUT,PATCH,DELETE,OPTIONS','Access-Control-Allow-Headers':'Content-Type,Authorization','Vary':'Origin'});res.end();return;}
  try{
    const staticFiles={'/':'index.html','/demo':'index.html','/demo/':'index.html','/demo/styles.css':'styles.css','/demo/app.js':'app.js','/demo/workflow.js':'workflow.js','/demo/workflow.css':'workflow.css','/demo/modern.css':'modern.css'};
    if(req.method==='GET' && Object.hasOwn(staticFiles,new URL(req.url,'http://localhost').pathname)){
      const pathname=new URL(req.url,'http://localhost').pathname,file=staticFiles[pathname];
      const bytes=await readFile(join('demo',file));
      const mime=file.endsWith('.html')?'text/html; charset=utf-8':file.endsWith('.css')?'text/css; charset=utf-8':'application/javascript; charset=utf-8';
      res.writeHead(200,{'Content-Type':mime,'X-Content-Type-Options':'nosniff','Cache-Control':'no-cache'});res.end(bytes);return;
    }
    let content='';for await (const c of req){content+=c.toString();if(content.length>1700000)throw Object.assign(new Error('Body too large.'),{status:413});}
    let body={};if(content){try{body=JSON.parse(content);}catch{throw Object.assign(new Error('Invalid JSON.'),{status:400});}}
    const url=new URL(req.url,'http://localhost');const query=Object.fromEntries(url.searchParams);
    const r=await dispatch({method:req.method,path:url.pathname,body,query,headers:req.headers,ip:req.socket.remoteAddress});
    if(r.binary){res.writeHead(r.status,{'Content-Type':r.contentType,'Cache-Control':'private, no-store','Access-Control-Allow-Origin':cors||'null','X-Content-Type-Options':'nosniff'});res.end(r.binary);}
    else json(res,r.status,r.data,cors);
  }catch(e){const status=e.status||((e.code==='SQLITE_CONSTRAINT_UNIQUE'||e.code==='23505'||e.code==='23P01')?409:500);if(status===500)console.error(e);json(res,status,{error:status===500?'Internal error.':status===409&&!e.status?'Unique value or booking date conflict.':e.message},cors);}
});
const timer=setInterval(()=>triggerAlerts(db).catch(e=>console.error('Alert job:',e.message)),6*3600000);timer.unref();
server.listen(cfg.port,cfg.host,()=>console.log(`DriveDesk Pro API (native HTTP, ${cfg.driver}) on http://${cfg.host}:${server.address().port}`));
for(const s of ['SIGINT','SIGTERM'])process.on(s,()=>{server.close();db.close().finally(()=>process.exit(0));});
