const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const qml=fs.readFileSync('kwin/contents/ui/main.qml','utf8');
const context={console,Date,Array,JSON,String,Math,Qt:{rect:(x,y,width,height)=>({x,y,width,height})},originals:{},restored:{},managed:{},pendingAssignments:[],remembering:false,movingWindow:null,pendingDrop:null,lastReply:Date.now()};
context.root=context;vm.createContext(context);
vm.runInContext(fs.readFileSync('kwin/contents/code/geometry.js','utf8'),context);context.Geometry={rect:context.rect,copy:context.copy};
for(const name of ['healthy','applicationId','place','remember','sendAssignment','restoreApplications']){
 const start=qml.indexOf('function '+name+'('),brace=qml.indexOf('{',start);let end=brace+1,depth=1;
 for(;depth;end++){if(qml[end]==='{')depth++;if(qml[end]==='}')depth--;}
 vm.runInContext(qml.slice(start,end),context);
}
const output={name:'DP-1'};
context.Workspace={screens:[output],currentDesktop:1,clientArea:()=>({x:-1920,y:0,width:1920,height:1080})};context.KWin={MaximizeArea:1};
const w={internalId:'one',desktopFileName:'org.example.App',normalWindow:true,resizeable:true,fullScreen:false,move:false,frameGeometry:{x:0,y:0,width:300,height:300},setMaximize:()=>{}};
context.trackedWindows=[w];context.rememberCall={call(){}};
context.state={automatic:true,profile_key:'desk',gap:2,profile:{applications:{'org.example.app':{monitor:'edid',zone:1}}},monitors:[{name:'DP-1',identity:'edid'}],zones:{'DP-1':[[0,0,.5,1],[.5,0,.5,1]]}};
context.restoreApplications({});assert.equal(w.frameGeometry.x,-959);assert.equal(w.frameGeometry.width,958);
w.frameGeometry.x=42;context.restoreApplications(context.state);assert.equal(w.frameGeometry.x,42,'do not fight manual repositioning');
context.state.profile_key='mobile';context.state.profile.applications['org.example.app'].zone=0;
context.restoreApplications({profile_key:'desk',automatic:true,gap:2});assert.equal(w.frameGeometry.x,-1919);
context.state.automatic=false;w.frameGeometry.x=45;context.restoreApplications({});assert.equal(w.frameGeometry.x,45,'pause blocks restore');
context.state.automatic=true;context.state.profile.applications['org.example.app'].zone=8;context.restoreApplications({});assert.equal(w.frameGeometry.x,45,'removed zone skipped');
context.place(w,context.state.zones['DP-1'][1],output,null);assert.equal(JSON.parse(context.rememberCall.arguments[2])[0],'org.example.app');assert.equal(context.rememberCall.arguments[3],'1');
console.log('Application restore: startup, profile change, manual move, pause, missing zone, explicit save PASS');

const second={...w,internalId:'two',caption:'Calendar',frameGeometry:{x:0,y:0,width:100,height:100}};
w.caption='Tasks';context.trackedWindows=[w,second];
context.state.profile.applications={};
context.state.profile.applications[context.applicationId(w)]={monitor:'edid',zone:0};
context.state.profile.applications[context.applicationId(second)]={monitor:'edid',zone:1};
context.restoreApplications({});assert.equal(w.frameGeometry.x,-1919);assert.equal(second.frameGeometry.x,-959);
console.log('Separate application subwindows restore into distinct zones PASS');

context.Workspace.currentDesktop={id:'desktop-a'};context.state.desktop_scoped=true;context.state.desktop_id='desktop-a';
w.desktops=[{id:'desktop-a'}];second.desktops=[{id:'desktop-b'}];
w.frameGeometry.x=66;second.frameGeometry.x=77;context.restoreApplications({});
assert.equal(w.frameGeometry.x,-1919);assert.equal(second.frameGeometry.x,77,'background desktop must stay untouched');
context.state.desktop_id='desktop-b';assert.equal(context.healthy(),false,'stale desktop reply blocks placement');
context.Workspace.currentDesktop={id:'desktop-b'};context.restoreApplications({});assert.equal(second.frameGeometry.x,-959);
console.log('Virtual desktops: background windows untouched and stale desktop blocked PASS');
// Default operation must never invoke saved placement from polling/open events.
assert.equal((qml.match(/root\.restoreApplications\(/g)||[]).length,1);
assert.match(qml,/onActivated:root\.restoreApplications\(\{\}\)/);
for(const name of ['updateOverlay','beginMove','finishMove']) {
 const start=qml.indexOf('function '+name+'('),brace=qml.indexOf('{',start);let end=brace+1,depth=1;
 for(;depth;end++){if(qml[end]==='{')depth++;if(qml[end]==='}')depth--;}
 vm.runInContext(qml.slice(start,end),context);
}
for(const name of ['same','inside','hit','helperHit'])context.Geometry[name]=context[name];
context.activeZones=[];context.highlighted=-1;context.overlay={visible:false};context.refresh=()=>{};context.dropCheck={call(){}};
context.state.desktop_scoped=false;context.state.modifier_ready=true;context.state.free_move=false;
context.state.drag_overlay=true;context.state.placement_helper=false;
context.Workspace.cursorPos={x:-1500,y:400};output.geometry={x:-1920,y:0,width:1920,height:1080};
w.move=true;context.beginMove(w);assert.equal(context.overlay.visible,false);
w.frameGeometry.x+=20;context.finishMove(w);assert.equal(context.pendingDrop,null,'ordinary drag never snaps');
context.beginMove(w);context.state.free_move=true;context.updateOverlay();assert.equal(context.overlay.visible,true,'chord pressed mid-drag enables preview');
context.state.free_move=false;context.updateOverlay();assert.equal(context.overlay.visible,false,'releasing chord hides preview');
w.frameGeometry.x+=20;context.finishMove(w);assert.equal(context.pendingDrop,null,'released chord cancels snap');
context.state.free_move=true;context.beginMove(w);w.frameGeometry.x+=20;context.finishMove(w);assert.ok(context.pendingDrop,'modified drop requests placement');
context.pendingDrop=null;context.state.modifier_ready=false;context.beginMove(w);assert.equal(context.overlay.visible,false,'missing modifier listener fails closed');
console.log('Opt-in dragging: normal drag, chord activation/release, modified drop, unavailable listener PASS');
