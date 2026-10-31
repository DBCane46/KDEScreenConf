pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as C
import org.kde.kirigami as Kirigami
ColumnLayout {
    id: notice
    property string connectionState: "connecting"
    readonly property string installationUrl: "https://github.com/DBCane46/KDEScreenConf#installation"
    signal retryRequested()
    spacing: Kirigami.Units.largeSpacing
    Image { source: "../images/kdescreenconf.svg"; sourceSize.width: 64; sourceSize.height: 64; Layout.alignment: Qt.AlignHCenter }
    Kirigami.Heading {
        level: 2; Layout.fillWidth: true; wrapMode: Text.Wrap
        text: notice.connectionState === "missing" ? "Backend not installed" : notice.connectionState === "connecting" ? "Connecting to KDEScreenConf…" : "Backend unavailable"
    }
    C.Label {
        Layout.fillWidth: true; wrapMode: Text.Wrap
        text: notice.connectionState === "connecting" ? "Checking the companion service…" :
            "This widget needs the KDEScreenConf Rust backend and KWin integration. Installing it from the KDE Store does not install these components."
    }
    C.Label {
        visible: notice.connectionState === "unavailable"
        Layout.fillWidth: true; wrapMode: Text.Wrap
        text: "If you already installed the companion, check its user service with: systemctl --user status kdescreenconf.service"
    }
    C.Button {
        visible: notice.connectionState !== "connecting"
        text: "Open installation instructions"
        onClicked: Qt.openUrlExternally(notice.installationUrl)
    }
    C.Button { text: "Check again"; onClicked: notice.retryRequested() }
    C.Label {
        visible: notice.connectionState !== "connecting"
        Layout.fillWidth: true; wrapMode: Text.Wrap
        text: "After installation, this widget reconnects automatically. Nothing is downloaded or installed by this screen."
    }
}
