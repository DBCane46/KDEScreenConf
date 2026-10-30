pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../kwin/contents/ui"
Item {
    id: fixture
    property int starts:0
    property int finishes:0
    QtObject {
        id: source
        property bool normalWindow:true
        signal interactiveMoveResizeStarted()
        signal interactiveMoveResizeFinished()
    }
    Component {
        id: factory
        WindowDragConnection {
            window:source
            onDragStarted:fixture.starts++
            onDragFinished:fixture.finishes++
        }
    }
    TestCase {
        name:"DragConnectionLifecycle"
        function test_reload_disconnects_old_callbacks(){
            const first=factory.createObject(fixture);
            source.interactiveMoveResizeStarted();compare(fixture.starts,1);
            first.destroy();wait(1);
            source.interactiveMoveResizeStarted();compare(fixture.starts,1);
            const second=factory.createObject(fixture);
            source.interactiveMoveResizeStarted();compare(fixture.starts,2);
            source.interactiveMoveResizeFinished();compare(fixture.finishes,1);
            second.destroy();wait(1);
            source.interactiveMoveResizeFinished();compare(fixture.finishes,1);
        }
    }
}
