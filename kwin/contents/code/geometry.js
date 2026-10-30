// Pure geometry shared by the overlay and keyboard placement.
function rect(zone, area, gap) {
    return {x:Math.round(area.x+zone[0]*area.width+gap),y:Math.round(area.y+zone[1]*area.height+gap),
        width:Math.max(1,Math.round(zone[2]*area.width-2*gap)),height:Math.max(1,Math.round(zone[3]*area.height-2*gap))};
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
