import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(p,'utf8');
test('Flutter tool hub shows one compact group and preserves every destination',()=>{
 const s=read('flutter_app/lib/screens.dart');
 assert.match(s,/class _SmartPageState/);
 assert.match(s,/ChoiceChip/);
 assert.match(s,/activeGroup/);
 assert.match(s,/toolCard/);
 for(const name of ['PricingTool','RecommendationTool','AnomaliesTool','OcrTool','DamageTool','GeoTool','MaintenanceTool','DemandTool','AssistantTool']) assert.ok(s.includes(name+'(api:widget.api)'));
 assert.doesNotMatch(s,/class SmartPage extends StatelessWidget/);
});
test('browser backup retains existing handlers and hides unrelated tool groups',()=>{
 const s=read('demo/app.js');
 assert.match(s,/data-tool-group/);
 assert.match(s,/data-tool-panel/);
 assert.match(s,/\.dataset\.toolPanel!==group/);
 for(const id of ['get-price','get-recs','get-anomalies','get-demand','ask','do-scan']) assert.ok(s.includes('id="'+id+'"'));
});
