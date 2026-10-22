import { randomBytes,scryptSync,timingSafeEqual,createHash } from 'node:crypto';
export const sha256=s=>createHash('sha256').update(s).digest('hex');
export function hashPassword(p){if(typeof p!=='string'||p.length<8)throw Error('Password must be at least 8 characters.');const salt=randomBytes(16).toString('hex');return `scrypt:${salt}:${scryptSync(p,salt,64).toString('hex')}`;}
export function verifyPassword(p,encoded){try{const [scheme,salt,hash]=encoded.split(':');if(scheme!=='scrypt')return false;const a=scryptSync(p,salt,64),b=Buffer.from(hash,'hex');return b.length===a.length&&timingSafeEqual(a,b);}catch{return false;}}
export const newToken=()=>randomBytes(32).toString('base64url');
export const validEmail = s=>typeof s==='string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s)&&s.length<=180;
