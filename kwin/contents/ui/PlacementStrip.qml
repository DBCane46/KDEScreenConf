pragma ComponentBehavior: Bound
import QtQuick
Rectangle {
    id: strip
    property var zones: []
    property string screenName: ""
    property bool expanded: false
    property int highlighted: -1
    color:"#ed202b3b";radius:expanded?12:8
    border.color:"#703daee9";border.width:1
    Text {
        x:12;y:strip.expanded?8:3;width:parent.width-24
        text:strip.expanded?strip.screenName+" · Drop on a zone":"▾ "+strip.screenName+" · Place window"
        color:"#e8f5ff";font.pixelSize:strip.expanded?14:12
        horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight
    }
    Item {
        x:16;y:34;width:parent.width-32;height:parent.height-46
        visible:strip.expanded
        Repeater {
            model:strip.expanded?strip.zones:[]
            delegate: Rectangle {
                id: tile
                required property var modelData
                required property int index
                x:modelData[0]*parent.width+2;y:modelData[1]*parent.height+2
                width:Math.max(1,modelData[2]*parent.width-4);height:Math.max(1,modelData[3]*parent.height-4)
                color:strip.highlighted===index?"#3daee9":"#344c60"
                border.color:strip.highlighted===index?"#d4f3ff":"#7093aa";radius:4
                Text {anchors.centerIn:parent;text:tile.index+1;color:"white";font.pixelSize:18}
            }
        }
    }
}
