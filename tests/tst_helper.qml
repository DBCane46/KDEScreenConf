import QtQuick
import QtTest
import "../kwin/contents/ui"
Item {
    width:400;height:200
    PlacementStrip {id:strip;x:20;y:20;width:360;height:160;expanded:true;screenName:"Screen 1";zones:[[0,0,.5,1],[.5,0,.5,.5],[.5,.5,.5,.5]];highlighted:1}
    TestCase {
        name:"PlacementHelper";when:windowShown
        function test_render(){wait(50);compare(strip.zones.length,3);grabImage(strip).save("/tmp/kdescreenconf-helper.png")}
    }
}
