import QtQuick
import QtTest
import "../widget/contents/ui"
Item {
    width:500;height:480
    Rectangle {anchors.fill:parent;color:"#eff0f1"}
    BackendNotice {id:notice;anchors.fill:parent;anchors.margins:24;connectionState:"missing"}
    TestCase {
        name:"BackendNotice";when:windowShown
        function test_missing(){notice.connectionState="missing";wait(50);verify(notice.installationUrl.startsWith("https://github.com/DBCane46/"));grabImage(parent).save("/tmp/kdescreenconf-backend-missing.png")}
        function test_unavailable(){notice.connectionState="unavailable";wait(50);verify(notice.visible)}
    }
}
