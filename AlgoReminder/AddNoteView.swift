import SwiftUI
import CoreData

struct AddNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var content = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedProblem: Problem?
    @State private var showingProblemSelector = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Problem.title, ascending: true)],
        animation: .default)
    private var problems: FetchedResults<Problem>
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("添加笔记")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Form
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标题 *")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("请输入笔记标题", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("关联题目")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Button(action: { showingProblemSelector = true }) {
                            HStack {
                                Text(selectedProblem?.title ?? "选择关联题目")
                                    .foregroundColor(selectedProblem != nil ? .primary : .secondary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("内容 *")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextEditor(text: $content)
                            .frame(height: 300)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("提示")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("• 支持 Markdown 格式")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• 支持 [[题目名称]] 格式的双向链接")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• 关联题目后，可以在题目详情中查看此笔记")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                
                Button("保存") {
                    saveNote()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(title.isEmpty || content.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(title.isEmpty || content.isEmpty)
            }
            .padding()
        }
        .frame(width: 700, height: 600)
        .sheet(isPresented: $showingProblemSelector) {
            ProblemSelectorView(selectedProblem: $selectedProblem)
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveNote() {
        guard !title.isEmpty else {
            alertMessage = "请输入笔记标题"
            showingAlert = true
            return
        }
        
        guard !content.isEmpty else {
            alertMessage = "请输入笔记内容"
            showingAlert = true
            return
        }
        
        let note = Note(context: viewContext)
        note.id = UUID()
        note.title = title
        note.rawMarkdown = content
        note.renderedHTML = MarkdownRenderer.shared.renderMarkdown(content, context: viewContext)
        note.updatedAt = Date()
        
        // Associate with selected problem
        if let problem = selectedProblem {
            note.addToProblems(problem)
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "保存失败：\(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct ProblemSelectorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedProblem: Problem?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Problem.title, ascending: true)],
        animation: .default)
    private var problems: FetchedResults<Problem>
    
    @State private var searchText = ""
    
    private var filteredProblems: [Problem] {
        problems.filter { problem in
            searchText.isEmpty || 
            (problem.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (problem.source?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (problem.algorithmType?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("选择关联题目")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Search
            HStack {
                TextField("搜索题目...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("清除") {
                    selectedProblem = nil
                    dismiss()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            
            // Problems List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredProblems, id: \.id) { problem in
                        Button(action: {
                            selectedProblem = problem
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(problem.title ?? "Untitled")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 8) {
                                        Text(problem.source ?? "Custom")
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(4)
                                        
                                        if let algorithmType = problem.algorithmType {
                                            Text(algorithmType)
                                                .font(.caption)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.purple.opacity(0.2))
                                                .cornerRadius(4)
                                        }
                                        
                                        Text(problem.difficulty ?? "未知")
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(difficultyColor(problem).opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedProblem?.id == problem.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
    }
    
    private func difficultyColor(_ problem: Problem) -> Color {
        switch problem.difficulty {
        case "简单": return .green
        case "中等": return .orange
        case "困难": return .red
        default: return .gray
        }
    }
}

#Preview {
    AddNoteView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}