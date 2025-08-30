import SwiftUI
import CoreData

struct AddProblemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appConfig) private var appConfig
    
    @State private var title = ""
    @State private var source = "LeetCode"
    @State private var url = ""
    @State private var algorithmType = ""
    @State private var dataStructure = ""
    @State private var difficulty = "中等"
    @State private var skillTags = ""
    @State private var companies = ""
    @State private var tags = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var customSource = ""
    @State private var customAlgorithmType = ""
    @State private var customDataStructure = ""
    @State private var customDifficulty = ""
    @State private var showingCustomSourceInput = false
    @State private var showingCustomAlgorithmTypeInput = false
    @State private var showingCustomDataStructureInput = false
    @State private var showingCustomDifficultyInput = false
    
    // 使用统一配置管理器
    private var sources: [String] { appConfig.allSources }
    private var difficulties: [String] { appConfig.difficulties + ["自定义"] }
    private var algorithmTypes: [String] { appConfig.algorithmTypes + ["自定义"] }
    private var dataStructures: [String] { appConfig.dataStructures + ["自定义"] }
    
    init(preFilledTitle: String = "") {
        self._title = State(initialValue: preFilledTitle)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("添加题目")
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
                        
                        TextField("请输入题目标题", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("来源 *")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if showingCustomSourceInput {
                            HStack {
                                TextField("输入自定义来源", text: $customSource)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button("取消") {
                                    showingCustomSourceInput = false
                                    customSource = ""
                                    source = "LeetCode"
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        } else {
                            HStack {
                                Picker("来源", selection: $source) {
                                    ForEach(sources, id: \.self) { source in
                                        Text(source).tag(source)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .onChange(of: source) { newValue in
                                    if newValue == "自定义" {
                                        showingCustomSourceInput = true
                                        source = "LeetCode"
                                    }
                                }
                                
                                if source == "自定义" {
                                    Button("编辑") {
                                        showingCustomSourceInput = true
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("URL")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("请输入题目链接", text: $url)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // 算法类型和数据结构
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("算法类型")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if showingCustomAlgorithmTypeInput {
                                HStack {
                                    TextField("输入自定义算法类型", text: $customAlgorithmType)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button("取消") {
                                        showingCustomAlgorithmTypeInput = false
                                        customAlgorithmType = ""
                                        algorithmType = ""
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            } else {
                                HStack {
                                    Picker("算法类型", selection: $algorithmType) {
                                        Text("无").tag("")
                                        ForEach(algorithmTypes, id: \.self) { type in
                                            Text(type).tag(type)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .onChange(of: algorithmType) { newValue in
                                        if newValue == "自定义" {
                                            showingCustomAlgorithmTypeInput = true
                                            algorithmType = ""
                                        }
                                    }
                                    
                                    if algorithmType == "自定义" {
                                        Button("编辑") {
                                            showingCustomAlgorithmTypeInput = true
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("数据结构")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if showingCustomDataStructureInput {
                                HStack {
                                    TextField("输入自定义数据结构", text: $customDataStructure)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button("取消") {
                                        showingCustomDataStructureInput = false
                                        customDataStructure = ""
                                        dataStructure = ""
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            } else {
                                HStack {
                                    Picker("数据结构", selection: $dataStructure) {
                                        Text("无").tag("")
                                        ForEach(dataStructures, id: \.self) { structure in
                                            Text(structure).tag(structure)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .onChange(of: dataStructure) { newValue in
                                        if newValue == "自定义" {
                                            showingCustomDataStructureInput = true
                                            dataStructure = ""
                                        }
                                    }
                                    
                                    if dataStructure == "自定义" {
                                        Button("编辑") {
                                            showingCustomDataStructureInput = true
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                    
                    // 难度和公司标签
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("难度")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if showingCustomDifficultyInput {
                                HStack {
                                    TextField("输入自定义难度", text: $customDifficulty)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button("取消") {
                                        showingCustomDifficultyInput = false
                                        customDifficulty = ""
                                        difficulty = "中等"
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            } else {
                                HStack {
                                    Picker("难度", selection: $difficulty) {
                                        ForEach(difficulties, id: \.self) { difficulty in
                                            Text(difficulty).tag(difficulty)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .onChange(of: difficulty) { newValue in
                                        if newValue == "自定义" {
                                            showingCustomDifficultyInput = true
                                            difficulty = "中等"
                                        }
                                    }
                                    
                                    if difficulty == "自定义" {
                                        Button("编辑") {
                                            showingCustomDifficultyInput = true
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("公司标签")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("用逗号分隔，如：Google,Microsoft", text: $companies)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    // 技能标签和普通标签
                    VStack(alignment: .leading, spacing: 8) {
                        Text("技能标签")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("用逗号分隔，如：双指针,滑动窗口", text: $skillTags)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("提示：建议的技能标签：\(appConfig.skillTags.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("其他标签")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("用逗号分隔，如：高频题,经典题", text: $tags)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("提示：用逗号分隔多个标签")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                
                Button("保存") {
                    saveProblem()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(title.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(title.isEmpty)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveProblem() {
        guard !title.isEmpty else {
            alertMessage = "请输入题目标题"
            showingAlert = true
            return
        }
        
        let finalSource: String
        if showingCustomSourceInput {
            finalSource = customSource
            // 添加到自定义来源列表
            appConfig.addCustomSource(customSource)
        } else {
            finalSource = source
        }
        
        let finalAlgorithmType: String?
        if showingCustomAlgorithmTypeInput {
            finalAlgorithmType = customAlgorithmType.isEmpty ? nil : customAlgorithmType
        } else {
            finalAlgorithmType = algorithmType.isEmpty ? nil : algorithmType
        }
        
        let finalDataStructure: String?
        if showingCustomDataStructureInput {
            finalDataStructure = customDataStructure.isEmpty ? nil : customDataStructure
        } else {
            finalDataStructure = dataStructure.isEmpty ? nil : dataStructure
        }
        
        let finalDifficulty: String
        if showingCustomDifficultyInput {
            finalDifficulty = customDifficulty
        } else {
            finalDifficulty = difficulty
        }
        
        let problem = Problem(context: viewContext)
        problem.id = UUID()
        problem.title = title
        problem.source = finalSource
        problem.url = url.isEmpty ? nil : url
        problem.algorithmType = finalAlgorithmType
        problem.dataStructure = finalDataStructure
        problem.difficulty = finalDifficulty
        problem.skillTags = skillTags.isEmpty ? nil : skillTags
        problem.companies = companies.isEmpty ? nil : companies
        problem.mastery = 0
        problem.lastPracticeAt = nil
        
        // 生成相似度哈希（基于标题和算法类型）
        let hashInput = "\(title)\(finalAlgorithmType ?? "")\(finalDataStructure ?? "")"
        // similarityHash is not in the current Core Data model, skipping
        
        // Create initial review plan
        ReviewScheduler.shared.createInitialReviewPlan(for: problem, context: viewContext)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "保存失败：\(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    AddProblemView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}