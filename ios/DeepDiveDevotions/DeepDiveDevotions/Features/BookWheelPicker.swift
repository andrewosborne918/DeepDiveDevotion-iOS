import SwiftUI
import UIKit

struct BookWheelPicker: UIViewRepresentable {
    let books: [String]
    @Binding var selection: String

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.delegate = context.coordinator
        picker.dataSource = context.coordinator
        picker.backgroundColor = .clear
        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        context.coordinator.books = books
        context.coordinator.selection = $selection
        uiView.reloadAllComponents()

        if let index = books.firstIndex(of: selection), index < books.count {
            uiView.selectRow(index, inComponent: 0, animated: false)
        } else if let first = books.first {
            selection = first
            uiView.selectRow(0, inComponent: 0, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(books: books, selection: $selection)
    }

    final class Coordinator: NSObject, UIPickerViewDelegate, UIPickerViewDataSource {
        var books: [String]
        var selection: Binding<String>

        init(books: [String], selection: Binding<String>) {
            self.books = books
            self.selection = selection
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            books.count
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            42
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            pickerView.bounds.width - 20
        }

        func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
            guard row < books.count else { return nil }
            return NSAttributedString(
                string: books[row],
                attributes: [
                    .foregroundColor: UIColor(Color.dddIvory),
                    .font: UIFont.systemFont(ofSize: 30, weight: .semibold),
                ]
            )
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            guard row < books.count else { return }
            selection.wrappedValue = books[row]
        }
    }
}
