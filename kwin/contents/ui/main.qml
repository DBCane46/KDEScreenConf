pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import org.kde.kwin
import org.kde.plasma.core as PlasmaCore
import "../code/geometry.js" as Geometry
Item {
    id: root
    property var state: ({})
    property var restored: ({})
    property var managed: ({})
    property var pendingAssignments: []
    property bool remembering: false
    property double dragStartedAt: 0
    property var pendingDrop: null
    function applicationId(w) {
        const app=String(w.desktopFileName || w.resourceClass || "").toLowerCase();
        if(!app)return "";
        // Distinguish application subwindows; never persist transient internalId.
        return JSON.stringify([app,String(w.windowRole || ""),String(w.caption || "")]);
    }
    function remember(w,target,index) {
        const app=applicationId(w);
        if(!app || index<0)return;
        pendingAssignments.push([state.profile_key,target.name,app,String(index)]);
        sendAssignment();
    }
    function sendAssignment() {
        if(remembering || !pendingAssignments.length)return;
        remembering=true;rememberCall.arguments=pendingAssignments.shift();rememberCall.call();
    }
    function restoreApplications(previous) {
        if(!healthy() || movingWindow || pendingDrop)return;
        if(previous.profile_key!==state.profile_key || !previous.automatic || JSON.stringify(previous.zones)!==JSON.stringify(state.zones)){restored=({});managed=({})}
        const rules=state.profile?state.profile.applications || {}:{};
        for(const w of trackedWindows){
            if(!w || !w.normalWindow || !w.resizeable || w.fullScreen || w.move)continue;
            if(state.desktop_scoped && !w.onAllDesktops && !Array.from(w.desktops || []).some(function(d){return d.id===Workspace.currentDesktop.id}))continue;
            const id=String(w.internalId),app=applicationId(w),rule=rules[app] || rules[String(w.desktopFileName || w.resourceClass || "").toLowerCase()];
            if(!app || !rule)continue;
            const monitor=(state.monitors||[]).find(function(m){return m.identity===rule.monitor});
            const target=monitor?Array.from(Workspace.screens).find(function(o){return o.name===monitor.name}):null;
            const zs=target?state.zones[target.name] || []:[];
            if(!zs[rule.zone])continue;
            if(restored[id]!==state.profile_key || (managed[id] && previous.gap!==state.gap)){
                place(w,zs[rule.zone],target,null,false);
                restored[id]=state.profile_key;managed[id]=true;
            }
        }
    }
    property var originals: ({})
    property var trackedWindows: []
    property var helperScreens: []
    property bool helperExpanded: false
    property var helperGeometry: Geometry.helperBox(area)
    function updateHelperScreens() {
        const screens=Workspace.screens,result=[];
        for(let i=0;i<screens.length;i++){
            const a=Workspace.clientArea(KWin.MaximizeArea,screens[i],Workspace.currentDesktop);
            result.push({name:screens[i].name,x:a.x,y:a.y,width:a.width,height:a.height});
        }
        if(JSON.stringify(result)!==JSON.stringify(helperScreens))helperScreens=result;
    }
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
    function healthy() { return (!state.desktop_scoped || state.desktop_id===String(Workspace.currentDesktop.id)) && state.automatic && !state.error && Date.now()-lastReply<3500 }
    function refresh() { if (!busy) { busy=true; statusCall.call() } }
    function place(window, zone, target, original, saveAssignment) {
        if (!window || !window.normalWindow || !window.resizeable || window.fullScreen || !target || !zone) return;
        const key=String(window.internalId);
        if (!originals[key]) originals[key]=original || Geometry.copy(window.frameGeometry);
        const a=Workspace.clientArea(KWin.MaximizeArea,target,Workspace.currentDesktop);
        const g=Geometry.rect(zone,a,state.gap===undefined?2:state.gap);
        window.setMaximize(false,false);
        window.frameGeometry=Qt.rect(g.x,g.y,g.width,g.height);
        restored[key]=state.profile_key;managed[key]=true;
        if(saveAssignment!==false)remember(window,target,(state.zones[target.name]||[]).indexOf(zone));
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
        if (!movingWindow || suppressed || !state.modifier_ready || !state.free_move || !healthy() || (!state.drag_overlay && !state.placement_helper) || state.profile_key!==dragProfile) { overlay.visible=false;highlighted=-1;return }
        const cursor=Workspace.cursorPos;
        const screens=Workspace.screens;
        let found=null;
        for (let i=0;i<screens.length;i++) { const g=screens[i].geometry; if(cursor.x>=g.x&&cursor.x<g.x+g.width&&cursor.y>=g.y&&cursor.y<g.y+g.height) {found=screens[i];break} }
        if (!found) {overlay.visible=false;highlighted=-1;return}
        output=found;
        area=Workspace.clientArea(KWin.MaximizeArea,found,Workspace.currentDesktop);
        activeZones=state.zones[found.name] || [];
        helperExpanded=state.placement_helper && Geometry.inside(cursor.x,cursor.y,helperGeometry);
        highlighted=helperExpanded ? Geometry.helperHit(activeZones,cursor.x,cursor.y,area) : (state.drag_overlay?Geometry.hit(activeZones,(cursor.x-area.x)/area.width,(cursor.y-area.y)/area.height):-1);
        overlay.x=area.x;overlay.y=area.y;overlay.width=area.width;overlay.height=area.height;
        overlay.visible=activeZones.length>0 && (state.drag_overlay || helperExpanded);
    }
    function beginMove(w) {
        if (!w.move || !w.resizeable || w.fullScreen) return;
        root.movingWindow=w;root.startGeometry=Geometry.copy(w.frameGeometry);
        root.dragProfile=root.state.profile_key || "";root.suppressed=false;
        root.dragStartedAt=Date.now();root.pendingDrop=null;
        root.restored[String(w.internalId)]=root.dragProfile;delete root.managed[String(w.internalId)];
        root.refresh();root.updateOverlay();
    }
    function finishMove(w) {
        if (root.movingWindow!==w) return;
        root.updateOverlay();
        // Escape restores the original geometry; do not snap a cancelled move.
        const shouldSnap=overlay.visible && root.highlighted>=0 && !Geometry.same(w.frameGeometry,root.startGeometry);
        const zone=root.activeZones[root.highlighted],target=root.output,original=root.startGeometry;
        root.movingWindow=null;overlay.visible=false;root.highlighted=-1;
        if (shouldSnap) {
            pendingDrop={window:w,zone:zone,target:target,original:original,profile:dragProfile,epoch:dragStartedAt};
            dropCheck.call();
        }
    }
    DBusCall {
        id:dropCheck
        service:"org.kde.KDEScreenConf";path:"/KDEScreenConf";dbusInterface:"org.kde.KDEScreenConf";method:"DesktopStatus";arguments:[String(Workspace.currentDesktop.id),String(Workspace.currentDesktop.name)]
        onFinished:function(reply){
            const drop=root.pendingDrop;root.pendingDrop=null;
            if(!drop || !root.trackedWindows.includes(drop.window))return;
            try{
                const now=JSON.parse(reply[0]);
                if(now.automatic && !now.error && now.profile_key===drop.profile && !drop.window.move)
                    root.place(drop.window,drop.zone,drop.target,drop.original);
            }catch(e){console.warn("KDEScreenConf drop check failed",e)}
        }
        onFailed:root.pendingDrop=null
    }
    DBusCall {
        id:rememberCall
        service:"org.kde.KDEScreenConf";path:"/KDEScreenConf";dbusInterface:"org.kde.KDEScreenConf";method:"Remember"
        onFinished:{root.remembering=false;root.sendAssignment()}
        onFailed:{console.warn("KDEScreenConf could not save application assignment");root.remembering=false;root.sendAssignment()}
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
        service: "org.kde.KDEScreenConf"; path: "/KDEScreenConf"; dbusInterface: "org.kde.KDEScreenConf"; method: "DesktopStatus"
        arguments:[String(Workspace.currentDesktop.id),String(Workspace.currentDesktop.name)]
        onFinished: function(reply) {
            root.busy=false;
            try { root.state=JSON.parse(reply[0]);root.lastReply=Date.now() } catch(e) {root.state=({})}
            root.updateOverlay();root.updateIdentification();root.updateHelperScreens();
        }
        onFailed: {root.busy=false;root.state=({});root.updateOverlay();root.updateIdentification()}
    }
    Timer {interval:root.movingWindow?50:1000;running:true;repeat:true;triggeredOnStart:true;onTriggered:root.refresh()}
    Timer {interval:30;running:root.movingWindow!==null;repeat:true;onTriggered:root.updateOverlay()}
    Connections {
        target: Workspace
        function onCurrentDesktopChanged() {
            root.pendingDrop=null;root.suppressed=true;overlay.visible=false;
            root.refresh();
        }
        function onWindowAdded(w) {root.trackedWindows=root.trackedWindows.concat([w])}
        function onWindowRemoved(w) {
            root.trackedWindows=root.trackedWindows.filter(function(item){return item!==w});
            delete root.restored[String(w.internalId)];delete root.managed[String(w.internalId)];delete root.originals[String(w.internalId)];if(root.movingWindow===w){root.movingWindow=null;overlay.visible=false}
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
    ShortcutHandler {name:"KDEScreenConfRestoreAssignments";text:"KDEScreenConf: apply saved application assignments";sequence:"Meta+Ctrl+R";onActivated:root.restoreApplications({})}
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
                    visible:root.state.drag_overlay || root.highlighted===index
                    property var frame:Geometry.rect(modelData,{x:0,y:0,width:root.area.width,height:root.area.height},root.state.gap===undefined?2:root.state.gap)
                    x:frame.x;y:frame.y;width:frame.width;height:frame.height
                    radius:12;color:root.highlighted===index ? "#8044b9ee" : "#243daee9"
                    border.width:root.highlighted===index?3:1;border.color:root.highlighted===index?"#a9e3ff":"#803daee9"
                    Text {anchors.centerIn:parent;text:String(zoneItem.index+1);color:"white";font.pixelSize:38;style:Text.Outline;styleColor:"#263747"}
                }
            }
            PlacementStrip {
                visible:root.state.placement_helper===true
                x:root.helperExpanded?root.helperGeometry.x-root.area.x:(root.area.width-200)/2
                y:8;width:root.helperExpanded?root.helperGeometry.width:200;height:root.helperExpanded?root.helperGeometry.height:24
                expanded:root.helperExpanded;zones:root.activeZones;highlighted:root.highlighted
                screenName:root.output?root.output.name:""
            }
        }
    }
}
