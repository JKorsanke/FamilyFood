import PDFKit
import UIKit

/// Extracts content from a shared PDF for the two import paths:
/// - meal plan → text (`extractText`, with OCR fallback handled by the caller),
/// - recipe → rendered page image (`firstPageImage`) fed to the existing `OCRRecipeParser`.
struct PDFImportRenderer {
    let document: PDFDocument?

    init(data: Data) { document = PDFDocument(data: data) }

    /// Concatenated text layer across all pages. May be empty/short for scanned PDFs —
    /// the caller falls back to OCR on `firstPageImage()` in that case.
    func extractText() throws -> String {
        guard let document else { return "" }
        return (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
    }

    /// Renders the first page to an image (white background) for OCR-based recipe import.
    func firstPageImage(scale: CGFloat = 2) -> UIImage? {
        guard let page = document?.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: bounds.width * scale,
                                                            height: bounds.height * scale))
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))
            ctx.cgContext.translateBy(x: 0, y: bounds.height * scale)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}
