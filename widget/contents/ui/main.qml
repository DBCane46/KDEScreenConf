pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
PlasmoidItem {
    id: root
    property string connectionState: "connecting"
    property var snapshot: ({})
    property bool editing: false
    property string pendingSave: ""
    property var editorItem: null
    property string failure: "Connecting to KDEScreenConf…"
    property var layoutIds: ["full", "halves", "thirds", "priority", "quarters", "left-stack", "custom"]
    property var layoutNames: ["Full screen", "Two columns", "Three columns", "Wide centre", "Four equal quarters (2 × 2)", "Left half + two right quarters", "Custom"]
    function quote(text) { return "'" + text.replace(/'/g, "'\\''") + "'" }
    function run(args) { executable.connectSource('"$HOME/.local/bin/kdescreenconf" ' + args) }
    function refresh() { run("status") }
    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            if (data["exit code"] !== 0) {
                if(source.endsWith(" status")){root.connectionState=data["exit code"]===127?"missing":"unavailable";root.snapshot=({});root.editing=false;}
                root.failure = String(data.stderr || "KDEScreenConf backend is unavailable");
                if(source===root.pendingSave){root.pendingSave="";if(root.editorItem){root.editorItem.saving=false;root.editorItem.error=root.failure}}
                return
            }
            try { const next = JSON.parse(data.stdout); if(typeof next.automatic!=="boolean" || !Array.isArray(next.monitors))throw new Error("Invalid status"); root.connectionState="ready"; if (JSON.stringify(next) !== JSON.stringify(root.snapshot)) root.snapshot = next; root.failure = next.error || next.layout_warning || "" }
            catch (e) { root.connectionState="unavailable";root.snapshot=({});root.editing=false;root.failure = "Could not read KDEScreenConf status" }
            if(source===root.pendingSave){root.pendingSave="";if(root.editorItem)root.editorItem.saving=false;root.editing=false}
        }
    }
    Timer { interval: 2500; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    toolTipMainText: "KDEScreenConf"
    toolTipSubText: snapshot.profile ? snapshot.profile.name : failure
    compactRepresentation: MouseArea {
        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: implicitWidth
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon { anchors.fill: parent; source: Qt.resolvedUrl("../images/kdescreenconf.svg") }
    }
    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * (root.editing ? 32 : 22)
        Layout.preferredWidth: Kirigami.Units.gridUnit * (root.editing ? 34 : 25)
        Layout.minimumHeight: Kirigami.Units.gridUnit * 20
        spacing: Kirigami.Units.smallSpacing
        RowLayout {
            Kirigami.Heading { text: "KDEScreenConf"; level: 1; Layout.fillWidth: true }
            QQC2.Switch { visible:root.connectionState==="ready"; text: "Enabled"; checked: root.snapshot.automatic === true; onClicked: root.run(checked ? "resume" : "pause") }
        }
        BackendNotice {
            visible:root.connectionState!=="ready";Layout.fillWidth:true
            connectionState:root.connectionState
            onRetryRequested:root.refresh()
        }
        ColumnLayout {
            visible:root.connectionState==="ready";Layout.fillWidth:true;Layout.fillHeight:true
        Kirigami.Heading { level: 3; text: root.snapshot.profile ? root.snapshot.profile.name + (root.snapshot.desktop_scoped ? " · " + root.snapshot.desktop_name : "") : "Detecting screens…" }
        QQC2.Label { text: root.failure; visible: text.length > 0; wrapMode: Text.Wrap; Layout.fillWidth: true }
        QQC2.CheckBox { visible:!root.editing; text:"Show zones during Ctrl+Meta drag";checked:root.snapshot.drag_overlay===true;onClicked:root.run(checked?"overlay-on":"overlay-off") }
        QQC2.CheckBox {visible:!root.editing;text:"Placement helper during Ctrl+Meta drag";checked:root.snapshot.placement_helper===true;onClicked:root.run(checked?"helper-on":"helper-off")}
        RowLayout {
            QQC2.Label {text:"Gap between zones (pixels)"}
            QQC2.SpinBox {from:0;to:100;editable:true;value:root.snapshot.gap===undefined?2:root.snapshot.gap;onValueModified:root.run("gap "+value)}
        }
        QQC2.Label {
            visible:root.snapshot.modifier_ready===false
            text:"Ctrl+Meta detection is unavailable in this session. Use Ctrl+Meta+1…9 to place windows instead."
            wrapMode:Text.Wrap;Layout.fillWidth:true
        }
        LayoutEditor {
            id: layoutEditor
            Component.onCompleted: root.editorItem = this
            Component.onDestruction: root.editorItem = null
            visible:root.editing
            Layout.fillWidth:true
            onSaveRequested:function(screen,profile,payload){
                const args="custom "+root.quote(screen)+" "+root.quote(profile)+" "+root.quote(payload);
                root.pendingSave='"$HOME/.local/bin/kdescreenconf" '+args;root.run(args);
            }
            onCancelled:root.editing=false
            onIdentifyRequested:function(screen){root.run("identify "+root.quote(screen))}
        }
        QQC2.ScrollView {
            visible:!root.editing
            Layout.fillWidth: true; Layout.fillHeight: true
            implicitHeight: Math.min(400, monitorColumn.implicitHeight)
            ColumnLayout {
                id: monitorColumn
                width: parent.width
                Repeater {
                    model: root.snapshot.monitors || []
                    delegate: ColumnLayout {
                        id: monitorDelegate
                        required property var modelData
                        Layout.fillWidth: true
                        QQC2.Label { text: monitorDelegate.modelData.name + " · " + monitorDelegate.modelData.width + " × " + monitorDelegate.modelData.height; font.bold: true }
                        QQC2.ComboBox {
                            Layout.fillWidth: true
                            model: root.layoutNames
                            currentIndex: root.snapshot.profile ? root.layoutIds.indexOf(root.snapshot.profile.layouts[monitorDelegate.modelData.identity]) : 1
                            onActivated: {
                                if(root.layoutIds[currentIndex]==="custom" && !root.snapshot.profile.custom[monitorDelegate.modelData.identity]) {
                                    layoutEditor.load(monitorDelegate.modelData.name,root.snapshot.profile_key,root.snapshot.zones[monitorDelegate.modelData.name],monitorDelegate.modelData.width/monitorDelegate.modelData.height);root.editing=true;root.run("identify "+root.quote(monitorDelegate.modelData.name));
                                } else root.run("set " + root.quote(monitorDelegate.modelData.name) + " " + root.quote(root.layoutIds[currentIndex]) + " " + root.quote(root.snapshot.profile_key));
                            }
                        }
                        QQC2.Button {
                            text:"Edit zones…"
                            onClicked:{layoutEditor.load(monitorDelegate.modelData.name,root.snapshot.profile_key,root.snapshot.zones[monitorDelegate.modelData.name],monitorDelegate.modelData.width/monitorDelegate.modelData.height);root.editing=true;root.run("identify "+root.quote(monitorDelegate.modelData.name))}
                        }
                    }
                }
            }
        }
        QQC2.Label { text: "Layouts save automatically. With one screen, each virtual desktop has its own layout and app assignments.\nPlace a window: Ctrl+Meta+1…9\nRestore its previous size: Ctrl+Meta+0\nHold Ctrl+Meta while dragging to show zones and snap.\nNormal moves and newly opened windows are left alone.\nApply saved application positions: Ctrl+Meta+R"; wrapMode: Text.Wrap; Layout.fillWidth: true }
        }
    }
}
