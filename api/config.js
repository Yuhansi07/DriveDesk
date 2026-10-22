import { readFileSync,existsSync } from 'node:fs';
if (existsSync('.env')) for(const line of readFileSync('.env','utf8').split(/\r?\n/)) {
  const match=line.match(/^([A-Z_][A-Z_0-9]*)=(.*)$/);
  if(match && process.env[match[1]]===undefined) process.env[match[1]]=match[2].replace(/^("|')|("|')$/g,'');
}
export const cfg = {
  port: Number(process.env.PORT||3000), host:process.env.HOST||'127.0.0.1',
  driver:process.env.DB_DRIVER||'sqlite', path:process.env.DB_PATH||'./data/drivedesk-pro.db',
  databaseUrl:process.env.DATABASE_URL||'', seed:process.env.SEED_DEMO!=='0'&&process.env.NODE_ENV!=='production',
  cors:(process.env.CORS_ORIGIN||'http://localhost:8080,http://127.0.0.1:8080,http://localhost:3000,http://127.0.0.1:3000').split(','),
  ttlHours:Number(process.env.SESSION_TTL_HOURS||12), tesseract:process.env.ENABLE_TESSERACT==='1',
  damageUrl:process.env.AI_DAMAGE_URL||'http://127.0.0.1:8001', demoPayments:process.env.ENABLE_DEMO_PAYMENTS==='1'
};
