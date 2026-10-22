// Server-side role policy. UI visibility is never a security boundary.
export const ROLE_DETAILS = Object.freeze({
  admin: {label:'Administrator',description:'Manage the entire system and team access.'},
  manager: {label:'Operations Manager',description:'Supervise rentals, fleet and reports. No account administration.'},
  rental_agent: {label:'Rental Agent',description:'Register customers, create bookings and complete handovers.'},
  fleet_officer: {label:'Fleet Officer',description:'Maintain vehicles, inspections and authorized locations.'},
  finance_officer: {label:'Finance Officer',description:'Review bookings, record payments and view business forecasts.'},
  driver: {label:'Driver',description:'View only personally assigned trips.'},
  customer: {label:'Customer',description:'Browse vehicles, request/cancel rentals, manage own profile, view statements and alerts.'},
});
export const roleNames=Object.keys(ROLE_DETAILS);
export const effectiveRole=u=>u.access_role|| (u.role==='admin'?'admin':'rental_agent');
const allow=(method,path,patterns)=>patterns.some(([verb,re])=>(verb===method||verb==='*')&&re.test(path));
const read=(...expressions)=>expressions.map(re=>['GET',re]);
const write=(method,...expressions)=>expressions.map(re=>[method,re]);
const baseRead=read(/^\/api\/health$/, /^\/api\/features$/);
const common=[...baseRead,...write('GET',/^\/api\/auth\/me$/),...write('POST',/^\/api\/auth\/(?:logout|change-password)$/)];
const dashboard=read(/^\/api\/dashboard$/);
const fleetRead=read(/^\/api\/vehicles$/, /^\/api\/availability$/, /^\/api\/smart\/(?:pricing|recommendations)$/);
const bookingRead=read(/^\/api\/drivers$/,/^\/api\/bookings$/, /^\/api\/bookings\/\d+\/workflow$/);
const customerRead=read(/^\/api\/customers$/);
const bookingWrites=[...write('PATCH',/^\/api\/bookings\/\d+\/driver$/),...write('POST',/^\/api\/bookings$/,/^\/api\/bookings\/\d+\/(?:qr|handover)$/,/^\/api\/inspections$/),...write('PATCH',/^\/api\/bookings\/\d+\/status$/)];
const reviewRead=read(/^\/api\/smart\/(?:forecast|anomalies)$/);
const alertsRead=read(/^\/api\/notifications$/);
const paymentsRead=read(/^\/api\/payments$/);
const inspectionsRead=read(/^\/api\/inspections$/, /^\/api\/inspections\/\d+\/photo$/);
const driverEndpoints=[...read(/^\/api\/driver\/jobs$/),...write('POST',/^\/api\/driver\/jobs\/\d+\/inspection$/)];
const portalEndpoints=[
 ...read(/^\/api\/portal\/(?:me|vehicles|bookings|notifications|config)$/),
 ...read(/^\/api\/portal\/bookings\/\d+\/(?:invoice|location)$/),
 ...write('PATCH',/^\/api\/portal\/(?:me|notifications\/\d+\/read)$/),
 ...write('POST',/^\/api\/portal\/bookings$/,/^\/api\/portal\/bookings\/\d+\/(?:cancel|demo-pay)$/)
];
const policies={
  manager:[...dashboard,...fleetRead,...customerRead,...bookingRead,...bookingWrites,...reviewRead,...alertsRead,...paymentsRead,...inspectionsRead,
    ...write('POST',/^\/api\/(?:vehicles|customers|payments|locations|smart\/assistant|smart\/ocr\/(?:plate|license)|smart\/damage)$/),
    ...write('PUT',/^\/api\/(?:vehicles|customers)\/\d+$/),
    ...write('PATCH',/^\/api\/notifications\/\d+\/read$/),
    ...read(/^\/api\/locations$/)],
  rental_agent:[...dashboard,...fleetRead,...customerRead,...bookingRead,...bookingWrites,...alertsRead,...paymentsRead,...inspectionsRead,
    ...write('POST',/^\/api\/(?:customers|payments|smart\/ocr\/license|smart\/assistant)$/),
    ...write('PUT',/^\/api\/customers\/\d+$/),
    ...write('PATCH',/^\/api\/notifications\/\d+\/read$/)],
  fleet_officer:[...dashboard,...fleetRead,...bookingRead,...inspectionsRead,...alertsRead,...read(/^\/api\/locations$/),
    ...write('POST',/^\/api\/(?:vehicles|inspections|locations|smart\/ocr\/plate|smart\/damage)$/),
    ...write('PUT',/^\/api\/vehicles\/\d+$/),
    ...write('PATCH',/^\/api\/notifications\/\d+\/read$/)],
  finance_officer:[...dashboard,...fleetRead,...bookingRead,...paymentsRead,...reviewRead,...alertsRead,...write('POST',/^\/api\/payments$/),
    ...write('PATCH',/^\/api\/notifications\/\d+\/read$/)],
  driver:driverEndpoints,
  customer:portalEndpoints,
};
export function permitted(role,method,path){
  if(role==='admin')return true;
  return allow(method,path,common)||allow(method,path,policies[role]||[]);
}
