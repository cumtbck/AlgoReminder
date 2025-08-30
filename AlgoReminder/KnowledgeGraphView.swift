import SwiftUI
import CoreData
import SceneKit

struct KnowledgeGraphView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var graphData: GraphData
    @State private var selectedNode: GraphNode?
    @State private var showNodeDetail = false
    @State private var filterType: FilterType = .all
    @State private var searchText = ""
    
    enum FilterType: String, CaseIterable {
        case all = "全部"
        case problems = "题目"
        case notes = "笔记"
        case algorithms = "算法"
        case dataStructures = "数据结构"
    }
    
    init(context: NSManagedObjectContext) {
        self._graphData = State(initialValue: GraphData(context: context))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("知识图谱")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Filter controls
                Picker("筛选类型", selection: $filterType) {
                    ForEach(FilterType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: 120)
                
                TextField("搜索节点...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 200)
                
                Button("刷新") {
                    graphData.refresh(context: viewContext)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Graph content
            VStack {
                if graphData.nodes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("暂无数据")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("添加一些题目和笔记来构建知识图谱")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    SceneView(
                        scene: graphData.createScene(
                            filter: filterType,
                            searchText: searchText
                        ),
                        options: [.allowsCameraControl, .autoenablesDefaultLighting]
                    )
                    .onTapGesture { location in
                        handleTap(at: location)
                    }
                    .overlay(
                        // Legend
                        VStack(alignment: .leading, spacing: 8) {
                            Text("图例")
                                .font(.headline)
                            
                            HStack(spacing: 16) {
                                LegendItem(color: .red, label: "题目")
                                LegendItem(color: .blue, label: "笔记")
                                LegendItem(color: .green, label: "算法")
                                LegendItem(color: .orange, label: "数据结构")
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
                        .cornerRadius(8)
                        .padding([.leading, .bottom]),
                        alignment: .bottomLeading
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $showNodeDetail) {
            if let node = selectedNode {
                NodeDetailView(node: node, context: viewContext)
            }
        }
    }
    
    private func handleTap(at location: CGPoint) {
        // 这里应该实现节点点击检测逻辑
        // 由于SceneKit的复杂性，这里简化处理
        if let randomNode = graphData.nodes.randomElement() {
            selectedNode = randomNode
            showNodeDetail = true
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NodeDetailView: View {
    let node: GraphNode
    let context: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(node.title)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Basic info
                    Group {
                        HStack {
                            Text("类型:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(node.type.rawValue)
                                .font(.subheadline)
                        }
                        
                        if let subtitle = node.subtitle {
                            HStack {
                                Text("描述:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(subtitle)
                                    .font(.subheadline)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Connections
                    VStack(alignment: .leading, spacing: 8) {
                        Text("关联节点")
                            .font(.headline)
                        
                        if node.connections.isEmpty {
                            Text("暂无关联节点")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(node.connections.prefix(10), id: \.title) { connectedNode in
                                HStack {
                                    Circle()
                                        .fill(nodeColor(for: connectedNode.type))
                                        .frame(width: 8, height: 8)
                                    
                                    Text(connectedNode.title)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    Text(connectedNode.type.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            if node.connections.count > 10 {
                                Text("还有 \(node.connections.count - 10) 个关联节点...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Action buttons based on node type
                    if node.type == .problem {
                        actionButtonsForProblem()
                    } else if node.type == .note {
                        actionButtonsForNote()
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func nodeColor(for type: GraphNode.NodeType) -> Color {
        switch type {
        case .problem: return .red
        case .note: return .blue
        case .algorithm: return .green
        case .dataStructure: return .orange
        }
    }
    
    @ViewBuilder
    private func actionButtonsForProblem() -> some View {
        // 这里可以添加题目相关的操作按钮
        HStack {
            Button("查看题目详情") {
                // 实现查看题目详情的逻辑
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private func actionButtonsForNote() -> some View {
        // 这里可以添加笔记相关的操作按钮
        HStack {
            Button("查看笔记内容") {
                // 实现查看笔记内容的逻辑
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}

// MARK: - Graph Data Model

class GraphData: ObservableObject {
    @Published var nodes: [GraphNode] = []
    @Published var edges: [GraphEdge] = []
    
    private var context: NSManagedObjectContext?
    
    init(context: NSManagedObjectContext) {
        self.context = context
        refresh(context: context)
    }
    
    func refresh(context: NSManagedObjectContext) {
        self.context = context
        buildGraph()
    }
    
    private func buildGraph() {
        guard let context = context else { return }
        
        nodes.removeAll()
        edges.removeAll()
        
        // Add problem nodes
        let problemRequest: NSFetchRequest<Problem> = Problem.fetchRequest()
        do {
            let problems = try context.fetch(problemRequest)
            for problem in problems {
                let node = GraphNode(
                    id: problem.id!,
                    title: problem.title ?? "Untitled",
                    type: .problem,
                    subtitle: problem.algorithmType ?? problem.dataStructure,
                    data: problem
                )
                nodes.append(node)
            }
        } catch {
            print("Error fetching problems: \(error)")
        }
        
        // Add note nodes
        let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
        do {
            let notes = try context.fetch(noteRequest)
            for note in notes {
                let node = GraphNode(
                    id: note.id!,
                    title: note.title ?? "Untitled Note",
                    type: .note,
                    subtitle: note.noteType,
                    data: note
                )
                nodes.append(node)
            }
        } catch {
            print("Error fetching notes: \(error)")
        }
        
        // Add algorithm type nodes
        let algorithmTypes = Set(nodes.compactMap { ($0.data as? Problem)?.algorithmType }.compactMap { $0 })
        for algorithmType in algorithmTypes {
            let node = GraphNode(
                id: UUID(),
                title: algorithmType,
                type: .algorithm,
                subtitle: "算法类型",
                data: algorithmType
            )
            nodes.append(node)
        }
        
        // Add data structure nodes
        let dataStructures = Set(nodes.compactMap { ($0.data as? Problem)?.dataStructure }.compactMap { $0 })
        for dataStructure in dataStructures {
            let node = GraphNode(
                id: UUID(),
                title: dataStructure,
                type: .dataStructure,
                subtitle: "数据结构",
                data: dataStructure
            )
            nodes.append(node)
        }
        
        // Build edges
        buildEdges()
    }
    
    private func buildEdges() {
        guard let context = context else { return }
        
        // Problem to algorithm/data structure edges
        for node in nodes {
            if case .problem = node.type, let problem = node.data as? Problem {
                if let algorithmType = problem.algorithmType {
                    if let algorithmNode = nodes.first(where: { 
                        $0.type == .algorithm && $0.title == algorithmType 
                    }) {
                        edges.append(GraphEdge(from: node, to: algorithmNode))
                    }
                }
                
                if let dataStructure = problem.dataStructure {
                    if let dsNode = nodes.first(where: { 
                        $0.type == .dataStructure && $0.title == dataStructure 
                    }) {
                        edges.append(GraphEdge(from: node, to: dsNode))
                    }
                }
            }
            
            // Problem to note edges
            if case .problem = node.type, let problem = node.data as? Problem {
                if let notes = problem.notes?.allObjects as? [Note] {
                    for note in notes {
                        if let noteNode = nodes.first(where: { 
                            $0.type == .note && $0.id == note.id 
                        }) {
                            edges.append(GraphEdge(from: node, to: noteNode))
                        }
                    }
                }
            }
        }
        
        // Update node connections
        for i in nodes.indices {
            nodes[i].connections = edges.filter { edge in
                edge.from.id == nodes[i].id || edge.to.id == nodes[i].id
            }.compactMap { edge in
                edge.from.id == nodes[i].id ? edge.to : edge.from
            }
        }
    }
    
    func createScene(filter: KnowledgeGraphView.FilterType, searchText: String) -> SCNScene {
        let scene = SCNScene()
        
        // Filter nodes based on filter and search
        let filteredNodes = nodes.filter { node in
            switch filter {
            case .all:
                return true
            case .problems:
                return node.type == .problem
            case .notes:
                return node.type == .note
            case .algorithms:
                return node.type == .algorithm
            case .dataStructures:
                return node.type == .dataStructure
            }
        }.filter { node in
            searchText.isEmpty || node.title.localizedCaseInsensitiveContains(searchText)
        }
        
        // Create nodes
        for (index, node) in filteredNodes.enumerated() {
            let geometry = SCNSphere(radius: 0.5)
            geometry.firstMaterial?.diffuse.contents = nodeColor(for: node.type)
            
            let scnNode = SCNNode(geometry: geometry)
            
            // Position nodes in a circle
            let angle = Double(index) / Double(filteredNodes.count) * 2 * Double.pi
            let radius = 5.0
            scnNode.position = SCNVector3(
                Float(radius * cos(angle)),
                Float.random(in: -2...2),
                Float(radius * sin(angle))
            )
            
            scene.rootNode.addChildNode(scnNode)
        }
        
        // Create edges
        for edge in edges {
            guard filteredNodes.contains(where: { $0.id == edge.from.id }), filteredNodes.contains(where: { $0.id == edge.to.id }) else { continue }
            
            let fromPosition = SCNVector3Zero
            let toPosition = SCNVector3Zero
            
            let lineNode = createLineNode(from: fromPosition, to: toPosition)
            scene.rootNode.addChildNode(lineNode)
        }
        
        // Add camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 10, 15)
        cameraNode.eulerAngles = SCNVector3(-Double.pi/6, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
        
        return scene
    }
    
    private func createLineNode(from: SCNVector3, to: SCNVector3) -> SCNNode {
        let indices: [Int32] = [0, 1]
        let source = SCNGeometrySource(vertices: [from, to])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        
        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial?.diffuse.contents = NSColor.gray
        
        return SCNNode(geometry: geometry)
    }
    
    private func nodeColor(for type: GraphNode.NodeType) -> NSColor {
        switch type {
        case .problem: return .systemRed
        case .note: return .systemBlue
        case .algorithm: return .systemGreen
        case .dataStructure: return .systemOrange
        }
    }
}

// MARK: - Graph Node and Edge Models

struct GraphNode: Identifiable {
    let id: UUID
    let title: String
    let type: NodeType
    let subtitle: String?
    var data: Any?
    var connections: [GraphNode] = []
    
    enum NodeType: String, CaseIterable {
        case problem = "题目"
        case note = "笔记"
        case algorithm = "算法"
        case dataStructure = "数据结构"
    }
}

struct GraphEdge {
    let from: GraphNode
    let to: GraphNode
}

// MARK: - Preview

#Preview {
    KnowledgeGraphView(context: PersistenceController.preview.container.viewContext)
}