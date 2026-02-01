import SwiftUI
import UniformTypeIdentifiers

struct DataImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String = ""
    @State private var showWarning = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    @State private var importResult: ImportResult?
    @State private var importError: ImportError?
    @State private var importCompleted = false
    @State private var showExportSheet = false
    
    private let importManager = DataImportManager.shared
    
    var body: some View {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: CloveSpacing.large) {
                        // Header info
                        headerSection
                        
                        // How it works section
                        howItWorksSection
                        
                        // Warning section
                        warningSection
                        
                        // File selection or selected file info
                        if !isImporting && !importCompleted {
                            if selectedFileURL == nil {
                                fileSelectionSection
                            } else {
                                selectedFileSection
                            }
                        }
                        
                        // Warning section (after file selected)
                        if showWarning && !isImporting && !importCompleted {
                            inlineWarningSection
                        }
                        
                        // Import progress
                        if isImporting {
                            importProgressSection
                        }
                        
                        // Import results
                        if importCompleted {
                            importResultSection
                        }
                    }
                    .padding(CloveSpacing.medium)
                }
                
                // Bottom action bar
                if !isImporting && !importCompleted {
                    actionBar
                }
            }
        .background(CloveColors.background)
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showExportSheet) {
            DataExportSheet()
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.small) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Theme.shared.accent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import Your Data")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(CloveColors.primaryText)
                    
                    Text("Restore your health data from a Clove CSV export")
                        .font(.system(size: 16))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
            }
        }
    }
    
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text("How It Works")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(CloveColors.primaryText)
            
            VStack(alignment: .leading, spacing: CloveSpacing.small) {
                HowItWorksStep(
                    number: 1,
                    title: "Select CSV File",
                    description: "Choose a CSV file previously exported from Clove"
                )
                
                HowItWorksStep(
                    number: 2,
                    title: "Validation",
                    description: "We'll check the file format and data integrity"
                )
                
                HowItWorksStep(
                    number: 3,
                    title: "Import",
                    description: "Your logs, symptoms, and bowel movements will be restored"
                )
            }
        }
    }
    
    private var warningSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack(spacing: CloveSpacing.small) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                
                Text("Important Warning")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)
            }
            
            Text("Importing will completely replace all existing data in Clove. Make sure to export a backup of your current data before proceeding. This action cannot be undone.")
                .font(.system(size: 14))
                .foregroundStyle(CloveColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var fileSelectionSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text("Select File")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(CloveColors.primaryText)
            
            Button(action: {
                showFilePicker = true
            }) {
                HStack(spacing: CloveSpacing.medium) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.shared.accent)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose CSV File")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(CloveColors.primaryText)
                        
                        Text("Select a CSV file exported from Clove")
                            .font(.system(size: 14))
                            .foregroundStyle(CloveColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                .padding(CloveSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(CloveColors.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .stroke(Theme.shared.accent.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var importProgressSection: some View {
        VStack(spacing: CloveSpacing.large) {
            Text("Importing Your Data")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(CloveColors.primaryText)
            
            VStack(spacing: CloveSpacing.medium) {
                ProgressView(value: importProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: Theme.shared.accent))
                
                Text("\(Int(importProgress * 100))% Complete")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CloveColors.secondaryText)
            }
            
            Text("Please don't close the app while importing...")
                .font(.system(size: 14))
                .foregroundStyle(CloveColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(CloveSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.large)
                .fill(CloveColors.card)
        )
    }
    
    private var selectedFileSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            Text("Selected File")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(CloveColors.primaryText)
            
            HStack(spacing: CloveSpacing.medium) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(CloveColors.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedFileName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(CloveColors.primaryText)
                        .lineLimit(2)
                    
                    Text("CSV file ready for import")
                        .font(.system(size: 14))
                        .foregroundStyle(CloveColors.secondaryText)
                }
                
                Spacer()
                
                Button("Change") {
                    selectedFileURL = nil
                    selectedFileName = ""
                    showWarning = false
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.shared.accent)
            }
            .padding(CloveSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(CloveColors.green.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: CloveCorners.medium)
                            .stroke(CloveColors.green.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    private var inlineWarningSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack(spacing: CloveSpacing.small) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.red)
                
                Text("Data Override Warning")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)
            }
            
            Text("Importing will completely replace ALL existing data in Clove. This action cannot be undone. Make sure you've exported a backup first.")
                .font(.system(size: 14))
                .foregroundStyle(CloveColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: CloveSpacing.medium) {
                Button("Cancel") {
                    selectedFileURL = nil
                    selectedFileName = ""
                    showWarning = false
                }
                .foregroundStyle(CloveColors.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(CloveColors.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: CloveCorners.medium)
                                .stroke(CloveColors.secondaryText.opacity(0.3), lineWidth: 1)
                        )
                )
                
                Button("Import Data") {
                    if let fileURL = selectedFileURL {
                        startImport(fileURL: fileURL)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(.red)
                )
            }
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var importResultSection: some View {
        VStack(alignment: .leading, spacing: CloveSpacing.medium) {
            HStack(spacing: CloveSpacing.small) {
                Image(systemName: importResult != nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(importResult != nil ? CloveColors.success : CloveColors.error)
                
                Text(importResult != nil ? "Import Successful" : "Import Failed")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(CloveColors.primaryText)
            }
            
            Text(resultMessage)
                .font(.system(size: 14))
                .foregroundStyle(CloveColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            Button("Done") {
                dismiss()
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: CloveCorners.medium)
                    .fill(Theme.shared.accent)
            )
        }
        .padding(CloveSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CloveCorners.medium)
                .fill((importResult != nil ? CloveColors.success : CloveColors.error).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .stroke((importResult != nil ? CloveColors.success : CloveColors.error).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var actionBar: some View {
        VStack(spacing: CloveSpacing.small) {
            Divider()
            
            HStack(spacing: CloveSpacing.medium) {
                Button("Export Backup First") {
                    showExportSheet = true
                }
                .foregroundStyle(CloveColors.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(CloveColors.background)
                )
                
                Button("Select CSV File") {
                    showFilePicker = true
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: CloveCorners.medium)
                        .fill(Theme.shared.accent)
                )
            }
            .padding(CloveSpacing.medium)
        }
        .background(CloveColors.card)
    }
    
    // MARK: - Helper Methods
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFileURL = url
            selectedFileName = url.lastPathComponent
            showWarning = true
            
        case .failure(_):
            importError = ImportError.fileReadError
            importCompleted = true
        }
    }
    
    private func startImport(fileURL: URL) {
        isImporting = true
        importProgress = 0.0
        
        importManager.importFromCSV(fileURL: fileURL) { result in
            DispatchQueue.main.async {
                self.isImporting = false
                self.importCompleted = true
                
                switch result {
                case .success(let result):
                    self.importResult = result
                    
                    ToastManager.shared.showToast(
                        message: "Data imported successfully",
                        color: CloveColors.success,
                        icon: Image(systemName: "checkmark.circle")
                    )
                    
                case .failure(let error):
                    self.importError = error
                }
            }
        }
    }
    
    private var resultMessage: String {
        if let result = importResult {
            return """
            Import completed successfully!
            
            • \(result.importedLogsCount) logs imported
            • \(result.createdSymptomsCount) symptoms created
            • \(result.createdBowelMovementsCount) bowel movements imported
            \(result.skippedRowsCount > 0 ? "• \(result.skippedRowsCount) rows skipped" : "")
            """
        } else if let error = importError {
            return error.localizedDescription + "\n\n" + (error.recoverySuggestion ?? "")
        } else {
            return "Import completed"
        }
    }
}

// MARK: - How It Works Step Component
struct HowItWorksStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: CloveSpacing.medium) {
            // Step number
            ZStack {
                Circle()
                    .fill(Theme.shared.accent)
                    .frame(width: 28, height: 28)
                
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            // Step content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CloveColors.primaryText)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(CloveColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        DataImportView()
    }
}
