import { hashPassword } from './security.js';
import { cfg } from './config.js';
const isoOffset=d=>{const x=new Date();x.setUTCDate(x.getUTCDate()+d);return x.toISOString().slice(0,10);};
export async function seed(db){
  if(!cfg.seed)return;
  const existing=await db.one('SELECT COUNT(*) AS n FROM users');
  if(Number(existing.n)!==0){await seedAccounts(db);return;}
  await db.transaction(async tx=>{
    await tx.exec('INSERT INTO users(name,email,password_hash,role) VALUES (?,?,?,?)', ['Demo Admin','admin@drivedesk.local',hashPassword('Demo@12345'),'admin']);
    await tx.exec("UPDATE users SET access_role='admin' WHERE email='admin@drivedesk.local'");
    await tx.exec('INSERT INTO users(name,email,password_hash,role) VALUES (?,?,?,?)', ['Rental Staff','staff@drivedesk.local',hashPassword('Staff@12345'),'staff']);
    const vehicles=[['CAB-4125','Toyota','Aqua','Hybrid',2018,8500,5,36500,42000,isoOffset(90),'available'],['CBA-9021','Honda','Vezel','SUV',2021,14500,5,48000,52000,isoOffset(29),'available'],['WP-8921','Suzuki','Wagon R','Compact',2020,7000,4,72000,75000,isoOffset(10),'available'],['CAZ-1148','Toyota','Axio','Sedan',2019,10500,5,30000,35000,isoOffset(180),'available'],['CAD-7810','Nissan','X-Trail','SUV',2022,18500,7,44000,46000,isoOffset(12),'available'],['CAA-3502','Honda','Fit','Hatchback',2017,8000,5,99000,98000,isoOffset(-2),'maintenance']];
    for(const v of vehicles)await tx.exec('INSERT INTO vehicles(plate,make,model,category,year,daily_rate,seats,mileage_km,service_due_km,insurance_expiry,status) VALUES (?,?,?,?,?,?,?,?,?,?,?)',v);
    const customers=[['Kasun Perera','0771234567','kasun@example.com','B1234567'],['Nethmi Silva','0715557788','nethmi@example.com','B2214563'],['Sahan Fernando','0769981245','sahan@example.com','B3416590'],['Ayesha Jayasinghe','0751122456','ayesha@example.com','B0098123']];
    for(const c of customers)await tx.exec('INSERT INTO customers(name,phone,email,license_no) VALUES (?,?,?,?)',c);
    for(let i=0;i<22;i++){
      const vehicleId=i%5+1,customerId=i%4+1;
      const from=isoOffset(-110+i*4),to=isoOffset(-108+i*4);
      if(Date.parse(to)>Date.now()-86400000)break;
      const base=vehicles[vehicleId-1][5],rate=Math.round(base*(0.88+(i%7)*0.04));
      await tx.exec('INSERT INTO bookings(vehicle_id,customer_id,pickup_date,return_date,days,daily_rate,total_amount,status) VALUES (?,?,?,?,?,?,?,?)',[vehicleId,customerId,from,to,2,rate,rate*2,'completed']);
    }
    await tx.exec('INSERT INTO bookings(vehicle_id,customer_id,pickup_date,return_date,days,daily_rate,total_amount,status) VALUES (?,?,?,?,?,?,?,?)',[2,2,isoOffset(1),isoOffset(4),3,14500,43500,'confirmed']);
    await tx.exec('INSERT INTO bookings(vehicle_id,customer_id,pickup_date,return_date,days,daily_rate,total_amount,status) VALUES (?,?,?,?,?,?,?,?)',[3,3,isoOffset(5),isoOffset(9),4,7000,28000,'pending']);
  });
  await seedAccounts(db);
}

async function seedAccounts(db){
 // Demo accounts must NEVER be linked to an actual customer's private history.
 let demoCustomer=await db.one('SELECT id FROM customers WHERE email=?',['demo-portal@drivedesk.local']);
 if(!demoCustomer){
   demoCustomer=await db.one('INSERT INTO customers(name,phone,email,license_no,license_expiry) VALUES (?,?,?,?,?) RETURNING id',
     ['Demo Portal Customer','0700000000','demo-portal@drivedesk.local','DEMO-LIC-0001',isoOffset(365)]);
 }
 const prior=await db.one('SELECT id FROM bookings WHERE customer_id=? LIMIT 1',[demoCustomer.id]);
 if(!prior){
   const vehicle=await db.one("SELECT id,daily_rate FROM vehicles WHERE status='available' ORDER BY id ASC LIMIT 1");
   if(vehicle)await db.exec("INSERT INTO bookings(vehicle_id,customer_id,pickup_date,return_date,days,daily_rate,total_amount,status) VALUES (?,?,?,?,?,?,?,'pending')",
     [vehicle.id,demoCustomer.id,isoOffset(14),isoOffset(16),2,Number(vehicle.daily_rate),Number(vehicle.daily_rate)*2]);
 }
 const demo=[
 ['Demo Manager','manager@drivedesk.local','Manager@12345','manager',null],
 ['Booking Agent','booking@drivedesk.local','Booking@12345','rental_agent',null],
 ['Fleet Officer','fleet@drivedesk.local','Fleet@12345','fleet_officer',null],
 ['Finance Officer','finance@drivedesk.local','Finance@12345','finance_officer',null],
 ['Demo Driver','driver@drivedesk.local','Driver@12345','driver',null],
 ['Demo Customer','customer@drivedesk.local','Customer@12345','customer',demoCustomer.id],
 ];
 for(const [name,email,password,role,customerId] of demo){
   const existing=await db.one('SELECT id FROM users WHERE email=?',[email]);
   if(!existing)await db.exec('INSERT INTO users(name,email,password_hash,role,access_role,customer_id) VALUES (?,?,?,?,?,?)',[name,email,hashPassword(password),'staff',role,customerId]);
 }
 const driver=await db.one('SELECT id FROM users WHERE email=?',['driver@drivedesk.local']);
 await db.exec("UPDATE users SET access_role='admin' WHERE role='admin' AND access_role<>'admin'");
 if(driver){await db.exec("UPDATE bookings SET assigned_driver_id=? WHERE id=(SELECT id FROM bookings WHERE status='confirmed' ORDER BY id DESC LIMIT 1) AND assigned_driver_id IS NULL",[driver.id]);}
}

