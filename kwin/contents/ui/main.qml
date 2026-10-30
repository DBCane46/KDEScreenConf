pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import org.kde.kwin
import org.kde.plasma.core as PlasmaCore
import "../code/geometry.js" as Geometry
Item {
    id: root
    property var state: ({})
    property var originals: ({})
    property var trackedWindows: []
    property var movingWindow: null
    property var startGeometry: null
    property string dragProfile: ""
    property bool suppressed: false
    property bool busy: false
    property double lastReply: 0
    property var output: null
    property rect area: Qt.rect(0,0,1,1)
    property var activeZones: []
    property int highlighted: -1
    property rect identifyArea: Qt.rect(0,0,1,1)
    property string identifyName: ""
    property string identifyResolution: ""
    function updateIdentification() {
        const name=state.identify;
        const screens=Workspace.screens;
        let found=null;
        for(let i=0;i<screens.length;i++)if(screens[i].name===name)found=screens[i];
        if(!name || !found || Date.now()-lastReply>3500){identification.visible=false;return}
        identifyName=name;
        const monitor=(state.monitors || []).find(function(m){return m.name===name});
        identifyResolution=monitor ? monitor.width+" × "+monitor.height : "";
        identifyArea=found.geometry;
        identification.x=identifyArea.x;identification.y=identifyArea.y;
        identification.width=identifyArea.width;identification.height=identifyArea.height;
        identification.visible=true;
        identifyTimeout.restart();
    }
    Timer {id:identifyTimeout;interval:2000;onTriggered:identification.visible=false}
    function healthy() { return state.automatic && !state.error && Date.now()-lastReply<3500 }
    function refresh() { if (!busy) { busy=true; statusCall.call() } }
    function place(window, zone, target, original) {
        if (!window || !window.normalWindow || !window.resizeable || window.fullScreen || !target || !zone) return;
        const key=String(window.internalId);
        if (!originals[key]) originals[key]=original || Geometry.copy(window.frameGeometry);
        const a=Workspace.clientArea(KWin.MaximizeArea,target,Workspace.currentDesktop);
        const g=Geometry.rect(zone,a,8);
        window.setMaximize(false,false);
        window.frameGeometry=Qt.rect(g.x,g.y,g.width,g.height);
    }
    function keyboardPlace(index) {
        const w=Workspace.activeWindow;
        if (!healthy()||!w||!w.output) return;
        const zs=state.zones[w.output.name] || [];
        place(w,zs[index],w.output,null);
    }
    function restore() {
        const w=Workspace.activeWindow;
        if (!w) return;
        const key=String(w.internalId),g=originals[key];
        if (!g) return;
        const a=Workspace.clientArea(KWin.MaximizeArea,w.output,Workspace.currentDesktop),r=Geometry.clamp(g,a);
        w.setMaximize(false,false);w.frameGeometry=Qt.rect(r.x,r.y,r.width,r.height);delete originals[key];
    }
    function updateOverlay() {
        if (!movingWindow || suppressed || !healthy() || !state.drag_overlay || state.profile_key!==dragProfile) { overlay.visible=false;highlighted=-1;return }
        const cursor=Workspace.cursorPos;
        const screens=Workspace.screens;
        let found=null;
        for (let i=0;i<screens.length;i++) { const g=screens[i].geometry; if(cursor.x>=g.x&&cursor.x<g.x+g.width&&cursor.y>=g.y&&cursor.y<g.y+g.height) {found=screens[i];break} }
        if (!found) {overlay.visible=false;highlighted=-1;return}
        output=found;
        area=Workspace.clientArea(KWin.MaximizeArea,found,Workspace.currentDesktop);
        activeZones=state.zones[found.name] || [];
        highlighted=Geometry.hit(activeZones,(cursor.x-area.x)/area.width,(cursor.y-area.y)/area.height);
        overlay.x=area.x;overlay.y=area.y;overlay.width=area.width;overlay.height=area.height;
        overlay.visible=activeZones.length>0;
    }
    function beginMove(w) {
        if (!w.move || !w.resizeable || w.fullScreen) return;
        root.movingWindow=w;root.startGeometry=Geometry.copy(w.frameGeometry);
        root.dragProfile=root.state.profile_key || "";root.suppressed=false;
        root.refresh();root.updateOverlay();
    }
    function finishMove(w) {
        if (root.movingWindow!==w) return;
        root.updateOverlay();
        // Escape restores the original geometry; do not snap a cancelled move.
        const shouldSnap=overlay.visible && root.highlighted>=0 && !Geometry.same(w.frameGeometry,root.startGeometry);
        const zone=root.activeZones[root.highlighted],target=root.output,original=root.startGeometry;
        root.movingWindow=null;overlay.visible=false;root.highlighted=-1;
        if (shouldSnap) root.place(w,zone,target,original);
    }
    Instantiator {
        model: root.trackedWindows
        delegate: WindowDragConnection {
            required property var modelData
            window: modelData
            onDragStarted: function(w) { root.beginMove(w) }
            onDragFinished: function(w) { root.finishMove(w) }
        }
    }
    DBusCall {
        id: statusCall
        service: "org.kde.KDEScreenConf"; path: "/KDEScreenConf"; dbusInterface: "org.kde.KDEScreenConf"; method: "Status"
        onFinished: function(reply) {
            root.busy=false;
            try { root.state=JSON.parse(reply[0]);root.lastReply=Date.now() } catch(e) {root.state=({})}
            root.updateOverlay();root.updateIdentification();
        }
        onFailed: {root.busy=false;root.state=({});root.updateOverlay();root.updateIdentification()}
    }
    Timer {interval:1000;running:true;repeat:true;triggeredOnStart:true;onTriggered:root.refresh()}
    Timer {interval:30;running:root.movingWindow!==null;repeat:true;onTriggered:root.updateOverlay()}
    Connections {
        target: Workspace
        function onWindowAdded(w) {root.trackedWindows=root.trackedWindows.concat([w])}
        function onWindowRemoved(w) {
            root.trackedWindows=root.trackedWindows.filter(function(item){return item!==w});
            delete root.originals[String(w.internalId)];if(root.movingWindow===w){root.movingWindow=null;overlay.visible=false}
        }
    }
    Component.onCompleted: root.trackedWindows=Array.from(Workspace.stackingOrder)
    Repeater {
        model:9
        delegate: Item {
            id: shortcutItem
            required property int index
            ShortcutHandler {name:"KDEScreenConfZone"+(shortcutItem.index+1);text:"KDEScreenConf: place in zone "+(shortcutItem.index+1);sequence:"Meta+Ctrl+"+(shortcutItem.index+1);onActivated:root.keyboardPlace(shortcutItem.index)}
        }
    }
    ShortcutHandler {name:"KDEScreenConfRestore";text:"KDEScreenConf: restore window geometry";sequence:"Meta+Ctrl+0";onActivated:root.restore()}
    ShortcutHandler {name:"KDEScreenConfSkipDrag";text:"KDEScreenConf: skip snapping for this drag";sequence:"Meta+Ctrl+D";onActivated:{root.suppressed=true;root.updateOverlay()}}
    PlasmaCore.Dialog {
        id: identification
        title: "KDEScreenConf screen identification"
        location: PlasmaCore.Types.Floating
        type: PlasmaCore.Dialog.OnScreenDisplay
        backgroundHints: PlasmaCore.Types.NoBackground
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput | Qt.BypassWindowManagerHint
        outputOnly:true;visible:false
        mainItem: Rectangle {
            width:root.identifyArea.width;height:root.identifyArea.height
            color:"transparent";border.width:10;border.color:"#50d9b0";radius:12
            Rectangle {
                anchors.centerIn:parent;width:Math.min(560,parent.width-40);height:180
                color:"#ee202b3b";radius:18;border.color:"#50d9b0";border.width:3
                Column {
                    anchors.centerIn:parent;spacing:12
                    Text {anchors.horizontalCenter:parent.horizontalCenter;text:root.identifyName;color:"white";font.pixelSize:40;font.bold:true}
                    Text {anchors.horizontalCenter:parent.horizontalCenter;text:root.identifyResolution;color:"#b8d9e8";font.pixelSize:24}
                    Text {anchors.horizontalCenter:parent.horizontalCenter;text:"Editing this screen · KDEScreenConf";color:"#50d9b0";font.pixelSize:17}
                }
            }
        }
    }
    PlasmaCore.Dialog {
        id: overlay
        title: "KDEScreenConf zone overlay"
        location: PlasmaCore.Types.Floating
        type: PlasmaCore.Dialog.OnScreenDisplay
        backgroundHints: PlasmaCore.Types.NoBackground
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput | Qt.BypassWindowManagerHint
        outputOnly: true
        visible: false
        mainItem: Item {
            width:root.area.width;height:root.area.height
            Repeater {
                model:root.activeZones
                delegate: Rectangle {
                    id: zoneItem
                    required property var modelData
                    required property int index
                    x:modelData[0]*root.area.width+8;y:modelData[1]*root.area.height+8
                    width:Math.max(1,modelData[2]*root.area.width-16);height:Math.max(1,modelData[3]*root.area.height-16)
                    radius:12;color:root.highlighted===index ? "#8044b9ee" : "#243daee9"
                    border.width:root.highlighted===index?3:1;border.color:root.highlighted===index?"#a9e3ff":"#803daee9"
                    Text {anchors.centerIn:parent;text:String(zoneItem.index+1);color:"white";font.pixelSize:38;style:Text.Outline;styleColor:"#263747"}
                }
            }
        }
    }
}
