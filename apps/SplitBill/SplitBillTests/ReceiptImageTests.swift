import Foundation
import Testing
import UIKit
@testable import SplitBill

@Suite("ReceiptImage Tests")
@MainActor
struct ReceiptImageTests {

    private func makeTestImage(
        width: CGFloat,
        height: CGFloat,
        color: UIColor = .systemBlue,
        orientation: UIImage.Orientation = .up
    ) -> UIImage {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let baseImage = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        if orientation == .up {
            return baseImage
        }
        guard let cg = baseImage.cgImage else { return baseImage }
        return UIImage(cgImage: cg, scale: 1.0, orientation: orientation)
    }

    @Test("Resizes large image exceeding 2048px while maintaining aspect ratio")
    func resizesLargeImage() throws {
        // 3000 x 1500 (Landscape 2:1)
        let original = makeTestImage(width: 3000, height: 1500)
        let processedData = try #require(ReceiptImageProcessor.process(original, maxDimension: 2048))
        let resultImage = try #require(UIImage(data: processedData))

        #expect(resultImage.size.width <= 2048)
        #expect(resultImage.size.height <= 2048)
        #expect(resultImage.size.width == 2048)
        #expect(resultImage.size.height == 1024)

        let originalRatio = original.size.width / original.size.height
        let resultRatio = resultImage.size.width / resultImage.size.height
        #expect(abs(originalRatio - resultRatio) < 0.01)
    }

    @Test("Resizes portrait ticket image (height > width) accurately")
    func resizesPortraitTicketImage() throws {
        // 1500 x 3000 (Portrait 1:2, standard receipt shape)
        let original = makeTestImage(width: 1500, height: 3000)
        let processedData = try #require(ReceiptImageProcessor.process(original, maxDimension: 2048))
        let resultImage = try #require(UIImage(data: processedData))

        #expect(resultImage.size.width <= 2048)
        #expect(resultImage.size.height <= 2048)
        #expect(resultImage.size.width == 1024)
        #expect(resultImage.size.height == 2048)

        let originalRatio = original.size.width / original.size.height
        let resultRatio = resultImage.size.width / resultImage.size.height
        #expect(abs(originalRatio - resultRatio) < 0.01)
    }

    @Test("Does not upscale small image that is already within maxDimension")
    func doesNotUpscaleSmallImage() throws {
        let original = makeTestImage(width: 800, height: 600)
        let processedData = try #require(ReceiptImageProcessor.process(original, maxDimension: 2048))
        let resultImage = try #require(UIImage(data: processedData))

        #expect(resultImage.size.width == 800)
        #expect(resultImage.size.height == 600)
    }

    @Test("Normalizes EXIF image orientation to .up")
    func normalizesOrientationToUp() throws {
        let orientedImage = makeTestImage(width: 600, height: 400, orientation: .right)
        #expect(orientedImage.imageOrientation == .right)

        let processedData = try #require(ReceiptImageProcessor.process(orientedImage))
        let resultImage = try #require(UIImage(data: processedData))

        #expect(resultImage.imageOrientation == .up)
    }

    @Test("Corrupted data cleanly returns nil")
    func corruptedDataReturnsNil() {
        let corruptData = Data("this is not an image format".utf8)
        let result = ReceiptImageProcessor.process(data: corruptData)
        #expect(result == nil)
    }

    @Test("Zero-dimension or invalid image returns nil")
    func invalidZeroDimensionsReturnsNil() {
        let zeroImage = UIImage()
        let result = ReceiptImageProcessor.process(zeroImage)
        #expect(result == nil)
    }

    @Test(
        "Generates valid receipt image and data for all sample presets",
        arguments: SampleReceiptPreset.allCases
    )
    func generatesValidImageForAllPresets(preset: SampleReceiptPreset) throws {
        let image = SampleReceiptImageGenerator.generateImage(for: preset)
        #expect(image.size.width == SampleReceiptImageGenerator.receiptWidth)
        #expect(image.size.height > 300)

        let data = SampleReceiptImageGenerator.generateImageData(for: preset)
        #expect(!data.isEmpty)

        let decoded = try #require(UIImage(data: data))
        #expect(decoded.size.width == SampleReceiptImageGenerator.receiptWidth)
        #expect(decoded.size.height > 300)
    }

    @Test("ReceiptSnapshot and SwiftDataReceiptStore round-trip with image data and update to nil")
    func roundTripReceiptImageDataInStore() throws {
        let store = try SwiftDataReceiptStore.inMemory()

        let samplePreset = SampleReceiptPreset.taqueriaElPastor
        let sampleData = SampleReceiptImageGenerator.generateImageData(for: samplePreset)
        #expect(!sampleData.isEmpty)

        let p1 = try Participant(name: "Ana")
        let item1 = try ReceiptItem(
            name: "Tacos al Pastor",
            unitPrice: Money(amountInMinorUnits: 17_000, currency: .mxn),
            quantity: 1,
            splitMode: .wholeItem(p1.id)
        )

        var snapshot = ReceiptSnapshot(
            id: UUID(),
            title: "Taquería El Pastor Ticket",
            currency: .mxn,
            participants: [p1],
            items: [item1],
            receiptImageData: sampleData
        )

        // 1. Save snapshot with image data
        try store.save(snapshot)

        // 2. Fetch and verify receiptImageData persisted faithfully
        let loaded = try #require(try store.fetch(id: snapshot.id))
        #expect(loaded.receiptImageData != nil)
        #expect(loaded.receiptImageData == sampleData)
        #expect(loaded.title == "Taquería El Pastor Ticket")

        // 3. Update snapshot clearing the image data
        snapshot.receiptImageData = nil
        snapshot.updatedAt = Date()
        try store.save(snapshot)

        // 4. Fetch again and verify image data was cleanly removed
        let reloaded = try #require(try store.fetch(id: snapshot.id))
        #expect(reloaded.receiptImageData == nil)
        #expect(reloaded.title == "Taquería El Pastor Ticket")
        #expect(reloaded.participants.count == 1)
        #expect(reloaded.items.count == 1)
    }
}

// MARK: - ViewModel Lifecycle & Persistence Tests

@Suite("ReceiptEditorViewModel Image Lifecycle Tests")
@MainActor
struct ReceiptEditorViewModelImageLifecycleTests {

    @Test("Attaching image as only content automatically persists the session")
    func attachingImageAsOnlyContentPersistsAutomatically() throws {
        let store = try SwiftDataReceiptStore.inMemory()
        let vm = ReceiptEditorViewModel(store: store)

        #expect(vm.receiptImageData == nil)
        #expect(!vm.hasReceiptImage)
        #expect(try store.fetchAll().isEmpty)

        vm.attachSampleReceipt(.taqueriaElPastor)

        #expect(vm.hasReceiptImage)
        #expect(vm.receiptImageData != nil)
        #expect(vm.validationMessage == nil)

        let saved = try store.fetchAll()
        #expect(saved.count == 1)
        #expect(saved.first?.id == vm.receiptID)
        #expect(saved.first?.receiptImageData == vm.receiptImageData)
    }

    @Test("Relaunching ViewModel restores receiptImageData from store")
    func relaunchingViewModelRestoresReceiptImageData() throws {
        let store = try SwiftDataReceiptStore.inMemory()
        let vm1 = ReceiptEditorViewModel(store: store)
        vm1.attachSampleReceipt(.cafeCentral)

        let savedImage = try #require(vm1.receiptImageData)

        let vm2 = ReceiptEditorViewModel(store: store)
        #expect(vm2.receiptID == vm1.receiptID)
        #expect(vm2.hasReceiptImage)
        #expect(vm2.receiptImageData == savedImage)
    }

    @Test("attachSampleReceipt attaches and persists sample image correctly")
    func attachSampleReceiptAttachesAndPersistsSampleCorrectly() throws {
        let store = try SwiftDataReceiptStore.inMemory()
        let vm = ReceiptEditorViewModel(store: store)

        let expectedData = SampleReceiptImageGenerator.generateImageData(for: .pizzeriaNapoli)
        vm.attachSampleReceipt(.pizzeriaNapoli)

        #expect(vm.hasReceiptImage)
        #expect(vm.receiptImageData == expectedData)
        #expect(vm.validationMessage == nil)

        let fetched = try #require(try store.fetch(id: vm.receiptID))
        #expect(fetched.receiptImageData == expectedData)
    }

    @Test("removeReceiptImage clears receiptImageData and updates persistence")
    func removeReceiptImageClearsDataAndUpdatesPersistence() throws {
        let store = try SwiftDataReceiptStore.inMemory()
        let vm = ReceiptEditorViewModel(store: store)
        vm.receiptTitle = "Cena con amigos"
        vm.attachSampleReceipt(.taqueriaElPastor)

        #expect(vm.hasReceiptImage)
        let fetchedWithImage = try #require(try store.fetch(id: vm.receiptID))
        #expect(fetchedWithImage.receiptImageData != nil)

        vm.removeReceiptImage()

        #expect(!vm.hasReceiptImage)
        #expect(vm.receiptImageData == nil)

        let fetchedWithoutImage = try #require(try store.fetch(id: vm.receiptID))
        #expect(fetchedWithoutImage.receiptImageData == nil)
        #expect(fetchedWithoutImage.title == "Cena con amigos")
    }

    @Test("removeReceiptImage when image was sole content cleans up orphan record from store")
    func removeReceiptImageWhenSoleContentDeletesOrphanFromStore() throws {
        let store = try SwiftDataReceiptStore.inMemory()
        let vm = ReceiptEditorViewModel(store: store)

        // 1. Attach sample receipt to blank account -> auto-saved to store
        vm.attachSampleReceipt(.taqueriaElPastor)
        #expect(vm.hasReceiptImage)
        #expect(try store.fetchAll().count == 1)

        // 2. Remove receipt image when no other content exists
        vm.removeReceiptImage()

        #expect(!vm.hasReceiptImage)
        #expect(vm.receiptImageData == nil)
        #expect(vm.validationMessage == nil)

        // 3. Verify orphan was deleted from store rather than resurrecting on reload
        #expect(try store.fetchAll().isEmpty)
        #expect(vm.savedReceipts.isEmpty)
    }

    @Test("Switching between receipts with and without photo restores state accurately")
    func switchingReceiptsWithAndWithoutPhotoRestoresState() throws {
        let store = try SwiftDataReceiptStore.inMemory()
        let vm = ReceiptEditorViewModel(store: store)

        // 1. Create Receipt 1 with photo
        vm.receiptTitle = "Cuenta Café"
        vm.attachSampleReceipt(.cafeCentral)
        let receipt1ID = vm.receiptID
        let receipt1ImageData = try #require(vm.receiptImageData)

        // 2. Create Receipt 2 without photo
        vm.startNewReceipt()
        vm.receiptTitle = "Cuenta Tacos"
        let p1 = try Participant(name: "Carlos")
        vm.participants = [p1]
        vm.persistCurrentSession()
        let receipt2ID = vm.receiptID

        #expect(receipt1ID != receipt2ID)
        #expect(vm.receiptImageData == nil)
        #expect(!vm.hasReceiptImage)

        // 3. Switch back to Receipt 1
        vm.selectReceipt(id: receipt1ID)
        #expect(vm.receiptID == receipt1ID)
        #expect(vm.receiptTitle == "Cuenta Café")
        #expect(vm.hasReceiptImage)
        #expect(vm.receiptImageData == receipt1ImageData)

        // 4. Switch back to Receipt 2
        vm.selectReceipt(id: receipt2ID)
        #expect(vm.receiptID == receipt2ID)
        #expect(vm.receiptTitle == "Cuenta Tacos")
        #expect(!vm.hasReceiptImage)
        #expect(vm.receiptImageData == nil)
    }

    @Test("Corrupt data in attachReceiptImageData exposes validation message and preserves state")
    func corruptDataInAttachReceiptImageDataExposesErrorAndPreservesState() throws {
        let store = try SwiftDataReceiptStore.inMemory()
        let vm = ReceiptEditorViewModel(store: store)

        // Initially attach a valid sample image
        vm.attachSampleReceipt(.taqueriaElPastor)
        let originalData = try #require(vm.receiptImageData)
        #expect(vm.validationMessage == nil)

        // Attempt attaching corrupt non-image bytes
        let corruptData = Data("this is not an image format".utf8)
        vm.attachReceiptImageData(corruptData)

        #expect(vm.validationMessage == "No se pudo procesar la imagen seleccionada.")
        #expect(vm.receiptImageData == originalData)
        #expect(vm.hasReceiptImage)

        // Attaching valid data clears the validation message
        let validSample = SampleReceiptImageGenerator.generateImageData(for: .cafeCentral)
        vm.attachReceiptImageData(validSample)

        #expect(vm.validationMessage == nil)
        #expect(vm.receiptImageData != originalData)
        #expect(vm.hasReceiptImage)
    }
}
