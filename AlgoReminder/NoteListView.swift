import SwiftUI
import CoreData

struct NoteListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var problem: Problem
    @Binding var selectedNote: Note?
    
    @FetchRequest private var notes: FetchedResults<Note>
    
    init(problem: Problem, selectedNote: Binding<Note?>) {
        self.problem = problem
        self._selectedNote = selectedNote
        
        // Create fetch request for notes associated with this problem
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "ANY problems == %@", problem)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        self._notes = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("笔记列表")
                    .font(.headline)
                
                Spacer()
                
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            if notes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "note.text")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("暂无笔记")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("导入Markdown文件来添加笔记")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(notes, id: \.id) { note in
                            NoteListItemView(
                                note: note,
                                isSelected: selectedNote?.id == note.id,
                                onSelect: {
                                    selectedNote = note
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct NoteListItemView: View {
    @ObservedObject var note: Note
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(note.title ?? "Untitled Note")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                HStack {
                    Text("更新于 \(note.updatedAt ?? Date(), style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let importedFrom = note.importedFromURL {
                        Text("📎 \(URL(fileURLWithPath: importedFrom).lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Preview of first few lines
                if let preview = note.rawMarkdown?.prefix(100) {
                    Text(String(preview) + (note.rawMarkdown?.count ?? 0 > 100 ? "..." : ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .hoverEffect(isSelected ? .none : .highlight)
    }
}

// Helper for hover effect
extension View {
    func hoverEffect(_ effect: HoverEffect) -> some View {
        self.onHover { isHovered in
            switch effect {
            case .highlight:
                if isHovered {
                    self.background(Color.gray.opacity(0.1))
                } else {
                    self.background(Color.clear)
                }
            case .none:
                self
            }
        }
    }
}

enum HoverEffect {
    case highlight
    case none
}

#Preview {
    NoteListView(problem: {
        let context = PersistenceController.preview.container.viewContext
        let problem = Problem(context: context)
        problem.id = UUID()
        problem.title = "示例题目"
        problem.source = "LeetCode"
        problem.difficulty = "中等"
        
        // Add some sample notes
        let note1 = Note(context: context)
        note1.id = UUID()
        note1.title = "解题思路"
        note1.rawMarkdown = "# 解题思路\n这是一道动态规划题目..."
        note1.updatedAt = Date()
        note1.addToProblems(problem)
        
        let note2 = Note(context: context)
        note2.id = UUID()
        note2.title = "代码实现"
        note2.rawMarkdown = "```python\ndef solution():\n    pass\n```"
        note2.updatedAt = Date().addingTimeInterval(-3600)
        note2.addToProblems(problem)
        
        try? context.save()
        
        return problem
    }(), selectedNote: .constant(nil))
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}