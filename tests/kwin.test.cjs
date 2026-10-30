const vm=require('node:vm'),fs=require('node:fs'),assert=require('node:assert/strict');
const g={};vm.createContext(g);vm.runInContext(fs.readFileSync('kwin/contents/code/geometry.js','utf8'),g);
const r=g.rect([.5,0,.5,1],{x:-1920,y:100,width:1920,height:1080},8);
assert.equal(r.x,-956);assert.equal(r.width,952);assert.equal(r.y,104);
assert.equal(g.hit([[0,0,1,1],[.25,.25,.5,.5]],.5,.5),1);
assert.equal(g.hit([[0,0,.25,1]],.5,.5),-1);
assert.equal(g.hit([[0,0,.5,1],[.5,0,.5,1]],.5,.5),1);
assert.equal(g.same({x:1,y:2,width:3,height:4},{x:1,y:2,width:3,height:4}),true);
const c=g.clamp({x:-2000,y:50,width:3000,height:2000},{x:0,y:0,width:1920,height:1080});
assert.equal(c.x,0);assert.equal(c.y,0);assert.equal(c.width,1920);
console.log('Geometry: negative origins, gaps, overlap priority, boundaries, cancellation, restore PASS');
const area={x:-1920,y:24,width:1920,height:1056},box=g.helperBox(area);
const zs=[[0,0,.5,1],[.5,0,.5,1]];
assert.equal(g.helperHit(zs,box.x+20,box.y+50,area),0);
assert.equal(g.helperHit(zs,box.x+box.width-20,box.y+50,area),1);
assert.equal(g.helperHit(zs,box.x+20,box.y+10,area),-1);
assert.equal(g.helperHit(zs,box.x-1,box.y+50,area),-1);
assert.equal(g.helperHit([[0,0,.25,1]],box.x+box.width/2,box.y+50,area),-1);
console.log('Placement helper: monitor origin, zones, header and empty-area hit tests PASS');

for(const gap of [0,1,2,3,20]) {
 const a={x:-1365,y:0,width:1365,height:769};
 const left=g.rect([0,0,.5,1],a,gap),right=g.rect([.5,0,.5,1],a,gap);
 assert.equal(right.x-left.x-left.width,gap);
}
console.log('Exact global gaps including odd widths and negative origins PASS');
