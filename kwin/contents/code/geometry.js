// Pure geometry shared by the overlay and keyboard placement.
function rect(zone, area, gap) {
    // Round shared boundaries first; split the total gap across neighbours.
    var left=Math.round(area.x+zone[0]*area.width)+Math.floor(gap/2);
    var top=Math.round(area.y+zone[1]*area.height)+Math.floor(gap/2);
    var right=Math.round(area.x+(zone[0]+zone[2])*area.width)-Math.ceil(gap/2);
    var bottom=Math.round(area.y+(zone[1]+zone[3])*area.height)-Math.ceil(gap/2);
    return {x:left,y:top,width:Math.max(1,right-left),height:Math.max(1,bottom-top)};
}
function hit(zones, x, y) {
    // Last drawn zone wins when custom zones overlap.
    for (var i=zones.length-1;i>=0;i--) {
        var z=zones[i];
        if(x>=z[0]&&y>=z[1]&&x<z[0]+z[2]&&y<z[1]+z[3]) return i;
    }
    return -1;
}
function same(a,b) { return Math.abs(a.x-b.x)<1&&Math.abs(a.y-b.y)<1&&Math.abs(a.width-b.width)<1&&Math.abs(a.height-b.height)<1; }
function copy(g) {return {x:g.x,y:g.y,width:g.width,height:g.height};}
function clamp(g,a) {
    var w=Math.min(g.width,a.width),h=Math.min(g.height,a.height);
    return {x:Math.max(a.x,Math.min(g.x,a.x+a.width-w)),y:Math.max(a.y,Math.min(g.y,a.y+a.height-h)),width:w,height:h};
}
function helperBox(area) {
    var w=Math.min(360,Math.max(120,area.width-24)),h=Math.min(160,area.height-24);
    return {x:area.x+(area.width-w)/2,y:area.y+8,width:w,height:h};
}
function inside(x,y,r) {return x>=r.x&&y>=r.y&&x<r.x+r.width&&y<r.y+r.height;}
function helperHit(zones,x,y,area) {
    var b=helperBox(area);
    var preview={x:b.x+16,y:b.y+34,width:b.width-32,height:b.height-46};
    if(!inside(x,y,preview))return -1;
    return hit(zones,(x-preview.x)/preview.width,(y-preview.y)/preview.height);
}
