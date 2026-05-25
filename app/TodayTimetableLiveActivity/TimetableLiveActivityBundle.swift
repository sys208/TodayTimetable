import SwiftUI
import WidgetKit

@main
struct TimetableLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TimetableLiveActivity()
        FocusLiveActivity()
        TeacherLiveActivity()
    }
}
