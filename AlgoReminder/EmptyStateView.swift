import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    let actionLabel: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !actionLabel.isEmpty {
                Button(actionLabel) {
                    action()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        title: "暂无内容",
        subtitle: "这里还没有任何内容",
        action: {},
        actionLabel: "添加内容"
    )
}