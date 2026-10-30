pragma ComponentBehavior: Bound
import QtQml
// The owned Connections object disconnects when its script is destroyed.
QtObject {
    id: watcher
    required property var window
    signal dragStarted(var movedWindow)
    signal dragFinished(var movedWindow)
    property Connections connection: Connections {
        target: watcher.window && watcher.window.normalWindow ? watcher.window : null
        function onInteractiveMoveResizeStarted() { watcher.dragStarted(watcher.window) }
        function onInteractiveMoveResizeFinished() { watcher.dragFinished(watcher.window) }
    }
}
