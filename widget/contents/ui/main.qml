pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
PlasmoidItem {
    id: root
    property var snapshot: ({})
    property bool editing: false
    property string pendingSave: ""
    property var editorItem: null
    property string failure: "Connecting to KDEScreenConf…"
    property var layoutIds: ["full", "halves", "thirds", "priority", "quarters", "custom"]
    property var layoutNames: ["Full screen", "Two columns", "Three columns", "Wide centre", "Four quarters", "Custom"]
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
                root.failure = String(data.stderr || "KDEScreenConf backend is unavailable");
                if(source===root.pendingSave){root.pendingSave="";if(root.editorItem){root.editorItem.saving=false;root.editorItem.error=root.failure}}
                return
            }
            try { const next = JSON.parse(data.stdout); if (JSON.stringify(next) !== JSON.stringify(root.snapshot)) root.snapshot = next; root.failure = next.error || next.layout_warning || "" }
            catch (e) { root.failure = "Could not read KDEScreenConf status" }
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
        Kirigami.Icon { anchors.fill: parent; source: "kdescreenconf" }
    }
    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * (root.editing ? 32 : 22)
        Layout.preferredWidth: Kirigami.Units.gridUnit * (root.editing ? 34 : 25)
        Layout.minimumHeight: Kirigami.Units.gridUnit * 20
        spacing: Kirigami.Units.smallSpacing
        RowLayout {
            Kirigami.Heading { text: "KDEScreenConf"; level: 1; Layout.fillWidth: true }
            QQC2.Switch { text: "Enabled"; checked: root.snapshot.automatic === true; onClicked: root.run(checked ? "resume" : "pause") }
        }
        Kirigami.Heading { level: 3; text: root.snapshot.profile ? root.snapshot.profile.name : "Detecting screens…" }
        QQC2.Label { text: root.failure; visible: text.length > 0; wrapMode: Text.Wrap; Layout.fillWidth: true }
        QQC2.CheckBox { visible:!root.editing; text:"Show zones while dragging windows";checked:root.snapshot.drag_overlay===true;onClicked:root.run(checked?"overlay-on":"overlay-off") }
        QQC2.CheckBox {visible:!root.editing;text:"Placement helper at the top of each screen";checked:root.snapshot.placement_helper===true;onClicked:root.run(checked?"helper-on":"helper-off")}
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
                                } else root.run("set " + root.quote(monitorDelegate.modelData.name) + " " + root.quote(root.layoutIds[currentIndex]));
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
        QQC2.Label { text: "Layouts save automatically for this monitor combination.\nPlace a window: Ctrl+Meta+1…9\nRestore its previous size: Ctrl+Meta+0\nSkip snapping during a drag: Ctrl+Meta+D"; wrapMode: Text.Wrap; Layout.fillWidth: true }
    }
}
