import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(p,'utf8');
test('contextual help and success feedback are built into Flutter workflows',()=>{
 const journey=read('flutter_app/lib/experience.dart');
 const flow=read('flutter_app/lib/rental_flow.dart');
 const screens=read('flutter_app/lib/screens.dart');
 const main=read('flutter_app/lib/main.dart');
 assert.match(journey,/SnackBarBehavior.floating/);
 assert.match(flow,/Vehicle is available/);
 assert.match(flow,/Rental completed/);
 assert.match(flow,/ContextualTip/);
 assert.match(screens,/Review fleet health/);
 assert.match(screens,/Open license scanner/);
 assert.match(main,/More tools/);
});
test('browser fallback gives actionable notifications and contextual shortcuts',()=>{
 const app=read('demo/app.js');
 assert.match(app,/data-quick-go/);
 assert.match(app,/toast-icon/);
 assert.match(app,/More tools/);
 assert.doesNotMatch(app,/const sections=.*'Smart lab'/);
});
