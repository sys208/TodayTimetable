import PhotosUI
import SwiftUI
import UIKit

struct BarcodeCardListView: View {
    let school: School
    @State private var store = BarcodeCardStore.shared
    @State private var showEditor = false
    @State private var editingCard: BarcodeCard?

    var body: some View {
        List {
            if store.cards.isEmpty {
                ContentUnavailableView(
                    "등록된 카드 없음",
                    systemImage: "barcode.viewfinder",
                    description: Text("도서관 대출증이나 학생 바코드 카드를 등록할 수 있습니다.")
                )
            } else {
                ForEach(store.cards) { card in
                    NavigationLink {
                        BarcodeCardDetailView(card: card)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "barcode")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(card.schoolName)
                                    .font(.headline)
                                Text("\(card.grade)학년 \(card.classNumber)반 \(card.studentNumber)번 \(card.studentName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            store.delete(card)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }

                        Button {
                            editingCard = card
                            showEditor = true
                        } label: {
                            Label("편집", systemImage: "pencil")
                        }
                    }
                }
            }
        }
        .navigationTitle("바코드 카드")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingCard = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            BarcodeCardEditorView(school: school, existing: editingCard)
        }
    }
}

struct BarcodeCardEditorView: View {
    let school: School
    let existing: BarcodeCard?

    @Environment(\.dismiss) private var dismiss
    @State private var store = BarcodeCardStore.shared
    @State private var schoolName: String
    @State private var grade: Int
    @State private var classNumber: String
    @State private var studentNumber: String
    @State private var studentName: String
    @State private var barcodeValue: String
    @State private var barcodeFormat: BarcodeCard.BarcodeFormat
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showScanner = false

    init(school: School, existing: BarcodeCard?) {
        self.school = school
        self.existing = existing
        _schoolName = State(initialValue: existing?.schoolName ?? school.name)
        _grade = State(initialValue: existing?.grade ?? school.grade)
        _classNumber = State(initialValue: existing?.classNumber ?? school.classNumber)
        _studentNumber = State(initialValue: existing?.studentNumber ?? "")
        _studentName = State(initialValue: existing?.studentName ?? "")
        _barcodeValue = State(initialValue: existing?.barcodeValue ?? "")
        _barcodeFormat = State(initialValue: existing?.barcodeFormat ?? .code128)
        _photoData = State(initialValue: existing?.photoData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("카드 정보") {
                    TextField("학교", text: $schoolName)
                    Stepper("\(grade)학년", value: $grade, in: 1...6)
                    TextField("반", text: $classNumber)
                    TextField("번호", text: $studentNumber)
                        .keyboardType(.numberPad)
                    TextField("이름", text: $studentName)
                }

                Section("사진") {
                    HStack {
                        profileImage
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(photoData == nil ? "사진 선택" : "사진 변경", systemImage: "photo")
                        }
                    }
                }

                Section("바코드") {
                    Picker("형식", selection: $barcodeFormat) {
                        ForEach(BarcodeCard.BarcodeFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    TextField("바코드 값", text: $barcodeValue)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        showScanner = true
                    } label: {
                        Label("카메라로 스캔", systemImage: "barcode.viewfinder")
                    }
                }

                if let image = BarcodeImageService.image(for: barcodeValue, format: barcodeFormat, scale: barcodeFormat == .qr ? 8 : 3) {
                    Section("미리보기") {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle(existing == nil ? "카드 등록" : "카드 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: selectedPhoto) {
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                NavigationStack {
                    BarcodeScannerView { value, format in
                        barcodeValue = value
                        barcodeFormat = format
                        showScanner = false
                    }
                    .ignoresSafeArea()
                    .navigationTitle("바코드 스캔")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("닫기") { showScanner = false }
                        }
                    }
                }
            }
        }
    }

    private var profileImage: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.square")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var canSave: Bool {
        !schoolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !studentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let card = BarcodeCard(
            id: existing?.id ?? UUID(),
            schoolName: schoolName.trimmingCharacters(in: .whitespacesAndNewlines),
            grade: grade,
            classNumber: classNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            studentNumber: studentNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            studentName: studentName.trimmingCharacters(in: .whitespacesAndNewlines),
            barcodeValue: barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines),
            barcodeFormat: barcodeFormat,
            photoData: photoData,
            createdAt: existing?.createdAt ?? Date()
        )
        store.save(card)
    }
}

struct BarcodeCardDetailView: View {
    let card: BarcodeCard
    @State private var showFullScreen = false
    @State private var isAddingToWallet = false
    @State private var alertMessage: String?
    @State private var showWalletAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                cardPreview

                Button {
                    showFullScreen = true
                } label: {
                    Label("크게 보기", systemImage: "barcode")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task { await addToWallet() }
                } label: {
                    if isAddingToWallet {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Apple Wallet에 추가", systemImage: "wallet.pass")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isAddingToWallet)
            }
            .padding()
        }
        .navigationTitle("바코드 카드")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showFullScreen) {
            BarcodeFullScreenView(card: card)
        }
        .alert("Wallet 추가", isPresented: $showWalletAlert) {
            Button("확인") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var cardPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                if let data = card.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 68, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(card.schoolName)
                        .font(.title3.bold())
                    Text("\(card.grade)학년 \(card.classNumber)반")
                        .font(.headline)
                    Text("\(card.studentNumber)번 \(card.studentName)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let image = BarcodeImageService.image(for: card.barcodeValue, format: card.barcodeFormat, scale: card.barcodeFormat == .qr ? 10 : 4) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(card.barcodeValue)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func addToWallet() async {
        isAddingToWallet = true
        defer { isAddingToWallet = false }
        do {
            try await BarcodeWalletService.shared.addToWallet(card: card)
        } catch {
            alertMessage = (error as NSError).localizedDescription
            showWalletAlert = true
        }
    }
}

struct BarcodeFullScreenView: View {
    let card: BarcodeCard
    @Environment(\.dismiss) private var dismiss
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(card.schoolName)
                        .font(.title2.bold())
                        .foregroundStyle(.black)
                    Text("\(card.grade)학년 \(card.classNumber)반 \(card.studentNumber)번 \(card.studentName)")
                        .font(.callout)
                        .foregroundStyle(.black.opacity(0.65))
                }

                if let image = BarcodeImageService.image(for: card.barcodeValue, format: card.barcodeFormat, scale: card.barcodeFormat == .qr ? 14 : 6) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: card.barcodeFormat == .qr ? 320 : 180)
                        .padding(.horizontal, 20)
                }

                Text(card.barcodeValue)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.black.opacity(0.65))

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.black.opacity(0.7))
                }
                .padding(.top, 16)
            }
            .padding()
        }
        .onAppear {
            previousBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1
        }
        .onDisappear {
            UIScreen.main.brightness = previousBrightness
        }
    }
}
