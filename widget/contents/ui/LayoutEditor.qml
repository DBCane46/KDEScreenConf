pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
ColumnLayout {
    id: editor
    property var zones: []
    property int selected: -1
    property real aspect: 16/9
    property string screenName: ""
    property string profileKey: ""
    property bool saving: false
    property string error: ""
    signal saveRequested(string screen, string profile, string payload)
    signal cancelled()
    signal identifyRequested(string screen)
    function load(screen, profile, value, ratio) {
        screenName=screen;profileKey=profile;zones=JSON.parse(JSON.stringify(value));aspect=ratio;selected=0;error="";saving=false;
    }
    function change(index, z) { const copy=zones.slice();copy[index]=z;zones=copy }
    function add() { if(zones.length>=9)return;zones=zones.concat([[0.25,0.25,0.5,0.5]]);selected=zones.length-1 }
    function remove() { if(zones.length<=1||selected<0)return;const copy=zones.slice();copy.splice(selected,1);zones=copy;selected=Math.min(selected,zones.length-1) }
    function setPercent(field, value) {
        if(selected<0||selected>=zones.length)return;
        const z=zones[selected].slice();z[field]=value/100;
        z[2]=Math.max(0.05,Math.min(z[2],1-z[0]));z[3]=Math.max(0.05,Math.min(z[3],1-z[1]));
        change(selected,z);
    }
    spacing:Kirigami.Units.smallSpacing
    RowLayout {
        Kirigami.Heading {level:3;text:"Edit zones · "+editor.screenName;Layout.fillWidth:true}
        C.Button {text:"Identify screen";onClicked:editor.identifyRequested(editor.screenName)}
    }
    C.Label {text:"Drag zones to move them. Drag the lower-right corner to resize.\nOverlaps are allowed; the last zone takes priority.";wrapMode:Text.Wrap;Layout.fillWidth:true}
    Rectangle {
        id: canvas
        objectName: "zoneCanvas"
        Layout.fillWidth:true
        Layout.preferredHeight:Math.max(180,Math.min(340,width/editor.aspect))
        color:Kirigami.Theme.backgroundColor
        border.color:Kirigami.Theme.disabledTextColor
        clip:true
        enabled:!editor.saving
        Repeater {
            model:editor.zones.length
            delegate: Rectangle {
                id: zone
                required property int index
                property var value:editor.zones[index] || [0,0,1,1]
                x:value[0]*canvas.width;y:value[1]*canvas.height
                width:value[2]*canvas.width;height:value[3]*canvas.height
                color:editor.selected===index ? "#603daee9":"#303daee9"
                border.width:editor.selected===index?3:1
                border.color:editor.selected===index?Kirigami.Theme.highlightColor:Kirigami.Theme.textColor
                C.Label {anchors.centerIn:parent;text:String(zone.index+1);font.pixelSize:24}
                MouseArea {
                    anchors.fill:parent
                    cursorShape:Qt.SizeAllCursor
                    property point start
                    property var original
                    onPressed:function(mouse){editor.selected=zone.index;start=mapToItem(canvas,mouse.x,mouse.y);original=zone.value.slice()}
                    onPositionChanged:function(mouse){
                        if(!pressed)return;
                        const p=mapToItem(canvas,mouse.x,mouse.y),z=original.slice();
                        z[0]=Math.max(0,Math.min(1-z[2],original[0]+(p.x-start.x)/canvas.width));
                        z[1]=Math.max(0,Math.min(1-z[3],original[1]+(p.y-start.y)/canvas.height));editor.change(zone.index,z);
                    }
                }
                Rectangle {
                    width:18;height:18;anchors.right:parent.right;anchors.bottom:parent.bottom
                    color:Kirigami.Theme.highlightColor
                    MouseArea {
                        anchors.fill:parent;cursorShape:Qt.SizeFDiagCursor
                        property point start
                        property var original
                        onPressed:function(mouse){editor.selected=zone.index;start=mapToItem(canvas,mouse.x,mouse.y);original=zone.value.slice()}
                        onPositionChanged:function(mouse){
                            if(!pressed)return;
                            const p=mapToItem(canvas,mouse.x,mouse.y),z=original.slice();
                            z[2]=Math.max(0.05,Math.min(1-z[0],original[2]+(p.x-start.x)/canvas.width));
                            z[3]=Math.max(0.05,Math.min(1-z[1],original[3]+(p.y-start.y)/canvas.height));editor.change(zone.index,z);
                        }
                    }
                }
            }
        }
    }
    RowLayout {
        enabled:!editor.saving
        C.Button {text:"Add zone";enabled:editor.zones.length<9;onClicked:editor.add()}
        C.Button {text:"Delete selected";enabled:editor.zones.length>1&&editor.selected>=0;onClicked:editor.remove()}
        C.Label {text:editor.zones.length+" / 9"}
    }
    GridLayout {
        columns:4;enabled:!editor.saving&&editor.selected>=0
        Repeater {
            model:["Left %","Top %","Width %","Height %"]
            delegate: ColumnLayout {
                id: field
                required property string modelData
                required property int index
                C.Label {text:field.modelData}
                C.SpinBox {
                    Layout.fillWidth:true;editable:true;from:field.index<2?0:5
                    to:field.index<2?95:100
                    value:editor.selected>=0&&editor.zones[editor.selected]?Math.round(editor.zones[editor.selected][field.index]*100):0
                    onValueModified:editor.setPercent(field.index,value)
                }
            }
        }
    }
    C.Label {text:editor.error;visible:text.length>0;wrapMode:Text.Wrap;Layout.fillWidth:true;color:Kirigami.Theme.negativeTextColor}
    RowLayout {
        C.Button {text:editor.saving?"Saving…":"Save layout";enabled:!editor.saving;onClicked:{editor.saving=true;editor.error="";editor.saveRequested(editor.screenName,editor.profileKey,JSON.stringify(editor.zones))}}
        C.Button {text:"Cancel";enabled:!editor.saving;onClicked:editor.cancelled()}
    }
}
