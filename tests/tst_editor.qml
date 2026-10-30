import QtQuick
import QtTest
import "../widget/contents/ui"
Item {
    width:800;height:700
    LayoutEditor {id:editor;anchors.fill:parent}
    TestCase {
        name:"LayoutEditor";when:windowShown
        function init(){editor.load("Test screen","profile",[[0,0,0.5,1],[0.5,0,0.5,1]],16/9)}
        function test_preview(){wait(50);grabImage(editor).save("/tmp/kdescreenconf-editor-preview.png")}
        function test_add_delete(){editor.add();compare(editor.zones.length,3);editor.remove();compare(editor.zones.length,2)}
        function test_bounds(){editor.setPercent(0,95);verify(editor.zones[0][0]+editor.zones[0][2]<=1.000001);editor.setPercent(2,100);verify(editor.zones[0][0]+editor.zones[0][2]<=1.000001)}
        function test_drag_resize(){
            const canvas=findChild(editor,"zoneCanvas");verify(canvas!==null);
            editor.load("Test","profile",[[0.1,0.1,0.4,0.4]],16/9);wait(100);
            const before=editor.zones[0][0];
            mouseDrag(canvas,canvas.width*.25,canvas.height*.25,50,20,Qt.LeftButton);
            verify(editor.zones[0][0]>before);
            const z=editor.zones[0],oldWidth=z[2];
            mouseDrag(canvas,(z[0]+z[2])*canvas.width-5,(z[1]+z[3])*canvas.height-5,40,20,Qt.LeftButton);
            verify(editor.zones[0][2]>oldWidth);
        }
    }
}
