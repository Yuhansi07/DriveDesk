import { test } from 'node:test';
import assert from 'node:assert/strict';
import {rentalDays,fitPricingModel,quotePrice,recommendVehicles,anomalyFlags,distanceKm,plateFromOcr,licenseFields} from '../api/smart.js';
test('dates use half-open date ranges and validate invalid dates',()=>{assert.equal(rentalDays('2026-11-01','2026-11-05'),4);assert.throws(()=>rentalDays('2026-02-30','2026-03-01'));assert.throws(()=>rentalDays('2026-10-05','2026-10-05'));});
test('linear regression fits small historical dataset',()=>{const hist=Array.from({length:12},(_,i)=>({pickup_date:`2026-0${i%8+1}-${i%2?'07':'06'}`,daily_rate:9000+i*100,base_rate:10000,demand_index:(i%5)/4}));const m=fitPricingModel(hist);assert.ok(m);assert.equal(m.samples,12);assert.ok(m.coefficients.every(Number.isFinite));});
test('rule fallback transparently labels low data',()=>{const r=quotePrice({id:1,daily_rate:12000,category:'SUV'},'2026-11-07','2026-11-10',[]);assert.equal(r.method,'transparent_rule_fallback');assert.equal(r.days,3);assert.ok(r.estimated_total>0);});
test('vehicle recommendation respects capacity',()=>{const r=recommendVehicles([{id:1,status:'available',daily_rate:8000,category:'Mini',seats:4,plate:'AAA-1234',make:'A',model:'B'},{id:2,status:'available',daily_rate:9500,category:'SUV',seats:7,plate:'BBB-2345',make:'C',model:'D'}],{seats:7,budget:30000,days:2});assert.equal(r[0].vehicle_id,2);});
test('anomaly thresholds and plate parser',()=>{assert.equal(anomalyFlags({id:1,total_amount:600000,days:40},[]).level,'high');assert.equal(plateFromOcr('Plate number: CAB - 4125'), 'CAB-4125');assert.equal(licenseFields('B1234567').license_no,'B1234567');});
test('haversine distance',()=>{assert.ok(distanceKm(6.9,79.85,6.91,79.85)>1);});
test('demand forecasting labels simple trend and reports observed historical months',async()=>{
 const {forecastDemand}=await import('../api/smart.js');
 const history=['2026-01-01','2026-02-02','2026-03-04','2026-04-06','2026-04-16'].map(pickup_date=>({pickup_date}));
 const out=forecastDemand(history,3);assert.equal(out.method,'least_squares_linear_trend');assert.equal(out.forecast.length,3);assert.equal(out.history.length,4);
});
test('fleet assistant clearly uses database and does not invent availability',async()=>{
 const {assistantReply}=await import('../api/smart.js');
 const reply=assistantReply('Show SUVs',[{plate:'CAB-1234',make:'Toyota',model:'RAV4',category:'SUV',status:'available',daily_rate:18000}],[]);
 assert.match(reply,/CAB-1234/);assert.match(reply,/Availability Check/);
});
