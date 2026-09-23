import SwiftUI

enum ToastDuration: Equatable {
    case seconds(Double)
    case persistent

    fileprivate var seconds: Double? {
        switch self {
        case .seconds(let value): max(0.1, value)
        case .persistent: nil
        }
    }
}

struct ToastDismissAction {
    fileprivate let handler: () -> Void

    func callAsFunction() {
        handler()
    }
}

struct ToastNotification: Identifiable {
    let id: UUID
    let message: String
    let color: Color
    let icon: Image?
    let duration: Double?
    let actionTitle: String?
    let action: (() -> Void)?
    let customContent: AnyView?

    var isPersistent: Bool { duration == nil }
}

struct ToastStack: View {
    @State private var manager = ToastManager.shared

    var body: some View {
        VStack(spacing: 9) {
            ForEach(manager.notifications) { notification in
                ToastCard(notification: notification, manager: manager)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        )
                    )
            }
        }
        .padding(.horizontal, CloveSpacing.medium)
        .safeAreaPadding(.top, CloveSpacing.small)
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: manager.notifications.map(\.id))
    }
}

private struct ToastCard: View {
    let notification: ToastNotification
    let manager: ToastManager

    @State private var progress = 1.0
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 11) {
                if let customContent = notification.customContent {
                    customContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    standardContent
                }

                Button {
                    manager.dismiss(notification.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.13), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss notification")
            }
            .padding(.leading, 15)
            .padding(.trailing, 10)
            .padding(.vertical, 11)

            if let duration = notification.duration {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.white.opacity(0.38))
                        .frame(width: geometry.size.width * progress, height: 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 3)
                .task(id: notification.id) {
                    progress = 1
                    withAnimation(.linear(duration: duration)) {
                        progress = 0
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .background(notification.color, in: RoundedRectangle(cornerRadius: CloveCorners.medium))
        .clipShape(RoundedRectangle(cornerRadius: CloveCorners.medium))
        .overlay {
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .offset(
            x: dragOffset.width,
            y: min(0, dragOffset.height)
        )
        .opacity(dragOpacity)
        .gesture(dismissGesture)
        .accessibilityAction(.escape) {
            manager.dismiss(notification.id)
        }
    }

    private var standardContent: some View {
        HStack(spacing: 11) {
            if let icon = notification.icon {
                icon
                    .font(.system(size: 16, weight: .semibold))
            }

            Text(notification.message)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .multilineTextAlignment(.leading)
                .lineLimit(4)

            Spacer(minLength: 0)

            if let actionTitle = notification.actionTitle {
                Button(actionTitle) {
                    manager.performAction(for: notification.id)
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .background(.white.opacity(0.18), in: Capsule())
            }
        }
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                let movedSideways = abs(value.translation.width) > 65
                let movedUp = value.translation.height < -38
                if movedSideways || movedUp {
                    manager.dismiss(notification.id)
                }
            }
    }

    private var dragOpacity: Double {
        let distance = max(abs(dragOffset.width), abs(min(0, dragOffset.height)))
        return max(0.45, 1 - Double(distance / 180))
    }
}

struct ToastModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            content
            ToastStack()
                .zIndex(100)
        }
    }
}

extension View {
    func toastable() -> some View {
        modifier(ToastModifier())
    }
}

@Observable
final class ToastManager {
    static let shared = ToastManager()

    private(set) var notifications: [ToastNotification] = []

    // Legacy observable values retained for dependency-injected callers and
    // source compatibility. They reflect the newest visible notification.
    var offset: CGFloat = 0
    var message = ""
    var color: Color = .black
    var icon: Image?
    var duration = 3.0
    var isVisible = false
    var showProgress = false
    var actionTitle: String?

    @ObservationIgnored private var dismissalTasks: [UUID: Task<Void, Never>] = [:]

    init() {}

    func showToast(
        message: String,
        color: Color = .black,
        icon: Image? = nil,
        duration: Double = 3.0,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        _ = postToast(
            message: message,
            color: color,
            icon: icon,
            duration: duration,
            actionTitle: actionTitle,
            action: action
        )
    }

    /// Posts a timed standard notification and returns its identifier for
    /// callers that need to dismiss that specific notification later.
    @discardableResult
    func postToast(
        message: String,
        color: Color = .black,
        icon: Image? = nil,
        duration: Double = 3.0,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> UUID {
        enqueue(
            id: UUID(),
            message: message,
            color: color,
            icon: icon,
            duration: .seconds(duration),
            actionTitle: actionTitle,
            action: action,
            customContent: nil
        )
    }

    @discardableResult
    func showPersistentToast(
        message: String,
        color: Color = .black,
        icon: Image? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> UUID {
        enqueue(
            id: UUID(),
            message: message,
            color: color,
            icon: icon,
            duration: .persistent,
            actionTitle: actionTitle,
            action: action,
            customContent: nil
        )
    }

    /// Presents arbitrary SwiftUI content inside standard toast chrome. The
    /// supplied dismiss action can be used by any custom buttons in the view.
    @discardableResult
    func showToast<Content: View>(
        color: Color = .black,
        duration: ToastDuration = .persistent,
        @ViewBuilder content: (ToastDismissAction) -> Content
    ) -> UUID {
        let id = UUID()
        let dismiss = ToastDismissAction { [weak self] in self?.dismiss(id) }
        return enqueue(
            id: id,
            message: "",
            color: color,
            icon: nil,
            duration: duration,
            actionTitle: nil,
            action: nil,
            customContent: AnyView(content(dismiss))
        )
    }

    func dismiss(_ id: UUID) {
        dismissalTasks[id]?.cancel()
        dismissalTasks[id] = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
            notifications.removeAll { $0.id == id }
        }
        synchronizeLegacyState()
    }

    func hide() {
        guard let newest = notifications.last else { return }
        dismiss(newest.id)
    }

    func dismissAll() {
        dismissalTasks.values.forEach { $0.cancel() }
        dismissalTasks.removeAll()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
            notifications.removeAll()
        }
        synchronizeLegacyState()
    }

    func performAction(for id: UUID) {
        guard let notification = notifications.first(where: { $0.id == id }) else { return }
        let pendingAction = notification.action
        dismiss(id)
        pendingAction?()
    }

    // Maintains compatibility with the previous single-toast API.
    func performAction() {
        guard let newest = notifications.last else { return }
        performAction(for: newest.id)
    }

    @discardableResult
    private func enqueue(
        id: UUID,
        message: String,
        color: Color,
        icon: Image?,
        duration: ToastDuration,
        actionTitle: String?,
        action: (() -> Void)?,
        customContent: AnyView?
    ) -> UUID {
        let notification = ToastNotification(
            id: id,
            message: message,
            color: color,
            icon: icon,
            duration: duration.seconds,
            actionTitle: actionTitle,
            action: action,
            customContent: customContent
        )

        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
            notifications.append(notification)
        }
        synchronizeLegacyState()
        provideHaptic(for: color)

        if let seconds = notification.duration {
            dismissalTasks[id] = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                self?.dismiss(id)
            }
        }

        return id
    }

    private func synchronizeLegacyState() {
        guard let newest = notifications.last else {
            isVisible = false
            message = ""
            icon = nil
            actionTitle = nil
            showProgress = false
            return
        }

        isVisible = true
        message = newest.message
        color = newest.color
        icon = newest.icon
        duration = newest.duration ?? 0
        actionTitle = newest.actionTitle
        showProgress = newest.duration != nil
        offset = 0
    }

    private func provideHaptic(for color: Color) {
        if color == CloveColors.success {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else if color == CloveColors.error {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

#Preview {
    VStack(spacing: 18) {
        Button("Stack notifications") {
            ToastManager.shared.showToast(
                message: "Your changes were saved.",
                color: CloveColors.success,
                icon: Image(systemName: "checkmark.circle.fill")
            )
            ToastManager.shared.showPersistentToast(
                message: "This stays until you dismiss it.",
                color: CloveColors.info,
                icon: Image(systemName: "info.circle.fill")
            )
        }

        Button("Show custom notification") {
            ToastManager.shared.showToast(color: Theme.shared.accent) { dismiss in
                VStack(alignment: .leading, spacing: 7) {
                    Text("Custom content")
                        .font(.headline)
                    Button("Got it") { dismiss() }
                        .font(.subheadline.bold())
                }
            }
        }
    }
    .toastable()
}
